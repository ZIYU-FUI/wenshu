//
//  Tests/Library/Service/BookProtectionMutationTests.swift · Wenshu
//
//  The permission matrix, measured through the sidebar's OWN mutation
//  layer (= the door the user's right-click menu opens).
//
//  The matrix the boss ruled:
//
//  | row          | rename | edit | delete |
//  |--------------|--------|------|--------|
//  | the help book| NO     | NO   | YES    |
//  | the default shelf | NO | –    | YES    |
//  | an ordinary book/shelf | YES | YES | YES |
//
//  These tests go through `SidebarService.renameBook` /
//  `renameShelf` / `deleteShelf`, = because the UI hiding a menu item
//  is a CONVENIENCE, = not the rule. The rule has to hold when the
//  caller is not the menu (= the agent's tool, = a future keyboard
//  shortcut, = a script).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The book's protection rules (= the sidebar's mutation layer)")
@MainActor
struct BookProtectionMutationTests {
    // MARK: - The fixture

    /// A library with a default shelf, a help book and an ordinary book.
    private struct Fixture {
        let root: URL
        let service: SidebarService
        let bookStore: BookStore
        let helpBook: Book
        let ordinaryBook: Book
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-book-protection-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)

        let store = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: store
        )
        let bookStore = BookStore(stores: stores)
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { [] },
            bookStore: bookStore
        )

        // The help book (= the app's own document) and an ordinary book,
        // both on the default shelf.
        let helpBook = Book(
            id: BookSessionLifecycle.helpBookID,
            title: "Help",
            author: "wenshu",
            shelfId: BookSessionLifecycle.defaultShelfID,
            createdAt: Date(),
            updatedAt: Date()
        )
        let ordinaryBook = Book(
            id: UUID(),
            title: "My Novel",
            author: "wenshu",
            shelfId: BookSessionLifecycle.defaultShelfID,
            createdAt: Date(),
            updatedAt: Date()
        )
        try bookStore.sidebarSaveBook(helpBook)
        try bookStore.sidebarSaveBook(ordinaryBook)

        return Fixture(
            root: root,
            service: service,
            bookStore: bookStore,
            helpBook: helpBook,
            ordinaryBook: ordinaryBook
        )
    }

    // MARK: - The helper

    /// The title the book.json on disk carries (= what the user sees).
    ///
    /// The assertion reads the FILE, = not the store's in-memory array:
    /// the store's array is what the mutation updates, = so reading it
    /// would prove that the mutation ran, = not that the user's book
    /// changed.
    private func onDiskTitle(of bookID: UUID, in fixture: Fixture) throws -> String? {
        let bookDirectory = fixture.root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(BookSessionLifecycle.defaultShelfID.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
        let json = bookDirectory.appendingPathComponent("book.json")
        guard FileManager.default.fileExists(atPath: json.path) else { return nil }
        let data = try Data(contentsOf: json)
        return try JSONDecoder().decode(Book.self, from: data).title
    }

    // MARK: - The book

    @Test("The help book cannot be renamed")
    func helpBookCannotBeRenamed() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        #expect(throws: SidebarService.MutationError.cannotRenameHelpBook) {
            try fixture.service.renameBook(
                id: fixture.helpBook.id,
                newTitle: "Renamed Help"
            )
        }
    }

    @Test("The help book's title on disk is unchanged after a refused rename")
    func helpBookTitleIsUnchangedAfterARefusedRename() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try? fixture.service.renameBook(
            id: fixture.helpBook.id,
            newTitle: "Renamed Help"
        )

        #expect(try onDiskTitle(of: fixture.helpBook.id, in: fixture) == "Help")
    }

    @Test("An ordinary book can be renamed")
    func ordinaryBookCanBeRenamed() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try fixture.service.renameBook(
            id: fixture.ordinaryBook.id,
            newTitle: "Renamed Novel"
        )

        #expect(try onDiskTitle(of: fixture.ordinaryBook.id, in: fixture) == "Renamed Novel")
    }

    @Test("The help book CAN be deleted")
    func helpBookCanBeDeleted() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The refusal to rename is NOT a refusal to delete: the boss
        // ruled the help book deletable (= the user may clear the app's
        // own document out of the way).
        try fixture.service.deleteBook(id: fixture.helpBook.id)

        #expect(try onDiskTitle(of: fixture.helpBook.id, in: fixture) == nil)
    }

    @Test("A removal that FAILS leaves the book in the shared list")
    func aFailedRemovalLeavesTheBookInTheList() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // ⇒ THE BOOK IS FORGOTTEN ONLY AFTER A SUCCESSFUL REMOVAL.
        //
        // The earlier version forgot the book in a `defer`, = and a
        // `defer` runs on EVERY exit path (= including one that exits by
        // an error), = so a removal that FAILED (= the book is still on
        // disk) dropped the book from the shared list anyway: = the list
        // and the disk disagreed, = in the direction this change exists
        // to remove. MEASURED: the removal can fail (= a permission
        // error).
        //
        // The removal fails when the book's PARENT cannot be written
        // to: = the book directory is a child of it, = and unlinking a
        // child needs write permission on the parent. = ⇒ It is the
        // `books` directory that has to be read-only, = NOT the shelf
        // directory above it: = unlinking the book needs write on
        // `books`, = and the shelf's own permission is not consulted.
        // MEASURED: `rm -rf` on the book succeeds with the shelf at
        // 0555 (= it unlinks the book from `books`, = which is still
        // writable) and fails with `books` at 0555.
        let booksDirectory = fixture.root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(BookSessionLifecycle.defaultShelfID.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: booksDirectory.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: booksDirectory.path
            )
        }

        #expect(throws: (any Error).self) {
            try fixture.service.deleteBook(id: fixture.ordinaryBook.id)
        }

        #expect(
            fixture.bookStore.books.contains { $0.id == fixture.ordinaryBook.id },
            "the book must stay in the shared list while it is still on disk"
        )
    }

    // MARK: - The shelf

    @Test("The default shelf cannot be renamed")
    func defaultShelfCannotBeRenamed() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        #expect(throws: SidebarService.MutationError.cannotRenameDefault) {
            try fixture.service.renameShelf(
                id: BookSessionLifecycle.defaultShelfID,
                newName: "Renamed Shelf"
            )
        }
    }

    @Test("The default shelf CAN be deleted")
    func defaultShelfCanBeDeleted() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The default shelf's NAME is the app's; = the shelf itself is
        // the user's to clear away.
        try fixture.service.deleteShelf(id: BookSessionLifecycle.defaultShelfID)

        let shelfDirectory = fixture.root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(BookSessionLifecycle.defaultShelfID.uuidString, isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: shelfDirectory.path) == false)
    }

    @Test("An ordinary shelf is not refused by the default-shelf guard")
    func ordinaryShelfIsNotRefusedByTheDefaultShelfGuard() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // An ordinary shelf (= one that is not the default) is not
        // refused by the DEFAULT-SHELF guard. What it gets instead is
        // the ordinary "no such shelf" answer, = which is a different
        // error: the guard named the right thing to refuse.
        #expect(throws: SidebarService.MutationError.shelfNotFound) {
            try fixture.service.renameShelf(id: UUID(), newName: "My Shelf")
        }
    }
}
