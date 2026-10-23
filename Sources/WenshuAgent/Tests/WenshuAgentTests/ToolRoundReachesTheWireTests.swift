import XCTest
@testable import WenshuAgent
import Foundation

/// The interface-level proof of the tool round.
///
/// The REAL conversation loop produces the messages (= a scripted
/// connector records what the loop asked), the REAL wire builder turns
/// those messages into the request body, and the body is checked for
/// the two shapes the provider rejects.
///
/// Measured 2026-10-24: the provider answered HTTP 400 with
/// "invalid params, messages.1.content.N.tool_use.input: Input should
/// be a valid dictionary (2013)" for the string form of `input`, and
/// ignored the tool result when it sat under "output" (= not a key of
/// the Messages API).
final class ToolRoundReachesTheWireTests: XCTestCase {

    /// A connector that records the message list it was handed and
    /// answers with a scripted turn: a tool call first, then text.
    private final class ScriptedConnector: LLMConnector, @unchecked Sendable {
        let connectorID = "scripted"
        let contextWindow = 32_000

        private let lock = NSLock()
        private var recorded: [[LLMMessage]] = []

        var calls: [[LLMMessage]] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }

        func send(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) async throws -> LLMResponse {
            LLMResponse(blocks: [.text("unused")])
        }

        nonisolated func stream(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) -> AsyncStream<LLMBlock> {
            lock.lock()
            recorded.append(messages)
            let turn = recorded.count
            lock.unlock()
            return AsyncStream { continuation in
                if turn == 1 {
                    continuation.yield(.toolUse(
                        id: "call_1",
                        name: "reference_library",
                        input: "{\"action\":\"list\"}"
                    ))
                } else {
                    continuation.yield(.text("The library has no cards yet."))
                }
                continuation.finish()
            }
        }
    }

    /// A tool that answers without touching the disk.
    private struct EchoTool: Tool {
        func execute(input: String) async throws -> String { "{\"ok\":true}" }
    }

    func testTheLoopToolRoundReachesTheWireInTheProviderShape() async throws {
        let connector = ScriptedConnector()
        let loop = ConversationLoop(connection: connector, systemPrompt: "system")
        let schemas = [
            ToolRegistrySchema(
                name: "reference_library",
                description: "Query the reference library.",
                inputSchema: [
                    "action": ToolRegistrySchemaProperty(
                        type: "string", description: "action")
                ],
                required: ["action"]
            )
        ]

        _ = try await loop.runTurn(
            userMessage: "List the cards in my library.",
            tools: ["reference_library": EchoTool()],
            toolSchemas: schemas
        )

        // The round that carries the tool call (= the list the provider
        // receives with the tool result attached).
        let toolRound = try XCTUnwrap(connector.calls.first { call in
            call.contains { message in
                message.blocks.contains { block in
                    if case .toolUse = block { return true } else { return false }
                }
            }
        })

        // The REAL wire builder, on the REAL message list.
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: ConnectorCredentials(
                provider: .minimaxCn,
                apiKey: "test-key-not-a-secret",
                baseURL: "https://example.invalid"
            ),
            model: "test-model",
            maxTokens: 64,
            systemPrompt: "system",
            messages: toolRound,
            tools: schemas
        )
        let data = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let wireMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])

        // The assistant turn carries the tool call.
        let assistant = try XCTUnwrap(wireMessages.first { message in
            message["role"] as? String == "assistant"
        })
        let assistantBlocks = try XCTUnwrap(assistant["content"] as? [[String: Any]])
        let toolUse = try XCTUnwrap(assistantBlocks.first { block in
            block["type"] as? String == "tool_use"
        })
        XCTAssertEqual(toolUse["id"] as? String, "call_1")
        XCTAssertEqual(toolUse["name"] as? String, "reference_library")
        // The exact shape the provider rejects: a string.
        XCTAssertTrue(
            toolUse["input"] is [String: Any],
            "tool_use.input must be an object on the wire, not a string"
        )
        XCTAssertEqual(
            (toolUse["input"] as? [String: Any])?["action"] as? String, "list"
        )

        // The tool result carries the answer, under the key the
        // Messages API defines, and it is paired with the call.
        let resultMessage = try XCTUnwrap(wireMessages.first { message in
            guard message["role"] as? String == "user" else { return false }
            let blocks = message["content"] as? [[String: Any]] ?? []
            return blocks.contains { $0["type"] as? String == "tool_result" }
        })
        let resultBlocks = try XCTUnwrap(resultMessage["content"] as? [[String: Any]])
        let toolResult = try XCTUnwrap(resultBlocks.first { block in
            block["type"] as? String == "tool_result"
        })
        XCTAssertEqual(toolResult["tool_use_id"] as? String, "call_1")
        XCTAssertEqual(toolResult["content"] as? String, "{\"ok\":true}")
        XCTAssertNil(toolResult["output"], "'output' is not a key of the Messages API")
    }
}
