//
//  SubAgentLedgerTests.swift · Wenshu
//
//  The ledger of agent work.
//
//  The models were already there and so was the writer that fills
//  them; = but no run ever called it, = so the ledger was always
//  empty and the archive pane had nothing to show.
//
//  These tests pin the two facts the archive depends on: = a run
//  leaves a row, = and a chat session never appears among the runs.
//

import Testing
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("SubAgentLedger · the ledger of agent work")
@MainActor
struct SubAgentLedgerTests {

    // MARK: - Helpers

    private static func makeLedger() throws -> (SubAgentLedger, WSChatRepository) {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let repository = WSChatRepository(container: container)
        return (SubAgentLedger(repository: repository), repository)
    }

    // MARK: - Writing

    @Test("an opened run leaves a row in the ledger")
    func anOpenedRunLeavesARow() throws {
        let (ledger, _) = try Self.makeLedger()
        try ledger.openRun(
            runID: "run-1",
            agentName: "researcher",
            task: "Find the tax system",
            parentSessionID: "chat-1",
            bookID: "book-1"
        )

        let runs = try ledger.listRuns()
        #expect(runs.count == 1, "the run must leave a row")
        #expect(runs[0].agentName == "researcher", "the row must name the agent")
        #expect(runs[0].source == WSSessionSource.subagent, "the row must be tagged as a run")
        #expect(runs[0].parentSessionID == "chat-1", "the row must point back at the chat")
        #expect(runs[0].title == "Find the tax system", "the row must carry the task")
    }

    @Test("a closed run carries the outcome")
    func aClosedRunCarriesTheOutcome() throws {
        let (ledger, _) = try Self.makeLedger()
        try ledger.openRun(
            runID: "run-1",
            agentName: "researcher",
            task: "Find the tax system",
            parentSessionID: nil,
            bookID: nil
        )
        try ledger.closeRun(
            runID: "run-1",
            status: "done",
            output: "The tax system was this.",
            error: nil,
            bookID: nil
        )

        let runs = try ledger.listRuns()
        #expect(runs.count == 1)
        #expect(runs[0].subAgentRuns.count == 1, "the run row must carry the outcome")
        let run = runs[0].subAgentRuns.first
        #expect(run?.status == "done")
        #expect(run?.outputText == "The tax system was this.")
        #expect(run?.errorMessage == nil)
    }

    /// A run that belongs to a book closes onto the row it opened.
    ///
    /// The row's key is the session id plus the book, = so the close
    /// has to name the same book the open did. = The common case for a
    /// run the user started from a book's surface.
    @Test("a run scoped to a book closes onto the row it opened")
    func aBookScopedRunCloses() throws {
        let (ledger, _) = try Self.makeLedger()
        try ledger.openRun(
            runID: "run-1",
            agentName: "researcher",
            task: "Find the tax system",
            parentSessionID: "chat-1",
            bookID: "book-1"
        )
        try ledger.closeRun(
            runID: "run-1",
            status: "done",
            output: "The tax system was this.",
            error: nil,
            bookID: "book-1"
        )

        let runs = try ledger.listRuns()
        #expect(runs.count == 1)
        #expect(runs.first?.subAgentRuns.count == 1, "the run row must carry the outcome")
        #expect(runs.first?.subAgentRuns.first?.outputText == "The tax system was this.")
    }

    @Test("a failed run records the failure")
    func aFailedRunRecordsTheFailure() throws {
        let (ledger, _) = try Self.makeLedger()
        try ledger.openRun(
            runID: "run-1",
            agentName: "writer",
            task: "Write the chapter",
            parentSessionID: nil,
            bookID: nil
        )
        try ledger.closeRun(
            runID: "run-1",
            status: "failed",
            output: nil,
            error: "the LLM refused"
        )

        let runs = try ledger.listRuns()
        #expect(runs.count == 1)
        #expect(runs[0].subAgentRuns.first?.status == "failed")
        #expect(runs[0].subAgentRuns.first?.errorMessage == "the LLM refused")
    }

    @Test("re-opening the same run does not add a second row")
    func reOpeningDoesNotDuplicate() throws {
        let (ledger, _) = try Self.makeLedger()
        for _ in 0..<3 {
            try ledger.openRun(
                runID: "run-1",
                agentName: "researcher",
                task: "Find the tax system",
                parentSessionID: nil,
                bookID: nil
            )
        }
        #expect(try ledger.listRuns().count == 1, "one run must be one row")
    }

    // MARK: - A chat is not a run

    @Test("a chat session never appears among the runs")
    func aChatSessionIsNotARun() throws {
        let (ledger, repository) = try Self.makeLedger()
        // A chat session (= no source tag).
        try repository.createSession(sessionID: "chat-1", title: "A conversation")
        // A run.
        try ledger.openRun(
            runID: "run-1",
            agentName: "researcher",
            task: "Find the tax system",
            parentSessionID: "chat-1",
            bookID: nil
        )

        let runs = try ledger.listRuns()
        #expect(runs.count == 1, "only the run may appear")
        #expect(runs.allSatisfy { $0.source != nil }, "a chat carries no source tag")
        #expect(
            !runs.contains { $0.sessionID == "chat-1" },
            "the chat must not be listed as a run"
        )
    }

    // MARK: - Reading

    @Test("the runs can be filtered by the agent that did them")
    func runsCanBeFilteredByAgent() throws {
        let (ledger, _) = try Self.makeLedger()
        try ledger.openRun(runID: "run-1", agentName: "researcher", task: "A", parentSessionID: nil, bookID: nil)
        try ledger.openRun(runID: "run-2", agentName: "writer", task: "B", parentSessionID: nil, bookID: nil)
        try ledger.openRun(runID: "run-3", agentName: "researcher", task: "C", parentSessionID: nil, bookID: nil)

        #expect(try ledger.listRuns(agentName: "researcher").count == 2)
        #expect(try ledger.listRuns(agentName: "writer").count == 1)
        #expect(try ledger.listRuns().count == 3)
    }

    @Test("an archived run is hidden unless it is asked for")
    func anArchivedRunIsHiddenUnlessAskedFor() throws {
        let (ledger, repository) = try Self.makeLedger()
        try ledger.openRun(runID: "run-1", agentName: "researcher", task: "A", parentSessionID: nil, bookID: nil)
        let session = try repository.getSession(sessionID: "run-run-1", bookID: nil)
        session?.archive()
        try repository.save(session!)

        #expect(try ledger.listRuns().count == 0, "an archived run is hidden by default")
        #expect(try ledger.listRuns(includeArchived: true).count == 1)
    }

    @Test("a run with no ledger row does not break the close")
    func closingAnUnknownRunIsHarmless() throws {
        let (ledger, _) = try Self.makeLedger()
        // No open first: the close must not throw.
        try ledger.closeRun(runID: "never-opened", status: "done", output: "x", error: nil)
    }
}
