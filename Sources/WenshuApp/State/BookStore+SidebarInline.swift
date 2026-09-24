//
//  BookStore+SidebarInline.swift · Wenshu
//
//  Extension on `BookStore` (= sidebar inline-storage methods:
//  shelf / book CRUD). Each MARK section in `BookStore.swift`
//  is a focused extension on its own concern.
//

import Foundation

// MARK: - Sidebar inline-storage consolidation
//
// Moved from the pre-v1.69e `NewLibraryOutlineView.swift`
// (= inline FileManager + JSONDecoder + JSONEncoder calls
// duplicated the storage adapter logic in two places). These
// methods are the canonical place to ask the sidebar / outline
// views for shelf / book CRUD. Views never touch FileManager
// directly.

extension BookStore {
    /// Read all shelves from the filesystem. Forgiving: missing root
    /// = empty list (= first-launch / empty library convention).
    /// Sort = createdAt ascending (= oldest first; matches
    /// NewLibraryOutlineView's sidebar tree order pre-fix).
    func sidebarLoadShelves() throws -> [Bookshelf] {
        let shelvesRoot = stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else { return [] }
        let entries = try FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var result: [Bookshelf] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let jsonURL = entry.appendingPathComponent("shelf.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let shelf = try? JSONDecoder().decode(Bookshelf.self, from: data) else { continue }
            result.append(shelf)
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    /// Read all books across all shelves. The sidebar shows books
    /// regardless of which shelf they belong to (= 2-level tree =
    /// shelf > books regardless of shelf membership).
    /// Sort = createdAt ascending (= oldest first).
    func sidebarLoadAllBooks() throws -> [Book] {
        let shelvesRoot = stores.shelvesRoot
        guard FileManager.default.fileExists(atPath: shelvesRoot.path) else { return [] }
        var result: [Book] = []
        let shelves = try FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for shelfDir in shelves {
            let isDir = (try? shelfDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let booksDir = shelfDir.appendingPathComponent("books", isDirectory: true)
            guard FileManager.default.fileExists(atPath: booksDir.path) else { continue }
            let bookEntries = try FileManager.default.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for bookDir in bookEntries {
                let isBookDir = (try? bookDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isBookDir else { continue }
                let jsonURL = bookDir.appendingPathComponent("book.json")
                guard let data = try? Data(contentsOf: jsonURL),
                      let book = try? JSONDecoder().decode(Book.self, from: data) else { continue }
                result.append(book)
            }
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    /// Create a new book on disk + run per-book bootstrap (= creates
    /// the 8 standard folders + 2 JSON data files).
    /// Path = `<shelvesRoot>/<shelf-uuid>/books/<book-uuid>/`,
    /// matching the v5 spec layout (= the previous path duplicated
    /// the 'books' segment).
    func sidebarSaveBook(_ book: Book) throws {
        let bookDir = stores.shelvesRoot
            .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        let bootstrapper = LibraryBootstrapper(wsRoot: stores.referenceLibraryRoot.deletingLastPathComponent())
        try bootstrapper.ensureValidStructure()
        // 015.019: keep `books` in sync. Insert in
        // `createdAt`-ascending order (= matches
        // `sidebarLoadAllBooks()` sort). If a duplicate id already
        // exists, replace it (= idempotent re-save guard).
        if let existingIndex = books.firstIndex(where: { $0.id == book.id }) {
            books[existingIndex] = book
        } else {
            books.append(book)
            books.sort { $0.createdAt < $1.createdAt }
        }
    }

    /// B-07 015.019: delete a book by id. Mirrors
    /// `sidebarSaveBook(_:)` for removals (= keeps the reactive
    /// `books` array in sync so `bookStore.books.count` stays
    /// accurate after a remove). Idempotent: deleting an unknown
    /// id is a no-op for both the disk and the in-memory mirror.
    func sidebarDeleteBook(id: UUID) throws {
        // Resolve the on-disk directory (= walk shelves). If not
        // found, treat as no-op (= mirror stays empty for that id).
        if let bookDir = bookDirectory(bookId: id) {
            try FileManager.default.removeItem(at: bookDir)
        }
        books.removeAll { $0.id == id }
    }

    /// B-07 015.019: refresh the reactive `books` array from
    /// disk (= reads every `<shelvesRoot>/<shelf>/books/<id>/book.json`).
    /// Called once at launch (= by `LibraryRootView`'s layout
    /// shell) and from any view that has just performed a bulk
    /// mutation outside of `sidebarSaveBook` /
    /// `sidebarDeleteBook`.
    func reloadAllBooks() {
        books = (try? sidebarLoadAllBooks()) ?? []
        // Invalidate cache (= fresh books = potentially
        // different on-disk paths).
        bookDirectoryCache.removeAll(keepingCapacity: true)
    }

    /// Create a new shelf on disk with reserved-name + duplicate-name
    /// guards (= Apple HIG document-based app: shelf.id is the
    /// filesystem identity; shelf.name is the user-visible label, so
    /// duplicate user labels would confuse the reader).
    func sidebarSaveShelf(name: String, icon: String?) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reserved names (= cannot be used for a user shelf).
        let reservedNames: Set<String> = ["资料库", "参考库", "reference library"]
        if reservedNames.contains(where: { trimmedName.caseInsensitiveCompare($0) == .orderedSame }) {
            throw NSError(
                domain: "Wenshu.BookStore.sidebarSaveShelf",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Reserved shelf name: \(trimmedName)"]
            )
        }
        // Duplicate check (= case-insensitive, trim-insensitive).
        let existingNames = shelves.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            throw NSError(
                domain: "Wenshu.BookStore.sidebarSaveShelf",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Duplicate shelf name: \(trimmedName)"]
            )
        }
        let shelf = Bookshelf(name: trimmedName, icon: icon)
        let shelfDir = stores.shelvesRoot
            .appendingPathComponent(shelf.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shelfDir.appendingPathComponent("books"), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(shelf)
        try data.write(to: shelfDir.appendingPathComponent("shelf.json"))
    }

    /// Resolve the on-disk directory for a given book id by scanning
    /// every shelf (= a book id is unique across the library; it lives
    /// in exactly one shelf, so we walk shelves/<shelf>/books/<id>).
    ///
    /// B-09 (= kanban + todo UI functional linkage): the Kanban + Todo
    /// views use this to construct per-book ``BookKanbanStore`` /
    /// ``BookTodoStore`` instances (= read/write kanban.json + todo.json
    /// inside the active book directory). Returns nil if the book id
    /// is not on disk (= caller decides how to render the empty state).
    ///
    /// Apple HIG: pure helper on the data store (= no SwiftUI
    /// dependency; trivially testable; matches `folderDocumentCount`
    /// scan pattern above).
    ///
    /// Read-through cache (= O(1) hit on warm cache;
    /// = the original N-shelf scan only runs on cache miss; =
    /// rebuild on miss rebuilds from the freshest `books` array in
    /// one pass; = subsequent calls hit cache until the next books
    /// mutation invalidates it).
    /// Nonisolated counterpart for the agent-tool
    /// actors that previously called `bookDirectory(bookId:)`
    /// synchronously from inside their `actor` body (= Swift 6 strict
    /// concurrency can't let a non-MainActor caller access the
    /// @MainActor `bookDirectoryCache` mutable dict). Re-runs the same
    /// shelves scan via `stores.shelvesRoot` (= which IS nonisolated;
    /// see the `nonisolated let stores` annotation above). The cache
    /// hit path is bypassed (= agent tools hit a cold cache every call;
    /// acceptable because the scan is N-shelf and bounded by the
    /// user's library size).
    nonisolated func bookDirectory(bookId: UUID) -> URL? {
        let fm = FileManager.default
        let shelvesRoot = stores.shelvesRoot
        guard let shelfEntries = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for shelfEntry in shelfEntries {
            let candidate = shelfEntry
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookId.uuidString, isDirectory: true)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// MainActor-isolated original (= retains the cache for the
    /// SwiftUI view path that calls this on every render).
    func bookDirectoryCached(bookId: UUID) -> URL? {
        if let cached = bookDirectoryCache[bookId] {
            return cached
        }
        if let resolved = bookDirectory(bookId: bookId) {
            bookDirectoryCache[bookId] = resolved
            return resolved
        }
        return nil
    }
}
