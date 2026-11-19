// SidebarService.swift · Wenshu Loads the wenshu sidebar tree from the existing data
// layer (= flat Bookshelf / Book / Reference) and projects it into the SidebarNode
// tree that the macOS 27 Apple HIG `List(_, children:)` initializer needs. The
// projection lives at view-layer (= inside the sidebar's own state object) — = the
// domain models stay flat (= the rest of wenshu continues to use them as before). The
// service takes pure closures (= loadShelves, loadBooks, loadReferences) instead of a
// LibraryStoring reference — = no change to LibraryStores / BookStore.init / 12 test
// fixtures (= the a leak that the user rejected). b differs from the previous attempt
// (= same idea, = the user accepted the architecture but rejected the rest of the a
// patch because it leaked changes into LibraryStores / BookStore.init / 12 test
// fixtures — none of those are touched here).

import Foundation
import os

let sidebarLogger = Logger(subsystem: "com.wenshu", category: "sidebarservice")

/// Loads and projects the sidebar tree (= flat row + cell library
/// + reference) into a SidebarNode tree for the Apple HIG
/// `List(_, children:)` initializer.
@MainActor
@Observable
final class SidebarService {

    /// The current sidebar tree (= shelf roots + a synthetic
    /// Reference Library root). Apple HIG syncs this state into the
    /// List's row content closure (= one node per row).
    ///
    /// ⇒ ⇒ ⇒ THE TREE IS PUBLISHED WITH ITS SHAPE: = the rows are
    /// compared by their OWN data, = so a tree whose rows differ only
    /// BELOW the top compares EQUAL, = and the observation that carries
    /// the tree never fires (= the rows under the user keep the text
    /// they had). = ⇒ ⇒ ⇒ The shape is the digest of every row's
    /// subtree, = so a tree that changed IS a new tree (= the sidebar
    /// reads it again).
    private(set) var tree = SidebarTree(nodes: [])

    /// The shelf hierarchy (= the user's shelves and their books).
    ///
    /// The sidebar shows one hierarchy per part, so the shelf hierarchy
    /// and the reference library hierarchy live in separate collections
    /// instead of one joined list.
    ///
    /// ⇒ ⇒ ⇒ PUBLISHED WITH ITS SHAPE: = the rows compare by their own
    /// data, = so a shelf whose books changed compares EQUAL, = and the
    /// sidebar would never read the new rows.
    private(set) var shelfTree = SidebarTree(nodes: [])

    /// The reference library hierarchy (= the grouped tag surface).
    ///
    /// ⇒ ⇒ ⇒ PUBLISHED WITH ITS SHAPE: = the rows compare by their own
    /// data, = so a category whose tags changed compares EQUAL, = and
    /// the sidebar would never read the new rows.
    private(set) var libraryTree = SidebarTree(nodes: [])

    /// The current sidebar tree's rows (= the tree's rows).
    var nodes: [SidebarNode] {
        tree.nodes
    }

    /// The shelf hierarchy's rows (= the tree's rows).
    var shelfNodes: [SidebarNode] {
        shelfTree.nodes
    }

    /// The reference library hierarchy's rows (= the tree's rows).
    var libraryNodes: [SidebarNode] {
        libraryTree.nodes
    }

    /// Last reload error (= surfaced in the sidebar's error footer
    /// = the loadError semantics the legacy LazySidebarView
    /// preserved before the MVVM split).
    private(set) var loadError: String?

    /// Closure that returns all shelves from the data layer.
    /// (= `bookStore.sidebarLoadShelves()` in production.)
    let loadShelves: @MainActor () throws -> [Bookshelf]

    /// Closure that returns all books in the library.
    /// (= `bookStore.sidebarLoadAllBooks()` in production.) The
    /// sidebar (not the data layer) groups them by shelf via
    /// `Book.shelfId` (= the previous pattern preserved through
    /// the MVVM split).
    /// = no per-shelf
    /// loader (= the existing flat BookStore API stays).
    let loadAllBooks: @MainActor () throws -> [Book]

    /// Closure that returns all references from the library.
    /// (= `bookStore.referenceStore.loadAllReferences()` in production.)
    let loadReferences: @MainActor () throws -> [Reference]

    /// closure that returns the number
    /// of .md files in a given book + folder (= used to populate
    /// the "X " subtitle on each folder row in the sidebar).
    /// Defaults to `{ _, _ in 0 }` (= unit tests + legacy call
    /// sites that don't need folder counts; = the subtitle reads
    /// "0 " which is harmless).
    let loadFolderDocCount: @MainActor (UUID, String) -> Int

    init(
        loadShelves: @MainActor @escaping () throws -> [Bookshelf],
        loadAllBooks: @MainActor @escaping () throws -> [Book],
        loadReferences: @MainActor @escaping () throws -> [Reference],
        loadFolderDocCount: @MainActor @escaping (UUID, String) -> Int = { _, _ in 0 },
        bookStore: BookStore? = nil
    ) {
        self.loadShelves = loadShelves
        self.loadAllBooks = loadAllBooks
        self.loadReferences = loadReferences
        self.loadFolderDocCount = loadFolderDocCount
        // y: optional bookStore reference (= used by create/delete/rename on the
        // persistence layer; = shelvesRoot + per-shelf per-book paths live on
        // bookStore. = nil for unit-test SidebarService instances that only
        // exercise `nodes()` tree building).
        self.bookStore = bookStore
    }

    /// optional BookStore reference (= injected at
    /// AppleSidebarView's .task block; = nil for unit-test
    /// instances that only test the read-side tree building).
    let bookStore: BookStore?

    /// latest cached shelves (= populated by `reload()`
    /// from `loadShelves()`; = read by createShelf / renameShelf
    /// for name validation).
    private(set) var shelves: [Bookshelf] = []

    /// latest cached books (= populated by `reload()`
    /// from `loadAllBooks()`; = read by createBook / renameBook
    /// for title validation).
    private(set) var books: [Book] = []

    /// Reload the sidebar tree from the data layer. Idempotent
    /// (= the previous tree is replaced wholesale; = no partial-
    /// state flicker).
    func reload() async {
        do {
            let shelves = try loadShelves()
            let allBooks = (try? loadAllBooks()) ?? []
            // A failed load is an UNKNOWN set, not an empty one: the
            // cover reconciler must not treat a failed read as "no
            // references exist".
            let loadedReferences = try? loadReferences()
            let references = loadedReferences ?? []

            // A cover is a CHILD of its document: remove the covers
            // whose document is gone (= deleted in Finder, by a
            // script, by a git checkout). The reconciler is the
            // second line of defence, after the delete cascade.
            CoverReconciler.live().sweep(
                liveReferenceIds: loadedReferences?.map(\.id),
                shelvesRoot: bookStore?.stores.shelvesRoot
            )

            // y: cache the latest shelves + books (= the create / rename / delete
            // business methods read these for duplicate-name validation; =
            // avoids refetching on every UI event).
            self.shelves = shelves
            self.books = allBooks

            var roots: [SidebarNode] = []

            // e (see OOB.md #2026-09-22) OOB '' (= the standard folders under each book
            // stay on disk; = LibraryMigrator seeds them). f (see OOB.md
            // #2026-09-22) OOB ' ，' (= the default help-doc book + the
            // test novels seeded with ' ' folders on first launch should
            // show their folders in the sidebar so the user can
            // navigate to them). The fix re-adds the user-facing folders
            // (= world / characters / chapters / drafts / ideas) as
            // children of each book, but only for books that have those
            // folders on disk (= default-seeded books).
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
                            children: folderChildren(for: book)
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

            // Reference library = one root node whose children are the tag facet (=
            // the cross-cutting tag cloud: = one row per distinct tag, = the most
            // carried tag first).
            //
            // ⇒ ⇒ ⇒ The library's own categories (= the 22 CLC buckets) are NOT a
            // second level: = a category row was a grouping the tree rebuilt from
            // the classifier's answer on every reload (= so the rows moved when
            // the selection changed), = and the flat cloud is the surface the
            // user asked for.
            //
            // The tag rows carry the count of the documents that carry them (= the
            // entities layer only, = the layer the grid shows), = the tag glyph, =
            // and no children (= a leaf, = so a click scopes the grid to that
            // tag).
            let tagRows = Self.tagRows(for: references)
            // The reference library is its own hierarchy (= the sidebar
            // shows one hierarchy per part, so the two no longer share a
            // list and need no divider between them).
            let libraryRoot = SidebarNode(
                id: Self.referenceLibraryRootId,
                kind: .reference,
                title: String(localized: "sidebar.reference_library.title"),
                subtitle: nil,
                systemImage: "books.vertical",
                children: tagRows.isEmpty ? nil : tagRows
            )

            shelfTree = SidebarTree(nodes: roots)
            libraryTree = SidebarTree(nodes: [libraryRoot])
            // The joined list stays for the callers that still read it
            // (= the preview pane's scope resolution walks it).
            tree = SidebarTree(nodes: roots + [libraryRoot])
            loadError = nil
        } catch {
            tree = SidebarTree(nodes: [])
            loadError = "Failed to load sidebar: \(error.localizedDescription)"
        }
    }

    /// Stable sentinel id for the synthetic Reference-Library root
    /// node (= used by ShellState.sidebarSelection's .referenceCategory
    /// discriminator).
    static let referenceLibraryRootId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// '
    /// ': sentinel UUID for the divider row inserted
    /// between user shelves and the reference library root.
    /// (= a different sentinel than referenceLibraryRootId so
    /// the divider never accidentally collides with selection
    /// state; = UUID is irrelevant to UX = just a unique
    /// identity for SwiftUI's diff machinery).
    static let dividerSentinelId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// Canonical UUID of the default help-doc book seeded on first
    /// launch by LibraryMigrator.swift:216 seedDefaultHelpDoc().
    /// (= the same UUID lives in LibraryMigrator; = duplicated here
    /// rather than imported so SidebarService has no transitive
    /// dependency on the Storage module.)
    // (defaultHelpBookId removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py confirmed
    // 0 external callers; = the constant was introduced as a "duplicate for no
    // transitive dep" affordance but never actually used; = callers all reference
    // LibraryMigrator.swift:216 directly. See wenshu-pocock-workflow
    // references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup SKILL.md.)

    /// Folder list shown under each book in the sidebar (= 5
    /// user-facing folders:  /  /  / 
    /// / ). Matches `LazySidebarStandardFolders.all` but
    /// inlined here so SidebarService doesn't reach across the
    /// LazySidebar* family (= that family is the legacy cleanup
    /// historical; = the v1.68 family owns the sidebar tree).
    ///
    /// the
    /// (name, displayName, icon) tuples are derived from
    /// BookFolderCatalog.userFacing (= the canonical source).
    /// SidebarService no longer hardcodes any of these fields;
    /// = to rename a folder or change its icon, edit the
    /// BookFolderSpec literal in BookFolderCatalog.swift and
    /// the sidebar picks up the new value automatically.
    /// BookFolderCatalog.userFacing = the 5 folders with
    /// isUserFacing = true (= world / characters / chapters /
    /// drafts / ideas); = the folders without a sidebar row
    /// (= outlines / sessions) are filtered here.
    private static let folderCatalog: [(name: String, displayName: String, icon: String)] =
        BookFolderCatalog.userFacing.map { spec in
            // The icon field is non-nil for all 5 user-facing folders (= enforced by
            // BookFolderCatalogTests' user- facing check); = the `??
            // "folder"` fallback is a defensive default if a future spec
            // accidentally leaves icon = nil on a user-facing folder (=
            // the sidebar would render a blank rectangle rather than
            // crashing).
            (spec.directoryName, spec.sidebarDisplayName, spec.icon ?? "folder")
        }

    /// Build the folder children for a book (= the user-facing
    /// folders). Returns nil (= leaf row, no disclosure
    /// indicator) for books that should not show folders.
    ///
    /// '
    /// ，' (= default-seeded books should
    /// show their 5 standard folders in the sidebar). All other
    /// books (= user-created) currently also show folders (= the
    /// LazySidebarStandardFolders.all list applies to every book;
    /// = the v1.68f design keeps that convention so existing user
    /// muscle memory still works; = future ticket can scope this
    /// to default-seeded books only if needed).
    private func folderChildren(for book: Book) -> [SidebarNode]? {
        // Stable id = "<book-id>.<folder-name>" so two different books don't collide on
        // the same folder name. Apple HIG List(.sidebar) requires unique row
        // ids within the tree. add the "X " subtitle (= the .md file count
        // under each folder) so the sidebar rows mirror the reference-library
        // row shape (= same 2-line: icon + title + subtitle = icon + title +
        // "X ").
        return Self.folderCatalog.map { folder in
            let count = self.loadFolderDocCount(book.id, folder.name)
            return SidebarNode(
                id: UUID(uuidString: Self.stableFolderId(bookId: book.id, folderName: folder.name)) ?? UUID(),
                kind: .book,
                title: folder.displayName,
                subtitle: "\(count) 项",
                systemImage: folder.icon,
                children: nil
            )
        }
    }

    /// Build a stable UUID (= deterministic, = same book + same
    /// folder always produces the same UUID across launches).
    /// Used as the row id for folder rows in the sidebar so
    /// selection state survives reload.
    private static func stableFolderId(bookId: UUID, folderName: String) -> String {
        // Compose a fixed string and hash it to a UUID-like namespace. Deterministic
        // across processes).
        let raw = "wenshu.sidebar.folder.\(bookId.uuidString).\(folderName)"
        var hasher = Hasher()
        hasher.combine(raw)
        let hash = hasher.finalize()
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        // Pad / truncate to 16 bytes.
        var uuidBytes = Array(bytes)
        while uuidBytes.count < 16 { uuidBytes.append(0) }
        uuidBytes = Array(uuidBytes.prefix(16))
        // Mark version 4 + variant bits to look like a UUID v4.
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        let u = uuidBytes.map { String(format: "%02x", $0) }.joined()
        // Format as UUID string: 8-4-4-4-12.
        let s = u
        let formatted = "\(s.prefix(8))-\(s.dropFirst(8).prefix(4))-\(s.dropFirst(12).prefix(4))-\(s.dropFirst(16).prefix(4))-\(s.dropFirst(20).prefix(12))"
        return String(formatted)
    }

}
