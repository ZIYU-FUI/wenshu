//
//  ToolResultClassificationHermesGapPortTests.swift · Wenshu · P2-TOOL-RESULT-CLASSIFICATION-HERMES-PORT (2026-09-19)
//
//  Verifies the new hermes port addition to
//  `Core/Agent/Tool/ToolResultClassification.swift`
//  (= hermes `agent/tool_result_classification.py` 26 LOC
//  Python).
//
//  Hermes-side pure helpers ported (= the file_mutation_result_landed
//  function + FILE_MUTATING_TOOL_NAMES constant).
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure-function port;
//  = wenshus FileTools owns the actual file mutation layer.

import XCTest
@testable import WenshuApp

final class ToolResultClassificationHermesGapPortTests: XCTestCase {

    // MARK: -- fileMutationResultLanded tests (= hermes L12-L25)

    func testFileMutationResultLanded_writeFileSuccess() {
        let result = #"{"bytes_written": 1024, "path": "/tmp/foo.txt"}"#
        XCTAssertTrue(fileMutationResultLanded(toolName: "write_file", result: result))
    }

    func testFileMutationResultLanded_writeFileMissingBytesWritten() {
        let result = #"{"path": "/tmp/foo.txt"}"#
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: result))
    }

    func testFileMutationResultLanded_writeFileWithError() {
        let result = #"{"error": "permission denied", "bytes_written": 0}"#
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: result))
    }

    func testFileMutationResultLanded_patchSuccess() {
        let result = #"{"success": true, "patched_lines": 5}"#
        XCTAssertTrue(fileMutationResultLanded(toolName: "patch", result: result))
    }

    func testFileMutationResultLanded_patchSuccessFalse() {
        let result = #"{"success": false, "error": "patch failed"}"#
        XCTAssertFalse(fileMutationResultLanded(toolName: "patch", result: result))
    }

    func testFileMutationResultLanded_patchMissingSuccess() {
        let result = #"{"patched_lines": 5}"#
        XCTAssertFalse(fileMutationResultLanded(toolName: "patch", result: result))
    }

    func testFileMutationResultLanded_unknownTool() {
        let result = #"{"bytes_written": 1024}"#
        XCTAssertFalse(fileMutationResultLanded(toolName: "read_file", result: result))
    }

    func testFileMutationResultLanded_nonStringResult() {
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: 42))
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: ["bytes_written": 1024] as [String: Any]))
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: NSNull()))
    }

    func testFileMutationResultLanded_invalidJSON() {
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: "not json"))
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: "{\"unclosed"))
    }

    func testFileMutationResultLanded_jsonArrayNotDict() {
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: "[1, 2, 3]"))
    }

    func testFileMutationResultLanded_whitespaceTrimmed() {
        let result = "  \n  {\"bytes_written\": 1024}  \n  "
        XCTAssertTrue(fileMutationResultLanded(toolName: "write_file", result: result))
    }

    func testFileMutationResultLanded_emptyString() {
        XCTAssertFalse(fileMutationResultLanded(toolName: "write_file", result: ""))
    }

    // MARK: -- fileMutatingToolNames tests (= hermes L9)

    func testFileMutatingToolNames_containsWriteFileAndPatch() {
        XCTAssertTrue(fileMutatingToolNames.contains("write_file"))
        XCTAssertTrue(fileMutatingToolNames.contains("patch"))
    }

    func testFileMutatingToolNames_doesNotContainReadFile() {
        XCTAssertFalse(fileMutatingToolNames.contains("read_file"))
    }

    func testFileMutatingToolNames_countMatchesHermes() {
        XCTAssertEqual(fileMutatingToolNames.count, 2)
    }

    // MARK: -- Spec check (= hermes line-range citations in source)

    func testSourceFile_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "ToolResultClassificationHermesGapPortTests.swift", with: "")
            + "ToolResultClassification.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read ToolResultClassification.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("P2-TOOL-RESULT-CLASSIFICATION-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/tool_result_classification.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("fileMutationResultLanded"))
    }
}
