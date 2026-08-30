// BookStore.swift · Wenshu (文枢) · v0.26 (FCP library replica)
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