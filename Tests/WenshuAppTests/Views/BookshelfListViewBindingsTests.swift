// BookshelfListViewTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. These tests describe the view's public behavior using SwiftUI's
// ViewInspector-free approach (= exercise the model methods the view
// calls + assert on observable state changes). Full visual smoke
// testing lives behind the screenshot script (= pocock/
// screenshot-wenshu.sh), which catches layout / style regressions that
// these tests can't see.

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookshelfListView bindings")
struct BookshelfListViewBindingsTests {

    /// The view's binding surface (= what BookshelfListView exposes to
    /// its parent). Verifies the bindings the view reads / writes go
    /// through WenshuLibrary, not directly to the store.
    private final class InMemoryStore: LibraryStoring, @unchecked Sendable {
        let rootURL = URL(fileURLWithPath: "/tmp/inmem", isDirectory: true)
        var shelves: [UUID: Bookshelf] = [:]
        var books: [UUID: Book] = [:]  // v0.02.1
        func loadShelves() throws -> [Bookshelf] {
            Array(shelves.values).sorted { $0.updatedAt > $1.updatedAt }
        }
        func saveShelf(_ shelf: Bookshelf) throws {
            if shelves[shelf.id] != nil {
                throw LibraryStoringError(kind: .shelfAlreadyExists(shelf.id))
            }
            shelves[shelf.id] = shelf
        }
        func deleteShelf(id: UUID) throws { shelves.removeValue(forKey: id) }
        func search(query: String) throws -> [SearchHit] { [] }
        // v0.02.1 book ops
        func loadBooks(shelfId: UUID) throws -> [Book] {
            books.values.filter { $0.shelfId == shelfId }.sorted { $0.updatedAt > $1.updatedAt }
        }
        func saveBook(_ book: Book) throws {
            if !shelves.keys.contains(book.shelfId) {
                throw LibraryStoringError(kind: .parentShelfNotFound(book.shelfId))
            }
            if books[book.id] != nil {
                throw LibraryStoringError(kind: .bookAlreadyExists(book.id))
            }
            books[book.id] = book
        }
        func deleteBook(id: UUID) throws { books.removeValue(forKey: id) }
    }

    @Test("addShelf via the view's binding model is persisted")
    func addShelfBinding() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        // The view calls lib.addShelf() under a 'New Shelf' button.
        try await lib.addShelf(Bookshelf(name: "Sci-Fi"))
        #expect(try store.loadShelves().count == 1)
    }

    @Test("deleteShelf via the view's context-menu flow persists")
    func deleteShelfBinding() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "Throwaway")
        try await lib.addShelf(shelf)
        try await lib.deleteShelf(id: shelf.id)
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("renameShelf via the view's inline-edit flow persists")
    func renameShelfBinding() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "Old")
        try await lib.addShelf(shelf)
        try await lib.renameShelf(id: shelf.id, to: "New")
        let stored = try store.loadShelves().first
        #expect(stored?.name == "New")
    }

    @Test("selecting a shelf via the view's row-tap flow updates selection")
    func selectionBinding() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "Pick me")
        try await lib.addShelf(shelf)
        await lib.setSelectedShelf(id: shelf.id)
        let selected = await lib.selectedShelfId
        #expect(selected == shelf.id)
    }
}