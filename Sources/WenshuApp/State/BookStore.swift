// BookStore.swift · Wenshu (文枢) · v0.26 (FCP library replica) + B-13 scope unification
//
// Single BookStore @Observable singleton (= boss 8/26 OOB "反面 apple 标
// 准实现是对的, 符合苹果的标准" + "用最少的代码, 符合苹果的标准, 实现
// 最好"). Holds the per-book in-memory state (= the 10 standard entries
// per book + per-book JSON data: kanban + todo + the 8 folder indexes).
//
// Switching books triggers BookStore.reload(bookId:) which reads the
// per-book JSON files into in-memory state; previous book's state is
// dropped (= Apple standard "data source switch" pattern).
//
// Single @Observable instance (= not per-book instances; Apple
// Observation framework pattern). Injected via @Environment in
// App.swift (= ticket 019 wiring; this file = the data model only).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 019.

import Foundation
import Observation

/// In-memory bundle of one book's data (= 10 standard entries: 8 folder
/// indexes + kanban + todo). Apple standard value type; reloaded by
/// BookStore.reload(bookId:).
struct BookBundle: Sendable {
    let bookId: UUID
    /// 8 folder indexes (= [WorldEntry], [Character], [Outline], etc.).
    /// Stored as a single struct = simpler than 8 separate @Observable
    /// fields (= atomic reload = one drop / one assignment).
    var worldEntries: [WorldEntry]
    var characterEntries: [Character]
    var outlineEntries: [Document]   // (= existing BookCategory.chapter / .setting / .research content)
    var chapterEntries: [Document]
    var draftEntries: [Document]
    var sessionEntries: [Document]
    var foreshadowingEntries: [Document]
    var placeholderEntries: [Document]
    /// 2 per-book JSON data files (= kanban + todo per spec v5).
    var kanbanData: Data
    var todoData: Data
}

/// Single @Observable BookStore (= Apple standard pattern: one
/// observation-tracked state holder; not per-book instances; per Apple
/// HIG + WWDC23 'Discover Observation in SwiftUI').
///
/// v0.27 ticket 019 wiring followup: BookStore now holds a
/// `LibraryStores` reference (= constructed by LibraryLifecycleHook)
/// + a `currentBookDirectory` optional. `reload(bookId:)` swaps the
/// directory; the WorldStoring / CharacterStoring callable members
/// lazily resolve the per-book store via `LibraryStores.makeBookStores`.
@Observable
final class BookStore: @unchecked Sendable {
    /// All shelves (= loaded once at app launch; edits in-memory;
    /// save on change).
    var shelves: [Bookshelf] = []

    /// Currently selected book id (= drives currentBook reload via
    /// SwiftUI .onChange observer in App.swift).
    var selectedBookId: UUID?

    /// Currently loaded per-book data (= nil when no book selected or
    /// reload in progress).
    var currentBook: BookBundle?

    /// Library-level store bundle (= constructed by LibraryLifecycleHook
    /// at app launch; held here for per-book resolution).
    let stores: LibraryStores

    /// Current book directory (= swapped by reload(bookId:)).
    var currentBookDirectory: URL?

    /// Reference library (= library-level, NOT per-book; loaded once
    /// at app launch).
    var referenceLibrary: ReferenceLibrary = ReferenceLibrary()

    /// Init (= v0.27 wiring): takes the LibraryStores bundle from the
    /// launch result. The v0.26 init signature was preserved for back-
    /// compat in commit 1de8e0e7f (= pre-v0.27 tests + callers), but
    /// git grep shows zero external callers; the init is removed in
    /// this commit to fix the S5 sentinel path bug (= reload(bookId:)
    /// would have written to `/books/<uuid>/` if any future caller used
    /// the back-compat init).
    init(stores: LibraryStores) {
        self.stores = stores
        self.worldStore = stores.makeBookStores(for: stores.shelvesRoot)
            .worldStore  // (= valid per-book store if shelvesRoot is a book dir; v0.27 upgrades to currentBookDirectory at reload)
        self.characterStore = stores.makeBookStores(for: stores.shelvesRoot)
            .characterStore
        self.referenceStore = stores.referenceStore
    }

    /// The 3 v0.26 entity stores (= kept as direct properties for the
    /// 6 CP3 views' functional-injection compatibility; v0.27 followups
    /// migrate views to @Environment(BookStore.self)).
    let worldStore: WorldStoring
    let characterStore: CharacterStoring
    let referenceStore: ReferenceStoring

    /// Reload the per-book data for the given book id. Drops the
    /// previous bundle and reads fresh from the storage layer. Apple
    /// standard "data source switch" pattern.
    ///
    /// v0.27 followup: the App.swift `.onChange` of selectedBookId
    /// observer calls this method (= wired by the App.swift wiring
    /// ticket). v0.27-01 lands the contract only.
    func reload(bookId: UUID) {
        selectedBookId = bookId
        let bookDir = stores.shelvesRoot
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        currentBookDirectory = bookDir
        currentBook = nil
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
    ///
    /// Path layout (= per FCP library replica spec v5):
    ///   <ws>/shelves/<shelf-id>/books/<book-id>/<folder-name>/*.md
    ///
    /// Scans all shelves for the book (= books can be in any shelf).
    /// Forgiving: missing folder / permission error = 0.
    func folderDocumentCount(bookId: UUID, folderDirectoryName: String) -> Int {
        let fm = FileManager.default
        let shelvesRoot = stores.shelvesRoot

        // Find which shelf contains the book
        guard let shelfDirs = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for shelfDir in shelfDirs {
            let folderURL = shelfDir
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookId.uuidString, isDirectory: true)
                .appendingPathComponent(folderDirectoryName, isDirectory: true)
            guard let contents = try? fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            let mdCount = contents.filter { url in
                url.pathExtension.lowercased() == "md"
            }.count
            if mdCount > 0 { return mdCount }
        }
        return 0
    }
}

/// Library-public reference library (= the library's default shelf per
/// boss 8/26 OOB; system-managed; user CANNOT delete or rename).
struct ReferenceLibrary: Sendable {
    var metadata: ReferenceLibraryMetadata = .empty
    var rawReferences: [Reference] = []
    var entityReferences: [Reference] = []
}

// MARK: - v0.32 sidebar inline-storage consolidation
//
// Moved from `NewLibraryOutlineView.swift` (= inline FileManager +
// JSONDecoder + JSONEncoder calls duplicated the storage adapter
// logic in two places). These methods are the canonical place to
// ask the sidebar / outline views for shelf / book CRUD. Views
// never touch FileManager directly.

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
    /// v0.30 boss 8/31 OOB: path = `<shelvesRoot>/<shelf-uuid>/books/<book-uuid>/`,
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
    func bookDirectory(bookId: UUID) -> URL? {
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
}

// MARK: - B-13 scope unification (= Kanban / Todo / reference-library data tree)
//
// Boss 2026-09-04 OOB:
//   - "这两个看板都有同一个问题, 只识别书的目录, 书的子目录, 按说也是书的
//     目录, 不支持" — the old `bookDirectory(bookId:)` only resolved the
//     book root. The 8 standard sub-folders (= `chapters/` etc.) and the
//     `reference-library/` root are now valid scope targets too.
//   - "资料库也不支持" — the reference library (= `reference-library/`
//     at the workspace root) is added as `TaskScope.referenceLibrary`
//     (= its own kanban / todo JSON files at the library root).
//
// Design (= per spec `.scratch/2026-09-04-b-13-scope-unification.md`):
//   - Scope is a VIEW FILTER, not a data-layer change. One kanban.json /
//     todo.json per (book, sub-folder) pair + a library-kanban.json /
//     library-todo.json at the library root.
//   - `TaskScope` enumerates the valid scope variants. The UI scope picker
//     in Kanban + Todo views uses `availableScopes(bookId:)` to enumerate
//     the user's choices for the active book.
//   - `scopeDirectory(bookId:scope:)` is the single helper views call to
//     resolve the URL that BookKanbanStore / BookTodoStore should write to.

/// One of the 8 standard sub-folders every book carries (= `chapters/`,
/// `world/`, `characters/`, etc., per LibraryBootstrapper). Each case is
/// also a valid `TaskScope` (= the picker lets the user target one).
public enum StandardBookFolder: String, CaseIterable, Sendable, Codable {
    case world
    case characters
    case outlines
    case chapters
    case drafts
    case sessions
    case foreshadowing
    case placeholders

    /// Filesystem directory name (= matches `LibraryBootstrapper`).
    public var folderName: String { rawValue }

    /// User-facing label (Chinese — matches the rest of the DynamicZone
    /// chrome per boss cadence).
    public var displayName: String {
        switch self {
        case .world: return "世界观"
        case .characters: return "角色"
        case .outlines: return "大纲"
        case .chapters: return "章节"
        case .drafts: return "草稿"
        case .sessions: return "会话"
        case .foreshadowing: return "伏笔"
        case .placeholders: return "占位"
        }
    }
}

/// A scope variant for Kanban / Todo data. Either the book root, one of
/// the 8 standard sub-folders inside the active book, or the reference
/// library (= library-public, cross-book). Scope is a view filter, not
/// a data-layer change: BookKanbanStore / BookTodoStore resolve to
/// different JSON filenames per scope (see `bookKanbanStoreURL` /
/// `bookTodoStoreURL` on the store types).
public enum TaskScope: Hashable, Identifiable, Sendable {
    case book
    case folder(StandardBookFolder)
    case referenceLibrary

    public var id: String {
        switch self {
        case .book: return "book"
        case .folder(let f): return "folder-\(f.folderName)"
        case .referenceLibrary: return "reference-library"
        }
    }

    public var displayName: String {
        switch self {
        case .book: return "(全书)"
        case .folder(let f): return f.displayName
        case .referenceLibrary: return "资料库"
        }
    }

    /// All 8 standard sub-folder scopes (= the entries the picker
    /// shows between "全书" and "资料库" when a book is active).
    public static func folderScopes() -> [TaskScope] {
        StandardBookFolder.allCases.map { .folder($0) }
    }
}

extension BookStore {
    /// Resolve the on-disk directory for a given `(bookId, scope)` pair.
    ///
    /// - `.book` (= book root): `bookDirectory(bookId:)` (= unchanged).
    /// - `.folder(f)`: `bookDirectory/<f.folderName>/` (= the standard
    ///   sub-folder inside the active book).
    /// - `.referenceLibrary`: `stores.referenceLibraryRoot` (= the
    ///   library-public archive; `bookId` is ignored).
    ///
    /// Returns nil if the book id is unknown AND the scope is per-book
    /// (= `.book` / `.folder`). The reference library always resolves if
    /// the workspace is bootstrapped.
    func scopeDirectory(bookId: UUID?, scope: TaskScope) -> URL? {
        switch scope {
        case .book:
            return bookId.flatMap { bookDirectory(bookId: $0) }
        case .folder(let folder):
            guard let bookDir = bookId.flatMap({ bookDirectory(bookId: $0) }) else {
                return nil
            }
            return bookDir.appendingPathComponent(folder.folderName, isDirectory: true)
        case .referenceLibrary:
            return stores.referenceLibraryRoot
        }
    }

    /// Enumerate the scope variants the UI picker should offer for the
    /// active book (= book root + 8 standard sub-folders + reference
    /// library). When no book is selected (= `bookId == nil`), the
    /// 8 sub-folder options are hidden (= they all live inside a book).
    func availableScopes(bookId: UUID?) -> [TaskScope] {
        var scopes: [TaskScope] = [.book]
        if bookId != nil {
            scopes.append(contentsOf: TaskScope.folderScopes())
        }
        scopes.append(.referenceLibrary)
        return scopes
    }
}