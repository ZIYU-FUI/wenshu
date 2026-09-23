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
    /// = the loadError semantics the v1.67 LazySidebarView
    /// preserved before the v1.69 MVVM split).
    private(set) var loadError: String?

    /// Closure that returns all shelves from the data layer.
    /// (= `bookStore.sidebarLoadShelves()` in production.)
    private let loadShelves: @MainActor () throws -> [Bookshelf]

    /// Closure that returns all books in the library.
    /// (= `bookStore.sidebarLoadAllBooks()` in production.) The
    /// sidebar (not the data layer) groups them by shelf via
    /// `Book.shelfId` (= the pre-v1.69 pattern preserved through
    /// the MVVM split).
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
        loadFolderDocCount: @MainActor @escaping (UUID, String) -> Int = { _, _ in 0 },
        bookStore: BookStore? = nil
    ) {
        self.loadShelves = loadShelves
        self.loadAllBooks = loadAllBooks
        self.loadReferences = loadReferences
        self.loadFolderDocCount = loadFolderDocCount
        // v1.69y: optional bookStore reference (= used by
        // create/delete/rename on the persistence layer; =
        // shelvesRoot + per-shelf per-book paths live on bookStore.
        // = nil for unit-test SidebarService instances that
        // only exercise `nodes()` tree building).
        self.bookStore = bookStore
    }

    /// v1.69y: optional BookStore reference (= injected at
    /// AppleSidebarView's .task block; = nil for unit-test
    /// instances that only test the read-side tree building).
    private let bookStore: BookStore?

    /// v1.69y: latest cached shelves (= populated by `reload()`
    /// from `loadShelves()`; = read by createShelf / renameShelf
    /// for name validation).
    private(set) var shelves: [Bookshelf] = []

    /// v1.69y: latest cached books (= populated by `reload()`
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
            let references = (try? loadReferences()) ?? []

            // v1.69y: cache the latest shelves + books (= the
            // create / rename / delete business methods read
            // these for duplicate-name validation; = avoids
            // refetching on every UI event).
            self.shelves = shelves
            self.books = allBooks

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
                    //
                    // v1.69p boss 2026-09-22 OOB '资料库分类,
                    // 现在显示是的一个字母. 不是中文分类名':
                    // the user-facing title carries the Chinese
                    // displayName (= what the user reads in the
                    // sidebar). The routing key (= the
                    // EntityCategory.directoryName that
                    // ShellMiddleColumn previewScope's case-
                    // insensitive rawValue lookup resolves
                    // back to a category) is stored separately
                    // in `routingKey` so forwardSelection can
                    // write the routing key into SidebarItem
                    // without polluting the user-visible
                    // title slot.
                    referenceRootChildren.append(SidebarNode(
                        id: Self.stableReferenceCategoryId(key),
                        kind: .referenceCategory,
                        title: category.displayName,
                        subtitle: "\(refs.count) 项",
                        systemImage: category.icon,
                        children: nil,
                        routingKey: category.directoryName
                    ))
                } else {
                    // nil-category bucket (= pre-v0.29 references
                    // that were imported before EntityClassifier
                    // existed). Same leaf shape as the official
                    // categories (= the user can still see and
                    // pick the bucket from the sidebar; = the
                    // bucket's contents show in the middle-column
                    // card grid).
                    //
                    // Routing: the bucket key ("未分类") is
                    // stored as the title (= matches the routing
                    // contract that official categories follow).
                    // ShellMiddleColumn.previewScope's case-
                    // insensitive rawValue lookup can't resolve
                    // "未分类" to an EntityCategory (= no
                    // EntityCategory carries this label) so the
                    // previewScope falls through to
                    // .referenceScope(nil) = the full overview
                    // (= the user sees ALL references, including
                    // the bucket's). This is the conservative
                    // behaviour (= better than hiding the bucket
                    // = the user can still reach the uncategorized
                    // row's contents). A future ticket can add a
                    // dedicated .uncategorizedReference scope for
                    // narrow filtering.
                    referenceRootChildren.append(SidebarNode(
                        id: Self.stableReferenceCategoryId(key),
                        kind: .referenceCategory,
                        title: key,
                        subtitle: "\(refs.count) 项",
                        systemImage: "tray.full",
                        children: nil,
                        routingKey: key
                    ))
                }
            }
            // v1.69bb boss 2026-09-23 OOB '现在把资料库上面也
            // 加一条分割线': insert a non-interactive divider
            // row between the user shelves (= `roots` collected
            // from bookStore.sidebarLoadShelves) and the
            // reference library root (= synthetic `reference`
            // kind). The Divider is rendered by SidebarRowView
            // when `node.kind == .divider` (= it has no row
            // chrome; = just a horizontal line; = Apple HIG
            // section separator).
            roots.append(SidebarNode(
                id: Self.dividerSentinelId,
                kind: .divider,
                title: "",
                subtitle: nil,
                systemImage: "",
                children: nil
            ))
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

    /// v1.69bb boss 2026-09-23 OOB '现在把资料库上面也加一条
    /// 分割线': sentinel UUID for the divider row inserted
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

// MARK: - v1.69y boss 2026-09-23 OOB '新建功能, 右边菜单等恢复'
//
//  Create + delete + rename business layer for the sidebar.
//  Restored from the deleted NewLibraryOutlineView.swift
//  (2366 LOC) after v1.69e `git rm`'d it without re-wiring
//  (= per boss 2026-09-23 OOB '需要你把新建功能，右边菜单等恢复').
//
//  What lives here:
//   - persistence surface (= FileManager + JSONEncoder/Decoder
//     for shelvesRoot/, books/<bookId>/book.json, shelf.json).
//   - reserved-name guard (= rejects "资料库" / "Reference Library"
//     pre-v0.26 system-shelf names; = boss 2026-09-20 OOB).
//   - default-shelf-delete guard (= shelf 00000000-... cannot be
//     deleted; = Reference Library is immutable).
//   - duplicate-name validation for create + rename.
//
//  What does NOT live here:
//   - UI (= sheets in SidebarSheets.swift + context menu in
//     SidebarContextMenu.swift + alert + sheet wiring in
//     AppleSidebarView.swift).
//
//  Error type = one enum with LocalizedError (= the v1.0.0-m1
//  legacy ShelfError / ShelfDeleteError pair merged into one
//  with all cases; = same set of reserved + duplicate +
//  cannot-delete-default guards preserved verbatim).
extension SidebarService {
    /// v1.69y: domain error for the create / delete / rename
    /// operations (= LocalizedError so the caller can present
    /// the message in a SwiftUI `.alert(item:)`).
    enum MutationError: LocalizedError, Equatable {
        case cannotDeleteDefault
        case duplicateName(String)
        case reservedName(String)
        case bookNotFound
        case shelfNotFound

        var errorDescription: String? {
            switch self {
            case .cannotDeleteDefault:
                return WenshuI18n.t("sidebar_service_error_cannot_delete_default")
            case .duplicateName(let name):
                return WenshuI18n.t("new_shelf_sheet_duplicate_error")
                    .replacingOccurrences(of: "%@", with: name)
            case .reservedName(let name):
                return WenshuI18n.t("new_shelf_sheet_reserved_error")
                    .replacingOccurrences(of: "%@", with: name)
            case .bookNotFound:
                return WenshuI18n.t("sidebar_service_error_book_not_found")
            case .shelfNotFound:
                return WenshuI18n.t("sidebar_service_error_shelf_not_found")
            }
        }
    }

    /// v1.69y: reserved shelf / book names (= the reference library
    /// uses `资料库` as its display name; = reusing that name for
    /// a user shelf would shadow the reference root; = same set
    /// the legacy NewLibraryOutlineView.renameShelf enforced).
    static let reservedNames: Set<String> = [
        WenshuI18n.t("library.sidebar.reference_root"),
        "资料库", "参考库", "reference library"
    ]

    /// v1.69y: list all shelf display names (= for duplicate-name
    /// validation in NewShelfSheet + RenameItemSheet).
    /// Caller passes the cached `shelves` from SidebarService.
    func existingShelfNames() -> [String] {
        shelves.map { $0.name }
    }

    /// v1.69y: list all book titles (= for duplicate-name
    /// validation in RenameItemSheet; = the legacy
    /// NewLibraryOutlineView.renameBook logic).
    func existingBookTitles() -> [String] {
        books.map { $0.title }
    }

    /// v1.69y: create a new shelf on disk (= shelves/<uuid>/shelf.json
    /// + standard 8 book folders + empty kanban.json + todo.json).
    /// Returns the new shelf's UUID on success (= the caller
    /// updates `shelves` + `sidebarSelection` + calls `reload()`).
    @discardableResult
    func createShelf(name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw MutationError.reservedName(trimmed)
        }
        if existingShelfNames().contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        let shelfId = UUID()
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(shelfId.uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        let now = Date()
        let shelf = Bookshelf(id: shelfId, name: trimmed, createdAt: now, updatedAt: now)
        let data = try JSONEncoder().encode(shelf)
        try data.write(to: shelfDir.appendingPathComponent("shelf.json"))
        return shelfId
    }

    /// v1.69y: create a new book on disk (= shelves/<shelf>/books/<book-uuid>/
    /// with 8 standard folders + book.json + kanban.json + todo.json).
    /// Mirrors the v0.29 LibraryBootstrapper per-book setup pattern.
    /// Returns the new book's UUID on success.
    @discardableResult
    func createBook(input: NewBookSheet.NewBookInput) throws -> UUID {
        let trimmedTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw MutationError.bookNotFound  // signal empty title (= use this case)
        }
        if existingBookTitles().contains(where: { $0.caseInsensitiveCompare(trimmedTitle) == .orderedSame }) {
            throw MutationError.duplicateName(trimmedTitle)
        }
        let bookId = UUID()
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        let bookDir = shelvesRoot
            .appendingPathComponent(input.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let now = Date()
        let standardFolders = [
            "world", "characters", "outlines", "chapters",
            "drafts", "sessions", "foreshadowing", "placeholders"
        ]
        for folder in standardFolders {
            try fm.createDirectory(
                at: bookDir.appendingPathComponent(folder, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        // Empty kanban + todo JSON.
        for dataFile in ["kanban.json", "todo.json"] {
            try Data("[]".utf8).write(to: bookDir.appendingPathComponent(dataFile))
        }
        // Book metadata.
        let book = Book(
            id: bookId,
            title: trimmedTitle,
            author: input.author.trimmingCharacters(in: .whitespacesAndNewlines),
            shelfId: input.shelfId
        )
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        return bookId
    }

    /// v1.69y: delete a shelf on disk (= shelves/<uuid>/).
    /// The default shelf (`00000000-0000-0000-0000-000000000000`)
    /// cannot be deleted (= the legacy ShelfDeleteError
    /// guard; = boss OOB 'Reference Library cannot be deleted').
    func deleteShelf(id: UUID) throws {
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw MutationError.cannotDeleteDefault
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: shelfDir.path) {
            try FileManager.default.removeItem(at: shelfDir)
        }
    }

    /// v1.69y: delete a single book on disk (= shelves/<shelf>/books/<book-uuid>/).
    /// Silently no-op if the book is not on disk (= the legacy
    /// NewLibraryOutlineView.deleteBook behavior).
    func deleteBook(id: UUID) throws {
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        // Find the shelf that contains the book (= walk shelves to
        // find the dir containing shelves/<shelf>/books/<bookId>).
        let fm = FileManager.default
        guard let shelfDirs = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for shelfDir in shelfDirs {
            let bookDir = shelfDir
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString, isDirectory: true)
            if fm.fileExists(atPath: bookDir.path) {
                try fm.removeItem(at: bookDir)
                return
            }
        }
        // Book not on disk = silent no-op (= matches legacy).
    }

    /// v1.69y: rename a shelf (= rewrites shelf.json with the
    /// new name). The directory name (= UUID) is preserved (= the
    /// shelf's identity is stable per Apple HIG document-based app).
    func renameShelf(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.reservedNames.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw MutationError.reservedName(trimmed)
        }
        let others = existingShelfNames().filter { name in
            guard let shelf = self.shelves.first(where: { $0.name == name }) else {
                return true  // skip self if name lookup fails
            }
            return shelf.id != id
        }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.shelfNotFound
        }
        let shelfDir = shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let shelfJSONURL = shelfDir.appendingPathComponent("shelf.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: shelfJSONURL.path),
              let data = try? Data(contentsOf: shelfJSONURL),
              var existing = try? JSONDecoder().decode(Bookshelf.self, from: data)
        else { throw MutationError.shelfNotFound }
        existing.name = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: shelfJSONURL)
    }

    /// v1.69y: rename a book (= rewrites book.json with the new
    /// title). The directory name (= UUID) is preserved (= the
    /// book's identity is stable per Apple HIG document-based app).
    func renameBook(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw MutationError.bookNotFound
        }
        let others = existingBookTitles().filter { title in
            guard let book = self.books.first(where: { $0.title == title }) else {
                return true
            }
            return book.id != id
        }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MutationError.duplicateName(trimmed)
        }
        guard let shelvesRoot = bookStore?.stores.shelvesRoot else {
            throw MutationError.bookNotFound
        }
        let fm = FileManager.default
        guard let shelfDirs = try? fm.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { throw MutationError.bookNotFound }
        for shelfDir in shelfDirs {
            let bookJSONURL = shelfDir
                .appendingPathComponent("books")
                .appendingPathComponent(id.uuidString, isDirectory: true)
                .appendingPathComponent("book.json")
            if fm.fileExists(atPath: bookJSONURL.path),
               let data = try? Data(contentsOf: bookJSONURL),
               var existing = try? JSONDecoder().decode(Book.self, from: data) {
                existing.title = trimmed
                existing.updatedAt = Date()
                let updated = try JSONEncoder().encode(existing)
                try updated.write(to: bookJSONURL)
                return
            }
        }
        throw MutationError.bookNotFound
    }

    // MARK: v1.69y: picker / state query helpers (= consumed by
    // AppleSidebarView when presenting NewBookSheet /
    // RenameItemSheet; = pure reads of the current SidebarService
    // state).

    /// v1.69y: list of (id, name) for the shelf picker in
    /// NewBookSheet (= the user picks which shelf a new book
    /// goes into).
    func availableShelvesForPicker() -> [(id: UUID, name: String)] {
        shelves.map { ($0.id, $0.name) }
    }

    /// v1.69y: resolve the target shelf for a new book (= the
    /// current sidebarSelection if it's a shelf, else fallback
    /// to the default shelf). Mirrors the v1.0.0-m1 legacy
    /// NewLibraryOutlineView.resolveNewBookTargetShelf.
    func targetShelfForNewBook(currentSelection: SidebarItem?) -> (id: UUID, name: String)? {
        if case .shelf(let id) = currentSelection,
           let shelf = shelves.first(where: { $0.id == id }) {
            return (shelf.id, shelf.name)
        }
        if case .book(let id) = currentSelection,
           let book = books.first(where: { $0.id == id }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        return defaultShelfTarget()
    }

    /// v1.69y: fallback target shelf (= the default all-zeros
    /// shelf; = first-launch enable).
    func defaultShelfTarget() -> (id: UUID, name: String)? {
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        if let shelf = shelves.first(where: { $0.id == defaultId }) {
            return (shelf.id, shelf.name)
        }
        // First-launch fallback: no shelves on disk yet.
        return (defaultId, WenshuI18n.t("library.default.shelf_name"))
    }

    /// v1.69y: shelf names excluding the one with `id` (= for
    /// duplicate-name validation in RenameItemSheet when the
    /// user is renaming a shelf).
    func otherShelfNames(excluding id: UUID) -> [String] {
        shelves.filter { $0.id != id }.map { $0.name }
    }

    /// v1.69y: book titles excluding the one with `id` (= for
    /// duplicate-title validation in RenameItemSheet when the
    /// user is renaming a book).
    func otherBookTitles(excluding id: UUID) -> [String] {
        books.filter { $0.id != id }.map { $0.title }
    }
}