// LibraryStoringContractTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. These tests describe the BEHAVIORAL CONTRACT that every
// LibraryStoring implementation must satisfy:
//   - FileSystemLibraryStore (v0.02.0)
//   - MetadataQueryLibraryStore (v0.03.0)
//   - CoreDataLibraryStore     (v0.04.0+, if needed)
//   - CloudKitDocumentsLibraryStore (v0.04.0+, if needed)
//
// The contract is parameterized over an `any LibraryStoring` factory so
// each impl runs through the same test suite (= Apple HIG Test Suite
// pattern). Adding a new impl = adding a new conformance factory; the
// test bodies don't change.

import Testing
import Foundation
@testable import WenshuApp

/// One conformance = one suite. To add FileSystem tests, create
/// `FileSystemLibraryStoreContractTests` that uses `LibraryStoringContractTests`
/// as a base (= struct inheritance is not in Swift; instead, the contract
/// body is exposed as static funcs called by each suite).
///
/// v0.02.0 only has FileSystemLibraryStore (lands in v39); once it's in
/// place, FileSystemLibraryStoreContractTests is added here.

@Suite("LibraryStoring contract")
struct LibraryStoringContractTests {

    // Use the FileSystem implementation under /tmp to verify the contract
    // end-to-end (= each test creates an isolated tmp root so tests don't
    // collide and don't touch real user data).

    private func makeStore() throws -> (any LibraryStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        return (FileSystemLibraryStore(rootURL: root), root)
    }

    @Test("empty store returns no shelves")
    func emptyStore() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelves = try store.loadShelves()
        #expect(shelves.isEmpty)
    }

    @Test("saveShelf + loadShelves round-trips a shelf")
    func roundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Bookshelf(id: UUID(), name: "长篇小说", createdAt: .now, updatedAt: .now)
        try store.saveShelf(original)
        let loaded = try store.loadShelves()
        #expect(loaded.count == 1)
        #expect(loaded.first == original)
    }

    @Test("saving twice with the same id throws .shelfAlreadyExists")
    func duplicateSave() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        try store.saveShelf(Bookshelf(id: id, name: "A", createdAt: .now, updatedAt: .now))
        #expect(throws: LibraryStoringError.self) {
            try store.saveShelf(Bookshelf(id: id, name: "B", createdAt: .now, updatedAt: .now))
        }
    }

    @Test("saveShelf + deleteShelf round-trips: re-load is empty")
    func deleteRoundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "Trash me", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        try store.deleteShelf(id: shelf.id)
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("deleteShelf on a missing id is a no-op (= idempotent)")
    func deleteMissingIsNoop() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.deleteShelf(id: UUID())  // nothing on disk yet
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("saveShelf creates a directory at <root>/<shelf-id>/")
    func directoryCreated() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "X", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let expectedDir = root.appendingPathComponent(shelf.directoryName)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expectedDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test("saveShelf writes shelf.json inside the shelf directory")
    func shelfJsonWritten() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "X", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let jsonURL = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("shelf.json")
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
        let data = try Data(contentsOf: jsonURL)
        let decoded = try JSONDecoder().decode(Bookshelf.self, from: data)
        #expect(decoded == shelf)
    }

    @Test("multiple shelves: saveShelf three, loadShelves returns three sorted by updatedAt desc")
    func multipleShelves() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date.now
        let a = Bookshelf(id: UUID(), name: "A", createdAt: now, updatedAt: now)
        let b = Bookshelf(id: UUID(), name: "B", createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(-100))
        let c = Bookshelf(id: UUID(), name: "C", createdAt: now.addingTimeInterval(-50), updatedAt: now.addingTimeInterval(-50))
        try store.saveShelf(a)
        try store.saveShelf(b)
        try store.saveShelf(c)
        let loaded = try store.loadShelves()
        #expect(loaded.map(\.id) == [a.id, c.id, b.id])
    }

    @Test("search returns [] in v0.02.0 (= stub; v0.03.0 implements)")
    func searchStubReturnsEmpty() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveShelf(Bookshelf(id: UUID(), name: "Anything", createdAt: .now, updatedAt: .now))
        #expect(try store.search(query: "Anything").isEmpty)
    }

    @Test("rootURL points at the configured directory (= so UI can show it)")
    func rootURLExposed() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(store.rootURL.standardizedFileURL == root.standardizedFileURL)
    }

    // MARK: - Book ops (v0.02.1)

    @Test("empty shelf returns no books")
    func emptyShelfHasNoBooks() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "Empty", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        #expect(try store.loadBooks(shelfId: shelf.id).isEmpty)
    }

    @Test("saveBook + loadBooks round-trips a book")
    func saveBookRoundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "X", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let loaded = try store.loadBooks(shelfId: shelf.id)
        #expect(loaded == [book])
    }

    @Test("saveBook requires the parent shelf to exist (= .parentShelfNotFound)")
    func saveBookWithoutParentThrows() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = Book(id: UUID(), title: "Orphan", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        #expect(throws: LibraryStoringError.self) {
            try store.saveBook(book)
        }
    }

    @Test("saving a book twice with the same id throws .bookAlreadyExists")
    func duplicateSaveBookThrows() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let id = UUID()
        try store.saveBook(Book(id: id, title: "A", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now))
        #expect(throws: LibraryStoringError.self) {
            try store.saveBook(Book(id: id, title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now))
        }
    }

    @Test("saveBook creates directory at <root>/<shelf-id>/books/<book-id>/")
    func bookDirectoryCreated() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "X", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let expectedDir = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("books")
            .appendingPathComponent(book.directoryName)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expectedDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test("saveBook writes book.json inside the book directory")
    func bookJsonWritten() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "X", author: "Author", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let jsonURL = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("books")
            .appendingPathComponent(book.directoryName)
            .appendingPathComponent("book.json")
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
        let decoded = try JSONDecoder().decode(Book.self, from: Data(contentsOf: jsonURL))
        #expect(decoded == book)
    }

    @Test("multiple books: saveBook three, loadBooks returns three sorted by updatedAt desc")
    func multipleBooks() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let now = Date.now
        let a = Book(id: UUID(), title: "A", author: "", shelfId: shelf.id, createdAt: now, updatedAt: now)
        let b = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(-100))
        let c = Book(id: UUID(), title: "C", author: "", shelfId: shelf.id, createdAt: now.addingTimeInterval(-50), updatedAt: now.addingTimeInterval(-50))
        try store.saveBook(a)
        try store.saveBook(b)
        try store.saveBook(c)
        let loaded = try store.loadBooks(shelfId: shelf.id)
        #expect(loaded.map(\.id) == [a.id, c.id, b.id])
    }

    @Test("loadBooks for a different shelf returns its own books (= no cross-leak)")
    func loadBooksIsolatedByShelf() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let s1 = Bookshelf(id: UUID(), name: "S1", createdAt: .now, updatedAt: .now)
        let s2 = Bookshelf(id: UUID(), name: "S2", createdAt: .now, updatedAt: .now)
        try store.saveShelf(s1)
        try store.saveShelf(s2)
        try store.saveBook(Book(id: UUID(), title: "OnlyInS1", author: "", shelfId: s1.id, createdAt: .now, updatedAt: .now))
        #expect(try store.loadBooks(shelfId: s1.id).map(\.title) == ["OnlyInS1"])
        #expect(try store.loadBooks(shelfId: s2.id).isEmpty)
    }

    @Test("saveBook + deleteBook round-trips: re-load is empty")
    func deleteBookRoundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "X", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        try store.deleteBook(id: book.id)
        #expect(try store.loadBooks(shelfId: shelf.id).isEmpty)
    }

    @Test("deleteBook on a missing id is a no-op (= idempotent)")
    func deleteMissingBookIsNoop() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.deleteBook(id: UUID())
    }

    @Test("deleting a shelf also removes its books from disk (= cascade)")
    func shelfDeleteCascadesToBooks() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        try store.saveBook(Book(id: UUID(), title: "X", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now))
        try store.deleteShelf(id: shelf.id)
        // After the shelf is gone, loading books for that shelf should
        // not crash and should return [] (the parent directory is gone).
        let loaded = try store.loadBooks(shelfId: shelf.id)
        #expect(loaded.isEmpty)
    }

    // MARK: - Document ops (v0.03.0, = document module end-to-end)
    //
    // v53 (= boss 8/15 17:48 '3 类, 卡片显示文档的中心思想'). The
    // library has grown document operations: loadDocuments /
    // loadDocumentContent / saveDocument / deleteDocument. These
    // match the new BookCategory + Document domain types added in
    // v53.1.

    @Test("loadDocuments on an empty category returns []")
    func loadDocumentsEmpty() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "X", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        // loadDocuments is called per category; for an empty category
        // (= no .md files on disk), the store returns []. Not an error.
        #expect(try store.loadDocuments(bookId: book.id, category: .chapter).isEmpty)
    }

    @Test("saveDocument + loadDocuments round-trip: a chapter .md with a '# Title' H1")
    func saveAndLoadDocumentWithH1() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let docId = UUID()
        let body = """
        # 第一章 雪山的狼

        一个孤独的旅人踏上北方的雪路...
        """
        try store.saveDocument(
            id: docId,
            bookId: book.id,
            category: .chapter,
            content: body
        )
        let loaded = try store.loadDocuments(bookId: book.id, category: .chapter)
        #expect(loaded.count == 1)
        let doc = loaded[0]
        #expect(doc.id == docId)
        #expect(doc.title == "第一章 雪山的狼")  // H1 extracted
        #expect(doc.summary.contains("孤独"))  // first ~100 chars
        #expect(doc.byteSize > 0)
    }

    @Test("saveDocument writes <docId>.md to <book-dir>/<category.dir>/")
    func saveDocumentFileLocation() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let docId = UUID()
        try store.saveDocument(id: docId, bookId: book.id, category: .setting, content: "# 角色表")
        let expected = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("books")
            .appendingPathComponent(book.directoryName)
            .appendingPathComponent("settings")
            .appendingPathComponent("\(docId.uuidString).md")
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test("loadDocumentContent round-trips the full MD body (= not just title/summary)")
    func loadDocumentContent() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let body = "# 标题\n\n这是第一章的完整内容..."
        try store.saveDocument(id: UUID(), bookId: book.id, category: .chapter, content: body)
        let docs = try store.loadDocuments(bookId: book.id, category: .chapter)
        #expect(docs.count == 1)
        let content = try store.loadDocumentContent(id: docs[0].id, bookId: book.id, category: .chapter)
        #expect(content == body)
    }

    @Test("saveDocument on existing id replaces (= first-save-wins... but content overwrite is the user's intent when they 'Save')")
    func saveDocumentOverwrite() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let id = UUID()
        try store.saveDocument(id: id, bookId: book.id, category: .chapter, content: "v1")
        try store.saveDocument(id: id, bookId: book.id, category: .chapter, content: "v2")
        let docs = try store.loadDocuments(bookId: book.id, category: .chapter)
        #expect(docs.count == 1)
        let content = try store.loadDocumentContent(id: id, bookId: book.id, category: .chapter)
        #expect(content == "v2")
    }

    @Test("loadDocuments is isolated by category (= chapters / settings / research are independent lists)")
    func loadDocumentsIsolatedByCategory() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        try store.saveDocument(id: UUID(), bookId: book.id, category: .chapter, content: "# ch")
        try store.saveDocument(id: UUID(), bookId: book.id, category: .setting, content: "# se")
        try store.saveDocument(id: UUID(), bookId: book.id, category: .research, content: "# re")
        #expect(try store.loadDocuments(bookId: book.id, category: .chapter).count == 1)
        #expect(try store.loadDocuments(bookId: book.id, category: .setting).count == 1)
        #expect(try store.loadDocuments(bookId: book.id, category: .research).count == 1)
    }

    @Test("deleteDocument is idempotent (= missing id is no-op)")
    func deleteDocumentIdempotent() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        // Deleting a non-existent document is a no-op (= Apple HIG
        // document-based apps: deleting a file that was already trashed
        // outside the app is a no-op, not an error).
        try store.deleteDocument(id: UUID(), bookId: book.id, category: .chapter)
    }

    @Test("summary: extract first ~100 chars from MD body, strip frontmatter, collapse newlines")
    func loadDocumentSummary() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        let body = """
        ---
        title: hidden frontmatter
        ---

        # Visible Title

        First paragraph of the body goes here, the storage layer should
        extract a summary from this.
        """
        let docId = UUID()
        try store.saveDocument(id: docId, bookId: book.id, category: .chapter, content: body)
        let docs = try store.loadDocuments(bookId: book.id, category: .chapter)
        let doc = docs.first(where: { $0.id == docId })!
        // Summary must NOT include the frontmatter (= 'hidden frontmatter' is stripped)
        #expect(!doc.summary.contains("hidden frontmatter"))
        // Summary must include the first body sentence (= 'First paragraph')
        #expect(doc.summary.contains("First paragraph"))
        // Summary must be a single line (= newlines collapsed)
        #expect(!doc.summary.contains("\n"))
    }

    @Test("title: extract first H1 from MD body, fallback to filename")
    func loadDocumentTitleFallback() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let book = Book(id: UUID(), title: "B", author: "", shelfId: shelf.id, createdAt: .now, updatedAt: .now)
        try store.saveBook(book)
        // MD without H1
        let docId1 = UUID()
        try store.saveDocument(id: docId1, bookId: book.id, category: .chapter, content: "No H1, just body.")
        // MD with H1
        let docId2 = UUID()
        try store.saveDocument(id: docId2, bookId: book.id, category: .chapter, content: "# Real Title\n\nBody.")
        let docs = try store.loadDocuments(bookId: book.id, category: .chapter)
        let d1 = docs.first(where: { $0.id == docId1 })!
        let d2 = docs.first(where: { $0.id == docId2 })!
        // No H1 → falls back to a default title
        #expect(!d1.title.isEmpty)
        // H1 → uses the H1
        #expect(d2.title == "Real Title")
    }
}