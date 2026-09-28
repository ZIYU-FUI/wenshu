// ROBUSTNESS-1 — WSChatRepository nil-bookID round-trip contract.
//
// Wenshu v1.79 (§11.11) split chat history per book at the row level.
// The contract: when caller passes `bookID: nil`, messages land in the
// global un-attached bucket (bookID column = NULL on disk) and
// `loadMessages(sessionId: ..., bookID: nil)` returns ONLY those rows —
// never cross-book leaks.
//
// Pre-fix bug (§11.11 finding 2026-09-28): effectiveBookID fallback to
// `BookID(rawValue: "")` when session.bookID was empty string caused
// messages to round-trip under a phantom BookID, breaking the
// nil = global invariant.
//
// Reference: AGENTS.md §11.11 (row-level split), §11.13 (TypedID pilot).
import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite(.serialized)
struct WSChatRepositoryNilBookIDContractTests {

    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let schema = Schema([WSChatMessage.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return WSChatRepository(container: container)
    }

    @MainActor
    private func makeMessage(id: String, content: String) -> StoredChatMessage {
        StoredChatMessage(
            id: id,
            source: "user",
            content: content,
            timestamp: Date()
        )
    }

    @Test
    @MainActor
    func nilBookIDRoundTripsAsGlobalBucket() throws {
        let repo = try makeRepository()
        let sessionID = "book::global-test"

        try repo.append(
            makeMessage(id: "m-global-1", content: "global-bucket-message"),
            sessionId: sessionID,
            bookID: nil
        )

        let rows = try repo.loadMessages(sessionId: sessionID, bookID: nil)
        #expect(rows.count == 1)
        #expect(rows.first?.content == "global-bucket-message")
        #expect(rows.first?.id == "m-global-1",
                "global-bucket message must round-trip with same id under nil bookID")
    }

    @Test
    @MainActor
    func bookARowsDoNotLeakIntoGlobalOrBookB() throws {
        let repo = try makeRepository()
        let bookA = BookID(rawValue: "11111111-1111-1111-1111-111111111111")
        let bookB = BookID(rawValue: "22222222-2222-2222-2222-222222222222")
        let sessionA = "book:\(bookA.rawValue):default"
        let sessionB = "book:\(bookB.rawValue):default"

        try repo.append(makeMessage(id: "m-A", content: "book-A-payload"),
                        sessionId: sessionA, bookID: bookA)
        try repo.append(makeMessage(id: "m-B", content: "book-B-payload"),
                        sessionId: sessionB, bookID: bookB)

        // Book A load only sees book-A rows.
        let aRows = try repo.loadMessages(sessionId: sessionA, bookID: bookA)
        #expect(aRows.count == 1)
        #expect(aRows.first?.content == "book-A-payload")
        #expect(aRows.contains(where: { $0.content == "book-B-payload" }) == false,
                "book-A reader must not see book-B content")

        // Book B load only sees book-B rows.
        let bRows = try repo.loadMessages(sessionId: sessionB, bookID: bookB)
        #expect(bRows.count == 1)
        #expect(bRows.first?.content == "book-B-payload")

        // Global load sees neither book (no un-attached rows were written).
        let globalRows = try repo.loadMessages(
            sessionId: "book::untouched-global",
            bookID: nil
        )
        #expect(globalRows.isEmpty,
                "global bucket must be empty when no un-attached rows were written")
    }

    @Test
    @MainActor
    func emptyStringSessionIDDoesNotProducePhantomBookID() throws {
        // ROBUSTNESS-1.3 — Pre-fix the effectiveBookID fallback used
        // `BookID(rawValue: "")` which is technically a valid BookID but
        // represents an empty-string-book, not the global bucket.
        // Post-fix: empty-string session.bookID falls through to nil.
        let repo = try makeRepository()
        let sessionID = "book::legacy-empty-bk"

        try repo.append(
            makeMessage(id: "m-legacy-1", content: "legacy-bucket-message"),
            sessionId: sessionID,
            bookID: nil
        )

        let rows = try repo.loadMessages(sessionId: sessionID, bookID: nil)
        #expect(rows.count == 1,
                "legacy empty-bk session must round-trip under nil bookID")
        #expect(rows.first?.content == "legacy-bucket-message")
    }
}