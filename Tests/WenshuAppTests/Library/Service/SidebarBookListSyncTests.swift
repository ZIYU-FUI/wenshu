//
//  Tests/Library/Service/SidebarBookListSyncTests.swift · Wenshu
//
//  The user's OWN door must keep the app's shared book list current.
//
//  The chat zone's session bar reads `bookStore.books` (= its page list
//  is "one page per ordinary book"), and the store's list is written by
//  the doors that create, rename and delete a book. The agent's door
//  (`BookManagerTool`) went through the store's own writers, so it kept
//  the list current; the USER's door (= the sidebar's row menu, = the
//  preview pane's card menu, = the New Book sheet) wrote the disk
//  itself and left the list stale, = so the bar showed no page for a
//  book the user had just created, and still showed a page for a book
//  the user had just deleted.
//
//  ⇒ SO THESE TESTS DRIVE THE PRODUCTION DOOR (= `SidebarService`'s own
//  mutations, = the ones the menus call) AND READ THE COLLECTION THE
//  BAR READS. A test that calls `ChatScope.pageList(books:)` with a
//  hand-built array proves the function is right and says nothing about
//  whether the user's door ever reaches it.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The user's door keeps the shared book list current (= the bar's page list follows)")
@MainActor
struct SidebarBookListSyncTests {
    // MARK: - The fixture

    /// A library with a real store, and the sidebar's service over it.
    private struct Fixture {
        let root: URL
        let service: SidebarService
        let bookStore: BookStore
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-book-list-sync-\(UUID().uuidString)")
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
            loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
            loadReferences: { [] },
            bookStore: bookStore
        )
        return Fixture(root: root, service: service, bookStore: bookStore)
    }

    /// The bar's page list, read from the collection the bar reads.
    private func pageTitles(_ fixture: Fixture) -> [String] {
        ChatScope.pageList(
            books: fixture.bookStore.books,
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        ).map(\.title)
    }

    private func newBookInput(_ title: String, shelfId: UUID) -> NewBookSheet.NewBookInput {
        NewBookSheet.NewBookInput(
            title: title,
            author: "wenshu",
            shelfId: shelfId,
            icon: "book"
        )
    }

    // MARK: - The create

    @Test("A book the user creates gets a page at once")
    func createdBookGetsAPageAtOnce() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let shelfID = BookSessionLifecycle.defaultShelfID
        let bookID = try fixture.service.createBook(
            input: newBookInput("My Novel", shelfId: shelfID)
        )

        // The shared list names it (= the bar reads that list).
        #expect(fixture.bookStore.books.contains { $0.id == bookID })
        // The bar's page list has its page.
        #expect(pageTitles(fixture) == ["Wenshu", "My Novel", "Reference Library"])
    }

    // MARK: - The rename

    @Test("A book the user renames shows its NEW name in the page list")
    func renamedBookShowsItsNewName() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let shelfID = BookSessionLifecycle.defaultShelfID
        let bookID = try fixture.service.createBook(
            input: newBookInput("Old Title", shelfId: shelfID)
        )
        try fixture.service.renameBook(id: bookID, newTitle: "New Title")

        let onDisk = try fixture.bookStore.sidebarLoadAllBooks()
            .first { $0.id == bookID }
        #expect(onDisk?.title == "New Title")
        // The bar's page list names the NEW title (= the list is what
        // the bar reads, = and the list carried the old one before).
        #expect(pageTitles(fixture) == ["Wenshu", "New Title", "Reference Library"])
    }

    // MARK: - The delete

    @Test("A book the user deletes leaves NO page behind")
    func deletedBookLeavesNoPage() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let shelfID = BookSessionLifecycle.defaultShelfID
        let bookID = try fixture.service.createBook(
            input: newBookInput("Doomed", shelfId: shelfID)
        )
        #expect(pageTitles(fixture) == ["Wenshu", "Doomed", "Reference Library"])

        try fixture.service.deleteBook(id: bookID)

        // The book is off the disk and out of the shared list.
        #expect(try fixture.bookStore.sidebarLoadAllBooks().contains { $0.id == bookID } == false)
        #expect(fixture.bookStore.books.contains { $0.id == bookID } == false)
        // The bar's page list has no page for it.
        #expect(pageTitles(fixture) == ["Wenshu", "Reference Library"])
    }

    // MARK: - The whole round, through the door

    @Test("The page list follows the user's door through a create, a rename and a delete")
    func thePageListFollowsTheUsersDoor() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let shelfID = BookSessionLifecycle.defaultShelfID
        // The library starts with no book, = so the bar has its two
        // fixed pages and nothing else.
        #expect(pageTitles(fixture) == ["Wenshu", "Reference Library"])

        let bookID = try fixture.service.createBook(
            input: newBookInput("First", shelfId: shelfID)
        )
        #expect(pageTitles(fixture) == ["Wenshu", "First", "Reference Library"])

        try fixture.service.renameBook(id: bookID, newTitle: "Second")
        #expect(pageTitles(fixture) == ["Wenshu", "Second", "Reference Library"])

        try fixture.service.deleteBook(id: bookID)
        #expect(pageTitles(fixture) == ["Wenshu", "Reference Library"])
    }

    @Test("The help book is in the shared list but contributes NO page")
    func theHelpBookContributesNoPage() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // The help book on disk (= the migrator's own book).
        let help = Book(
            id: BookSessionLifecycle.helpBookID,
            title: "Help",
            author: "wenshu",
            shelfId: BookSessionLifecycle.defaultShelfID,
            createdAt: Date(),
            updatedAt: Date()
        )
        try fixture.bookStore.sidebarSaveBook(help)
        let ordinary = Book(
            id: UUID(),
            title: "Ordinary",
            author: "wenshu",
            shelfId: BookSessionLifecycle.defaultShelfID,
            createdAt: Date(),
            updatedAt: Date()
        )
        try fixture.bookStore.sidebarSaveBook(ordinary)

        // The list holds both (= the help book IS a book), = and the
        // bar's page list holds one page (= the ordinary book's).
        #expect(fixture.bookStore.books.count == 2)
        #expect(pageTitles(fixture) == ["Wenshu", "Ordinary", "Reference Library"])
    }
}
