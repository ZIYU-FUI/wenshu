//
//  AnthropicAdapterHermesGapPortTests.swift · Wenshu · P5-ANTHROPIC-ADAPTER-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Agent/Connector/AnthropicStreamingChunkToLLMBlock.swift`
//  (= hermes `agent/anthropic_adapter.py` 2789 LOC Python).
//
//  Hermes pure helpers ported:
//    - extractPreservedThinkingBlocks(_:) (= hermes
//      `_extract_preserved_thinking_blocks` at L1800-L1820)
//    - convertContentToAnthropic(_:) (= hermes
//      `_convert_content_to_anthropic` at L1822-L1834)
//    - convertContentPartToAnthropic(_:) (= hermes
//      `_convert_content_part_to_anthropic` at L1836-L1866)
//    - sanitizeReplayBlock(_:) (= hermes
//      `_sanitize_replay_block` at L1868-L1916)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  OAuth/credential handling (= ProviderKeychain owns the
//  macOS Keychain layer per AGENTS.md §11).
//

import XCTest
@testable import WenshuApp

final class AnthropicAdapterHermesGapPortTests: XCTestCase {

    // MARK: -- P5.1 extractPreservedThinkingBlocks tests (= hermes L1800-L1820)

    func testExtractPreservedThinkingBlocks_emptyMessage() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks([:])
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractPreservedThinkingBlocks_noReasoningDetails() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["role": "assistant", "content": "hello"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractPreservedThinkingBlocks_thinkingBlockPreserved() {
        let detail: [String: Any] = [
            "type": "thinking",
            "thinking": "Let me think...",
            "signature": "abc123"
        ]
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": [detail]]
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?["type"] as? String, "thinking")
        XCTAssertEqual(result.first?["thinking"] as? String, "Let me think...")
        XCTAssertEqual(result.first?["signature"] as? String, "abc123")
    }

    func testExtractPreservedThinkingBlocks_redactedThinkingPreserved() {
        let detail: [String: Any] = [
            "type": "redacted_thinking",
            "data": "encrypted-blob"
        ]
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": [detail]]
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?["type"] as? String, "redacted_thinking")
        XCTAssertEqual(result.first?["data"] as? String, "encrypted-blob")
    }

    func testExtractPreservedThinkingBlocks_unknownTypeDropped() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": [
                ["type": "tool_use", "id": "x", "name": "y", "input": [:]]
            ]]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractPreservedThinkingBlocks_caseInsensitive() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": [["type": "THINKING", "thinking": "x"]]]
        )
        XCTAssertEqual(result.count, 1)
    }

    func testExtractPreservedThinkingBlocks_nonDictEntriesDropped() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": ["string-not-dict", ["type": "thinking"]]]
        )
        XCTAssertEqual(result.count, 1)
    }

    func testExtractPreservedThinkingBlocks_mixedTypesKeepsBoth() {
        let result = AnthropicChunkToLLMBlockConverter.extractPreservedThinkingBlocks(
            ["reasoning_details": [
                ["type": "thinking", "thinking": "x"],
                ["type": "redacted_thinking", "data": "y"],
            ]]
        )
        XCTAssertEqual(result.count, 2)
    }

    // MARK: -- P5.2 convertContentToAnthropic tests (= hermes L1822-L1834)

    func testConvertContentToAnthropic_nonListPassthrough() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic("plain string")
        XCTAssertEqual(result as? String, "plain string")
    }

    func testConvertContentToAnthropic_textPart() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [["type": "text", "text": "hello"]]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?["type"] as? String, "text")
        XCTAssertEqual(result?.first?["text"] as? String, "hello")
    }

    func testConvertContentToAnthropic_imageUrlPart() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [["type": "image_url", "image_url": ["url": "https://x.com/y.png"]]]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?["type"] as? String, "image")
        XCTAssertEqual(((result?.first?["source"] as? [String: Any])?["url"] as? String), "https://x.com/y.png")
    }

    func testConvertContentToAnthropic_anthropicImageSourcePart() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": "x"]]]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?["type"] as? String, "image")
    }

    func testConvertContentToAnthropic_documentPart() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [["type": "document", "source": ["type": "base64", "media_type": "application/pdf", "data": "x"]]]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?["type"] as? String, "document")
    }

    func testConvertContentToAnthropic_plainStringPart() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            ["just a string"]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?["type"] as? String, "text")
        XCTAssertEqual(result?.first?["text"] as? String, "just a string")
    }

    func testConvertContentToAnthropic_unknownTypeDropped() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [["type": "unknown_type", "data": "x"]]
        ) as? [[String: Any]]
        XCTAssertTrue(result?.isEmpty ?? true)
    }

    func testConvertContentToAnthropic_mixedParts() {
        let result = AnthropicChunkToLLMBlockConverter.convertContentToAnthropic(
            [
                ["type": "text", "text": "hello"],
                ["type": "image_url", "image_url": ["url": "https://x.com/y.png"]],
                ["type": "unknown", "data": "dropped"],
            ]
        ) as? [[String: Any]]
        XCTAssertEqual(result?.count, 2)
    }

    // MARK: -- P5.3 sanitizeReplayBlock tests (= hermes L1868-L1916)

    func testSanitizeReplayBlock_textBlock() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "text", "text": "hello"]
        )
        XCTAssertEqual(result?["type"] as? String, "text")
        XCTAssertEqual(result?["text"] as? String, "hello")
    }

    func testSanitizeReplayBlock_textBlockPreservesCitations() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "text", "text": "x", "citations": [["url": "y"]]]
        )
        XCTAssertNotNil(result?["citations"])
    }

    func testSanitizeReplayBlock_textBlockDropsEmptyCitations() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "text", "text": "x", "citations": []]
        )
        XCTAssertNil(result?["citations"])
    }

    func testSanitizeReplayBlock_textBlockDropsOutputOnlyFields() {
        // parsed_output is an output-only field (= hermes
        // L1877-L1880) and must NOT survive into replay input.
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "text", "text": "x", "parsed_output": "must-be-dropped"]
        )
        XCTAssertNil(result?["parsed_output"])
    }

    func testSanitizeReplayBlock_thinkingBlockPreservesSignature() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "thinking", "thinking": "reasoning...", "signature": "sig-xyz"]
        )
        XCTAssertEqual(result?["type"] as? String, "thinking")
        XCTAssertEqual(result?["thinking"] as? String, "reasoning...")
        XCTAssertEqual(result?["signature"] as? String, "sig-xyz")
    }

    func testSanitizeReplayBlock_thinkingBlockOmitsEmptySignature() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "thinking", "thinking": "x", "signature": ""]
        )
        XCTAssertNil(result?["signature"])
    }

    func testSanitizeReplayBlock_redactedThinkingWithData() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "redacted_thinking", "data": "encrypted-blob"]
        )
        XCTAssertEqual(result?["type"] as? String, "redacted_thinking")
        XCTAssertEqual(result?["data"] as? String, "encrypted-blob")
    }

    func testSanitizeReplayBlock_redactedThinkingWithoutDataDropped() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "redacted_thinking"]
        )
        XCTAssertNil(result)
    }

    func testSanitizeReplayBlock_redactedThinkingWithEmptyDataDropped() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "redacted_thinking", "data": ""]
        )
        XCTAssertNil(result)
    }

    func testSanitizeReplayBlock_toolUseBlock() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "tool_use", "id": "t1", "name": "read_file", "input": ["path": "/x"]]
        )
        XCTAssertEqual(result?["type"] as? String, "tool_use")
        XCTAssertEqual(result?["id"] as? String, "t1")
        XCTAssertEqual(result?["name"] as? String, "read_file")
    }

    func testSanitizeReplayBlock_toolUseBlockDropsCaller() {
        // caller is an output-only field (= hermes L1901)
        // and must NOT survive into replay input.
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "tool_use", "id": "t1", "name": "x", "input": [:], "caller": "must-be-dropped"]
        )
        XCTAssertNil(result?["caller"])
    }

    func testSanitizeReplayBlock_toolUseBlockPreservesCacheControl() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "tool_use", "id": "t1", "name": "x", "input": [:], "cache_control": ["type": "ephemeral"]]
        )
        XCTAssertNotNil(result?["cache_control"])
    }

    func testSanitizeReplayBlock_unknownTypeDropped() {
        // Whitelist pattern: unknown types are dropped (= hermes
        // explicitly chose whitelist over blacklist so future
        // Anthropic SDK output-only fields cannot reintroduce
        // the bug).
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "future_anthropic_block_type", "data": "x"]
        )
        XCTAssertNil(result)
    }

    func testSanitizeReplayBlock_textBlockPreservesCacheControl() {
        let result = AnthropicChunkToLLMBlockConverter.sanitizeReplayBlock(
            ["type": "text", "text": "x", "cache_control": ["type": "ephemeral"]]
        )
        XCTAssertNotNil(result?["cache_control"])
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "AnthropicAdapterHermesGapPortTests.swift", with: "")
            + "AnthropicStreamingChunkToLLMBlock.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read AnthropicStreamingChunkToLLMBlock.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("P5-ANTHROPIC-ADAPTER-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/anthropic_adapter.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("extractPreservedThinkingBlocks"))
        XCTAssertTrue(source.contains("convertContentToAnthropic"))
        XCTAssertTrue(source.contains("sanitizeReplayBlock"))
    }
}
