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

    /// v1.69 boss 2026-09-22 OOB: closure that returns the number
    /// of .md files in a given book + folder (= used to populate
    /// the "X 项" subtitle on each folder row in the sidebar).
    /// Defaults to `{ _, _ in 0 }` (= unit tests + legacy call
    /// sites that don't need folder counts; = the subtitle reads
    /// "0 项" which is harmless).
    private let loadFolderDocCount: @MainActor (UUID, String) -> Int

    init(
        loadShelves: @MainActor @escaping () throws -> [Bookshelf],
        loadAllBooks: @MainActor @escaping () throws -> [Book],
        loadReferences: @MainActor @escaping () throws -> [Reference],
        loadFolderDocCount: @MainActor @escaping (UUID, String) -> Int = { _, _ in 0 }
    ) {
        self.loadShelves = loadShelves
        self.loadAllBooks = loadAllBooks
        self.loadReferences = loadReferences
        self.loadFolderDocCount = loadFolderDocCount
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
            // = LibraryMigrator seeds them).
            //
            // v1.68f boss 2026-09-22 OOB '帮助和测试小说下面的
            // 自动生成的目录没有出现，需要实现' (= the default
            // help-doc book + the test novels seeded with '自动
            // 生成' folders on first launch should show their
            // 5 standard folders in the sidebar so the user can
            // navigate to them). The fix re-adds the 5
            // user-facing folders (= world / characters /
            // outlines / chapters / drafts) as children of each
            // book, but only for books that have those folders
            // on disk (= default-seeded books).
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

            // Reference library = one root node whose children
            // are the auto-classified CLC categories (= boss
            // 2026-09-22 OOB '资料库自动分类目录的展示' = the
            // 22 CLC top-level categories that auto-classify
            // references; = user can pick a category in the
            // sidebar to filter the middle-column card grid).
            //
            // v0.29 incremental display rule (= boss 8/30 OOB):
            // 'category folders grow with the content, instead of
            // being laid out all at once' — only categories with
            // >= 1 reference are visible. Empty categories are
            // hidden (= no row = no disclosure clutter).
            //
            // Projection rules:
            // 1. Group references by category (= .category? — nil
            //    references go under a synthetic '未分类' bucket
            //    = below the official 22 CLC categories; =
            //    entity-classifier assigns category on save;
            //    pre-v0.29 references have nil).
            // 2. For each non-empty bucket, emit one
            //    `.referenceCategory` parent SidebarNode with the
            //    EntityCategory's displayName + icon (= the same
            //    iconography the entity-classifier uses for the
            //    folder rendering in the reference library).
            // 3. Each category parent's children = the references
            //    (= `.reference` leaves, sorted by title ascending
            //    = CLC convention).
            // 4. The Reference-Library root keeps its existing
            //    kind = .reference (= the v0.30 SidebarItem
            //    .referenceCategory(__root__) sentinel still
            //    resolves to .referenceScope(nil) in
            //    ShellMiddleColumn.previewScope).
            let grouped = Dictionary(grouping: references, by: { Self.referenceCategoryKey(for: $0) })
            var referenceRootChildren: [SidebarNode] = []
            for (key, refs) in grouped.sorted(by: { lhs, rhs in
                Self.categorySortKey(lhs.key) < Self.categorySortKey(rhs.key)
            }) {
                let leafNodes = refs
                    .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
                    .map { ref -> SidebarNode in
                        SidebarNode(
                            id: ref.id,
                            kind: .reference,
                            title: ref.title,
                            subtitle: ref.source,
                            systemImage: "book.closed",
                            children: nil
                        )
                    }
                if let category = Self.EntityCategoryFromDirectoryName(key) {
                    // Official CLC category — show by its
                    // EntityCategory displayName + icon.
                    //
                    // v1.69 boss 2026-09-22 OOB '到分类层就够
                    // 了': leaf rows (= individual references)
                    // are NOT rendered in the sidebar (= the
                    // user browses them via the middle-column
                    // card grid after picking a category). Pass
                    // nil for children so the row carries no
                    // disclosure chevron (= leaf-shaped row;
                    // = single-click routes to the category
                    // scope immediately).
                    referenceRootChildren.append(SidebarNode(
                        id: Self.stableReferenceCategoryId(key),
                        kind: .referenceCategory,
                        title: category.displayName,
                        subtitle: "\(refs.count) 项",
                        systemImage: category.icon,
                        children: nil
                    ))
                } else {
                    // nil-category bucket (= pre-v0.29 references
                    // that were imported before EntityClassifier
                    // existed). Same leaf shape as the official
                    // categories (= the user can still see and
                    // pick the bucket from the sidebar; = the
                    // bucket's contents show in the middle-column
                    // card grid).
                    referenceRootChildren.append(SidebarNode(
                        id: Self.stableReferenceCategoryId(key),
                        kind: .referenceCategory,
                        title: key,
                        subtitle: "\(refs.count) 项",
                        systemImage: "tray.full",
                        children: nil
                    ))
                }
            }
            roots.append(SidebarNode(
                id: Self.referenceLibraryRootId,
                kind: .reference,
                title: WenshuI18n.t("sidebar.reference_library.title"),
                subtitle: nil,
                systemImage: "books.vertical",
                children: referenceRootChildren.isEmpty ? nil : referenceRootChildren
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

    /// Canonical UUID of the default help-doc book seeded on first
    /// launch by LibraryMigrator.swift:216 seedDefaultHelpDoc().
    /// (= the same UUID lives in LibraryMigrator; = duplicated here
    /// rather than imported so SidebarService has no transitive
    /// dependency on the Storage module.)
    static let defaultHelpBookId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// Folder list shown under each book in the sidebar (= 5
    /// user-facing folders: 世界观 / 角色 / 章节大纲 / 小说正文
    /// / 小说草稿). Matches `LazySidebarStandardFolders.all` but
    /// inlined here so SidebarService doesn't reach across the
    /// LazySidebar* family (= that family is v1.67 cleanup
    /// historical; = the v1.68 family owns the sidebar tree).
    private static let folderCatalog: [(name: String, displayName: String, icon: String)] = [
        ("world",      "世界观",   "globe"),
        ("characters", "角色",     "person"),
        ("outlines",   "章节大纲", "list.bullet.rectangle"),
        ("chapters",   "小说正文", "text.book.closed"),
        ("drafts",     "小说草稿", "pencil"),
    ]

    /// Build the folder children for a book (= 5 user-facing
    /// folders). Returns nil (= leaf row, no disclosure
    /// indicator) for books that should not show folders.
    ///
    /// v1.68f boss 2026-09-22 OOB '帮助和测试小说下面的自动生成的
    /// 目录没有出现，需要实现' (= default-seeded books should
    /// show their 5 standard folders in the sidebar). All other
    /// books (= user-created) currently also show folders (= the
    /// LazySidebarStandardFolders.all list applies to every book;
    /// = the v1.68f design keeps that convention so existing user
    /// muscle memory still works; = future ticket can scope this
    /// to default-seeded books only if needed).
    private func folderChildren(for book: Book) -> [SidebarNode]? {
        // Stable id = "<book-id>.<folder-name>" so two different
        // books don't collide on the same folder name. Apple HIG
        // List(.sidebar) requires unique row ids within the tree.
        //
        // v1.69 boss 2026-09-22 OOB: add the "X 项" subtitle
        // (= the .md file count under each folder) so the
        // sidebar rows mirror the reference-library row shape
        // (= same 2-line: icon + title + subtitle = icon +
        // title + "X 项").
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
        // Compose a fixed string and hash it to a UUID-like
        // namespace. Deterministic across processes).
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

    // MARK: - v1.69 reference library auto-classification
    // (= boss 2026-09-22 OOB '资料库自动分类目录的展示').
    //
    // Group references into CLC top-level categories for the
    // sidebar tree (= project the 22-bucket CLC taxonomy onto
    // the reference library's display). Bucket key = the
    // EntityCategory.directoryName (= "a" / "b" / ... / "其它"
    // for official categories; "未分类" for pre-v0.29 references
    // whose category is nil).

    /// Map a Reference to its sidebar-bucket key. v0.29
    /// references always have a category (= assigned by
    /// EntityClassifier on save). Pre-v0.29 imports have nil
    /// (= still seen in the wild on existing user libraries);
    /// those bucket under a synthetic '未分类' label so they
    /// stay browsable rather than disappearing.
    private static func referenceCategoryKey(for ref: Reference) -> String {
        if let category = ref.category {
            return category.directoryName
        }
        return "未分类"
    }

    /// Sort the sidebar buckets in CLC canonical order (= A, B,
    /// C, ..., Z), with the synthetic '未分类' bucket pushed to
    /// the end (= the official categories are the primary
    /// structure; the unclassified bucket is the cleanup-pending
    /// tail). Returns a sort key that Dictionary.sorted(by:)
    /// can compare directly.
    private static func categorySortKey(_ key: String) -> String {
        if key == "未分类" { return "~" } // '~' = ASCII 0x7E = sorts after letters (= A-Z = 0x41-0x5A)
        return key
    }

    /// Map a directoryName back to the EntityCategory. Returns
    /// nil for the synthetic '未分类' bucket (= no
    /// EntityCategory corresponds) and for any unrecognized
    /// key (= forward-compatible with future CLC categories
    /// = the existing 22 cases cover CLC 5th edition
    /// simplified; future expansion would add new enum cases).
    private static func EntityCategoryFromDirectoryName(_ name: String) -> EntityCategory? {
        // EntityCategory.directoryName returns the lowercase
        // rawValue for the official 22 cases (= .a → "a",
        // .i → "i", etc.) and "其它" for .z.
        // EntityCategory(rawValue:) is case-sensitive — so we
        // case-fold the input for the lookup. The official raw
        // values are uppercase letters, so uppercase folding
        // restores the canonical form before lookup.
        let upper = name.uppercased()
        return EntityCategory(rawValue: upper)
    }

    /// Stable UUID for a sidebar category row (= same key →
    /// same UUID across launches; = selection state survives
    /// reload). Distinct from stableFolderId because category
    /// rows live under a different parent (= the synthetic
    /// Reference-Library root) and the ID namespace is
    /// separate (= "wenshu.sidebar.refcat." vs
    /// "wenshu.sidebar.folder.").
    private static func stableReferenceCategoryId(_ key: String) -> UUID {
        let raw = "wenshu.sidebar.refcat.\(key)"
        var hasher = Hasher()
        hasher.combine(raw)
        let hash = hasher.finalize()
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
        var uuidBytes = Array(bytes)
        while uuidBytes.count < 16 { uuidBytes.append(0) }
        uuidBytes = Array(uuidBytes.prefix(16))
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        let u = uuidBytes.map { String(format: "%02x", $0) }.joined()
        let formatted = "\(u.prefix(8))-\(u.dropFirst(8).prefix(4))-\(u.dropFirst(12).prefix(4))-\(u.dropFirst(16).prefix(4))-\(u.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}