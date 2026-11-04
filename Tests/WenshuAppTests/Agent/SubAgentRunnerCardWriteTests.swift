//
//  Tests/Agent/SubAgentRunnerCardWriteTests.swift · Wenshu
//
//  The runner moves the card by asking the registry, = and not by
//  writing a snapshot back.
//
//  Why this test exists (= the gap it closes):
//
//  The card's id was lost because the runner took a snapshot when the
//  run started and wrote that snapshot back when the run moved to
//  "running". = The card id is attached AFTER the delegation returns,
//  = so the write-back erased it, = and the card stayed in "running"
//  for ever.
//
//  The registry's own behaviour is pinned by
//  `SubAgentKanbanCardLifecycleTests` (= `markRunning` keeps the id).
//  = That suite cannot see the runner, though, = and the runner is
//  where the defect was. = So this suite reads the runner's own
//  source, = and holds the two calls that matter:
//
//  1. The runner asks the registry to change the state, = and does
//     not write a record back.
//  2. The runner reads the card id from the registry when the run
//     ends, = and not from the snapshot it started with.
//
//  A source-level assertion is weaker than a behavioural one, = and
//  that is why the registry's behaviour is pinned separately: = the
//  two together say "the registry keeps the id" and "the runner asks
//  the registry".
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The runner moves the card by asking the registry")
struct SubAgentRunnerCardWriteTests {

    private static func runnerSource() throws -> String {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Agent/Store/SubAgentRunner.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("the runner asks the registry to change the state, and does not write a record back")
    func theRunnerDoesNotWriteARecordBack() throws {
        let source = try Self.runnerSource()

        #expect(
            !source.contains("registry.update("),
            "the runner must not write a record back: = a snapshot erases what the record gained"
        )
        #expect(
            source.contains("markRunning(id:"),
            "the runner must ask the registry to change the state"
        )
    }

    @Test("the runner reads the card id from the registry when the run ends")
    func theRunnerReadsTheCardIDFromTheRegistry() throws {
        let source = try Self.runnerSource()

        // The assertion is scoped to the function, = because the
        // string it looks for also appears in the runner's step-0
        // snapshot (= the read that CAUSED the defect). = An
        // unscoped assertion is satisfied by that one too, = and it
        // would pass with the end-of-run read deleted.
        let start = try #require(
            source.range(of: "private func moveKanbanCard"),
            "the runner must have the method that moves the card"
        )
        let body = String(source[start.lowerBound...])
        let end = body.range(of: "\n    }")?.lowerBound ?? body.endIndex
        let function = String(body[..<end])

        #expect(
            function.contains("await registry.get(id: handle.id)"),
            "the card id must be read from the registry: = the snapshot the run started with has no card id"
        )
        #expect(
            !function.contains("let current = handle"),
            "reading the snapshot instead of the registry is the defect"
        )
    }

    @Test("the registry offers no wholesale write for a caller to reach for")
    func theRegistryOffersNoWholesaleWrite() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Agent/Store/AsyncDelegation.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // The write-back that lost the card id is gone, = so the next
        // caller cannot reach for it. = The test-only twin below is
        // marked as one, = and it is the only way to write a record
        // whole.
        #expect(
            !source.contains("func update(_ handle: BackgroundDelegationHandle)"),
            "the wholesale write must stay gone: = it is how the card id was lost"
        )
        #expect(
            source.contains("func writeBackForTest"),
            "the test-only twin must be named as one, = so nobody mistakes it for the API"
        )
    }
}
