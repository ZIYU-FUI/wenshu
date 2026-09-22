// SidebarService.swift · Wenshu · v1.68b
//
// Loads the wenshu sidebar tree from the existing data layer (= flat
// Bookshelf / Book / Reference) and projects it into the SidebarNode
// tree that the macOS 27 Apple HIG `List(_, children:)` initializer
// needs.
//
// Boss 2026-09-22 OOB '数据结构不要有变化' (= don't mutate the
// existing Bookshelf / Book / Reference / Document domain models):
// the projection lives at view-layer (= inside the sidebar's own
// state object) — = the domain models stay flat (= the rest of
// wenshu continues to use them as before).
//
// The service takes pure closures (= loadShelves, loadBooks,
// loadReferences) instead of a LibraryStoring reference — = no change
// to LibraryStores / BookStore.init / 12 test fixtures (= the
// v1.68a leak that the boss rejected).
//
// v1.68b differs from the reverted v1.68a (= same idea, =
// the boss accepted the architecture but rejected the rest of the
// v1.68a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import Foundation

/// Loads and projects the sidebar tree (= flat row + cell library
/// + reference) into a SidebarNode tree for the Apple HIG
/// `List(_, children:)` initializer.
@MainActor
@Observable
final class SidebarService {

    /// The current sidebar tree (= shelf roots + a synthetic
    /// Reference Library root). Apple HIG syncs this state into the
    /// List's row content closure (= one node per row).
    private(set) var nodes: [SidebarNode] = []

    /// Last reload error (= surfaced in the sidebar's error footer
    /// = the previous v1.67 LazySidebarView's `loadError` semantics).
    private(set) var loadError: String?

    /// Closure that returns all shelves from the data layer.
    /// (= `bookStore.sidebarLoadShelves()` in production.)
    private let loadShelves: @MainActor () throws -> [Bookshelf]

    /// Closure that returns all books in the library.
    /// (= `bookStore.sidebarLoadAllBooks()` in production.) The
    /// sidebar (not the data layer) groups them by shelf via
    /// `Book.shelfId` (= the v1.67 LazySidebarView pattern).
    /// v1.68b boss 2026-09-22 '数据结构不要有变化' = no per-shelf
    /// loader (= the existing flat BookStore API stays).
    private let loadAllBooks: @MainActor () throws -> [Book]

    /// Closure that returns all references from the library.
    /// (= `bookStore.referenceStore.loadAllReferences()` in production.)
    private let loadReferences: @MainActor () throws -> [Reference]

    /// Closure that returns the standard 5 sub-folders a book exposes
    /// in the sidebar (= world / characters / outlines / chapters /
    /// drafts). The v1.67 LazySidebarView hardcoded this as
    /// `LazySidebarStandardFolders.all` (= see
    /// LazySidebarFileOps.swift); we inject it here to avoid a
    /// dependency cycle (= SidebarService is the data layer for the
    /// sidebar view, but the standard folders list is owned by the
    /// business layer's file-ops).
    private let loadStandardFolders: @MainActor () -> [(name: String, displayName: String, icon: String)]

    init(
        loadShelves: @MainActor @escaping () throws -> [Bookshelf],
        loadAllBooks: @MainActor @escaping () throws -> [Book],
        loadReferences: @MainActor @escaping () throws -> [Reference],
        // v1.68e boss 2026-09-22 OOB '正常播种五文件夹' (= the 5
        // seeded standard folders under the default help-doc
        // book stay on disk; = LibraryMigrator 8/30 OOB seed is
        // unchanged). This injection point is no longer used by
        // reload (= the sidebar tree = shelf → book only) but is
        // retained for downstream callers that still need the
        // standard-folder list (= LazySidebarFileOps.pendingDeleteChildCount
        // uses it for cascade-delete counting).
        loadStandardFolders: @MainActor @escaping () -> [(name: String, displayName: String, icon: String)] = { LazySidebarStandardFolders.all.map { ($0.name, $0.displayName, $0.icon) } }
    ) {
        self.loadShelves = loadShelves
        self.loadAllBooks = loadAllBooks
        self.loadReferences = loadReferences
        self.loadStandardFolders = loadStandardFolders
    }

    /// Reload the sidebar tree from the data layer. Idempotent
    /// (= the previous tree is replaced wholesale; = no partial-
    /// state flicker).
    func reload() async {
        do {
            let shelves = try loadShelves()
            let allBooks = (try? loadAllBooks()) ?? []
            let references = (try? loadReferences()) ?? []

            var roots: [SidebarNode] = []

            // v1.68e boss 2026-09-22 OOB '正常播种五文件夹' (= the
            // 5 standard folders under each book stay on disk;
            // = LibraryMigrator seeds them; = they are not shown
            // in the sidebar by default). The sidebar tree below
            // is shelf → book only (= 1-level); = the 5 folders
            // are accessed via the editor's tab UI once a book
            // is opened (future ticket).
            for shelf in shelves {
                let books = allBooks.filter { $0.shelfId == shelf.id }
                let bookNodes = books
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .map { book -> SidebarNode in
                        return SidebarNode(
                            id: book.id,
                            kind: .book,
                            title: book.title,
                            subtitle: (book.author.isEmpty || book.author == "wenshu") ? nil : book.author,
                            systemImage: book.displayIcon,
                            children: nil
                        )
                    }
                roots.append(SidebarNode(
                    id: shelf.id,
                    kind: .shelf,
                    title: shelf.name,
                    subtitle: nil,
                    systemImage: shelf.displayIcon,
                    children: bookNodes.isEmpty ? nil : bookNodes
                ))
            }

            // Reference library = one root node (= matches the
            // previous v1.67 LazySidebarView's reference library
            // section; = expanded later when boss asks to).
            //
            // v1.68b boss 2026-09-22 '资料库先不动' (= reference
            // library expansion is out of scope for the v1.68 Apple
            // HIG sidebar rewrite — it has its own rewrite ticket).
            let referenceNodes = references
                .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
                .map { ref in
                    SidebarNode(
                        id: ref.id,
                        kind: .reference,
                        title: ref.title,
                        subtitle: ref.source,
                        systemImage: "book.closed",
                        children: nil
                    )
                }
            roots.append(SidebarNode(
                id: Self.referenceLibraryRootId,
                kind: .reference,
                title: WenshuI18n.t("sidebar.reference_library.title"),
                subtitle: nil,
                systemImage: "books.vertical",
                children: nil
            ))

            nodes = roots
            loadError = nil
        } catch {
            nodes = []
            loadError = "Failed to load sidebar: \(error.localizedDescription)"
        }
    }

    /// Stable sentinel id for the synthetic Reference-Library root
    /// node (= used by AppState.sidebarSelection's .referenceCategory
    /// discriminator).
    static let referenceLibraryRootId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}