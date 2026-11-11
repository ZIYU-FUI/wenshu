//
//  Tests/Library/Service/BookSessionLifecycleTests.swift · Wenshu
//
//  The book ⇄ session relationship, and the rules that say which books
//  the user may change.
//
//  The contract under test:
//
//    1. The help book (= the app's own document) is READ-ONLY: it
//       cannot be renamed, and its content cannot be written. It CAN be
//       deleted (= the user may clear the app's own document away).
//    2. The default shelf's NAME is the app's: it cannot be renamed.
//       The shelf ITSELF can be deleted (= only its name is protected).
//    3. Renaming a book renames its conversation (= the same session,
//       = the new title), and the session keeps its identity.
//    4. Deleting a book deletes its conversation, and every message in
//       it.
//
//  The identities are compared as IDS, = never by the localized display
//  title (= the title is a string the user can change; = the id is the
//  identity).
//

import Foundation
import SwiftData
import Testing
@testable import WenshuApp
import WenshuData

@Suite("Book ⇄ session lifecycle (= the book's protection rules)")
struct BookSessionLifecycleTests {
    // MARK: - The identities

    @Test("The help book is recognised by its id")
    func helpBookIsRecognisedByItsID() {
        #expect(BookSessionLifecycle.isHelpBook(BookSessionLifecycle.helpBookID))
    }

    @Test("An ordinary book is not the help book")
    func ordinaryBookIsNotTheHelpBook() {
        #expect(BookSessionLifecycle.isHelpBook(UUID()) == false)
    }

    @Test("The default shelf is recognised by its id")
    func defaultShelfIsRecognisedByItsID() {
        #expect(BookSessionLifecycle.isDefaultShelf(BookSessionLifecycle.defaultShelfID))
    }

    @Test("An ordinary shelf is not the default shelf")
    func ordinaryShelfIsNotTheDefaultShelf() {
        #expect(BookSessionLifecycle.isDefaultShelf(UUID()) == false)
    }

    @Test("The help book and the default shelf are different rows")
    func helpBookAndDefaultShelfAreDifferentRows() {
        #expect(BookSessionLifecycle.helpBookID != BookSessionLifecycle.defaultShelfID)
    }

    // MARK: - The directory → book identity (= the filesystem layer's view)

    @Test("A book directory names its book")
    func bookDirectoryNamesItsBook() {
        let bookID = UUID()
        let directory = URL(fileURLWithPath: "/tmp/wenshu/books/\(bookID.uuidString)")

        #expect(BookSessionLifecycle.bookID(inBookDirectory: directory) == bookID)
    }

    @Test("The help book's directory is a read-only directory")
    func helpBookDirectoryIsReadOnly() {
        let directory = URL(fileURLWithPath: "/tmp/wenshu/books/\(BookSessionLifecycle.helpBookID.uuidString)")

        #expect(BookSessionLifecycle.isReadOnlyBookDirectory(directory))
    }

    @Test("An ordinary book's directory is not a read-only directory")
    func ordinaryBookDirectoryIsNotReadOnly() {
        let directory = URL(fileURLWithPath: "/tmp/wenshu/books/\(UUID().uuidString)")

        #expect(BookSessionLifecycle.isReadOnlyBookDirectory(directory) == false)
    }

    @Test("A directory that names no book is not a read-only directory")
    func nonBookDirectoryIsNotReadOnly() {
        let directory = URL(fileURLWithPath: "/tmp/wenshu/books/not-a-uuid")

        #expect(BookSessionLifecycle.isReadOnlyBookDirectory(directory) == false)
    }

    // MARK: - The session movement (= the repository's half)

    @MainActor
    @Test("Renaming a book renames its session, and the session keeps its id")
    func renamingABookRenamesItsSession() throws {
        let repository = try makeRepository()
        let bookID = UUID()
        let sessionID = "book:\(bookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: sessionID,
            title: "Old Name",
            bookID: bookID.uuidString
        )

        BookSessionLifecycle.renameSession(
            bookID: bookID,
            newTitle: "New Name",
            repository: repository
        )

        let renamed = try repository.getSession(sessionID: sessionID, bookID: bookID.uuidString)
        #expect(renamed?.title == "New Name")
        // The session is the SAME session: its id is what the messages
        // point at, so a replaced session would take the history with
        // it.
        #expect(renamed?.sessionID == sessionID)
    }

    @MainActor
    @Test("Renaming a book leaves another book's session alone")
    func renamingABookLeavesOtherSessionsAlone() throws {
        let repository = try makeRepository()
        let renamedBookID = UUID()
        let otherBookID = UUID()
        let otherSessionID = "book:\(otherBookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: otherSessionID,
            title: "Other Name",
            bookID: otherBookID.uuidString
        )

        BookSessionLifecycle.renameSession(
            bookID: renamedBookID,
            newTitle: "New Name",
            repository: repository
        )

        let untouched = try repository.getSession(sessionID: otherSessionID, bookID: otherBookID.uuidString)
        #expect(untouched?.title == "Other Name")
    }

    @MainActor
    @Test("Deleting a book deletes its session")
    func deletingABookDeletesItsSession() throws {
        let repository = try makeRepository()
        let bookID = UUID()
        let sessionID = "book:\(bookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: sessionID,
            title: "Doomed",
            bookID: bookID.uuidString
        )

        BookSessionLifecycle.deleteSession(bookID: bookID, repository: repository)

        let deleted = try repository.getSession(sessionID: sessionID, bookID: bookID.uuidString)
        #expect(deleted == nil)
    }

    @MainActor
    @Test("Deleting a book leaves another book's session alone")
    func deletingABookLeavesOtherSessionsAlone() throws {
        let repository = try makeRepository()
        let doomedBookID = UUID()
        let otherBookID = UUID()
        let otherSessionID = "book:\(otherBookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: otherSessionID,
            title: "Survivor",
            bookID: otherBookID.uuidString
        )
        let doomedSessionID = "book:\(doomedBookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: doomedSessionID,
            title: "Doomed",
            bookID: doomedBookID.uuidString
        )

        BookSessionLifecycle.deleteSession(bookID: doomedBookID, repository: repository)

        let survivor = try repository.getSession(sessionID: otherSessionID, bookID: otherBookID.uuidString)
        #expect(survivor?.title == "Survivor")
    }

    @MainActor
    @Test("Deleting a book deletes every session under it")
    func deletingABookDeletesEverySessionUnderIt() throws {
        let repository = try makeRepository()
        let bookID = UUID()
        let firstSessionID = "book:\(bookID.uuidString):first"
        let secondSessionID = "book:\(bookID.uuidString):second"
        _ = try repository.createSession(
            sessionID: firstSessionID,
            title: "First",
            bookID: bookID.uuidString
        )
        _ = try repository.createSession(
            sessionID: secondSessionID,
            title: "Second",
            bookID: bookID.uuidString
        )

        BookSessionLifecycle.deleteSession(bookID: bookID, repository: repository)

        #expect(try repository.getSession(sessionID: firstSessionID, bookID: bookID.uuidString) == nil)
        #expect(try repository.getSession(sessionID: secondSessionID, bookID: bookID.uuidString) == nil)
    }

    @MainActor
    @Test("Deleting a book takes its messages with it")
    func deletingABookTakesItsMessagesWithIt() throws {
        let repository = try makeRepository()
        let bookID = UUID()
        let sessionID = "book:\(bookID.uuidString):default"
        _ = try repository.createSession(
            sessionID: sessionID,
            title: "Doomed",
            bookID: bookID.uuidString
        )
        try repository.append(
            id: "message-1",
            source: "user",
            content: "a message that belongs to the doomed book",
            tokens: nil,
            thinking: nil,
            timestamp: Date(),
            sessionId: sessionID,
            bookID: bookID.uuidString
        )
        #expect(try repository.loadMessages(sessionId: sessionID, bookID: bookID.uuidString).count == 1)

        BookSessionLifecycle.deleteSession(bookID: bookID, repository: repository)

        #expect(try repository.loadMessages(sessionId: sessionID, bookID: bookID.uuidString).isEmpty)
    }

    // MARK: - The helper

    /// A repository on its own in-memory store.
    ///
    /// The test must never write into the user's own library, so it
    /// brings its own container instead of using the app's shared one.
    @MainActor
    private func makeRepository() throws -> WSChatRepository {
        let schema = Schema([WSChatMessage.self, WSSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return WSChatRepository(container: container)
    }
}
