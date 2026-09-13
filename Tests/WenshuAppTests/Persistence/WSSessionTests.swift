//
//  Persistence/WSSessionTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSSession (= chat_sessions @Model)")
struct WSSessionTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSSession init sets sessionID + title; archivedAt = nil by default")
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
        try? Thread.sleep(forTimeInterval: 0.01)
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
}
