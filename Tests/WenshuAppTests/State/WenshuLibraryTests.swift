// WenshuLibraryTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
// These tests lock WenshuLibrary's public behavior so the view layer
// (= v40 BookshelfListView) can rely on it without re-implementing logic.

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuLibrary")
struct WenshuLibraryTests {

    /// In-memory LibraryStoring impl for tests (= avoid touching real
    /// ~/Documents/wenshu/). Lives next to the test target because it's
    /// only for contract / library tests; production code uses
    /// FileSystemLibraryStore.
    private final class InMemoryStore: LibraryStoring, @unchecked Sendable {
        let rootURL: URL = URL(fileURLWithPath: "/tmp/inmemory", isDirectory: true)
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
        func deleteShelf(id: UUID) throws {
            shelves.removeValue(forKey: id)
        }
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
        func loadBook(id: UUID) throws -> Book? { books[id] }
        // v53: in-memory document store (= doesn't need MD parsing for tests;
        // the FileSystem tests exercise the parsing layer).
        private var documents: [String: String] = [:]  // key = "<docId>/<category>", value = body
        private func docKey(_ id: UUID, _ category: BookCategory) -> String { "\(id)/\(category.directoryName)" }
        func loadDocuments(bookId: UUID, category: BookCategory) throws -> [Document] {
            documents.values.contains { $0.isEmpty }  // satisfy the compiler
            return []
        }
        func loadDocumentContent(id: UUID, bookId: UUID, category: BookCategory) throws -> String {
            documents[docKey(id, category)] ?? ""
        }
        func saveDocument(id: UUID, bookId: UUID, category: BookCategory, content: String) throws {
            documents[docKey(id, category)] = content
        }
        func deleteDocument(id: UUID, bookId: UUID, category: BookCategory) throws {
            documents.removeValue(forKey: docKey(id, category))
        }
    }

    @Test("init loads existing shelves from store")
    func initLoadsShelves() async throws {
        let store = InMemoryStore()
        try store.saveShelf(Bookshelf(id: UUID(), name: "Existing", createdAt: .now, updatedAt: .now))
        let lib = await WenshuLibrary(store: store)
        let names = await lib.shelves.map(\.name)
        #expect(names == ["Existing"])
    }

    @Test("addShelf appends to the in-memory list AND persists to store")
    func addShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "长篇小说")
        try await lib.addShelf(shelf)
        let names = await lib.shelves.map(\.name)
        #expect(names == ["长篇小说"])
        let persisted = try store.loadShelves().map(\.name)
        #expect(persisted == ["长篇小说"])
    }

    @Test("addShelf with duplicate id throws and does NOT corrupt the list")
    func addShelfDuplicateThrows() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let id = UUID()
        try await lib.addShelf(Bookshelf(id: id, name: "A"))
        await #expect(throws: LibraryStoringError.self) {
            try await lib.addShelf(Bookshelf(id: id, name: "B"))
        }
        // Only the first shelf is in the list
        let count = await lib.shelves.count
        #expect(count == 1)
    }

    @Test("renameShelf updates name + updatedAt in memory AND persists")
    func renameShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let id = UUID()
        try await lib.addShelf(Bookshelf(id: id, name: "Old"))
        try await Task.sleep(nanoseconds: 10_000_000)  // ensure updatedAt differs
        try await lib.renameShelf(id: id, to: "New")
        let names = await lib.shelves.map(\.name)
        #expect(names == ["New"])
        let persisted = try store.loadShelves().first?.name
        #expect(persisted == "New")
    }

    @Test("deleteShelf removes from list AND from store")
    func deleteShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "Trash me")
        try await lib.addShelf(shelf)
        try await lib.deleteShelf(id: shelf.id)
        #expect(await lib.shelves.isEmpty)
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("deleteShelf with unknown id is a no-op (= idempotent)")
    func deleteUnknownIsNoop() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        try await lib.deleteShelf(id: UUID())
        #expect(await lib.shelves.isEmpty)
    }

    @Test("selectedShelfId is nil by default; setSelectedShelf / clear work")
    func selectedShelfId() async throws {
        let lib = await WenshuLibrary(store: InMemoryStore())
        #expect(await lib.selectedShelfId == nil)
        let id = UUID()
        await lib.setSelectedShelf(id: id)
        #expect(await lib.selectedShelfId == id)
        await lib.clearSelection()
        #expect(await lib.selectedShelfId == nil)
    }

    @Test("init auto-selects the first (= most-recently-edited) shelf when there's an existing library")
    func initAutoSelectsFirstShelf() async throws {
        let store = InMemoryStore()
        // Pre-populate with two shelves; the second-most-recent is added
        // first so the auto-select lands on the actual most-recent.
        try store.saveShelf(Bookshelf(id: UUID(), name: "Old", createdAt: Date(timeIntervalSince1970: 1000), updatedAt: Date(timeIntervalSince1970: 1000)))
        try store.saveShelf(Bookshelf(id: UUID(), name: "Recent", createdAt: Date(timeIntervalSince1970: 2000), updatedAt: Date(timeIntervalSince1970: 2000)))
        let lib = await WenshuLibrary(store: store)
        let selected = await lib.selectedShelfId
        let shelves = await lib.shelves
        #expect(selected == shelves.first?.id)
        #expect(selected != nil)
    }

    @Test("init leaves selection nil when the library is empty (= fresh install)")
    func initNoAutoSelectOnEmpty() async throws {
        let lib = await WenshuLibrary(store: InMemoryStore())
        #expect(await lib.selectedShelfId == nil)
    }
}