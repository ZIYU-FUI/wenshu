//
//  Persistence/RunRetentionTests.swift · Wenshu
//
//  The archive keeps the agent's work for a while, and not forever.
//
//  Why this test exists (= the gap it closes):
//
//  The archive records what the agents did. = A record that grows
//  forever is not a record, = it is a leak, = and the memory pane
//  already has the shape for stopping it: = a closed set of days, =
//  and a change to the setting purges. = The archive had no such
//  thing, = so its rows would have accumulated for as long as the
//  user used the app.
//
//  What is pinned here:
//
//  1. A run older than the window goes. = A run inside it stays.
//  2. The user's own conversations stay, = whatever their age. = The
//     setting says how long the AGENT'S WORK is kept, = and the
//     user's words are not agent work.
//  3. The run's rows go with the session, = because a run without
//     its session is a row nobody can reach.
//  4. A window of zero keeps everything, = because zero days of
//     history would be a setting that deletes the user's archive the
//     moment it is set.
//

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("The archive's retention window")
struct RunRetentionTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSChatRepository(container: container)
    }

    /// A run session whose last update was `daysAgo` days ago.
    @MainActor
    private func seedRun(
        _ repo: WSChatRepository,
        id: String,
        daysAgo: Double
    ) throws {
        let session = try repo.createSession(
            sessionID: id,
            title: "A run",
            source: "subagent",
            parentSessionID: "chat-1",
            agentName: "researcher"
        )
        session.updatedAt = Date().addingTimeInterval(-daysAgo * 24 * 3600)
    }

    @Test("A run older than the window goes, and a run inside it stays")
    @MainActor
    func purgesTheOldRunsOnly() throws {
        let repo = try makeRepository()
        try seedRun(repo, id: "old-run", daysAgo: 200)
        try seedRun(repo, id: "new-run", daysAgo: 5)

        let deleted = try repo.purgeRuns(olderThanDays: 90)

        #expect(deleted == 1, "only the run past the window goes")
        let remaining = try repo.listRuns()
        #expect(remaining.count == 1)
        #expect(remaining.first?.sessionID == "new-run")
    }

    @Test("The user's own conversations are never purged")
    @MainActor
    func neverPurgesAChatSession() throws {
        let repo = try makeRepository()
        _ = try repo.createSession(sessionID: "old-chat", title: "An old conversation")
        // Age it past the window.
        let context = repo.store.context
        let chat = try #require(
            try context.fetch(FetchDescriptor<WSSession>()).first { $0.sessionID == "old-chat" }
        )
        chat.updatedAt = Date().addingTimeInterval(-400 * 24 * 3600)
        try context.save()

        let deleted = try repo.purgeRuns(olderThanDays: 90)

        #expect(deleted == 0, "a conversation is not the archive's to delete")
        let sessions = try repo.listRuns()
        #expect(sessions.isEmpty, "a chat session carries no source, so it was never a run")
        // The chat itself is still there.
        #expect(try repo.getSession(sessionID: "old-chat") != nil)
    }

    @Test("A window of zero keeps everything")
    @MainActor
    func aWindowOfZeroKeepsEverything() throws {
        let repo = try makeRepository()
        try seedRun(repo, id: "old-run", daysAgo: 500)

        let deleted = try repo.purgeRuns(olderThanDays: 0)

        #expect(deleted == 0)
        #expect(try repo.listRuns().count == 1)
    }

    @Test("The run's rows go with the session")
    @MainActor
    func theRunRowsGoToo() throws {
        let repo = try makeRepository()
        try seedRun(repo, id: "old-run", daysAgo: 200)

        // Put a run row under the session, = the way the ledger does.
        let context = repo.store.context
        let session = try #require(
            try context.fetch(FetchDescriptor<WSSession>()).first { $0.sessionID == "old-run" }
        )
        let run = WSSubAgentRun(
            id: "old-run",
            sessionID: "old-run",
            taskDescription: "The work",
            status: "done"
        )
        run.session = session
        context.insert(run)
        try context.save()

        _ = try repo.purgeRuns(olderThanDays: 90)

        let runs = try context.fetch(FetchDescriptor<WSSubAgentRun>())
        #expect(runs.isEmpty, "a run row without its session is a row nobody can reach")
    }
}
