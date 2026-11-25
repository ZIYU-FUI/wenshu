//
//  WSChatContextUsageTests.swift · Wenshu
//
//  The conversation's last context reading is stored on the conversation's
//  own session row, under the same `sessionID + bookID` the transcript is
//  keyed by. These tests hold that contract: the reading round-trips, it
//  never crosses a scope boundary, the row is not duplicated, and clearing
//  the conversation takes the reading with it.
//
//  Why this suite exists at all: the meter in the chat bar used to read a
//  process-local recorder and nothing else, so a relaunch restored the
//  messages and left the meter blank. These rows are what the meter reads
//  back. They run on an in-memory container (= the same fixture pattern as
//  WSChatRepositoryBookIDContractTests).
//

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("WSChatRepository context reading (= stored on the session row)")
struct WSChatContextUsageTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSChatRepository(container: container)
    }

    private static let bookA = "book-A-uuid"
    private static let bookB = "book-B-uuid"

    @Test("a stored reading reads back for its own scope")
    @MainActor
    func roundTripWithinOneScope() throws {
        let repo = try makeRepository()
        let before = try repo.loadContextUsage(sessionId: "s-1", bookID: Self.bookA)
        #expect(before == nil)

        try repo.saveContextUsage("{\"promptTokens\":120}", sessionId: "s-1", bookID: Self.bookA)

        let after = try repo.loadContextUsage(sessionId: "s-1", bookID: Self.bookA)
        #expect(after == "{\"promptTokens\":120}")
    }

    @Test("a reading never crosses the book boundary")
    @MainActor
    func readingIsScopedToItsBook() throws {
        let repo = try makeRepository()
        try repo.saveContextUsage("A-payload", sessionId: "shared-id", bookID: Self.bookA)

        #expect(try repo.loadContextUsage(sessionId: "shared-id", bookID: Self.bookB) == nil)
        #expect(try repo.loadContextUsage(sessionId: "shared-id", bookID: nil) == nil)
        #expect(try repo.loadContextUsage(sessionId: "shared-id", bookID: Self.bookA) == "A-payload")
    }

    @Test("the global bucket and a book bucket do not share a reading")
    @MainActor
    func globalBucketIsItsOwnScope() throws {
        let repo = try makeRepository()
        try repo.saveContextUsage("global-payload", sessionId: "default", bookID: nil)

        let global = try repo.loadContextUsage(sessionId: "default", bookID: nil)
        let scoped = try repo.loadContextUsage(sessionId: "default", bookID: Self.bookA)
        #expect(global == "global-payload")
        #expect(scoped == nil)
    }

    @Test("saving a reading for an unknown session creates one row, not two")
    @MainActor
    func savingCreatesTheSessionRowOnce() throws {
        let repo = try makeRepository()
        try repo.saveContextUsage("first", sessionId: "s-new", bookID: Self.bookA)
        let created = try #require(
            try repo.getSession(sessionID: "s-new", bookID: Self.bookA)
        )
        let stampBefore = created.updatedAt

        try repo.saveContextUsage("second", sessionId: "s-new", bookID: Self.bookA)

        let rows = try repo.listSessions(includeArchived: false, bookID: Self.bookA)
            .filter { $0.sessionID == "s-new" }
        #expect(rows.count == 1)

        let row = try #require(rows.first)
        #expect(row.contextUsageJSON == "second")
        // The meter's write must not move the session list's sort key,
        // so the row's stamp is the one the first save left behind.
        #expect(row.updatedAt == stampBefore)
    }

    @Test("a second save overwrites the reading and leaves the order alone")
    @MainActor
    func savingDoesNotReshuffleTheSessionList() throws {
        let repo = try makeRepository()
        try repo.saveContextUsage("old", sessionId: "s-2", bookID: Self.bookA)
        let found = try repo.getSession(sessionID: "s-2", bookID: Self.bookA)
        let row = try #require(found)
        let stampBefore = row.updatedAt

        try repo.saveContextUsage("new", sessionId: "s-2", bookID: Self.bookA)

        let after = try repo.loadContextUsage(sessionId: "s-2", bookID: Self.bookA)
        #expect(after == "new")
        #expect(row.updatedAt == stampBefore)
    }

    @Test("clearing the conversation drops its reading")
    @MainActor
    func clearingDropsTheReading() throws {
        let repo = try makeRepository()
        try repo.append(
            id: "m-1",
            source: "user",
            content: "hello",
            tokens: 2,
            thinking: nil,
            timestamp: Date(),
            sessionId: "s-3",
            bookID: Self.bookA
        )
        try repo.saveContextUsage("payload", sessionId: "s-3", bookID: Self.bookA)
        let before = try repo.loadContextUsage(sessionId: "s-3", bookID: Self.bookA)
        #expect(before == "payload")

        try repo.clear(sessionId: "s-3", bookID: Self.bookA)

        let after = try repo.loadContextUsage(sessionId: "s-3", bookID: Self.bookA)
        let messages = try repo.loadMessages(sessionId: "s-3", bookID: Self.bookA)
        #expect(after == nil)
        #expect(messages.isEmpty)
    }

    @Test("clearing one book leaves the other book's reading intact")
    @MainActor
    func clearingIsScopedToo() throws {
        let repo = try makeRepository()
        try repo.saveContextUsage("A", sessionId: "same-id", bookID: Self.bookA)
        try repo.saveContextUsage("B", sessionId: "same-id", bookID: Self.bookB)

        try repo.clear(sessionId: "same-id", bookID: Self.bookA)

        #expect(try repo.loadContextUsage(sessionId: "same-id", bookID: Self.bookA) == nil)
        #expect(try repo.loadContextUsage(sessionId: "same-id", bookID: Self.bookB) == "B")
    }

    @Test("the reading is on disk, = = so a new process reads it back")
    @MainActor
    func theReadingSurvivesTheProcessThatWroteIt() throws {
        // An in-memory container cannot answer the boss's question, = = because
        // it dies with the process. So this case writes to a FILE-backed
        // store, = = lets the writer's container go, = = and opens a second
        // container over the same file = = which is what a relaunch does.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-meter-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("WenshuStore.store")
        do {
            let writer = WSChatRepository(
                container: try WSPersistenceContainer.makeContainer(at: storeURL)
            )
            try writer.saveContextUsage("on-disk", sessionId: "s-restart", bookID: Self.bookA)
        }

        // A second container over the same file = = a new process reading
        // what the old one wrote.
        let reader = WSChatRepository(
            container: try WSPersistenceContainer.makeContainer(at: storeURL)
        )
        #expect(try reader.loadContextUsage(sessionId: "s-restart", bookID: Self.bookA) == "on-disk")
    }
}
