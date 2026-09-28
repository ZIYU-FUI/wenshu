//
//  Tests/Chat/LiveChatRepositoryTests.swift · Wenshu · v1.79 chat-by-book
//
//  Validates the LiveChatRepository (= the ChatRepositoryProtocol witness
//  backed by WSChatRepository.shared + SwiftData) correctly forwards
//  bookID through to the data layer.
//
//  Why a thin forwarding test (= the data layer itself is exhaustively
//  covered by WSChatRepositoryTests): the Live adapter is the seam where
//  future backends plug in. If a future Live implementation forgets to
//  forward bookID, every chat panel silently writes to the wrong scope.
//  This test catches that regression in 1 file (= Q112 scope).

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("LiveChatRepository (= ChatRepositoryProtocol SwiftData forwarder)")
struct LiveChatRepositoryTests {

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        try WSPersistenceContainer.makeInMemoryContainer()
    }

    @MainActor
    private func makeLive(container: ModelContainer) -> LiveChatRepository {
        LiveChatRepository(container: container)
    }

    @Test("append + loadMessages with bookID pass through to SwiftData scope")
    @MainActor
    func bookIDForwardedThroughProtocol() async throws {
        let container = try makeInMemoryContainer()
        // Seed via the same container the Live adapter will use (= same ModelContext).
        let repo = WSChatRepository(container: container)
        let live = makeLive(container: container)
        try repo.createSession(sessionID: "sess-A", bookID: BookID(rawValue: "book-A"))

        let userMsg = ChatMessage(
            id: UUID(),
            role: .user,
            source: .user,
            content: "in book A",
            timestamp: Date(),
            tokens: nil,
            thinking: nil
        )
        try await live.append(userMsg, sessionId: "sess-A", bookID: BookID(rawValue: "book-A"))

        // Load through the protocol (= the Live impl should forward bookID)
        let loaded = try await live.loadMessages(sessionId: "sess-A", bookID: BookID(rawValue: "book-A"))
        #expect(loaded.count == 1)
        #expect(loaded[0].content == "in book A")

        // Load with bookID: nil returns the global un-attached bucket
        // only (= §11.11 v1.79 row-level split contract). The
        // per-book message above has bookID = "book-A" so it does
        // not appear in the global view.
        let loadedGlobal = try await live.loadMessages(sessionId: "sess-A", bookID: nil)
        #expect(loadedGlobal.isEmpty)
    }

    @Test("append with nil bookID stores under global un-attached scope")
    @MainActor
    func nilBookIDStaysGlobal() async throws {
        let container = try makeInMemoryContainer()
        let repo = WSChatRepository(container: container)
        let live = makeLive(container: container)
        try repo.createSession(sessionID: "sess-global")

        let userMsg = ChatMessage(
            id: UUID(),
            role: .user,
            source: .user,
            content: "before picking a book",
            timestamp: Date()
        )
        try await live.append(userMsg, sessionId: "sess-global", bookID: nil)

        // Global scope reads the message back; = book-A scope rejects it.
        let messages = try repo.loadMessages(sessionId: "sess-global", bookID: nil)
        #expect(messages.count == 1)

        // A session lookup under a non-matching bookID scope returns nil
        // (= the append under nil leaves no bookID on the session row).
        let sessionInBookA = try repo.getSession(sessionID: "sess-global", bookID: BookID(rawValue: "book-A"))
        #expect(sessionInBookA == nil)
        let sessionGlobal = try repo.getSession(sessionID: "sess-global", bookID: nil)
        #expect(sessionGlobal != nil)
    }
}
