//
//  WSPersistenceContractTests.swift · Wenshu
//
//  The three contracts the persistence layer owes the rest of the app:
//
//  1. One store: every repository reads and writes the same file, so a
//     row written through one repository is visible through the other.
//  2. One session key: a session is identified by (sessionID + bookID),
//     so the same sessionID under two books is two rows, and the same
//     pair twice is one row.
//  3. One timestamp: a message carries the instant the caller observed
//     it, so the transcript order survives a round trip through the
//     store.
//
//  Each test prints its probe lines (= the evidence the commit body
//  quotes) and asserts the contract.
//

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("WSPersistence (= one store, one session key, one timestamp)")
struct WSPersistenceContractTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        WSChatRepository(container: try WSPersistenceContainer.makeInMemoryContainer())
    }

    // MARK: - 1. One store

    /// The app has one store. A row written through the chat repository
    /// is visible through the repository container, and both point at
    /// the same file.
    ///
    /// The probe activates a warehouse container at a scratch path (= the
    /// app's live path after the app delegate activates the library),
    /// so the singletons resolve to it and the real user store is not
    /// touched.
    @Test("One store: every repository resolves the same live container")
    @MainActor
    func oneStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-one-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let container = try WSPersistenceContainer.makeContainer(
            at: directory.appendingPathComponent("WenshuStore.store")
        )
        WSPersistenceContainer.activateWarehouseContainer(container)
        defer { WSPersistenceContainer.activateWarehouseContainer(nil) }

        try WSChatRepository.shared.createSession(sessionID: "probe-one-store", bookID: "book-A")

        let chatURL = WSChatRepository.shared.store.container.configurations.first?.url
        let containerURL = WSRepositoryContainer.shared.chat.store.container.configurations.first?.url

        print("PROBE1: chat repository store URL = \(chatURL?.path ?? "none")")
        print("PROBE1: repository container store URL = \(containerURL?.path ?? "none")")
        print("PROBE1: same store file = \(chatURL == containerURL)")

        #expect(chatURL != nil, "the chat repository resolves a file-backed store")
        #expect(chatURL == containerURL,
                "both repositories resolve the same store file")
        #expect(chatURL == directory.appendingPathComponent("WenshuStore.store"))

        let visible = try WSRepositoryContainer.shared.chat.listSessions(bookID: "book-A")
        print("PROBE1: session written through the chat repository, read through the container = \(visible.count) row")
        #expect(visible.contains { $0.sessionID == "probe-one-store" },
                "the row written through one repository is visible through the other")
    }

    // MARK: - 2. One session key

    /// A session is identified by (sessionID + bookID). The same
    /// sessionID under two books is two rows, and each book sees its
    /// own.
    @Test("One session key: the same sessionID under two books is two rows")
    @MainActor
    func oneSessionKey() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "shared", title: "A", bookID: "book-A")
        try repo.createSession(sessionID: "shared", title: "B", bookID: "book-B")

        let context = ModelContext(repo.store.container)
        let rows = try context.fetch(FetchDescriptor<WSSession>())

        print("PROBE2: WSSession rows for one sessionID under two books = \(rows.count)")
        print("PROBE2: book-A sessions = \(try repo.listSessions(bookID: "book-A").count), book-B sessions = \(try repo.listSessions(bookID: "book-B").count)")

        #expect(rows.count == 2, "the sessionID column does not collapse the two books")
        #expect(try repo.listSessions(bookID: "book-A").count == 1)
        #expect(try repo.listSessions(bookID: "book-B").count == 1)
        #expect(try repo.listSessions(bookID: "book-A").first?.title == "A")
        #expect(try repo.listSessions(bookID: "book-B").first?.title == "B")
    }

    /// The other half of the same key: the same pair twice is one row.
    @Test("One session key: the same (sessionID + bookID) twice is one row")
    @MainActor
    func oneRowPerSessionKey() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "twice", title: "first", bookID: "book-A")
        try repo.createSession(sessionID: "twice", title: "second", bookID: "book-A")

        let context = ModelContext(repo.store.container)
        let rows = try context.fetch(FetchDescriptor<WSSession>())

        print("PROBE2b: WSSession rows for one (sessionID + bookID) written twice = \(rows.count)")

        #expect(rows.count == 1, "the composite key is enforced by the repository")
        #expect(try repo.listSessions(bookID: "book-A").count == 1)
    }

    /// The global bucket (= no book) is its own key: the same
    /// sessionID with no book is one row, and a book-scoped session
    /// under the same sessionID is a different row.
    @Test("One session key: the global bucket is its own key")
    @MainActor
    func globalBucketIsItsOwnKey() throws {
        let repo = try makeRepository()
        try repo.createSession(sessionID: "shared", bookID: "book-A")
        try repo.createSession(sessionID: "shared", bookID: nil)
        try repo.createSession(sessionID: "shared", bookID: nil)

        let context = ModelContext(repo.store.container)
        let rows = try context.fetch(FetchDescriptor<WSSession>())

        print("PROBE2c: WSSession rows for one sessionID in the global bucket and under a book = \(rows.count)")

        #expect(rows.count == 2, "the global bucket is one row, the book scope is another")
        #expect(try repo.listSessions(bookID: nil).count == 1)
        #expect(try repo.listSessions(bookID: nil).first?.bookID == nil)
        #expect(try repo.listSessions(bookID: "book-A").count == 1)
    }

    // MARK: - 3. One timestamp

    /// A message carries the instant the caller observed it, not the
    /// instant it was written.
    @Test("One timestamp: the caller's time is stored")
    @MainActor
    func oneTimestamp() throws {
        let repo = try makeRepository()
        let observed = Date(timeIntervalSince1970: 1_000_000)
        try repo.append(
            id: "msg-1",
            source: "user",
            content: "hello",
            tokens: nil,
            thinking: nil,
            timestamp: observed,
            sessionId: "sess-1"
        )

        let rows = try repo.loadMessages(sessionId: "sess-1")
        let stored = try #require(rows.first?.createdAt)

        print("PROBE3: stored createdAt = \(stored.timeIntervalSince1970), expected = \(observed.timeIntervalSince1970)")
        print("PROBE3: wall clock at write = \(Date().timeIntervalSince1970)")

        #expect(abs(stored.timeIntervalSince(observed)) < 1,
                "the stored timestamp is the caller's, within a second")
        #expect(abs(stored.timeIntervalSinceNow) > 1,
                "the stored timestamp is not the wall clock at write time")
    }

    /// The order of the transcript survives the round trip: the read
    /// path orders by the stored timestamp.
    @Test("One timestamp: the transcript order survives the round trip")
    @MainActor
    func transcriptOrderSurvivesRoundTrip() throws {
        let repo = try makeRepository()
        let first = Date(timeIntervalSince1970: 1_000_000)
        let second = Date(timeIntervalSince1970: 1_000_500)
        // Appended out of order (= a late reply landing after the next
        // user message), which is the case the wall clock got wrong.
        try repo.append(
            id: "msg-late",
            source: "user",
            content: "late",
            tokens: nil,
            thinking: nil,
            timestamp: second,
            sessionId: "sess-2"
        )
        try repo.append(
            id: "msg-early",
            source: "wenshu",
            content: "early",
            tokens: nil,
            thinking: nil,
            timestamp: first,
            sessionId: "sess-2"
        )

        let rows = try repo.loadMessages(sessionId: "sess-2")
        print("PROBE3b: transcript order after the round trip = \(rows.map(\.id))")

        #expect(rows.map(\.id) == ["msg-early", "msg-late"],
                "the read path orders by the caller's timestamp")
    }

    /// Position is the tiebreaker behind the timestamp, and it counts
    /// the rows the session already holds (= zero-based).
    @Test("One timestamp: position counts the rows the session already holds")
    @MainActor
    func positionCountsExistingRows() throws {
        let repo = try makeRepository()
        for index in 1...3 {
            try repo.append(
                id: "msg-\(index)",
                source: "user",
                content: "message \(index)",
                tokens: nil,
                thinking: nil,
                timestamp: Date(timeIntervalSince1970: 1_000_000),
                sessionId: "sess-3"
            )
        }

        let rows = try repo.loadMessages(sessionId: "sess-3")
        print("PROBE3c: positions = \(rows.map(\.position))")

        #expect(rows.map(\.position) == [0, 1, 2],
                "position is the count of the rows already stored")
    }
}
