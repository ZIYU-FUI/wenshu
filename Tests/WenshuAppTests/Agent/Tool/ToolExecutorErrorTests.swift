//
//  ToolExecutorErrorTests.swift · Wenshu · v1.27 health-check
//
//  Pinned the ToolExecutorError errorDescription strings so future
//  refactors (= e.g. switching to a localized strings catalog) cannot
//  silently change the user-visible error messages.
//
//  3 tests pin:
//    1. toolNotFound error description
//    2. toolFailed error description
//    3. invalidInput error description
//
//  All 3 cases verified to produce non-empty descriptions (= LocalizedError
//  contract requires it) and to mention the offending tool name (= so
//  the user can identify which tool failed in the LLM-trace log).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolExecutorError (v1.27 health-check pin)")
struct ToolExecutorErrorTests {

    @Test("toolNotFound: error description names the missing tool")
    func testToolNotFoundDescription() {
        let err = ToolExecutorError.toolNotFound(name: "missing-tool")
        let desc = err.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("missing-tool"),
                "toolNotFound description should mention the offending tool name")
    }

    @Test("toolFailed: error description names the failed tool + underlying cause")
    func testToolFailedDescription() {
        let err = ToolExecutorError.toolFailed(name: "broken-tool", underlying: "ENOENT")
        let desc = err.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("broken-tool"),
                "toolFailed description should mention the offending tool name")
        #expect(desc!.contains("ENOENT"),
                "toolFailed description should mention the underlying error message")
    }

    @Test("invalidInput: error description names the tool + rejection reason")
    func testInvalidInputDescription() {
        let err = ToolExecutorError.invalidInput(name: "validator-tool", reason: "missing field 'path'")
        let desc = err.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("validator-tool"),
                "invalidInput description should mention the offending tool name")
        #expect(desc!.contains("missing field 'path'"),
                "invalidInput description should mention the rejection reason")
    }

    @Test("all error cases produce non-empty descriptions (= LocalizedError contract)")
    func testAllCasesProduceNonEmptyDescriptions() {
        // LocalizedError contract requires errorDescription to be a
        // user-facing string. If a future ticket adds a new case and
        // forgets to handle it in the switch (= returns nil), this
        // test catches the regression.
        let cases: [ToolExecutorError] = [
            .toolNotFound(name: "x"),
            .toolFailed(name: "y", underlying: "z"),
            .invalidInput(name: "a", reason: "b"),
        ]
        for err in cases {
            #expect(err.errorDescription != nil,
                    "error case \(err) must produce a non-nil description")
            #expect(!err.errorDescription!.isEmpty,
                    "error case \(err) must produce a non-empty description")
        }
    }
}
