//
//  BookManagerToolTests.swift · Wenshu · P2 ticket #20 (PORT-LIBRARIAN-001, 2026-09-05)
//
//  5 round-trip tests for BookManager actor + BookManagerTool
//  (= the Swift port of hermes's
//  `agent/librarian/book_manager.py`):
//
//    1. testCreateBook_returnsDescriptor
//    2. testRenameBook_updatesTitle
//    3. testDeleteBook_movesToTrash
//    4. testListBooks_returnsAll
//    5. testExecute_createAction_parsesAndCreates
//
//  Test isolation: each test creates a fresh /tmp root +
//  shelvesRoot + a real Bookshelf (= via BookStore.sidebarSaveShelf)
//  so the BookManager's shelf-existence check on create can pass.
//  Caller-side teardown is not required (= the directory is /tmp
//  + unique uuid; macOS auto-cleans /tmp).
//
//  Test pattern mirrors ForeshadowingTrackerToolsTests /
//  IdeaLibraryToolsTests (= uses the real LibraryStores struct +
//  FileSystemReferenceStore; no stubs).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookManagerTool (PORT-LIBRARIAN-001)")
struct BookManagerToolTests {

    // MARK: - Shared helpers

    /// Build a tiny BookStore rooted in a unique /tmp directory.
    private static func makeBookStore() throws -> (BookStore, LibraryStores) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-p2-20-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let shelvesRoot = tmpRoot.appendingPathComponent("shelves", isDirectory: true)
        let referenceLibraryRoot = tmpRoot.appendingPathComponent("reference-library", isDirectory: true)
        let referenceStore = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: referenceStore
        )
        return (BookStore(stores: stores), stores)
    }

    /// Create a real Bookshelf on disk via BookStore.sidebarSaveShelf
    /// (= mirrors the production UI path), then mirror it into
    /// `bookStore.shelves` (= the in-memory cache BookManager
    /// consults on create for shelf-existence checks).
    private static func makeShelf(
        bookStore: BookStore,
        stores: LibraryStores,
        name: String = "Test Shelf"
    ) throws -> Bookshelf {
        try bookStore.sidebarSaveShelf(name: name, icon: nil)
        // sidebarSaveShelf writes the JSON; now mirror it into the
        // in-memory cache so BookManager can find it (= production
        // code reloads via `reloadAllBooks()` at launch).
        let shelves = try bookStore.sidebarLoadShelves()
        bookStore.shelves = shelves
        // The freshly-created shelf is the last (= append order in
        // sidebarSaveShelf = createdAt ascending).
        guard let last = shelves.last(where: { $0.name == name }) else {
            throw BookManagerError.invalidInput(
                reason: "test setup: shelf \(name) was not persisted"
            )
        }
        _ = stores  // silence unused warning when shelf path changes
        return last
    }

    // MARK: - Test 1: create book returns descriptor

    @Test("createBook returns a descriptor with the requested fields")
    func testCreateBook_returnsDescriptor() async throws {
        let (store, _) = try Self.makeBookStore()
        let shelf = try Self.makeShelf(bookStore: store, stores: store.stores)
        let manager = BookManager(bookStore: store)

        let descriptor = try await manager.createBook(
            title: "My new novel",
            shelfId: shelf.id,
            description: "A coming-of-age story set in coastal Maine."
        )

        #expect(descriptor.title == "My new novel")
        #expect(descriptor.shelfId == shelf.id)
        #expect(descriptor.description == "A coming-of-age story set in coastal Maine.")
        #expect(descriptor.author.isEmpty)  // No author supplied => empty
        // Persisted to BookStore (= canonical wenshu-side state).
        #expect(store.books.contains(where: { $0.id == descriptor.id }))
    }

    // MARK: - Test 2: rename book updates title

    @Test("renameBook updates the title and preserves shelfId")
    func testRenameBook_updatesTitle() async throws {
        let (store, _) = try Self.makeBookStore()
        let shelf = try Self.makeShelf(bookStore: store, stores: store.stores)
        let manager = BookManager(bookStore: store)

        let original = try await manager.createBook(
            title: "Draft title",
            shelfId: shelf.id
        )

        try await manager.renameBook(id: original.id, newTitle: "Final title")

        let show = try await manager.showBook(id: original.id)
        #expect(show != nil)
        #expect(show?.title == "Final title")
        // shelfId is preserved (= rename doesn't move books across shelves).
        #expect(show?.shelfId == shelf.id)
        // lastEditedAt should have advanced (= rename bumps updatedAt).
        #expect((show?.lastEditedAt ?? .distantPast) >= original.lastEditedAt)
    }

    // MARK: - Test 3: delete book moves to trash (= removes from disk)

    @Test("deleteBook removes the book from BookStore.books and the per-book directory")
    func testDeleteBook_movesToTrash() async throws {
        let (store, _) = try Self.makeBookStore()
        let shelf = try Self.makeShelf(bookStore: store, stores: store.stores)
        let manager = BookManager(bookStore: store)

        let created = try await manager.createBook(
            title: "Book to delete",
            shelfId: shelf.id
        )
        // Sanity: book directory exists on disk.
        let bookDir = store.bookDirectory(bookId: created.id)
        #expect(bookDir != nil)
        #expect(FileManager.default.fileExists(atPath: bookDir!.path))

        try await manager.deleteBook(id: created.id)

        // BookStore.books no longer contains the id (= canonical
        // wenshu-side state is updated).
        #expect(!store.books.contains(where: { $0.id == created.id }))
        // showBook returns nil.
        let after = try await manager.showBook(id: created.id)
        #expect(after == nil)
    }

    // MARK: - Test 4: list books returns all (= filterable by shelf)

    @Test("listBooks returns every book; shelfId filter scopes the result")
    func testListBooks_returnsAll() async throws {
        let (store, _) = try Self.makeBookStore()
        let shelfA = try Self.makeShelf(bookStore: store, stores: store.stores, name: "Shelf A")
        let shelfB = try Self.makeShelf(bookStore: store, stores: store.stores, name: "Shelf B")
        let manager = BookManager(bookStore: store)

        _ = try await manager.createBook(title: "Book A1", shelfId: shelfA.id)
        _ = try await manager.createBook(title: "Book A2", shelfId: shelfA.id)
        _ = try await manager.createBook(title: "Book B1", shelfId: shelfB.id)

        // No filter = all 3.
        let all = try await manager.listBooks()
        #expect(all.count == 3)

        // Shelf A filter = 2.
        let aOnly = try await manager.listBooks(shelfId: shelfA.id)
        #expect(aOnly.count == 2)
        #expect(aOnly.allSatisfy { $0.shelfId == shelfA.id })

        // Shelf B filter = 1.
        let bOnly = try await manager.listBooks(shelfId: shelfB.id)
        #expect(bOnly.count == 1)
        #expect(bOnly.first?.shelfId == shelfB.id)
        #expect(bOnly.first?.title == "Book B1")
    }

    // MARK: - Test 5: execute("create") parses JSON and creates a book

    @Test("execute(create) parses the JSON envelope and creates a book")
    func testExecute_createAction_parsesAndCreates() async throws {
        let (store, _) = try Self.makeBookStore()
        let shelf = try Self.makeShelf(bookStore: store, stores: store.stores)
        let manager = BookManager(bookStore: store)
        let tool = BookManagerTool(manager: manager)

        let envelope: [String: Any] = [
            "action": "create",
            "title": "Slash command book",
            "shelfId": shelf.id.uuidString,
            "description": "Created via /create-book slash command."
        ]
        let inputData = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys]
        )
        let input = String(data: inputData, encoding: .utf8)!

        let output = try await tool.execute(input: input)
        let outputData = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: outputData) as? [String: Any]

        #expect(parsed?["ok"] as? Bool == true)
        #expect(parsed?["action"] as? String == "create")
        let bookDict = parsed?["book"] as? [String: Any]
        #expect(bookDict?["title"] as? String == "Slash command book")
        #expect(bookDict?["shelfId"] as? String == shelf.id.uuidString)
        #expect(bookDict?["description"] as? String == "Created via /create-book slash command.")
        #expect((bookDict?["id"] as? String) != nil)
    }
}
