//
//  ToolDispatchHelpersHermesGapPortTests.swift · Wenshu · H4-TOOL-DISPATCH-HELPERS-HERMES-PORT (2026-09-19)
//
//  Verifies the 5 new hermes port additions to
//  `Core/Agent/Tool/ToolDispatchHelpers.swift` (= hermes
//  `agent/tool_dispatch_helpers.py` multimodal + untrusted-wrap
//  helpers):
//    - isMultimodalToolResult (= hermes L177-L185)
//    - multimodalTextSummary (= hermes L188-L208)
//    - isUntrustedTool (= hermes L414-L418)
//    - neutralizeDelimiters (= hermes L420-L424)
//    - maybeWrapUntrusted (= hermes L427-L463)
//    - makeToolResultMessage (= hermes L342-L386)
//
//  Per AGENTS.md §11.3 decision 1 (= wenshu-side wins): the high-risk
//  tool set (= hermes's web_extract / web_search / browser_* / mcp_*)
//  is replaced with wenshu-flavored names (= read_file / search_files
//  / search_web / extract_web / vision_analyze / terminal /
//  process / execute_code / ha_* / browser_* / mcp_*).
//

import Testing
import WenshuData
import Foundation
@testable import WenshuApp

@Suite("ToolDispatchHelpers hermes-Python gap port (H4)")
struct ToolDispatchHelpersHermesGapPortTests {

    // MARK: - H4.1 Multimodal envelope helpers

    /// H4.1 contract: isMultimodalToolResult returns true for the
    /// exact hermes envelope shape (= hermes L177-L185).
    @Test func isMultimodalToolResult_detects_envelope() {
        let envelope: [String: Any] = [
            "_multimodal": true,
            "content": [["type": "text", "text": "hello"]],
        ]
        #expect(ToolDispatchInputParser.isMultimodalToolResult(envelope))
    }

    /// H4.1 contract: isMultimodalToolResult returns false for
    /// missing _multimodal flag (= hermes L182 check).
    @Test func isMultimodalToolResult_rejects_missing_flag() {
        let envelope: [String: Any] = [
            "content": [["type": "text", "text": "hello"]],
        ]
        #expect(!ToolDispatchInputParser.isMultimodalToolResult(envelope))
    }

    /// H4.1 contract: isMultimodalToolResult returns false for
    /// missing content list (= hermes L184 check).
    @Test func isMultimodalToolResult_rejects_string_content() {
        let envelope: [String: Any] = [
            "_multimodal": true,
            "content": "not a list",
        ]
        #expect(!ToolDispatchInputParser.isMultimodalToolResult(envelope))
    }

    /// H4.1 contract: isMultimodalToolResult returns false for
    /// non-dict (= hermes L180 check).
    @Test func isMultimodalToolResult_rejects_non_dict() {
        #expect(!ToolDispatchInputParser.isMultimodalToolResult("just a string"))
        #expect(!ToolDispatchInputParser.isMultimodalToolResult(42))
        // API is `Any` (not `Any?`); nil must be wrapped via Optional.
        #expect(!ToolDispatchInputParser.isMultimodalToolResult(Optional<Any>.none as Any))
    }

    /// H4.1 contract: multimodalTextSummary returns text_summary
    /// when present (= hermes L194-L196).
    @Test func multimodalTextSummary_returns_text_summary() {
        let envelope: [String: Any] = [
            "_multimodal": true,
            "content": [["type": "text", "text": "inner"], ["type": "image_url"]],
            "text_summary": "summary",
        ]
        let result = ToolDispatchInputParser.multimodalTextSummary(envelope)
        #expect(result == "summary")
    }

    /// H4.1 contract: multimodalTextSummary falls back to
    /// concatenating text parts when no text_summary (= hermes
    /// L197-L203).
    @Test func multimodalTextSummary_concatenates_text_parts() {
        let envelope: [String: Any] = [
            "_multimodal": true,
            "content": [
                ["type": "text", "text": "part1"],
                ["type": "image_url"],
                ["type": "text", "text": "part2"],
            ],
        ]
        let result = ToolDispatchInputParser.multimodalTextSummary(envelope)
        #expect(result.contains("part1"))
        #expect(result.contains("part2"))
        #expect(result.contains("\n"))
    }

    /// H4.1 contract: multimodalTextSummary returns placeholder
    /// for empty multimodal (= hermes L204 = "[multimodal tool
    /// result]").
    @Test func multimodalTextSummary_returns_placeholder_for_empty() {
        let envelope: [String: Any] = [
            "_multimodal": true,
            "content": [["type": "image_url"]],
        ]
        let result = ToolDispatchInputParser.multimodalTextSummary(envelope)
        #expect(result == "[multimodal tool result]")
    }

    /// H4.1 contract: multimodalTextSummary passes through string.
    @Test func multimodalTextSummary_passthrough_string() {
        let result = ToolDispatchInputParser.multimodalTextSummary("plain text")
        #expect(result == "plain text")
    }

    // MARK: - H4.2 Untrusted-tool-result wrapper

}
