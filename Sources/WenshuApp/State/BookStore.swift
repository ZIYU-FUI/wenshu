// BookStore.swift · Wenshu () · v0.26 (FCP library replica) + B-13 scope unification
//
// Single BookStore @Observable singleton. Holds the per-book in-memory state (= the 10 standard entries per book + per-book JSON data: kanban + todo + the 8 folder indexes).
//
// Switching books triggers BookStore.reload(bookId:) which reads the
// per-book JSON files into in-memory state; previous book's state is
// dropped (= Apple standard "data source switch" pattern).
//
// Single @Observable instance (= not per-book instances; Apple
// Observation framework pattern). Injected via @Environment in
// App.swift wires this singleton at launch; this file = the data model only.

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
/// `LibraryStores` reference (= constructed by LibraryLifecycleHook)
/// + a `currentBookDirectory` optional. `reload(bookId:)` swaps the
/// directory; the WorldStoring / CharacterStoring callable members
/// lazily resolve the per-book store via `LibraryStores.makeBookStores`.
///
/// `@MainActor` (= matches `WenshuLibrary` + `AppState`; = every
/// SwiftUI View + agent tools that read these properties are
/// already on the MainActor at runtime). Agent-tool callers
/// (= `PlotThreadTracker`, `TagManager`, `BookManagerTool`, ...)
/// that read `bookStore.stores.shelvesRoot` from inside their
/// `actor` bodies route through `nonisolated let stores` and the
/// standalone `BookStorePathHelper` (= same shape as the
/// LiveChatRepository forwarder pattern); = no `await` ceremony
/// required for tools that only need URL paths.
@MainActor
@Observable
final class BookStore {
    /// All shelves (= loaded once at app launch; edits in-memory;
    /// save on change).
    var shelves: [Bookshelf] = []

    /// Reactive
    /// flat list of every book across every shelf (= mirrors the
    /// result of `sidebarLoadAllBooks()`). Views that need a
    /// live book count (= projectSidebar bottom status ": N")
    /// bind to `books.count` instead of running an inline
    /// `FileManager.contentsOfDirectory` scan at render time.
    /// Sorted by `createdAt` ascending (= matches the order the
    /// Sidebar uses this array to enumerate books).
    ///
    /// Initialized empty; the caller (= `LibraryRootView`'s
    /// layout shell) calls `reloadAllBooks()` once at launch.
    /// Mutations through `sidebarSaveBook(_:)` /
    /// `sidebarDeleteBook(id:)` keep the array in sync (= no
    /// stale counts).
    var books: [Book] = []

    /// Cached book-id → on-disk directory URL lookup map.
    /// Previously every `bookDirectory(bookId:)` call (= and
    /// `folderDocumentCount(bookId:folderDirectoryName:)` which calls it
    /// internally) re-scanned every shelf under `shelvesRoot`
    /// (= N shelf scans per call; = the sidebar render path invoked
    /// both methods per cell = `shelves × books × 8 folders × 2 scans`
    /// = ~5000 file stat() calls per render on a 50-book library).
    /// The cache is invalidated whenever `books` mutates (= save /
    /// delete / reload) so the cache stays coherent with on-disk
    /// truth (= save + delete both touch the same path; = rebuild
    /// from the freshest `books` array). `var` (= not `let`) because
    /// @Observable + SwiftUI requires mutation through `var` to
    /// trigger view diff.
    var bookDirectoryCache: [UUID: URL] = [:]

    /// Currently selected book id (= drives currentBook reload via
    /// SwiftUI .onChange observer in App.swift).
    var selectedBookId: UUID?

    /// Currently loaded per-book data (= nil when no book selected or
    /// reload in progress).
    var currentBook: BookBundle?

    /// Library-level store bundle (= constructed by LibraryLifecycleHook
    /// at app launch; held here for per-book resolution).
    ///
    /// `nonisolated let` (= `LibraryStores` is itself a `Sendable`
    /// struct holding Sendable `URL` + `ReferenceStoring` references).
    /// Agent tools (= actors that synchronously need `bookStore.stores.shelvesRoot`
    /// or `bookStore.stores.referenceLibraryRoot` to resolve per-book
    /// paths) read this from inside their `actor` bodies without
    /// `await` ceremony. Mutable state (= `shelves`, `books`,
    /// `currentBookId`) stays on the MainActor.
    nonisolated let stores: LibraryStores

    /// Current book directory (= swapped by reload(bookId:)).
    var currentBookDirectory: URL?

    /// Reference library (= library-level, NOT per-book; loaded once
    /// at app launch).
    var referenceLibrary: ReferenceLibrary = ReferenceLibrary()

    /// Init: takes the LibraryStores bundle from the launch result.
    init(stores: LibraryStores) {
        self.stores = stores
        self.entityStore = FileSystemEntityStore(bookDirectory: stores.shelvesRoot)
        self.referenceStore = stores.referenceStore
    }

    /// The 3 entity stores (= kept as direct properties for views'
    /// functional-injection compatibility; views migrate to
    /// @Environment(BookStore.self) over time). The 3 per-book
    /// stores are private (= views can't reach past the root).
    /// The previous `let worldStore` (= public-by-default for
    /// internal module) let 5 callers reach
    /// `bookStore.characterStore.loadCharacters()` etc. (= bypassing
    /// the aggregate root). Passthrough methods on `BookStore` are
    /// the canonical surface (= callers depend on the root, not
    /// the underlying stores).
    private let entityStore: FileSystemEntityStore
    private let referenceStore: ReferenceStoring

    // MARK: - Reach-through passthroughs

    /// Load all characters (= entities with kind = .person) for the
    /// active book. v2.3 facade: maps EntityDescriptor to the
    /// legacy `Character` shape so existing views continue to work
    /// during the migration window. Long-term T13 deletes this
    /// facade once views switch to EntityDescriptor.
    func loadCharacters() throws -> [Character] {
        let bookId = selectedBookId
            ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")
            ?? UUID()
        let entities = try entityStore.loadEntities().filter {
            $0.kind == .person
        }
        return entities.map { entity in
            Character(
                id: UUID(uuidString: entity.id.rawValue) ?? UUID(),
                bookId: UUID(uuidString: entity.bookIDRaw) ?? bookId,
                name: entity.name,
                age: entity.attributes["age"].flatMap { Int($0) },
                role: CharacterRole(rawValue: entity.tags.first ?? "other") ?? .other,
                arc: entity.attributes["arc"],
                summary: entity.description,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt
            )
        }
    }

    /// Load all reference items for the active book.
    func loadAllReferences() throws -> [Reference] {
        try referenceStore.loadAllReferences()
    }

    /// Load a single reference body by entity id.
    func loadReferenceBody(id: UUID) -> String? {
        referenceStore.loadReferenceBody(id: id)
    }

    /// `WikiLinkNavigation` / `WikiLinkResolver` tools receive
    /// `bookStore.referenceStore` (= a `ReferenceStoring` protocol
    /// reference) as a parameter. Exposed as a method (= same
    /// passthrough pattern as the other load methods above) so
    /// callers depend on `BookStore`, not on its private stores.
    func loadReferenceStore() -> ReferenceStoring {
        referenceStore
    }

    /// Reload the per-book data for the given book id. Drops the
    /// previous bundle and reads fresh from the storage layer. Apple
    /// standard "data source switch" pattern.
    ///
    /// App.swift `.onChange` of selectedBookId observer calls this
    /// method.
    func reload(bookId: UUID) {
        selectedBookId = bookId
        let bookDir = stores.shelvesRoot
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        currentBookDirectory = bookDir
        currentBook = nil
    }

    /// Count .md files directly by folder directory name. Doesn't
    /// require BookCategory (= which only has 3 cases = chapter/
    /// setting/research; the 5 user-facing folders use custom
    /// directory names like 'world' / 'characters' / 'outlines'
    /// that aren't in BookCategory). Returns 0 for missing folders
    /// (= forgiving convention).
    ///
    /// Future migration: replace by a proper BookCategory extension
    /// (= add `world` / `characters` cases) once the Document
    /// model supports all 5 folder types.
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

/// Library-public reference library (= the library's default shelf;
/// system-managed; user CANNOT delete or rename).
struct ReferenceLibrary: Sendable {
    var metadata: ReferenceLibraryMetadata = .empty
    var rawReferences: [Reference] = []
    var entityReferences: [Reference] = []
}


// MARK: - Extensions (= sidebar inline-storage + scope unification)
//
// Concerns are extracted from the monolithic class body into focused
// extension files:
//   - `BookStore+SidebarInline.swift` (= sidebar CRUD over the on-disk JSON)
//   - `BookStore+ScopeUnification.swift` (= book/folder/reference-library
//     scope directory resolution)
