//
//  Persistence/WSSessionTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

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

    @Test("WSSession sessionID uniqueness enforced")
    @MainActor
    func sessionIDUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSSession(sessionID: "same", title: "a")
        let b = WSSession(sessionID: "same", title: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
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
}
