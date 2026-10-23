import XCTest
@testable import WenshuAgent
import Foundation

/// The wire level of the tool round: the request body the provider
/// actually receives must carry an object `tool_use.input` and a
/// `tool_result.content`.
final class AnthropicToolRoundWireTests: XCTestCase {

    private func wireBody(
        messages: [LLMMessage]
    ) throws -> [String: Any] {
        let credentials = ConnectorCredentials(
            provider: .minimaxCn,
            apiKey: "test-key-not-a-secret",
            baseURL: "https://example.invalid"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: credentials,
            model: "test-model",
            maxTokens: 64,
            systemPrompt: "system",
            messages: messages,
            tools: []
        )
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    func testToolRoundBodyCarriesAnObjectInput() throws {
        let body = try wireBody(messages: [
            LLMMessage(role: .user, blocks: [.text("go")]),
            LLMMessage(role: .assistant, blocks: [
                .toolUse(id: "call_1", name: "file", input: "{\"op\":\"read\"}")
            ]),
            LLMMessage(role: .user, blocks: [
                .toolResult(toolUseID: "call_1", output: "{\"ok\":true}")
            ])
        ])

        let wireMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(wireMessages.count, 3)

        let assistantBlocks = try XCTUnwrap(
            wireMessages[1]["content"] as? [[String: Any]]
        )
        let toolUse = try XCTUnwrap(assistantBlocks[0])
        XCTAssertEqual(toolUse["type"] as? String, "tool_use")
        XCTAssertTrue(
            toolUse["input"] is [String: Any],
            "the provider rejects a string here (= 2013)"
        )
        XCTAssertEqual(
            (toolUse["input"] as? [String: Any])?["op"] as? String, "read"
        )

        let resultBlocks = try XCTUnwrap(
            wireMessages[2]["content"] as? [[String: Any]]
        )
        let toolResult = try XCTUnwrap(resultBlocks[0])
        XCTAssertEqual(toolResult["type"] as? String, "tool_result")
        XCTAssertEqual(toolResult["content"] as? String, "{\"ok\":true}")
        XCTAssertNil(toolResult["output"])
    }

    func testEveryToolUseInATurnIsAnObject() throws {
        let body = try wireBody(messages: [
            LLMMessage(role: .user, blocks: [.text("go")]),
            LLMMessage(role: .assistant, blocks: [
                .toolUse(id: "call_1", name: "a", input: "{\"x\":1}"),
                .toolUse(id: "call_2", name: "b", input: "{\"y\":2}")
            ])
        ])
        let wireMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let blocks = try XCTUnwrap(wireMessages[1]["content"] as? [[String: Any]])
        for block in blocks {
            XCTAssertTrue(block["input"] is [String: Any])
        }
    }
}
