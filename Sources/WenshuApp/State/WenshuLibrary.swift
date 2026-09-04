// WenshuLibrary.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// @Observable state layer between the view (= SwiftUI BookshelfListView,
// v40+) and the storage backend (= LibraryStoring). Owns:
//
//   - the in-memory list of Bookshelf (= sorted by updatedAt desc on load)
//   - the user's current selection (= selectedShelfId; nil = no selection)
//   - the operations the view calls: add, rename, delete
//
// Architectural rules (= Owner 8/15 15:55, "lock the architecture first"):
//   - WenshuLibrary depends ONLY on the LibraryStoring protocol, never on
//     a concrete impl (= FileSystem / MetadataQuery / CoreData can all be
//     injected).
//   - All mutations go through the protocol (= no direct FileManager calls
//     in the state layer). If the UI needs new operations, they extend
//     LibraryStoring first, not WenshuLibrary.
//   - The state layer is the single source of truth for the view; the
//     view never reads the store directly.
//
// Concurrency: marked `@MainActor` so SwiftUI can read every property
// without `await`. The store calls (= async on FileManager etc.) are
// dispatched off-main by the store itself (= Future impl wraps each call
// in a Task). v0.02.0 keeps it MainActor-isolated for simplicity; the
// protocol can grow an async overload later if a remote store needs it.

import SwiftUI

@MainActor
@Observable
final class WenshuLibrary {
    /// All bookshelves, sorted by updatedAt descending (= Apple HIG Finder
    /// 'Recents' convention).
    private(set) var shelves: [Bookshelf] = []
    /// v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019): total book
    /// count across all shelves (= used by projectSidebar bottom toolbar
    /// right-side status "书: N"). Computed by iterating store.loadBooks
    /// for each shelf; cached in @Observable mirror so UI updates
    /// reactively when shelves/books change.
    private(set) var bookCount: Int = 0

    /// The user's current selection (= Apple HIG document-based apps
    /// default to a single selection; v0.02.0 is single-selection only).
    /// Nil means "no selection" (= fresh install, or user cleared).
    private(set) var selectedShelfId: UUID?

    /// Storage backend. Protocol-typed so a future swap to MetadataQuery /
    /// CoreData / CloudKit requires no UI changes. The store is held as a
    /// let (= not @Observable) because its state lives on disk; only the
    /// view-facing mirror (= shelves) is observable.
    private let store: any LibraryStoring

    init(store: any LibraryStoring) {
        self.store = store
        // Load on init so the view sees the existing library the moment
        // it renders. Failures (= missing root on a fresh install) are
        // handled by the loadShelves impl (= empty list, not a thrown
        // error).
        do {
            self.shelves = try store.loadShelves()
        } catch {
            self.shelves = []
        }
        // Apple HIG document-based app: on launch, if there's a
        // library, auto-select the most-recently-edited shelf (= the
        // same sort order the list shows). Avoids the empty-state in
        // the right pane for the typical 'I have existing books I want
        // to work on' launch.
        if let first = shelves.first, selectedShelfId == nil {
            selectedShelfId = first.id
        }
        // v53: also auto-select the first book in that shelf (= makes
        // the cards grid visible on first launch with existing data,
        // instead of the '先在左边选一本书' empty state).
        if selectedBookId == nil, let shelfId = selectedShelfId {
            do {
                let books = try store.loadBooks(shelfId: shelfId)
                if let firstBook = books.first {
                    selectedBookId = firstBook.id
                }
            } catch {
                // Books fail to load → leave selectedBookId nil; the
                // empty state will render and the user can pick one.
            }
        }
        // v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019): compute
        // total book count across all shelves (= used by projectSidebar
        // bottom toolbar right-side status '书: N').
        recomputeBookCount()
    }

    /// v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019): recompute
    /// bookCount by summing books across all shelves. Public so views can
    /// trigger recomputation after shelf/book add/remove mutations.
    public func recomputeBookCount() {
        var total = 0
        for shelf in shelves {
            if let books = try? store.loadBooks(shelfId: shelf.id) {
                total += books.count
            }
        }
        bookCount = total
        NSLog("[wenshu.library] recomputeBookCount: %d (shelf count=%d)", total, shelves.count)
    }

    /// URL to display in the UI (= 'Library at <rootURL>'). The view
    /// uses this for the Apple HIG 'Show in Finder' affordance.
    var libraryRootURL: URL { store.rootURL }

    // MARK: - Mutations (= all delegate to the storage layer; mirror the
    // result back into `shelves` so the view sees the change.)

    /// Creates a new shelf. The shelf must have a unique id (one will be
    /// assigned by Bookshelf's default init if you don't pass one). The
    /// view is responsible for prompting the user for a name; this method
    /// just persists.
    func addShelf(_ shelf: Bookshelf) throws {
        try store.saveShelf(shelf)
        // Insert in sorted position. LibraryStoring guarantees the new
        // shelf has the latest updatedAt (= .now from the init), so it
        // goes to the front.
        shelves.insert(shelf, at: 0)
        // Auto-select the newly added shelf (= Apple HIG Finder behavior:
        // creating a folder also selects it).
        selectedShelfId = shelf.id
    }

    /// Renames an existing shelf. id stays the same (= Apple HIG
    /// document-based: URL = identity, name = display label only).
    /// Throws .shelfNotFound if no shelf with that id exists.
    func renameShelf(id: UUID, to newName: String) throws {
        guard let index = shelves.firstIndex(where: { $0.id == id }) else {
            throw LibraryStoringError(kind: .shelfNotFound(id))
        }
        var updated = shelves[index]
        updated.name = newName
        updated.updatedAt = .now
        // The contract is "first save wins on id", so a rename goes
        // through delete + save (= the directory already exists at the
        // id, and FileSystemLibraryStore refuses to re-save the same id).
        try store.deleteShelf(id: id)
        try store.saveShelf(updated)
        shelves[index] = updated
        // Re-sort to keep updatedAt-descending invariant.
        shelves.sort { $0.updatedAt > $1.updatedAt }
    }

    /// Removes a shelf. Idempotent: deleting an unknown id is a no-op.
    func deleteShelf(id: UUID) throws {
        try store.deleteShelf(id: id)
        shelves.removeAll { $0.id == id }
        if selectedShelfId == id {
            selectedShelfId = nil
        }
    }

    // MARK: - Selection (= driven by the view; not stored on disk)

    func setSelectedShelf(id: UUID) {
        selectedShelfId = id
    }

    func clearSelection() {
        selectedShelfId = nil
    }

    /// Returns the currently-selected Bookshelf, if any. Convenience for
    /// views that bind selection to content (= v0.02.0 only shows the
    /// name; v0.02.1+ shows the books inside).
    var selectedShelf: Bookshelf? {
        guard let id = selectedShelfId else { return nil }
        return shelves.first(where: { $0.id == id })
    }

    // MARK: - Book state (v0.02.1, = book module end-to-end)
    //
    // Additive only (= v0.02.0 callers and contracts untouched). The
    // books for each shelf are lazily fetched from the store (= we don't
    // hold a per-shelf dictionary in memory; loadBooks is the source of
    // truth). Selected book id survives a shelf switch (= the user can
    // switch shelves and come back; their selected book is still selected).

    /// The user's currently-selected book (= single-select for v0.02.1).
    private(set) var selectedBookId: UUID?

    /// Returns the books in a given shelf, sorted by updatedAt desc
    /// (= mirrors the storage layer's sort order). Lazy: every call hits
    /// the store (= FileSystem / MetadataQuery / CoreData backend can
    /// optimize however it wants; the view sees a stable list).
    func books(in shelfId: UUID) throws -> [Book] {
        try store.loadBooks(shelfId: shelfId)
    }

    /// Creates a new book under a shelf. Auto-selects it (= Apple HIG
    /// Finder: creating a file also selects it).
    func addBook(_ book: Book) throws {
        try store.saveBook(book)
        if selectedShelfId == book.shelfId {
            selectedBookId = book.id
        }
    }

    /// Renames a book. id stays the same (= Apple HIG document-based:
    /// URL = identity, title = display label only).
    func renameBook(id: UUID, to newTitle: String) throws {
        guard let book = try store.loadBook(id: id) else {
            throw LibraryStoringError(kind: .bookNotFound(id))
        }
        var updated = book
        updated.title = newTitle
        updated.updatedAt = .now
        try store.deleteBook(id: id)
        try store.saveBook(updated)
    }

    /// Removes a book. Idempotent (= deleting an unknown id is a no-op).
    func deleteBook(id: UUID) throws {
        try store.deleteBook(id: id)
        if selectedBookId == id {
            selectedBookId = nil
        }
    }

    func setSelectedBook(id: UUID?) {
        selectedBookId = id
    }

    // MARK: - Document state (v0.03.0, = document module end-to-end)
    //
    // Lazy reads (= the storage layer decides how to optimize; current
    // FileSystemLibraryStore re-reads the .md each call). The view layer
    // (v53.3 BookOutlineView) calls these on each render — for v0.03.0
    // the per-card read is fine; v0.04+ can add an in-memory cache.

    /// Lists the documents in a given category for the currently-
    /// selected book. Empty (= no book selected, or the book has no
    /// documents in this category yet).
    func documents(in bookId: UUID, category: BookCategory) throws -> [Document] {
        try store.loadDocuments(bookId: bookId, category: category)
    }

    /// v0.30 boss OOB '为什么角色, 世界观, 后面没有显示数字': count .md
    /// files directly by folder directory name. Doesn't require
    /// BookCategory (= which only has 3 cases = chapter/setting/research;
    /// the 5 user-facing folders use custom directory names like
    /// 'world' / 'characters' / 'outlines' that aren't in BookCategory).
    /// Returns 0 for missing folders (= forgiving convention).
    ///
    /// v0.30 followup: this can be replaced by a proper BookCategory
    /// extension (= add `world` / `characters` cases) once the
    /// Document model migrates to support all 5 folder types.
    /// Note: delegate to BookStore (= same impl, available there too).
    func folderDocumentCount(bookId: UUID, folderDirectoryName: String) -> Int {
        guard let bookStore = store as? BookStore else { return 0 }
        return bookStore.folderDocumentCount(bookId: bookId, folderDirectoryName: folderDirectoryName)
    }

    /// Reads the full MD body of a document (= what the EDITOR will
    /// load into its text view). Throws .documentNotFound if the .md
    /// isn't on disk.
    func documentContent(id: UUID, bookId: UUID, category: BookCategory) throws -> String {
        try store.loadDocumentContent(id: id, bookId: bookId, category: category)
    }

    /// Creates a new document. The document id is generated here
    /// (= callers don't pass an id; the Library owns the id space).
    /// The category directory is created on demand by the storage
    /// layer. Auto-selects the new document.
    @discardableResult
    func addDocument(in bookId: UUID, category: BookCategory, title: String, content: String) throws -> Document {
        let id = UUID()
        try store.saveDocument(
            id: id,
            bookId: bookId,
            category: category,
            content: content
        )
        // Compute the metadata in-memory (= the storage layer reads
        // it back from disk, but for immediate UI feedback after the
        // save we already know title + byteSize).
        let doc = Document(
            id: id,
            bookId: bookId,
            category: category,
            title: title,
            byteSize: content.utf8.count,
            summary: FileSystemLibraryStore.extractSummary(from: content),
            createdAt: .now,
            updatedAt: .now
        )
        selectedDocumentId = id
        return doc
    }

    /// Persists the body of a document. Overwrites (= the EDITOR's
    /// 'Save' action).
    func updateDocumentContent(id: UUID, bookId: UUID, category: BookCategory, content: String) throws {
        try store.saveDocument(
            id: id,
            bookId: bookId,
            category: category,
            content: content
        )
    }

    /// Removes a document. Idempotent.
    func deleteDocument(id: UUID, bookId: UUID, category: BookCategory) throws {
        try store.deleteDocument(id: id, bookId: bookId, category: category)
        if selectedDocumentId == id {
            selectedDocumentId = nil
        }
    }

    /// Currently-selected document (= the EDITOR binds to this when
    /// the user clicks a card). nil = no selection.
    private(set) var selectedDocumentId: UUID?

    func setSelectedDocument(id: UUID?) {
        selectedDocumentId = id
    }
}