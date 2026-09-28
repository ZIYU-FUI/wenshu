//
//  Persistence/Repositories/WSChatRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSChatRepository (= SwiftData @Model replacement for the deleted ChatSessionStore actor)")
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
        // or expose a save method on the repo (= added in ). For now this
        // commit's archive() will be persisted on next save call (= next operation).
        // The test still verifies the API; archive state may not be flushed yet.
        let _ = try repo.listSessions(includeArchived: false)
        let allSessions = try repo.listSessions(includeArchived: true)
        let activeOnly = try repo.listSessions(includeArchived: false)
        #expect(allSessions.count == 2)
        #expect(activeOnly.count == 1)
        #expect(activeOnly[0].sessionID == "active")
    }

    @Test("createSession with bookID persists bookID; sessions under different books are isolated")
    @MainActor
    func sessionsIsolatedByBook() throws {
        let repo = try makeRepository()
        _ = try repo.createSession(sessionID: "sess-book-A", bookID: BookID(rawValue: "book-A"))
        _ = try repo.createSession(sessionID: "sess-book-B", bookID: BookID(rawValue: "book-B"))
        _ = try repo.createSession(sessionID: "sess-global")

        let sessionsForA = try repo.listSessions(bookID: BookID(rawValue: "book-A"))
        let sessionsForB = try repo.listSessions(bookID: BookID(rawValue: "book-B"))
        let sessionsGlobal = try repo.listSessions(bookID: nil)

        #expect(sessionsForA.count == 1)
        #expect(sessionsForA[0].sessionID == "sess-book-A")
        #expect(sessionsForB.count == 1)
        #expect(sessionsForB[0].sessionID == "sess-book-B")
        // bookID: nil returns ONLY the global un-attached bucket
        // (= §11.11 v1.79 row-level split contract; = the pre-v1.79
        // "all sessions" interpretation is rejected by the fix in the
        // bug-sweep-2026-09-28 arc).
        #expect(sessionsGlobal.count == 1)
        #expect(sessionsGlobal[0].sessionID == "sess-global")
    }

    @Test("append + loadMessages are scoped by bookID; cross-book append auto-creates a sibling session")
    @MainActor
    func messagesIsolatedByBook() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "sess-A", bookID: BookID(rawValue: "book-A"))
        try repo.createSession(sessionID: "sess-B", bookID: BookID(rawValue: "book-B"))

        // Append under book-A
        try repo.append(
            StoredChatMessage(id: "m-A1", source: "user", content: "in book A", timestamp: Date()),
            sessionId: "sess-A",
            bookID: BookID(rawValue: "book-A")
        )
        // Append under book-B
        try repo.append(
            StoredChatMessage(id: "m-B1", source: "user", content: "in book B", timestamp: Date()),
            sessionId: "sess-B",
            bookID: BookID(rawValue: "book-B")
        )

        // book-A scope only sees the book-A message
        let messagesA = try repo.loadMessages(sessionId: "sess-A", bookID: BookID(rawValue: "book-A"))
        #expect(messagesA.count == 1)
        #expect(messagesA[0].id == "m-A1")

        // Cross-scope append (= bookID = "book-B" targeting sessionID
        // "sess-A" which only exists under book-A) — v1.79 auto-creates
        // a sibling session under book-B with the same sessionID so the
        // chat pipeline can write per-book without coordinating session
        // lifecycle separately (= see WSChatRepository.append comment
        // block for the rationale).
        try repo.append(
            StoredChatMessage(id: "m-cross", source: "user", content: "x", timestamp: Date()),
            sessionId: "sess-A",
            bookID: BookID(rawValue: "book-B")
        )

        // Global (= bookID: nil) views must respect the §11.11 row-level split
        // (= the global bucket contains ONLY messages whose own bookID
        // is nil; = m-A1 and m-cross both have non-nil bookIDs and
        // belong to per-book buckets).
        let messagesGlobalA = try repo.loadMessages(sessionId: "sess-A")
        let messagesGlobalB = try repo.loadMessages(sessionId: "sess-B")
        #expect(messagesGlobalA.isEmpty)
        #expect(messagesGlobalB.isEmpty)

        // Per-book scope returns the right message.
        let crossBookB = try repo.loadMessages(
            sessionId: "sess-A",
            bookID: BookID(rawValue: "book-B")
        )
        #expect(crossBookB.count == 1)
        #expect(crossBookB[0].id == "m-cross")
    }

    @Test("count + clear respect bookID scope")
    @MainActor
    func countAndClearScoped() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "sess-A", bookID: BookID(rawValue: "book-A"))
        try repo.append(
            StoredChatMessage(id: "m1", source: "user", content: "x", timestamp: Date()),
            sessionId: "sess-A",
            bookID: BookID(rawValue: "book-A")
        )
        #expect(try repo.count(sessionId: "sess-A", bookID: BookID(rawValue: "book-A")) == 1)
        try repo.clear(sessionId: "sess-A", bookID: BookID(rawValue: "book-A"))
        #expect(try repo.count(sessionId: "sess-A", bookID: BookID(rawValue: "book-A")) == 0)
    }
}
