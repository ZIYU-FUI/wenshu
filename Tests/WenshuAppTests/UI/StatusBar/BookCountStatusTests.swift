// BookCountStatusTests.swift · Wenshu (文枢) · B-07 015.019
//
// Boss 2026-09-04 OOB '往后推进': the sidebar bottom status bar's
// "书: N" must reflect the actual library book count (=
// `BookStore.books.count`) and stay reactive across add / remove.
//
// These 3 round-trip tests verify the reactive `books` mirror on
// `BookStore`:
//   1. empty library → `books.count == 0`
//   2. one saved book → `books.count == 1`
//   3. add then delete → count returns to the pre-add value
//
// Test design: each test builds an isolated `LibraryStores` rooted
// in a fresh `/tmp` directory (= Apple HIG "sandbox per test" =
// no cross-test pollution, no fixture file dependency). The
// production `FileSystemReferenceStore` is used (= zero stubs =
// tests exercise the same code path the running app does).

import Testing
import Foundation
@testable import WenshuApp

@Suite("B-07 015.019 status bar book count")
struct BookCountStatusTests {

    /// Build a fresh `BookStore` rooted in a unique `/tmp` directory.
    /// Caller-side teardown not required (= each test uses a unique
    /// uuid so /tmp collisions are practically impossible during
    /// the test run; macOS auto-cleans /tmp on reboot).
    @MainActor
    private func makeBookStore() throws -> (BookStore, URL) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-b07-015019-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), tmpRoot)
    }

    /// 1) Empty library → `bookStore.books.count == 0`.
    /// Verifies the default state and that `reloadAllBooks()` on an
    /// empty workspace leaves the mirror at zero (not crashes).
    @Test("testBookCount_zeroLibrary")
    @MainActor
    func testBookCount_zeroLibrary() async throws {
        let (store, _) = try makeBookStore()
        // Initially empty (= property default = `[]`).
        #expect(store.books.count == 0)
        // After explicit reload: still zero (= nothing on disk).
        store.reloadAllBooks()
        #expect(store.books.count == 0)
        // This is the value the projectSidebar bottom-status reads.
        #expect(store.books.count == 0)
    }

    /// 2) One saved book → `bookStore.books.count == 1`.
    /// Verifies the add path keeps the mirror in sync (= no stale 0).
    @Test("testBookCount_withOneBook")
    @MainActor
    func testBookCount_withOneBook() async throws {
        let (store, tmpRoot) = try makeBookStore()
        // Stage a shelf dir + a shelf object so sidebarSaveBook can
        // write the book.json (= sidebarSaveBook creates the
        // bookDir under `<shelvesRoot>/<shelfId>/books/<bookId>/`
        // — we mirror the same pattern NewLibraryOutlineView uses).
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let shelf = Bookshelf(name: "Test Shelf")
        let shelfDir = shelvesRoot.appendingPathComponent(shelf.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDir.appendingPathComponent("books"), withIntermediateDirectories: true)
        let shelfData = try JSONEncoder().encode(shelf)
        try shelfData.write(to: shelfDir.appendingPathComponent("shelf.json"))

        let book = Book(title: "One", author: "", shelfId: shelf.id)
        try store.sidebarSaveBook(book)

        #expect(store.books.count == 1)
        #expect(store.books.first?.id == book.id)

        // Confirm `reloadAllBooks()` rebuilds the mirror from disk
        // (= if a sibling code path wrote the book.json without
        // calling sidebarSaveBook, the count still recovers).
        store.reloadAllBooks()
        #expect(store.books.count == 1)
    }

    /// 3) Add then remove → count returns to the pre-add value.
    /// Verifies the remove path keeps the mirror in sync (= no
    /// ghost books after delete).
    @Test("testBookCount_addAndRemoveBook")
    @MainActor
    func testBookCount_addAndRemoveBook() async throws {
        let (store, tmpRoot) = try makeBookStore()
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let shelf = Bookshelf(name: "Test Shelf")
        let shelfDir = shelvesRoot.appendingPathComponent(shelf.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDir.appendingPathComponent("books"), withIntermediateDirectories: true)
        let shelfData = try JSONEncoder().encode(shelf)
        try shelfData.write(to: shelfDir.appendingPathComponent("shelf.json"))

        // Baseline: zero books.
        #expect(store.books.count == 0)

        // Add a book.
        let book = Book(title: "Round-trip", author: "", shelfId: shelf.id)
        try store.sidebarSaveBook(book)
        #expect(store.books.count == 1)

        // Remove the book.
        try store.sidebarDeleteBook(id: book.id)
        #expect(store.books.count == 0)

        // After a fresh disk reload, count is still zero (= the
        // delete also wiped the on-disk book.json).
        store.reloadAllBooks()
        #expect(store.books.count == 0)

        // Idempotency: deleting an unknown id is a no-op.
        try store.sidebarDeleteBook(id: UUID())
        #expect(store.books.count == 0)
    }
}
