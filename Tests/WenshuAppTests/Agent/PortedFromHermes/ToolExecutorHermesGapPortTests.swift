//
//  ToolExecutorHermesGapPortTests.swift · Wenshu · P6-TOOL-EXECUTOR-HERMES-PORT (2026-09-19)
//
//  Verifies the 2 new hermes port additions to
//  `Core/Agent/Tool/ToolExecutor.swift` (= hermes
//  `agent/tool_executor.py` 1646 LOC Python).
//
//  Hermes pure helpers ported:
//    - isInterpreterShutdownSubmitError(_:) (= hermes
//      `_is_interpreter_shutdown_submit_error` at L120-L123)
//    - cancelledToolResultJSON(reason:) (= hermes
//      `_cancelled_tool_result` at L159-L167)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  execute_tool_calls_concurrent / _sequential (= those live
//  in ToolExecutor actor per the wenshu-side-wins pattern; = the
//  remaining 7 hermes helpers are actor-state-bound and don't
//  belong in a top-level pure function).

import XCTest
@testable import WenshuApp

final class ToolExecutorHermesGapPortTests: XCTestCase {

    // MARK: -- P6.1 isInterpreterShutdownSubmitError tests (= hermes L120-L123)

    func testIsInterpreterShutdownSubmitError_shutdownError_returnsTrue() {
        let error = NSError(
            domain: "RuntimeError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "cannot schedule new futures after interpreter shutdown"]
        )
        XCTAssertTrue(ToolExecutor.isInterpreterShutdownSubmitError(error))
    }

    func testIsInterpreterShutdownSubmitError_unrelatedError_returnsFalse() {
        let error = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Some other error"]
        )
        XCTAssertFalse(ToolExecutor.isInterpreterShutdownSubmitError(error))
    }

    func testIsInterpreterShutdownSubmitError_partialMatch() {
        // The hermes check uses substring match. The
        // signature can appear anywhere in the error
        // message (= wrapped errors).
        let error = NSError(
            domain: "RuntimeError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "RuntimeError: cannot schedule new futures after interpreter shutdown; please retry"]
        )
        XCTAssertTrue(ToolExecutor.isInterpreterShutdownSubmitError(error))
    }

    func testIsInterpreterShutdownSubmitError_emptyError_returnsFalse() {
        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: ""])
        XCTAssertFalse(ToolExecutor.isInterpreterShutdownSubmitError(error))
    }

    // MARK: -- P6.2 cancelledToolResultJSON tests (= hermes L159-L167)

    func testCancelledToolResultJSON_defaultReason() {
        let json = ToolExecutor.cancelledToolResultJSON()
        XCTAssertTrue(json.contains("\"error\""))
        XCTAssertTrue(json.contains("\"status\":\"cancelled\""))
        XCTAssertTrue(json.contains("user interrupt"))
    }

    func testCancelledToolResultJSON_customReason() {
        let json = ToolExecutor.cancelledToolResultJSON(reason: "system shutdown")
        XCTAssertTrue(json.contains("system shutdown"))
        XCTAssertTrue(json.contains("cancelled"))
    }

    func testCancelledToolResultJSON_parsesAsValidJSON() {
        let json = ToolExecutor.cancelledToolResultJSON(reason: "ctrl-c")
        let data = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?["status"] as? String, "cancelled")
        XCTAssertEqual(parsed?["error"] as? String, "Tool execution cancelled by ctrl-c")
    }

    func testCancelledToolResultJSON_emptyReason() {
        let json = ToolExecutor.cancelledToolResultJSON(reason: "")
        XCTAssertTrue(json.contains("cancelled by "))
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        // v1.57 stale-helper: per wenshu-stale-test-cleanup Class A recipe.
        guard let source = HermesGapPortTestHelpers.readSource(
            relativeToTest: #filePath,
            sourceFileName: "ToolExecutor.swift"
        ) else {
            XCTFail("HermesGapPortTestHelpers could not locate ToolExecutor.swift")
            return
        }
        XCTAssertTrue(source.contains("P6 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("agent/tool_executor.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("isInterpreterShutdownSubmitError"))
        XCTAssertTrue(source.contains("cancelledToolResultJSON"))
    }
}
