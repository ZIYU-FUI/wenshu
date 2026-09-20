//
//  MessageContentHermesGapPortTests.swift · Wenshu · P11-MESSAGE-CONTENT-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Agent/Conversation/MessageContent.swift`
//  (= hermes `agent/message_content.py` 50 LOC Python).
//
//  Hermes pure helpers ported:
//    - flattenMessageText(_:sep:) (= hermes
//      `flatten_message_text` at L34-L50)
//    - internal field(_:key:) (= hermes `_field` at L11-L15)
//    - internal textFromPart(_:) (= hermes
//      `_text_from_part` at L17-L32)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; =
//  wenshu-side canonicalize + coalesceAdjacentText preserved
//  (= Q112 no regressions; = the LLMBlock-level layer
//  remains the wenshu-side source of truth).
//

import XCTest
@testable import WenshuApp

final class MessageContentHermesGapPortTests: XCTestCase {

    // MARK: -- P11.1 flattenMessageText tests (= hermes L34-L50)

    func testFlattenMessageText_nil_returnsEmpty() {
        XCTAssertEqual(MessageContent.flattenMessageText(NSNull()), "")
    }

    func testFlattenMessageText_string_returnsVerbatim() {
        XCTAssertEqual(
            MessageContent.flattenMessageText("hello world"),
            "hello world"
        )
    }

    func testFlattenMessageText_emptyString_returnsEmpty() {
        XCTAssertEqual(MessageContent.flattenMessageText(""), "")
    }

    func testFlattenMessageText_listOfTextParts_joinedWithNewline() {
        let parts: [Any] = [
            "hello",
            "world",
        ]
        XCTAssertEqual(
            MessageContent.flattenMessageText(parts),
            "hello\nworld"
        )
    }

    func testFlattenMessageText_listWithImage_dropsImagePart() {
        let parts: [Any] = [
            "before",
            ["type": "image_url", "image_url": ["url": "https://x.com/y.png"]],
            "after",
        ]
        let result = MessageContent.flattenMessageText(parts)
        XCTAssertEqual(result, "before\nafter")
    }

    func testFlattenMessageText_listWithAudio_dropsAudioPart() {
        let parts: [Any] = [
            "text",
            ["type": "audio", "data": "x"],
            "more",
        ]
        let result = MessageContent.flattenMessageText(parts)
        XCTAssertEqual(result, "text\nmore")
    }

    func testFlattenMessageText_listWithInputImage_dropsPart() {
        let parts: [Any] = [
            "text",
            ["type": "input_image", "data": "x"],
            "more",
        ]
        let result = MessageContent.flattenMessageText(parts)
        XCTAssertEqual(result, "text\nmore")
    }

    func testFlattenMessageText_dictWithTextKey_extractsText() {
        let content: [String: Any] = ["type": "text", "text": "hello"]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "hello")
    }

    func testFlattenMessageText_dictWithContentKey_extractsContent() {
        let content: [String: Any] = ["type": "text", "content": "hello"]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "hello")
    }

    func testFlattenMessageText_dictWithInputTextKey_extractsText() {
        let content: [String: Any] = [
            "type": "tool_result",
            "input_text": "tool input",
        ]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "tool input")
    }

    func testFlattenMessageText_dictWithOutputTextKey_extractsText() {
        let content: [String: Any] = [
            "type": "tool_use",
            "output_text": "tool output",
        ]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "tool output")
    }

    func testFlattenMessageText_dictWithSummaryTextKey_extractsText() {
        let content: [String: Any] = [
            "type": "summary",
            "summary_text": "summary content",
        ]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "summary content")
    }

    func testFlattenMessageText_imageDict_returnsEmpty() {
        let content: [String: Any] = [
            "type": "image_url",
            "image_url": ["url": "https://x.com/y.png"],
        ]
        XCTAssertEqual(MessageContent.flattenMessageText(content), "")
    }

    func testFlattenMessageText_customSeparator() {
        let parts: [Any] = ["a", "b", "c"]
        XCTAssertEqual(
            MessageContent.flattenMessageText(parts, sep: " | "),
            "a | b | c"
        )
    }

    func testFlattenMessageText_listEmptyPartsDropped() {
        // Empty parts in list are dropped (= hermes
        // `_text_from_part` returns "" → join filter).
        let parts: [Any] = ["a", "", "b"]
        XCTAssertEqual(MessageContent.flattenMessageText(parts), "a\nb")
    }

    func testFlattenMessageText_unknownContentReturnsStringFallback() {
        // Unknown content type → str() fallback per
        // hermes L48-L50.
        let content: [String: Any] = ["custom": "x"]
        let result = MessageContent.flattenMessageText(content)
        // The fallback uses String(describing: content) which
        // returns a dict-like description. We just verify
        // it's non-empty.
        XCTAssertFalse(result.isEmpty)
    }

    func testFlattenMessageText_dictMissingTextKeys_usesStringFallback() {
        // Dict without any text key falls through to the
        // str() fallback path.
        let content: [String: Any] = ["type": "unknown"]
        let result = MessageContent.flattenMessageText(content)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: -- P11.2 pre-existing API preservation (= Q112 no regressions)

    func testCanonicalize_stillWorks() {
        let blocks: [LLMBlock] = [
            .text(""),
            .text("hello"),
            .thinking(text: "secret", signature: nil),
        ]
        let result = MessageContent.canonicalize(blocks)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.textValue, "hello")
    }

    func testCoalesceAdjacentText_stillWorks() {
        let blocks: [LLMBlock] = [
            .text("hello "),
            .text("world"),
        ]
        let result = MessageContent.coalesceAdjacentText(blocks)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.textValue, "hello world")
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        // v1.57 stale-helper: per wenshu-stale-test-cleanup Class A recipe.
        guard let source = HermesGapPortTestHelpers.readSource(
            relativeToTest: #filePath,
            sourceFileName: "MessageContent.swift"
        ) else {
            XCTFail("HermesGapPortTestHelpers could not locate MessageContent.swift")
            return
        }
        XCTAssertTrue(source.contains("P11 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("agent/message_content.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("flattenMessageText"))
        XCTAssertTrue(source.contains("L11-L15"))
        XCTAssertTrue(source.contains("L17-L32"))
        XCTAssertTrue(source.contains("L34-L50"))
    }
}
