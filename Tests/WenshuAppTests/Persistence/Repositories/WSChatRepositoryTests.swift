//
//  Persistence/Repositories/WSChatRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSChatRepository (= SwiftData @Model ChatSessionStore replacement)")
struct WSChatRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSChatRepository(container: container)
    }

    @Test("createSession + getSession round-trip")
    @MainActor
    func sessionCRUD() throws {
        let repo = try makeRepository()
        let session = try repo.createSession(sessionID: "sess-1", title: "Test")
        #expect(session.sessionID == "sess-1")
        #expect(session.title == "Test")
        let fetched = try repo.getSession(sessionID: "sess-1")
        #expect(fetched?.sessionID == "sess-1")
    }

    @Test("append + loadMessages preserves order by position")
    @MainActor
    func messagesOrder() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s1")
        try repo.append(
            StoredChatMessage(id: "m1", source: "user", content: "first", timestamp: Date()),
            sessionId: "s1"
        )
        try repo.append(
            StoredChatMessage(id: "m2", source: "assistant", content: "second", timestamp: Date()),
            sessionId: "s1"
        )
        let messages = try repo.loadMessages(sessionId: "s1")
        #expect(messages.count == 2)
        #expect(messages[0].id == "m1")
        #expect(messages[1].id == "m2")
    }

    @Test("count returns message count for session")
    @MainActor
    func count() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s1")
        #expect(try repo.count(sessionId: "s1") == 0)
        try repo.append(
            StoredChatMessage(id: "m1", source: "user", content: "x", timestamp: Date()),
            sessionId: "s1"
        )
        #expect(try repo.count(sessionId: "s1") == 1)
    }

    @Test("clear removes all messages")
    @MainActor
    func clear() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s1")
        try repo.append(
            StoredChatMessage(id: "m1", source: "user", content: "x", timestamp: Date()),
            sessionId: "s1"
        )
        try repo.clear(sessionId: "s1")
        #expect(try repo.count(sessionId: "s1") == 0)
    }

    @Test("saveSummary + loadSummary round-trip")
    @MainActor
    func summary() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s1")
        try repo.saveSummary("hello summary", sessionId: "s1", lastMessageId: "m1")
        let loaded = try repo.loadSummary(sessionId: "s1")
        #expect(loaded == "hello summary")
    }

    @Test("recordSubAgentRun + loadSubAgentRuns round-trip")
    @MainActor
    func subAgentRuns() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s1")
        let run = SubAgentRun(
            id: "r1",
            agentName: "writer",
            title: "draft chapter 1",
            status: .done,
            startedAt: Date(),
            completedAt: Date(),
            resultSummary: "done"
        )
        try repo.recordSubAgentRun(run, sessionId: "s1")
        let loaded = try repo.loadSubAgentRuns(sessionId: "s1")
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "r1")
        #expect(loaded[0].title == "draft chapter 1")
    }

    @Test("listSessions respects archived flag")
    @MainActor
    func listSessionsArchived() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "active", title: "active")
        let archived = try repo.createSession(sessionID: "old", title: "old")
        archived.archive()
        // Need to save context — call createSession again with different ID to flush;
        // or expose a save method on the repo (= added in Phase 3). For now this
        // commit's archive() will be persisted on next save call (= next operation).
        // The test still verifies the API; archive state may not be flushed yet.
        let _ = try repo.listSessions(includeArchived: false)
        let allSessions = try repo.listSessions(includeArchived: true)
        let activeOnly = try repo.listSessions(includeArchived: false)
        #expect(allSessions.count == 2)
        #expect(activeOnly.count == 1)
        #expect(activeOnly[0].sessionID == "active")
    }
}
