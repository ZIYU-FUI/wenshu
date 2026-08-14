// LibraryStoring.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
//
// This file is the architectural root of the wenshu library system.
// LibraryStoring defines the contract that all storage backends must
// satisfy. v0.02.0 ships one implementation (FileSystemLibraryStore);
// future versions can swap it for MetadataQuery / CoreData / CloudKit
// without touching the view layer (= the contract tests in
// Tests/WenshuAppTests/Storage/LibraryStoringContractTests.swift
// guarantee no conformance drift).
//
// Apple HIG document-based-app convention:
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json     ← encoded Bookshelf (the metadata)
//     books/         ← v0.02.1: book subdirs land here
//     chapters/      ← v0.02.1: chapter .md files land here
//
// Writes are atomic (= write-to-temp + rename) so a crash mid-write
// leaves the existing file intact. This matches the Apple HIG pattern
// used by NSDocument / FileWrapper.write(to:options:originalContents:).

import Foundation

// MARK: - Errors

struct LibraryStoringError: Error, Sendable {
    enum Kind: Sendable {
        case rootDirectoryUnavailable(URL)
        case shelfAlreadyExists(UUID)
        case shelfNotFound(UUID)
        case bookAlreadyExists(UUID)
        case bookNotFound(UUID)
        case parentShelfNotFound(UUID)
        case documentNotFound(UUID)
        case parentBookNotFound(UUID)
        case invalidShelfData(URL, underlying: String)
        case invalidBookData(URL, underlying: String)
        case ioFailed(URL, underlying: String)
    }
    let kind: Kind

    var localizedDescription: String {
        switch kind {
        case .rootDirectoryUnavailable(let url):
            return "wenshu library root directory unavailable at \(url.path)"
        case .shelfAlreadyExists(let id):
            return "a shelf with id \(id) already exists"
        case .shelfNotFound(let id):
            return "no shelf with id \(id)"
        case .bookAlreadyExists(let id):
            return "a book with id \(id) already exists"
        case .bookNotFound(let id):
            return "no book with id \(id)"
        case .parentShelfNotFound(let id):
            return "no parent shelf with id \(id) (= cannot save a book without its shelf)"
        case .documentNotFound(let id):
            return "no document with id \(id)"
        case .parentBookNotFound(let id):
            return "no parent book with id \(id) (= cannot save a document without its book)"
        case .invalidShelfData(let url, let err):
            return "shelf.json at \(url.path) is not valid: \(err)"
        case .invalidBookData(let url, let err):
            return "book.json at \(url.path) is not valid: \(err)"
        case .ioFailed(let url, let err):
            return "I/O failed at \(url.path): \(err)"
        }
    }
}

// MARK: - Search hit (v0.03.0 will populate; v0.02.0 stays empty)

struct SearchHit: Sendable, Hashable {
    /// The shelf that contains the hit. Even when search expands to books
    /// / chapters (= v0.02.1+), the shelf is always part of the result so
    /// the UI can route the user to the right container without an extra
    /// lookup.
    let shelfId: UUID
    let shelfName: String
    /// Free-form context for the hit. v0.02.0 is unused (= the protocol
    /// returns []); v0.02.1+ will populate this with a short snippet
    /// (= NSMetadataQuery result.snippet).
    let matchContext: String
}

// MARK: - Protocol

protocol LibraryStoring: Sendable {
    /// Where shelves are persisted on disk (= the ~/Documents/wenshu/ root
    /// for the FileSystem impl). Exposed so the UI can show 'Library at
    /// ~/Documents/wenshu' (= Apple HIG 'Show in Finder' affordance) and
    /// so tests can inject an isolated /tmp root.
    var rootURL: URL { get }

    /// Returns all shelves sorted by updatedAt descending (= most-recently
    /// edited first, Apple HIG Finder 'Recents' convention).
    func loadShelves() throws -> [Bookshelf]

    /// Persists the shelf (= creates the directory + writes shelf.json).
    /// Atomic write: writes to shelf.json.tmp, renames into place.
    /// Throws .shelfAlreadyExists if a shelf with the same id is already
    /// on disk (= the contract is "first save wins"; renaming is a
    /// separate operation that updates the existing shelf).
    func saveShelf(_ shelf: Bookshelf) throws

    /// Removes the shelf directory and its contents. Idempotent: if the
    /// shelf is already gone (= user deleted it via Finder), this is a
    /// no-op rather than an error. (= Apple HIG document-based apps treat
    /// delete as forgiving — Finder trashed the file from outside the
    /// app and the app should reconcile, not crash.)
    func deleteShelf(id: UUID) throws

    /// Search stub for v0.03.0 (= NSMetadataQuery on ~/Documents/wenshu).
    /// v0.02.0 always returns []. The signature is locked now so the UI
    /// can wire up its search bar without an API change later.
    /// Owner 8/15 15:55: lock the contract now, not when search ships.
    func search(query: String) throws -> [SearchHit]

    // MARK: - Book operations (v0.02.1, = book module end-to-end)
    //
    // Added in v0.02.1, after the shelf module shipped (v0.02.0). The
    // protocol extension is purely additive (= existing implementations
    // must satisfy these too; the contract test suite is extended
    // alongside).

    /// Returns the books in a given shelf, sorted by updatedAt desc
    /// (= same convention as loadShelves).
    func loadBooks(shelfId: UUID) throws -> [Book]

    /// Persists the book (= creates the book's directory under the
    /// parent's books/ subdir + writes book.json). Atomic write.
    /// Throws .bookAlreadyExists if a book with the same id is on disk.
    /// Throws .parentShelfNotFound if the parent shelf isn't on disk
    /// (= orphan-prevention: a book must have a parent shelf).
    func saveBook(_ book: Book) throws

    /// Removes a book's directory and contents. Idempotent (no-op
    /// if the book is already gone). Search index consistency: callers
    /// that wrap this with NSMetadataQuery (v0.03.0) get a removal
    /// notification automatically (= Spotlight tracks the directory).
    func deleteBook(id: UUID) throws

    /// v0.02.1 (book module): look up a single book by id across all
    /// shelves. The book id alone doesn't carry its shelfId, so the
    /// store must scan (= same forgiveness as loadBooks: missing
    /// shelves / corrupt book.json are skipped, returns nil if no
    /// match). Required by WenshuLibrary.renameBook.
    func loadBook(id: UUID) throws -> Book?

    // MARK: - Document operations (v0.03.0, = document module end-to-end)
    //
    // v53 (= boss 8/15 17:48 '3 类, 卡片显示文档的中心思想'). The library
    // grew document operations: each book has three categories of MD
    // files (= chapters / settings / research). The storage layer reads
    // the .md bytes, extracts the title (= first H1, falling back to a
    // generic placeholder) and the summary (= first ~100 chars after
    // stripping frontmatter / collapsing newlines), and exposes a
    // Document metadata record for the view's card grid. The full body
    // is available via loadDocumentContent (the EDITOR reads this).
    //
    // The 4-method split mirrors the Book API: a list call, a single-
    // item load (= the content the EDITOR will edit), a save (= the
    // EDITOR's 'Save' action), and a delete (= the context menu).
    //
    // saveDocument on an existing id REPLACES the file (overwrite).
    // This is different from saveBook's first-save-wins policy: when
    // the user clicks 'Save' in the editor, they explicitly want
    // their in-memory edit to land on disk. The first-save-wins
    // contract for Book exists because books have a richer identity
    // (= shelfId, createdAt) that we want to preserve; documents
    // are pure content (= just bytes), so overwriting is the
    // expected behavior.

    /// List all documents in a given category for a book (= one
    /// category per call: chapters / settings / research). Empty
    /// (= no .md files on disk) returns []. The list is sorted by
    /// updatedAt descending (= most-recently-edited first; matches
    /// Finder 'Recents').
    func loadDocuments(bookId: UUID, category: BookCategory) throws -> [Document]

    /// Read the full body of a .md file. Returns the raw string
    /// (= what the EDITOR loads into its text view; also what
    /// loadDocuments's auto-summary was extracted from).
    /// Throws .documentNotFound if no .md exists at the expected path.
    func loadDocumentContent(id: UUID, bookId: UUID, category: BookCategory) throws -> String

    /// Persist a .md to disk (= atomic write: tmp + replaceItemAt).
    /// Overwrites if a .md with the same id already exists.
    /// Throws .parentBookNotFound if the parent book isn't on disk
    /// (= orphan-prevention: a document must have a parent book).
    func saveDocument(id: UUID, bookId: UUID, category: BookCategory, content: String) throws

    /// Remove a .md from disk. Idempotent (= no-op if missing). The
    /// Document metadata is not separately stored (= the .md IS the
    /// source of truth; removing the file removes the document).
    func deleteDocument(id: UUID, bookId: UUID, category: BookCategory) throws
}