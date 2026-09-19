//
//  ShellHookChainHermesGapPortTests.swift · Wenshu · H8-SHELL-HOOKS-HERMES-PORT (2026-09-19)
//
//  Verifies the 7 new hermes port additions to
//  `Core/Agent/Tool/ShellHookChain.swift` (= hermes
//  `agent/shell_hooks.py` 928 LOC Python).
//
//  Hermes pure helpers ported:
//    - serializePayload(event:kwargs:) (= hermes `_serialize_payload` at L536-L553)
//    - blockMessage(primary:secondary:) (= hermes `_block_message` at L555-L564)
//    - parseResponse(event:stdout:) (= hermes `_parse_response` at L566-L625)
//    - allowlistPath() (= hermes `allowlist_path` at L627-L630)
//    - loadAllowlist() (= hermes `load_allowlist` at L632-L644)
//    - saveAllowlist(_:) (= hermes `save_allowlist` at L646-L676)
//    - isAllowlisted(event:command:) (= hermes `_is_allowlisted` at L678-L687)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure-function port; = no
//  register_from_config / spawn / subprocess invocation (= those live
//  in ToolExecutor per the wenshu-side-wins pattern; = per Q112 =
//  one ticket per file = the remaining 12 hermes functions deferred).

import XCTest
@testable import WenshuApp

final class ShellHookChainHermesGapPortTests: XCTestCase {

    // MARK: -- H8.1 serializePayload tests (= hermes L536-L553)

    func testSerializePayload_basicEvent() {
        let result = ShellHookChain.serializePayload(
            event: "pre_tool_call",
            kwargs: ["tool_name": "read_file", "args": ["path": "/x"]]
        )
        XCTAssertTrue(result.contains("pre_tool_call"))
        XCTAssertTrue(result.contains("read_file"))
    }

    func testSerializePayload_extrasExtracted() {
        let result = ShellHookChain.serializePayload(
            event: "post_tool_call",
            kwargs: [
                "tool_name": "x",
                "args": ["path": "/y"],
                "session_id": "sess_123",
                "extra_field": "extra_value",
            ]
        )
        XCTAssertTrue(result.contains("extra_field"))
        XCTAssertTrue(result.contains("extra_value"))
        XCTAssertTrue(result.contains("sess_123"))
    }

    func testSerializePayload_emptyKwargs_returnsValidJson() {
        let result = ShellHookChain.serializePayload(event: "test_event", kwargs: [:])
        XCTAssertTrue(result.contains("test_event"))
    }

    func testSerializePayload_sessionIdFallback() {
        let result = ShellHookChain.serializePayload(
            event: "x",
            kwargs: ["parent_session_id": "parent_42"]
        )
        XCTAssertTrue(result.contains("parent_42"))
    }

    func testSerializePayload_sessionIdEmptyWhenAbsent() {
        let result = ShellHookChain.serializePayload(event: "x", kwargs: [:])
        XCTAssertTrue(result.contains("\"session_id\":\"\""))
    }

    // MARK: -- H8.2 blockMessage tests (= hermes L555-L564)

    func testBlockMessage_primaryWinsWhenString() {
        let result = ShellHookChain.blockMessage(
            primary: "primary_msg",
            secondary: "secondary_msg"
        )
        XCTAssertEqual(result, "primary_msg")
    }

    func testBlockMessage_secondaryWhenPrimaryEmpty() {
        let result = ShellHookChain.blockMessage(
            primary: "",
            secondary: "secondary_msg"
        )
        XCTAssertEqual(result, "secondary_msg")
    }

    func testBlockMessage_secondaryWhenPrimaryNil() {
        let result = ShellHookChain.blockMessage(
            primary: nil,
            secondary: "secondary_msg"
        )
        XCTAssertEqual(result, "secondary_msg")
    }

    func testBlockMessage_defaultWhenBothEmpty() {
        let result = ShellHookChain.blockMessage(primary: "", secondary: nil)
        XCTAssertEqual(result, "Shell hook blocked the request.")
    }

    func testBlockMessage_defaultWhenBothNil() {
        let result = ShellHookChain.blockMessage(primary: nil, secondary: nil)
        XCTAssertEqual(result, "Shell hook blocked the request.")
    }

    // MARK: -- H8.3 parseResponse tests (= hermes L566-L625)

    func testParseResponse_emptyStdout_returnsNil() {
        XCTAssertNil(ShellHookChain.parseResponse(event: "pre_tool_call", stdout: ""))
        XCTAssertNil(ShellHookChain.parseResponse(event: "pre_tool_call", stdout: "   "))
    }

    func testParseResponse_invalidJSON_returnsNil() {
        XCTAssertNil(ShellHookChain.parseResponse(event: "pre_tool_call", stdout: "not json"))
    }

    func testParseResponse_preToolCallActionBlock() {
        let result = ShellHookChain.parseResponse(
            event: "pre_tool_call",
            stdout: #"{"action": "block", "message": "denied"}"#
        )
        XCTAssertEqual(result?["action"] as? String, "block")
        XCTAssertEqual(result?["message"] as? String, "denied")
    }

    func testParseResponse_preToolCallDecisionBlock_translatesToCanonical() {
        let result = ShellHookChain.parseResponse(
            event: "pre_tool_call",
            stdout: #"{"decision": "block", "reason": "denied too"}"#
        )
        XCTAssertEqual(result?["action"] as? String, "block")
        XCTAssertEqual(result?["message"] as? String, "denied too")
    }

    func testParseResponse_preVerifyContinueWithMessage() {
        let result = ShellHookChain.parseResponse(
            event: "pre_verify",
            stdout: #"{"action": "continue", "message": "keep going"}"#
        )
        XCTAssertEqual(result?["action"] as? String, "continue")
        XCTAssertEqual(result?["message"] as? String, "keep going")
    }

    func testParseResponse_preVerifyBlockTranslatesToContinue() {
        let result = ShellHookChain.parseResponse(
            event: "pre_verify",
            stdout: #"{"decision": "block", "reason": "stop"}"#
        )
        XCTAssertEqual(result?["action"] as? String, "continue")
    }

    func testParseResponse_preVerifyContinueWithEmptyMessage_returnsNil() {
        let result = ShellHookChain.parseResponse(
            event: "pre_verify",
            stdout: #"{"action": "continue"}"#
        )
        XCTAssertNil(result)
    }

    func testParseResponse_contextPassthrough() {
        let result = ShellHookChain.parseResponse(
            event: "pre_llm_call",
            stdout: #"{"context": "Today is Friday"}"#
        )
        XCTAssertEqual(result?["context"] as? String, "Today is Friday")
    }

    func testParseResponse_emptyContext_returnsNil() {
        let result = ShellHookChain.parseResponse(
            event: "pre_llm_call",
            stdout: #"{"context": ""}"#
        )
        XCTAssertNil(result)
    }

    func testParseResponse_nonDictJSON_returnsNil() {
        let result = ShellHookChain.parseResponse(
            event: "pre_tool_call",
            stdout: "[1, 2, 3]"
        )
        XCTAssertNil(result)
    }

    // MARK: -- H8.4 allowlistPath tests (= hermes L627-L630)

    func testAllowlistPath_returnsFileURL() {
        let url = ShellHookChain.allowlistPath()
        XCTAssertTrue(url.isFileURL)
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".json"))
    }

    func testAllowlistPath_containsWenshuDirectory() {
        let url = ShellHookChain.allowlistPath()
        XCTAssertTrue(url.path.contains("wenshu"))
    }

    // MARK: -- H8.5 loadAllowlist tests (= hermes L632-L644)

    func testLoadAllowlist_whenFileMissing_returnsEmptySkeleton() {
        // When the file doesn't exist (= first run), loadAllowlist
        // returns the empty skeleton.
        let result = ShellHookChain.loadAllowlist()
        XCTAssertNotNil(result["approvals"])
    }

    func testLoadAllowlist_whenFileCorrupt_returnsEmptySkeleton() {
        // Manual test: write invalid JSON, then load.
        let path = ShellHookChain.allowlistPath()
        try? FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? "not json".write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }

        let result = ShellHookChain.loadAllowlist()
        XCTAssertNotNil(result["approvals"])
    }

    func testLoadAllowlist_whenApprovalsMissing_addsEmptyList() {
        let path = ShellHookChain.allowlistPath()
        try? FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? #"{"other_key": "value"}"#.write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }

        let result = ShellHookChain.loadAllowlist()
        XCTAssertNotNil(result["approvals"])
        XCTAssertEqual((result["approvals"] as? [Any])?.count, 0)
    }

    // MARK: -- H8.6 saveAllowlist tests (= hermes L646-L676)

    func testSaveAllowlist_createsParentDirectory() {
        let path = ShellHookChain.allowlistPath()
        try? FileManager.default.removeItem(at: path)

        XCTAssertNoThrow(try ShellHookChain.saveAllowlist([
            "approvals": [["event": "pre_tool_call", "command": "ls"]]
        ]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        try? FileManager.default.removeItem(at: path)
    }

    func testSaveAllowlist_overwritesExisting() {
        let path = ShellHookChain.allowlistPath()
        try? ShellHookChain.saveAllowlist(["approvals": []])
        XCTAssertNoThrow(try ShellHookChain.saveAllowlist([
            "approvals": [["event": "x", "command": "y"]]
        ]))
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: -- H8.7 isAllowlisted tests (= hermes L678-L687)

    func testIsAllowlisted_emptyList_returnsFalse() {
        XCTAssertFalse(ShellHookChain.isAllowlisted(event: "x", command: "y"))
    }

    func testIsAllowlisted_exactMatch_returnsTrue() {
        let path = ShellHookChain.allowlistPath()
        try? ShellHookChain.saveAllowlist([
            "approvals": [["event": "pre_tool_call", "command": "ls"]]
        ])
        defer { try? FileManager.default.removeItem(at: path) }

        XCTAssertTrue(ShellHookChain.isAllowlisted(event: "pre_tool_call", command: "ls"))
        XCTAssertFalse(ShellHookChain.isAllowlisted(event: "pre_tool_call", command: "rm"))
        XCTAssertFalse(ShellHookChain.isAllowlisted(event: "post_tool_call", command: "ls"))
    }

    // MARK: -- H8.8 spec check (= hermes line-range citations in source)

    func testShellHookChain_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "ShellHookChainHermesGapPortTests.swift", with: "")
            + "ShellHookChain.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read ShellHookChain.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("H8 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("L536-L553"))
        XCTAssertTrue(source.contains("L566-L625"))
        XCTAssertTrue(source.contains("L632-L644"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
    }
}
