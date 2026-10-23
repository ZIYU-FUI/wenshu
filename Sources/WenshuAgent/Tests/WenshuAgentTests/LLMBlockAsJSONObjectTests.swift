import XCTest
@testable import WenshuAgent

/// The Anthropic wire needs `tool_use.input` as a JSON OBJECT.
///
/// Measured 2026-10-24: the live serializer sent the raw JSON string,
/// so the provider rejected every tool round ("Input should be a valid
/// dictionary" = MiniMax 2013) and the chat answered "temporarily
/// unable to reply" for every question that needed a tool.
final class LLMBlockAsJSONObjectTests: XCTestCase {

    func testToolUseInputIsAnObject() {
        let json = LLMBlock.toolUse(
            id: "call_1", name: "file", input: "{\"op\":\"read\",\"pattern\":\"AGENTS.md\"}"
        ).asJSONObject

        XCTAssertEqual(json["type"] as? String, "tool_use")
        let input = json["input"]
        XCTAssertTrue(
            input is [String: Any],
            "tool_use.input must be an object, not \(type(of: input))"
        )
        let object = input as? [String: Any]
        XCTAssertEqual(object?["op"] as? String, "read")
        XCTAssertEqual(object?["pattern"] as? String, "AGENTS.md")
    }

    func testToolUseInputIsNeverAString() {
        // The exact defect: the raw text went on the wire as a string.
        for input in ["{\"a\":1}", "", "not json", "[1,2]", "\"quoted\""] {
            let json = LLMBlock.toolUse(id: "x", name: "y", input: input).asJSONObject
            XCTAssertFalse(
                json["input"] is String,
                "input=\(input) must not serialize as a string"
            )
            XCTAssertTrue(json["input"] is [String: Any])
        }
    }

    func testToolUseInputFallsBackToRawText() {
        // Unparseable input keeps the text (= the package's other
        // serializer's convention) instead of dropping the arguments.
        let json = LLMBlock.toolUse(id: "x", name: "y", input: "not json").asJSONObject
        let object = json["input"] as? [String: Any]
        XCTAssertEqual(object?["_raw"] as? String, "not json")
    }

    func testToolResultUsesTheAnthropicContentKey() {
        // `output` is not part of the Messages API: the provider ignored
        // it, so the tool result never reached the model.
        let json = LLMBlock.toolResult(toolUseID: "call_1", output: "{\"ok\":true}").asJSONObject
        XCTAssertEqual(json["type"] as? String, "tool_result")
        XCTAssertEqual(json["tool_use_id"] as? String, "call_1")
        XCTAssertEqual(json["content"] as? String, "{\"ok\":true}")
        XCTAssertNil(json["output"])
    }
}
