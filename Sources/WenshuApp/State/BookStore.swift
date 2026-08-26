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

    /// Reference library (= library-level, NOT per-book; loaded once
    /// at app launch).
    var referenceLibrary: ReferenceLibrary = ReferenceLibrary()

    /// The 3 v0.26 entity stores (= functional injection source for
    /// the 6 new view files; loaded once; reused across books).
    let worldStore: WorldStoring
    let characterStore: CharacterStoring
    let referenceStore: ReferenceStoring

    /// Injected by App.swift at launch (= ticket 019). v0.26 uses
    /// constructor injection because SwiftUI @Environment cannot
    /// carry non-@Observable types at @Environment init time.
    init(
        worldStore: WorldStoring,
        characterStore: CharacterStoring,
        referenceStore: ReferenceStoring
    ) {
        self.worldStore = worldStore
        self.characterStore = characterStore
        self.referenceStore = referenceStore
    }

    /// Reload the per-book data for the given book id. Drops the
    /// previous bundle and reads fresh from the storage layer. Apple
    /// standard "data source switch" pattern (= per Apple Observation
    /// framework; no per-book store instances).
    func reload(bookId: UUID) {
        // v0.26: storage is parameterized by bookDirectory; the caller
        // (= App.swift .onChange observer) is responsible for
        // constructing the right store for the right book. This method
        // is a stub that captures the contract; the per-book directory
        // resolution is delegated to the caller (= ticket 019 App.swift
        // wiring reads Bookshelf -> books/ -> books/<book-id>/ and
        // constructs FileSystemWorldStore(books/<book-id>/) etc.).
        selectedBookId = bookId
        // Real implementation lands in ticket 019's App.swift wiring
        // (= constructs new per-book stores, calls loadWorld/loadCharacters,
        // populates BookBundle, assigns to currentBook).
        currentBook = nil
    }
}

/// Library-public reference library (= the library's default shelf per
/// boss 8/26 OOB; system-managed; user CANNOT delete or rename).
struct ReferenceLibrary: Sendable {
    var metadata: ReferenceLibraryMetadata = .empty
    var rawReferences: [Reference] = []
    var entityReferences: [Reference] = []
}