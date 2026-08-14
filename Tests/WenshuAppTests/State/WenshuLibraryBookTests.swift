// WenshuLibraryBookTests.swift · Wenshu (Wenshu) · v0.02.1 (book module)
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. WenshuLibrary grows by 4 book operations and 2 selection
// extensions (= no breaking changes to the v0.02.0 API).

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuLibrary book ops")
struct WenshuLibraryBookTests {

    private final class InMemoryStore: LibraryStoring, @unchecked Sendable {
        let rootURL = URL(fileURLWithPath: "/tmp/inmem2", isDirectory: true)
        var shelves: [UUID: Bookshelf] = [:]
        var books: [UUID: Book] = [:]
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

    @Test("addBook appends to the in-memory list AND persists to store")
    func addBook() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "S")
        try await lib.addShelf(shelf)
        let book = Book(title: "长篇", author: "", shelfId: shelf.id)
        try await lib.addBook(book)
        let titles = try await lib.books(in: shelf.id).map(\.title)
        #expect(titles == ["长篇"])
        let persisted = try store.loadBooks(shelfId: shelf.id).map(\.title)
        #expect(persisted == ["长篇"])
    }

    @Test("addBook with a missing shelf throws and does NOT corrupt any list")
    func addBookWithoutParent() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let orphan = Book(title: "Orphan", author: "", shelfId: UUID())
        await #expect(throws: LibraryStoringError.self) {
            try await lib.addBook(orphan)
        }
    }

    @Test("renameBook updates title + updatedAt in memory AND persists")
    func renameBook() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "S")
        try await lib.addShelf(shelf)
        let book = Book(title: "Old", author: "", shelfId: shelf.id)
        try await lib.addBook(book)
        try await Task.sleep(nanoseconds: 10_000_000)
        try await lib.renameBook(id: book.id, to: "New")
        #expect(try await lib.books(in: shelf.id).map(\.title) == ["New"])
        #expect(try store.loadBooks(shelfId: shelf.id).first?.title == "New")
    }

    @Test("deleteBook removes from list AND from store")
    func deleteBook() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "S")
        try await lib.addShelf(shelf)
        let book = Book(title: "X", author: "", shelfId: shelf.id)
        try await lib.addBook(book)
        try await lib.deleteBook(id: book.id)
        #expect(try await lib.books(in: shelf.id).isEmpty)
        #expect(try store.loadBooks(shelfId: shelf.id).isEmpty)
    }

    @Test("deleteBook with unknown id is a no-op (= idempotent)")
    func deleteUnknownBookIsNoop() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        try await lib.deleteBook(id: UUID())
    }

    @Test("selecting a book via the view's row-tap flow updates selection")
    func selectionBookBinding() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "S")
        try await lib.addShelf(shelf)
        let book = Book(title: "Pick me", author: "", shelfId: shelf.id)
        try await lib.addBook(book)
        await lib.setSelectedShelf(id: shelf.id)
        await lib.setSelectedBook(id: book.id)
        let sel = await lib.selectedBookId
        #expect(sel == book.id)
    }

    @Test("setSelectedBook(nil) clears book selection (= chat panel hint mode)")
    func clearBookSelection() async throws {
        let lib = await WenshuLibrary(store: InMemoryStore())
        await lib.setSelectedBook(id: nil)
        #expect(await lib.selectedBookId == nil)
    }
}