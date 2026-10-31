//
//  Persistence/WSSessionTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("WSSession (= chat_sessions @Model)")
struct WSSessionTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSSession.self, WSChatMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSSession init sets sessionID + title; archivedAt = nil; messages = []")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let s = WSSession(sessionID: "sess-001", title: "main chat")
        context.insert(s)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSession>())
        #expect(fetched.count == 1)
        #expect(fetched[0].sessionID == "sess-001")
        #expect(fetched[0].title == "main chat")
        #expect(fetched[0].archivedAt == nil)
        #expect(fetched[0].messages.isEmpty)
    }

    @Test("WSSession init without title (= nil title OK)")
    @MainActor
    func initWithoutTitle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let s = WSSession(sessionID: "sess-002")
        context.insert(s)
        try context.save()
        #expect(s.title == nil)
    }

    @Test("WSSession archive() sets archivedAt + bumps updatedAt")
    @MainActor
    func archive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let s = WSSession(sessionID: "sess-003", title: "x")
        context.insert(s)
        try context.save()
        let original = s.updatedAt
        try? Thread.sleep(forTimeInterval: 0.05)
        s.archive()
        try context.save()
        #expect(s.archivedAt != nil)
        #expect(s.updatedAt > original)
    }

    @Test("WSSession sessionID is unique per book (= the composite key, not the column)")
    @MainActor
    func sessionIDUniquePerBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // The same sessionID under two books is two rows: the chat-by-book
        // design lets one sessionID exist under several books, so the
        // column carries no unique constraint of its own. The composite
        // key (sessionID + bookID) is enforced by the repository.
        let a = WSSession(sessionID: "same", title: "a", bookID: "book-A")
        let b = WSSession(sessionID: "same", title: "b", bookID: "book-B")
        context.insert(a)
        context.insert(b)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<WSSession>()) == 2,
                "the same sessionID under two books is two rows")
    }

    @Test("WSSession init with bookID persists; default bookID = nil (= global un-attached)")
    @MainActor
    func bookIDDefaultIsNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaultSession = WSSession(sessionID: "default-session")
        context.insert(defaultSession)
        let scopedSession = WSSession(sessionID: "scoped-session", bookID: "book-uuid-A")
        context.insert(scopedSession)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSession>())
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.sessionID, $0) })
        #expect(byID["default-session"]?.bookID == nil)
        #expect(byID["scoped-session"]?.bookID == "book-uuid-A")
    }

    @Test("WSSession multiple sessions under same bookID is allowed (= no unique constraint on bookID)")
    @MainActor
    func bookIDNotUnique() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Same bookID, different sessionIDs = legitimate multi-chat-per-book.
        let a = WSSession(sessionID: "sess-A", bookID: "book-X")
        let b = WSSession(sessionID: "sess-B", bookID: "book-X")
        context.insert(a)
        context.insert(b)
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<WSSession>())
        #expect(count == 2)
    }

    @Test("WSSession carries the archive's three columns, and an ordinary chat carries none of them")
    @MainActor
    func archiveColumnsRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // A chat session (= source = nil) and a unit of agent work
        // (= source = the work kind), so the archive's read can tell
        // them apart by the tag alone.
        let chat = WSSession(sessionID: "sess-chat")
        let work = WSSession(
            sessionID: "sess-work",
            title: "the work",
            bookID: "book-A",
            source: WSSessionSource.agent,
            parentSessionID: "sess-chat",
            agentName: "researcher"
        )
        context.insert(chat)
        context.insert(work)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSSession>())
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.sessionID, $0) })
        #expect(byID["sess-chat"]?.source == nil,
                "an ordinary chat carries no work tag (= the archive lists only the tagged rows)")
        #expect(byID["sess-work"]?.source == WSSessionSource.agent)
        #expect(byID["sess-work"]?.parentSessionID == "sess-chat",
                "the work names the session that asked for it (= the archive walks back to the chat)")
        #expect(byID["sess-work"]?.agentName == "researcher",
                "the work names the agent that did it (= the archive's second search dimension)")
    }

    @Test("WSSessionSource names the work kinds Hermes writes into its sessions table")
    @MainActor
    func sessionSourceVocabulary() {
        // The column is a plain String (= SwiftData persists a String and
        // not a Swift enum), so the vocabulary lives here as constants.
        // Hermes keeps ONE sessions table and tags each row with where
        // it came from, so a delegated agent's run and a board task's
        // work are rows of the same table, told apart by the tag.
        #expect(WSSessionSource.agent == "agent")
    }
}
