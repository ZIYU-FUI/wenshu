//
//  WSChatRepositoryBookIDContractTests.swift · Wenshu · bug-sweep-2026-09-28
//
//  Contract invariants for the §11.11 v1.79 chat-by-book row-level
//  split. The chat rows live in a single SwiftData ModelContainer
//  (= per-row bookID column); = the repository's job is to expose
//  per-book filtering at the API surface (= BookID? brand wrapper)
//  while preserving global-bucket behavior for `bookID = nil`.
//
//  These tests assert the row-level invariants that source review
//  alone cannot prove: that filtering by bookID never leaks rows
//  across book boundaries, = that append-without-bookID lands in the
//  global bucket (= not the first per-book bucket), = that
//  cross-book sessions with the same sessionID don't collide.
//
//  This is the contract that hermes-style chat-by-book = broken
//  if it leaks. = tests run on in-memory SwiftData containers
//  (= same fixture pattern as WSChatRepositoryTests) so they're
//  fast + hermetic.

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSChatRepository bookID row-level isolation (= §11.11 contract)")
struct WSChatRepositoryBookIDContractTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSChatRepository(container: container)
    }

    private static let bookA = BookID(rawValue: "book-A-uuid")
    private static let bookB = BookID(rawValue: "book-B-uuid")
    private static let bookC = BookID(rawValue: "book-C-uuid")

    @Test("listSessions(bookID: A) never returns sessions owned by B/C")
    @MainActor
    func listSessionsFilteredByBookID() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "s-A-1", bookID: Self.bookA)
        try repo.createSession(sessionID: "s-B-1", bookID: Self.bookB)
        try repo.createSession(sessionID: "s-C-1", bookID: Self.bookC)
        try repo.createSession(sessionID: "s-global-1", bookID: nil)

        let aOnly = try repo.listSessions(includeArchived: false, bookID: Self.bookA)
        #expect(aOnly.count == 1)
        #expect(aOnly.first?.sessionID == "s-A-1")

        let bOnly = try repo.listSessions(includeArchived: false, bookID: Self.bookB)
        #expect(bOnly.count == 1)
        #expect(bOnly.first?.sessionID == "s-B-1")

        let globalOnly = try repo.listSessions(includeArchived: false, bookID: nil)
        #expect(globalOnly.count == 1)
        #expect(globalOnly.first?.sessionID == "s-global-1")
    }

    @Test("append to session under bookID = A never leaks into bookID = B view")
    @MainActor
    func appendIsolatedByBookID() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "shared", bookID: Self.bookA)
        try repo.createSession(sessionID: "shared", bookID: Self.bookB)

        // Append a message to the book-A session.
        try repo.append(
            StoredChatMessage(
                id: "msg-A-1",
                source: "user",
                content: "in book A",
                timestamp: Date()
            ),
            sessionId: "shared",
            bookID: Self.bookA
        )
        // Append a message to the book-B session.
        try repo.append(
            StoredChatMessage(
                id: "msg-B-1",
                source: "user",
                content: "in book B",
                timestamp: Date()
            ),
            sessionId: "shared",
            bookID: Self.bookB
        )

        // Loading under book-A returns only msg-A-1.
        let aMessages = try repo.loadMessages(sessionId: "shared", bookID: Self.bookA)
        #expect(aMessages.count == 1)
        #expect(aMessages.first?.id == "msg-A-1")

        // Loading under book-B returns only msg-B-1.
        let bMessages = try repo.loadMessages(sessionId: "shared", bookID: Self.bookB)
        #expect(bMessages.count == 1)
        #expect(bMessages.first?.id == "msg-B-1")

        // Loading without a bookID returns no messages from the per-book
        // bucket. The two messages are owned by book-A and book-B;
        // the global un-attached bucket is empty.
        let globalMessages = try repo.loadMessages(sessionId: "shared", bookID: nil)
        #expect(globalMessages.isEmpty)
    }

    @Test("append without bookID auto-routes to the global un-attached bucket")
    @MainActor
    func appendWithoutBookIDGoesToGlobal() throws {
        let repo = try makeRepository()
        // Two per-book sessions share the same sessionID.
        try repo.createSession(sessionID: "shared", bookID: Self.bookA)
        try repo.createSession(sessionID: "shared", bookID: Self.bookB)

        // Append with no bookID (= legacy call sites + onboarding).
        try repo.append(
            StoredChatMessage(
                id: "msg-global",
                source: "user",
                content: "global message",
                timestamp: Date()
            ),
            sessionId: "shared",
            bookID: nil
        )

        // DEBUG line removed (= §11.30 fix confirmed: append writes exactly
        // 1 message to the global bucket; = totalForShared == 1).

        // The global view must see it.
        let globalMessages = try repo.loadMessages(sessionId: "shared", bookID: nil)
        #expect(globalMessages.count == 1)
        #expect(globalMessages.first?.id == "msg-global")

        // Per-book views must NOT see it.
        let aMessages = try repo.loadMessages(sessionId: "shared", bookID: Self.bookA)
        #expect(aMessages.isEmpty)
        let bMessages = try repo.loadMessages(sessionId: "shared", bookID: Self.bookB)
        #expect(bMessages.isEmpty)
    }

    @Test("getSession(sessionID: A) under bookID = A returns A, under bookID = B returns nil")
    @MainActor
    func getSessionRespectsBookIDScope() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "shared", bookID: Self.bookA)

        let aHit = try repo.getSession(sessionID: "shared", bookID: Self.bookA)
        #expect(aHit?.sessionID == "shared")
        // No session with sessionID=shared under bookB = lookup misses.
        let bMiss = try repo.getSession(sessionID: "shared", bookID: Self.bookB)
        #expect(bMiss == nil)
    }
}