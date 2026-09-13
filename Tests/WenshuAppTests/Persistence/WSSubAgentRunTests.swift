//
//  Persistence/WSSubAgentRunTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSSubAgentRun (= sub_agent_runs @Model)")
struct WSSubAgentRunTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSSubAgentRun.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSSubAgentRun init sets task + status + startedAt; completedAt = nil")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let run = WSSubAgentRun(
            id: "run-001",
            sessionID: "sess-A",
            taskDescription: "summarize book 2",
            status: "queued"
        )
        context.insert(run)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSubAgentRun>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "run-001")
        #expect(fetched[0].taskDescription == "summarize book 2")
        #expect(fetched[0].status == "queued")
        #expect(fetched[0].completedAt == nil)
        #expect(fetched[0].errorMessage == nil)
    }

    @Test("WSSubAgentRun complete() sets status=ok + completedAt + output")
    @MainActor
    func complete() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let run = WSSubAgentRun(id: "r1", sessionID: "s", taskDescription: "x")
        context.insert(run)
        try context.save()
        run.complete(output: "done", outputTokens: 100)
        try context.save()
        #expect(run.status == "ok")
        #expect(run.outputText == "done")
        #expect(run.outputTokens == 100)
        #expect(run.completedAt != nil)
    }

    @Test("WSSubAgentRun fail() sets status=errored + completedAt + errorMessage")
    @MainActor
    func fail() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let run = WSSubAgentRun(id: "r2", sessionID: "s", taskDescription: "x")
        context.insert(run)
        try context.save()
        run.fail(error: "network timeout")
        try context.save()
        #expect(run.status == "errored")
        #expect(run.errorMessage == "network timeout")
        #expect(run.completedAt != nil)
    }

    @Test("WSSubAgentRun 1↔N relationship to WSSession")
    @MainActor
    func relationshipToSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = WSSession(sessionID: "sess-sub", title: "with sub-runs")
        context.insert(session)
        let r1 = WSSubAgentRun(id: "r1", sessionID: session.sessionID, taskDescription: "a")
        let r2 = WSSubAgentRun(id: "r2", sessionID: session.sessionID, taskDescription: "b")
        context.insert(r1)
        context.insert(r2)
        r1.session = session
        r2.session = session
        try context.save()

        #expect(session.subAgentRuns.count == 2)
        let ids = Set(session.subAgentRuns.map { $0.id })
        #expect(ids == Set(["r1", "r2"]))
    }
}
