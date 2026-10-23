import XCTest
@testable import WenshuAgent
import Foundation

/// The live tool round: the package's own builders, the real provider.
///
/// Skipped unless `WENSHU_TOOL_ROUND_LIVE=1` (= it costs money and
/// needs a provider key). The key is read from the local provider store
/// at runtime and is never committed.
final class ProviderToolRoundReplayTests: XCTestCase {

    func testProviderAcceptsTheToolRound() async throws {
        guard ProcessInfo.processInfo.environment["WENSHU_TOOL_ROUND_LIVE"] == "1" else {
            throw XCTSkip("set WENSHU_TOOL_ROUND_LIVE=1 to run the live replay")
        }
        let keyFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/com.wenshu.app/provider-keys.json"
            )
        guard let keyData = try? Data(contentsOf: keyFile),
              let object = try? JSONSerialization.jsonObject(with: keyData) as? [String: Any],
              let key = object["minimax-cn"] as? String,
              !key.isEmpty
        else {
            throw XCTSkip("no provider key on this machine")
        }

        let credentials = ConnectorCredentials(
            provider: .minimaxCn,
            apiKey: key,
            baseURL: "https://api.minimaxi.com/anthropic"
        )
        let tools = [
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
        let first: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("List the cards in my library.")])
        ]

        var blocks: [LLMBlock] = []
        let accumulator = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        for await chunk in AnthropicStreamingWireupFactory.streamingStream(
            credentials: credentials,
            model: "MiniMax-M3.1-Flash",
            maxTokens: 1024,
            systemPrompt: "You are a helpful assistant.",
            messages: first,
            tools: tools
        ) {
            if let block = accumulator.ingest(chunk) { blocks.append(block) }
        }

        var results: [LLMBlock] = []
        for block in blocks {
            if case .toolUse(let id, _, _) = block {
                results.append(.toolResult(toolUseID: id, output: "{\"ok\":true}"))
            }
        }
        try XCTSkipIf(results.isEmpty, "the provider did not ask for a tool")

        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: credentials,
            model: "MiniMax-M3.1-Flash",
            maxTokens: 1024,
            systemPrompt: "You are a helpful assistant.",
            messages: first + [
                LLMMessage(role: .assistant, blocks: blocks),
                LLMMessage(role: .user, blocks: results)
            ],
            tools: tools
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        XCTAssertEqual(
            status, 200,
            "the provider rejected the tool round: "
                + (String(data: data, encoding: .utf8) ?? "")
        )
    }
}
