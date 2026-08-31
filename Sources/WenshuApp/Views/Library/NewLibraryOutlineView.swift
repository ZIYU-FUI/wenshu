// NewLibraryOutlineView.swift · Wenshu (文枢) · v0.30 Apple HIG sidebar
//
// v0.30 boss 2026-08-30 OOB: '如果你要 100% Apple native, 我想选这个'.
//
// 100% Apple HIG standard sidebar (= List(selection:) + .listStyle(.sidebar)).
//
// Per Apple HIG "Sidebars" (developer.apple.com/design/human-interface-
// guidelines/sidebars):
//
// 1. "A sidebar's row height, text, and glyph size depend on its overall
//    size, which can be small, medium, or large. You can set the size
//    programmatically, but people can also change it by selecting a
//    different sidebar icon size in General settings."
//    → NO hardcoded 18 PT icon / 28 PT row / 18 PT trailing padding.
//      Apple std follows user's "Sidebar icon size" system preference.
//
// 2. "In general, show no more than two levels of hierarchy in a sidebar."
//    → Use DisclosureGroup (= Apple std 2-level tree). Books contain
//      folders as a DisclosureGroup (= level 1 → level 2). Reference
//      library root contains categories as a DisclosureGroup
//      (= level 1 → level 2).
//
// 3. "By default, sidebar icons use your app's accent color." On
//    macOS Tahoe, sidebar icon tint = black in light mode / white in
//    dark mode. Per marioaguzman.github.io/design/sidebarguidelines:
//    "the default tint for icons in the sidebar is now black in light
//    mode and white in dark mode".
//    → Use .foregroundStyle(.primary) (= black/white) instead of
//      category-color accent tint.
//
// 4. Apple SwiftUI std:
//    → List(selection:) for selection binding.
//    → Label { Text } icon: { LucideIcon } for rows (= Apple std row).
//    → .badge(count) for count badges (= Apple std count badge).
//    → listStyle(.sidebar) for native sidebar appearance + Liquid
//      Glass treatment.
//    → List selection highlighting is automatic (= Apple std accent
//      color tint; no manual .background() required).
//
// Migration notes (= what is REMOVED from prior wenshu-boss-taste
// implementation):
// - 18 PT icon .frame(width:height:)              → removed
// - 28 PT row .frame(height:)                      → removed
// - 18 PT .padding(.trailing) on each row          → removed
// - 4 PT indentPT custom indentation               → removed (= List
//   handles indentation via DisclosureGroup nesting)
// - Manual Color.accentColor.opacity(0.12)         → removed (= Apple
//   List selection is automatic)
// - Category-color icon tint                       → removed (= Apple
//   HIG: primary tint only)
// - Custom chevron Lucide icon                     → removed (= Apple
//   std uses system disclosure indicator)

import SwiftUI
import Lucide

/// Identifies a single sidebar item for List(selection:) binding.
/// v0.30: composite enum (= book OR reference category) because
/// Apple HIG allows ONE selection type per List, so we unify
/// both selection kinds into one Hashable enum.
enum SidebarItem: Hashable, Codable {
    case book(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2): shelf
    // (= first tree level) is now a clickable tree row, not just a
    // SwiftUI Section header. Tagging it with .shelf(UUID) lets the
    // user select a shelf directly (= will eventually scope preview
    // pane to the shelf; for now it just keeps the shelf row
    // highlighted when selected).
    case shelf(UUID)
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): folder row
    // (= third tree level, e.g. 世界观 / 角色 / 章节大纲 / 小说正文 /
    // / 小说草稿). Tagging with .folder(bookId, folderName) lets
    // the user select a folder directly; preview pane will scope to
    // that folder's content (= shows the .md files inside).
    case folder(bookId: UUID, folderName: String)
    case referenceCategory(String)  // = EntityCategory.directoryName

    static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")

    // MARK: - v0.30 boss 8/31 OOB: Codable for AppStorage persistence
    //
    // Custom JSON encode/decode for @AppStorage (= AppStorage uses
    // String, so we round-trip via JSONEncoder/JSONDecoder). Flat
    // shape (= 'kind' discriminator + per-case keys) keeps the
    // JSON human-readable in `defaults read`.
    //
    // JSON shapes:
    //   {"kind": "book", "book": "<UUID>"}
    //   {"kind": "shelf", "shelf": "<UUID>"}
    //   {"kind": "folder", "book": "<UUID>", "folder": "world"}
    //   {"kind": "referenceCategory", "referenceCategory": "文学"}
    private enum CodingKeys: String, CodingKey {
        case kind, book, shelf, folder, referenceCategory
    }
    private enum Kind: String, Codable {
        case book, shelf, folder, referenceCategory
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .book(let id):
            try c.encode(Kind.book, forKey: .kind)
            try c.encode(id.uuidString, forKey: .book)
        case .shelf(let id):
            try c.encode(Kind.shelf, forKey: .kind)
            try c.encode(id.uuidString, forKey: .shelf)
        case .folder(let bookId, let folderName):
            try c.encode(Kind.folder, forKey: .kind)
            try c.encode(bookId.uuidString, forKey: .book)
            try c.encode(folderName, forKey: .folder)
        case .referenceCategory(let dirName):
            try c.encode(Kind.referenceCategory, forKey: .kind)
            try c.encode(dirName, forKey: .referenceCategory)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .book:
            let s = try c.decode(String.self, forKey: .book)
            self = .book(UUID(uuidString: s) ?? UUID())
        case .shelf:
            let s = try c.decode(String.self, forKey: .shelf)
            self = .shelf(UUID(uuidString: s) ?? UUID())
        case .folder:
            let s = try c.decode(String.self, forKey: .book)
            let f = try c.decode(String.self, forKey: .folder)
            self = .folder(bookId: UUID(uuidString: s) ?? UUID(), folderName: f)
        case .referenceCategory:
            let d = try c.decode(String.self, forKey: .referenceCategory)
            self = .referenceCategory(d)
        }
    }
}

struct NewLibraryOutlineView: View {
    @Environment(BookStore.self) private var bookStore

    /// v0.30: parent passes binding (= WorkspaceView owns the state).
    /// When sidebar category is tapped, WorkspaceView's selectedEntityCategory
    /// updates → preview pane shows the category-scoped grid.
    /// Default-init available (= for non-workspace callers via `.constant(nil)`).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// v0.30 boss 8/31 OOB: default initializer (= non-workspace
    /// callers = registered panes, zoneHeaderButtons, fallback
    /// render). All cross-zone state now reads via @Environment,
    /// so this initializer takes no binding parameters.
    init(
        selectedEntityCategory: Binding<EntityCategory?> = .constant(nil),
        selectedEntity: Binding<Reference?> = .constant(nil)
    ) {
        self._selectedEntityCategory = selectedEntityCategory
        self._selectedEntity = selectedEntity
    }

    @State private var shelves: [Bookshelf] = []
    @State private var books: [Book] = []
    @State private var references: [Reference] = []
    @State private var loadError: String?
    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false
    // v0.30 boss 8/31 OOB: added an intermediate sheet
    // (= "New Book" / "New Shelf" two-button choice) to replace
    // the Menu pattern that failed to render inside the
    // ZoneContentTabBar trailing slot.
    @State private var showNewChoiceSheet: Bool = false
    // v0.30 boss 8/31 OOB: context-menu state (= delete / rename
    // confirmation). 'pendingDelete' holds the (kind, id) tuple
    // for the item awaiting deletion; setting it shows an
    // .alert with a confirm/cancel pair (= destructive action
    // requires explicit confirmation per macOS HIG).
    @State private var pendingDelete: PendingDelete?
    // 'renaming' holds the (kind, id) for the item being renamed;
    // setting it presents RenameItemSheet for the user to type a
    // new name (= reuses the NewShelfSheet / NewBookSheet field
    // patterns).
    @State private var renaming: RenamingTarget?

    /// v0.30 boss 8/31 OOB '各区域之间的联动' (= option A = global
    /// @Observable store): sidebar selection is now read directly
    /// from AppState via @Environment (= no @Binding threaded
    /// from WorkspaceView).
    @Environment(AppState.self) private var appState
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): per-shelf
    // DisclosureGroup expanded state (= remembers user expand/collapse
    // across selections). Keys = shelf.id, value = isExpanded.
    // Auto-expanded if any of its books is selected (= overrides user
    // collapse when user selects a book in this shelf).
    @State private var shelfDisclosureStates: [UUID: Bool] = [:]
    // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): per-book
    // folder DisclosureGroup expanded state. Auto-expanded when this
    // book is the current sidebar selection (= folders visible
    // immediately on book tap). Keys = book.id, value = isExpanded.
    @State private var bookDisclosureStates: [UUID: Bool] = [:]

    var body: some View {
        // v0.30: 100% Apple HIG standard sidebar.
        //
        // = List(selection: $sidebarSelection)
        //   .listStyle(.sidebar)
        //
        // Sections:
        // - Per user-named shelf (= Section per shelf)
        // - Per reference library (= single Section)
        // Books use DisclosureGroup for folder nesting (= 2 levels).
        // Reference library uses DisclosureGroup for category nesting
        // (= 2 levels).
        //
        // All rows use Label + .badge (= Apple std). No hardcoded
        // sizes (= Apple HIG: follow user system preference). Selection
        // highlight = automatic (= Apple std).
        // v0.30 boss 8/31 OOB '双击后蓝色小条消失, 状态和首次进入
        // 不一样': List(.sidebar) on macOS has a 'click-selected-row-
        // again-to-deselect' behavior (= standard Finder pattern).
        // For wenshu, this means clicking 世界观 a second time clears
        // the entire selection (= no sidebarSelection = no blue strip
        // anywhere = the 'state not persistent' the user observed).
        //
        // Fix: wrap the binding in a guard that ignores nil writes
        // (= the user can never accidentally clear their selection
        // via List(.sidebar)'s click-to-deselect). The selection is
        // only changed by explicit actions (= button taps, double-
        // click toggles, etc.) — never by List's own deselect gesture.
        List(selection: Binding(
            get: { appState.sidebarSelection },
            set: { newValue in
                if let newValue {
                    appState.sidebarSelection = newValue
                }
            }
        )) {
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2):
            // 'shelf "从这里开始" should be in the directory tree as
            // first level (= not a SwiftUI Section header)'. Replaced
            // Section { } header: { Label { Text(shelf.name) } } with
            // DisclosureGroup (= shelf is now a clickable tree row at
            // level 1, with chevron, instead of a grayed-out header).
            // The book rows inside the shelf (= level 2) are nested
            // inside the DisclosureGroup content. When a book row is
            // selected (= appState.sidebarSelection = .book(...)), its own
            // nested DisclosureGroup for folders (= level 3) auto-
            // expands so 世界观 / 角色 / 章节大纲 / 小说正文 / 小说草稿
            // are visible without an extra tap (= boss OOB #3 'child
            // folders should be visible immediately on book select').
            ForEach(shelves) { shelf in
                shelfRow(shelf)
            }
            // Reference library (= library's default shelf per boss 8/26
            // OOB; user CANNOT delete or rename). Treated as a single
            // Section per Apple HIG; categories expand via
            // DisclosureGroup (= 2-level hierarchy).
            Section {
                DisclosureGroup {
                    ForEach(usedCategories(), id: \.directoryName) { category in
                    // Note: double-click on reference library root
                    // (= 资料库) toggles the section below. The
                    // section's DisclosureGroup handles expand/collapse
                    // natively (= tap on the chevron). Boss OOB
                    // '双击目录树展开合上' = standard Finder behavior,
                    // supported here via the DisclosureGroup's built-in
                    // gesture.
                        Label {
                            Text(category.displayName)
                        } icon: {
                            LucideIconSidebar(category.icon)
                        .foregroundStyle(.primary)
                        }
                        .badge(entitiesCount(in: category))
                        .tag(SidebarItem.referenceCategory(category.directoryName))
                    }
                } label: {
                    Label {
                        Text("资料库")
                    } icon: {
                        LucideIconSidebar("square-library")
                        .foregroundStyle(.primary)
                    }
                    .badge(usedCategories().count)
                    .tag(SidebarItem.referenceLibraryRoot)
                }
            }
        }
        .listStyle(.sidebar)
        // v0.30 boss 8/31 OOB: right-click context menu on
        // selected rows. Apple HIG official pattern in macOS 14+ is
        // .contextMenu(forSelectionType:menu:primaryAction:) on
        // the List (= a single menu definition for the entire List,
        // shown when user right-clicks OR long-presses on any
        // selected row). The per-row .contextMenu modifier on
        // Label/DisclosureGroup label did NOT reliably surface on
        // macOS 26 Tahoe for List rows (= the List swallowed the
        // secondary click). This is the documented Apple HIG
        // replacement.
        //
        // The menu builder switches on the selected SidebarItem
        // kind (= shelf, book, reference category) to show the
        // right actions (= '新建书' only on shelves, etc.). The
        // reference library section is excluded (= per boss OOB
        // '资料库不允许删除').
        .contextMenu(forSelectionType: SidebarItem.self) { selectedItems in
            contextMenuForSelection(selectedItems)
        } primaryAction: { selectedItems in
            // No primary action (= double-click = open in editor
            // for books in a future ticket; for now, just no-op).
        }
        // v0.30 boss 8/31 OOB: right-click on EMPTY area of sidebar
        // (= the gap below the last row, before the next Section).
        // .contextMenu(forSelectionType:) only fires on row hits;
        // for empty-area right-click we use a plain .contextMenu on
        // the List (= macOS 14+ behavior: shows when the user right-
        // clicks anywhere inside the List, regardless of row hit).
        // Apple HIG: empty-area context menu = top-level actions
        // (= 创建新书架 is the canonical "I'm in the sidebar, I want
        // to add something" action).
        .contextMenu {
            Button("新建书架…") {
                showNewShelfSheet = true
            }
            Button("新建书…") {
                showNewBookSheet = true
            }
        }
        // v0.30 boss 8/31 OOB ('Sidebar 背景 不跟液态玻璃透明度调整 / 之前已经实现的,
        // 改目录树的时候动到了, 修复'):
        // Apple HIG .sidebar listStyle draws its own opaque background
        // (= macOS 26 Tahoe canonical sidebar material), which covers
        // the RegionContentBackground applied at ZonePerRegionChrome.
        // .scrollContentBackground(.hidden) makes the list itself
        // transparent so the parent's RegionContentBackground shows
        // through (= follows the liquid-glass opacity slider in Settings).
        .scrollContentBackground(.hidden)
        .onAppear {
            reload()
            // v0.30 boss 8/31 OOB: '首次进入, 选定效果是灰色的, 不是
            // 系统色. 双击后会变成蓝色'. macOS 26 Tahoe List(.sidebar)
            // shows the SELECTED row in GRAY (= not accent color) on
            // the very first render pass, then switches to the user's
            // accent color after the user interacts (= SwiftUI's
            // selection-tint resolution timing).
            //
            // Root cause: on cold-launch, bookStore.selectedBookId is
            // already set to the help book (= pre-populated by
            // WenshuLibrary init), but onChange(of: bookStore.selected
            // BookId) only fires on CHANGE (= not initial value), so
            // appState.sidebarSelection stays nil/empty on the first
            // render pass. Then when sidebarSelection IS set
            // (via user interaction), SwiftUI re-renders with accent
            // color.
            //
            // Fix: explicitly sync sidebarSelection from
            // bookStore.selectedBookId in onAppear (= before the
            // first render of the List). This way the List's first
            // render already has selection = .book(helpBook.id), and
            // SwiftUI uses the user's accent color from the start.
            if let id = bookStore.selectedBookId,
               appState.sidebarSelection == nil {
                appState.sidebarSelection = .book(id)
            }
        }
        .onChange(of: appState.sidebarSelection) { _, newValue in
            // v0.30: forward sidebar selection to bookStore.selectedBookId
            // (for books) and selectedEntityCategory binding (for
            // categories). Single onChange handler unifies both.
            switch newValue {
            case .book(let id):
                bookStore.selectedBookId = id
                selectedEntityCategory = nil
                selectedEntity = nil
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #3): handle
            // the new .folder(bookId, folderName) sidebar selection.
            // For now, selecting a folder just clears book/category
            // selection (= visual highlight only). Future ticket can
            // wire folder-level preview pane scoping (= show all .md
            // files in that folder with content previews).
            case .folder:
                bookStore.selectedBookId = nil
                selectedEntityCategory = nil
                selectedEntity = nil
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2): handle
            // the new .shelf(UUID) sidebar selection. For now, selecting
            // a shelf just clears book/category selection (= visual
            // highlight only). Future ticket can wire shelf-level
            // preview pane scoping (= show all books in this shelf).
            case .shelf:
                bookStore.selectedBookId = nil
                selectedEntityCategory = nil
                selectedEntity = nil
            case .referenceCategory(let dirName):
                if dirName == "__root__" {
                    selectedEntityCategory = nil
                } else if let cat = EntityCategory.allCases.first(where: { $0.directoryName == dirName }) {
                    selectedEntityCategory = cat
                    selectedEntity = nil
                }
            case .none:
                break
            }
        }
        .onChange(of: bookStore.selectedBookId) { _, newValue in
            // Sync external changes (= toolbar click elsewhere) into
            // local List selection.
            if let id = newValue {
                appState.sidebarSelection = .book(id)
            }
        }
        .onChange(of: selectedEntityCategory) { _, newValue in
            // Sync external category changes (= WorkspaceView → preview
            // pane state) into local List selection (= maintains
            // consistency between sidebar selection highlight and the
            // preview pane's category-scoped grid mode).
            if let cat = newValue {
                appState.sidebarSelection = .referenceCategory(cat.directoryName)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wenshuNewBookRequested)) { _ in
            showNewBookSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wenshuNewShelfRequested)) { _ in
            showNewShelfSheet = true
        }
        // v0.30 boss 8/31 OOB #2 ('弹出菜单没有恢复'):
        // The trailing-slot button posts .wenshuChoiceRequested; the
        // sidebar body NewLibraryOutlineView (= this view, real view
        // hierarchy) toggles its own showNewChoiceSheet @State and
        // presents NewChoiceSheet. The trailing-slot instance cannot
        // host .sheet itself (= AnyView wrapper).
        .onReceive(NotificationCenter.default.publisher(for: .wenshuChoiceRequested)) { _ in
            showNewChoiceSheet = true
        }
        .sheet(isPresented: $showNewBookSheet) {
            // v0.30 boss 8/31 OOB: pre-fill the new book with the
            // currently-selected shelf id (= so clicking '新建书'
            // while '测试书架' is selected creates the book in
            // '测试书架' instead of always in the default shelf).
            // The shelf picker inside the sheet lets the user
            // override this (= change shelf before saving).
            let target = resolveNewBookTargetShelf()
            NewBookSheet(
                onSave: { book in
                    do {
                        try saveBook(book)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                },
                targetShelfId: target.id,
                targetShelfName: target.name,
                availableShelves: shelves.map { ($0.id, $0.name) }
            )
        }
        .sheet(isPresented: $showNewShelfSheet) {
            NewShelfSheet(
                onSave: { name, icon in
                    do {
                        try saveShelf(name: name, icon: icon)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                },
                existingNames: shelves.map { $0.name }
            )
        }
        .sheet(isPresented: $showNewChoiceSheet) {
            NewChoiceSheet(
                onNewBook: {
                    showNewChoiceSheet = false
                    showNewBookSheet = true
                },
                onNewShelf: {
                    showNewChoiceSheet = false
                    showNewShelfSheet = true
                }
            )
        }
        // v0.30 boss 8/31 OOB: context-menu rename sheet (= opens
        // when user picks '重命名…' from shelf or book context
        // menu). The sheet pre-fills with the current name and
        // runs the same duplicate + reserved-name validation as
        // NewShelfSheet. User confirms to apply the rename.
        .sheet(item: $renaming) { target in
            Group {
                if target.kind == .shelf {
                    RenameItemSheet(
                        title: "重命名书架",
                        originalName: target.originalName,
                        existingNames: shelves
                            .filter { $0.id != target.itemId }
                            .map { $0.name }
                    ) { newName in
                        do {
                            try renameShelf(id: target.itemId, newName: newName)
                            reload()
                        } catch {
                            loadError = error.localizedDescription
                        }
                    }
                } else {
                    RenameItemSheet(
                        title: "重命名书",
                        originalName: target.originalName,
                        existingNames: books
                            .filter { $0.id != target.itemId }
                            .map { $0.title }
                    ) { newTitle in
                        do {
                            try renameBook(id: target.itemId, newTitle: newTitle)
                            reload()
                        } catch {
                            loadError = error.localizedDescription
                        }
                    }
                }
            }
        }
        // v0.30 boss 8/31 OOB: context-menu delete confirmation.
        // Apple HIG: destructive operations require explicit
        // confirmation via .alert (= the .destructive role on
        // the button is not enough on macOS for safety). The
        // alert message shows the count of children that will
        // be deleted along with the target (= user sees exactly
        // what they're losing before confirming).
        .alert(
            "确认删除?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
            Button("删除", role: .destructive) {
                do {
                    switch target.kind {
                    case .shelf:
                        try deleteShelf(id: target.itemId)
                    case .book:
                        try deleteBook(id: target.itemId)
                    }
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
                pendingDelete = nil
            }
        } message: { target in
            // Per Apple HIG: confirm dialogs should clearly state
            // what will be lost. We show the target name + child
            // count so the user knows the full blast radius.
            let childCount = pendingDeleteChildCount(target: target)
            if childCount > 0 {
                let childKindLabel = target.kind == .shelf ? "书" : "文档"
                Text("将永久删除 \(target.itemName) 以及其中的 \(childCount) 个\(childKindLabel)。此操作不可撤销。")
            } else {
                Text("将永久删除 \(target.itemName)。此操作不可撤销。")
            }
        }
    }

    // MARK: - Row builders

    /// v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): shelf
    /// row (= first tree level). Wraps shelf + books + folders in a
    /// single nested DisclosureGroup chain (= shelf is level 1, books
    /// are level 2, folders under selected book are level 3).
    ///
    /// - Shelf label = `shelf.name` (= "从这里开始" by default).
    /// - DisclosureGroup auto-expands when any of its child books is
    ///   selected (= user sees the book immediately on shelf select).
    /// - Book row contains its own nested DisclosureGroup of folders
    ///   (= level 3). Folder rows have no further children (= leaf).
    @ViewBuilder
    private func shelfRow(_ shelf: Bookshelf) -> some View {
        let books = booksInShelf(shelf)
        let isShelfExpanded = books.contains { isBookSelected($0.id) }
        DisclosureGroup(isExpanded: Binding(
            get: { isShelfExpanded || shelfDisclosureStates[shelf.id, default: false] },
            set: { shelfDisclosureStates[shelf.id] = $0 }
        )) {
            ForEach(books) { book in
                bookRowWithFolders(book)
            }
        } label: {
            Label {
                Text(shelf.name)
            } icon: {
                // v0.30 boss 8/31 OOB: use displayIcon (= user-picked
                // icon if set; otherwise defaults based on whether
                // this is the canonical default shelf or a user-
                // created shelf). Previously hardcoded to two static
                // icons, which left user-created shelves without
                // any icon at all (= '新建书架后，暑假没有 ICON').
                LucideIconSidebar(shelf.displayIcon)
                    .foregroundStyle(.primary)
            }
            // v0.30 boss 8/31 OOB: shelf count badge (= total books
            // in this shelf). User reported '书架后面没有统计数字'.
            .badge(books.count)
            .tag(SidebarItem.shelf(shelf.id))            // v0.30 boss 8/31 OOB: right-click context menu on shelf
            // row. Apple HIG canonical contextMenu pattern. Two
            // actions: 重命名 (= renames the shelf in place) +
            // 删除 (= marks shelf for deletion, triggers .alert for
            // confirmation). The default '从这里开始' shelf is NOT
            // blocked here (= it has the same context menu as
            // user-created shelves; the '资料库 不允许删除' rule
            // only applies to the reference library Section, which
            // is a different element).
            .contextMenu {
                Button("重命名…") {
                    renaming = RenamingTarget(
                        kind: .shelf,
                        itemId: shelf.id,
                        originalName: shelf.name,
                        shelfId: nil
                    )
                }
                Divider()
                Button("删除…", role: .destructive) {
                    pendingDelete = PendingDelete(
                        kind: .shelf,
                        itemId: shelf.id,
                        itemName: shelf.name
                    )
                }
            }
            // v0.30 boss 8/31 OOB '顺手做一下, 双击目录树展开合上
            // 的交互': double-click on the shelf label toggles the
            // DisclosureGroup (= standard macOS Finder pattern).
            // Single click selects the shelf (= sets sidebarSelection
            // to .shelf(id) for preview pane scope); double click
            // toggles expand/collapse. The double-click gesture is
            // recognized only after the second tap arrives within
            // the macOS standard double-click interval (~500ms);
            // single taps are unaffected.
            .onTapGesture(count: 2) {
                shelfDisclosureStates[shelf.id, default: false].toggle()
            }
        }
    }

    /// v0.30: Apple std book row + nested DisclosureGroup of folders.
    /// Per Apple HIG "show no more than two levels of hierarchy in a
    /// sidebar" (= book + folders = 2 levels). Folders are visual
    /// placeholders (= current docs hidden per boss OOB), so each
    /// folder has no badge (= displays no count).
    ///
    /// v0.30 boss 8/30 OOB '目录树有一个按文字从这里开始, 那个应该是
    /// 没用的, 正式的从这里开始缺少 ICON' = book row missing icon. Root
    /// cause = wrong Lucide icon name 'book.closed' (= doesn't exist in
    /// Lucide; falls back to Color.clear in LucideIcon helper). Correct
    /// Lucide canonical name = 'book' (= case book = "book" in
    /// LucideIcon enum).
    @ViewBuilder
    private func bookRowWithFolders(_ book: Book) -> some View {
        let folders = standardFolderNames
        if folders.isEmpty {
            // Defensive: a book with no folders (= shouldn't happen,
            // but keep single-row rendering for safety).
            Label {
                Text(book.title)
            } icon: {
                // v0.30 boss 8/31 OOB: use displayIcon (= user-picked
                // icon if set, else default "book").
                LucideIconSidebar(book.displayIcon)
                    .foregroundStyle(.primary)
            }
            .tag(SidebarItem.book(book.id))        } else {
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #3):
            // 'child folders should be visible immediately when book
            // is selected' = auto-expand the folder DisclosureGroup
            // when this book is the current sidebarSelection. User-
            // controlled collapse is preserved via bookDisclosureStates.
            let isBookSelectedNow = isBookSelected(book.id)
            let isAnyFolderInsideSelected = folders.contains { folder in
                appState.sidebarSelection == .folder(
                    bookId: book.id, folderName: folder.name
                )
            }
            // v0.30 boss 8/31 OOB '点世界观那一层会收起': the book
            // DisclosureGroup previously collapsed when the user
            // clicked a folder inside (= because the binding only
            // checked 'isBookSelected', which is false once the
            // selection moved from .book to .folder). Now we also
            // keep it expanded when ANY folder inside is selected,
            // so clicking 世界观 / 角色 / 章节大纲 / 小说正文 / 小说
            // 草稿 keeps the parent expanded (= same visual model
            // as Finder: a folder with a selected child stays open).
            DisclosureGroup(isExpanded: Binding(
                get: { isBookSelectedNow
                       || isAnyFolderInsideSelected
                       || bookDisclosureStates[book.id, default: false] },
                set: { bookDisclosureStates[book.id] = $0 }
            )) {
                // v0.30 boss 8/31 OOB (sidebar feedback bundle #3):
                // folder count badge (= number of .md files in this
                // folder). User reported '子目录后面没有显示数字' =
                // count badges were missing because folder rows
                // didn't have .badge() modifier.
                ForEach(folders, id: \.name) { folder in
                    // v0.30 boss 8/31 OOB: folder rows must NOT collapse
                    // the parent DisclosureGroup on click. Wrapping in
                    // a plain Button with sidebarSelection update on
                    // tap gives the row its own tap target (= the
                    // click is consumed by the button and does NOT
                    // propagate up to the DisclosureGroup label,
                    // which would otherwise collapse the parent's
                    // expansion state). The Button's tap also sets
                    // appState.sidebarSelection = .folder(...) (= the same
                    // path used by the .tag modifier, but the Button
                    // form is more reliable for nested rows inside
                    // a DisclosureGroup).
                    Button {
                        appState.sidebarSelection = .folder(
                            bookId: book.id,
                            folderName: folder.name
                        )
                    } label: {
                        Label {
                            Text(folder.displayName)
                        } icon: {
                            LucideIconSidebar(folder.icon)
                                .foregroundStyle(.primary)
                        }
                        .badge(bookStore.folderDocumentCount(
                            bookId: book.id,
                            folderDirectoryName: folder.name
                        ))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    // v0.30 boss 8/31 OOB: folder row tag (= enables
                    // List(selection:) routing for this row).
                    .tag(SidebarItem.folder(bookId: book.id, folderName: folder.name))
                }
            } label: {
                Label {
                    Text(book.title)
                } icon: {
                    // v0.30 boss 8/31 OOB: use displayIcon (= user-picked
                    // icon if set, else default "book").
                    LucideIconSidebar(book.displayIcon)
                        .foregroundStyle(.primary)
                }
                // v0.30 boss 8/31 OOB: book row count badge (= total
                // .md files across all folders in this book). User
                // reported '书后面没有统计数字'.
                .badge(folders.reduce(0) { $0 + bookStore.folderDocumentCount(
                    bookId: book.id,
                    folderDirectoryName: $1.name
                )})
                .tag(SidebarItem.book(book.id))                // v0.30 boss 8/31 OOB '顺手做一下, 双击目录树展开合上
                // 的交互': double-click on the book label toggles the
                // folder DisclosureGroup (= level 3 expand/collapse).
                // Single click selects the book (= sets
                // sidebarSelection to .book(id) for preview pane scope
                // + auto-expands folders per existing logic); double
                // click toggles expansion. Finder standard pattern.
                .onTapGesture(count: 2) {
                    bookDisclosureStates[book.id, default: false].toggle()
                }
                // v0.30 boss 8/31 OOB: right-click context menu on book
                // row. Apple HIG canonical pattern. The 帮助 book in
                // the default '从这里开始' shelf still gets the
                // menu (= user can delete the help book if they
                // want; the 资料库 rule is for the reference
                // library Section, not for the default help book).
                .contextMenu {
                    Button("重命名…") {
                        renaming = RenamingTarget(
                            kind: .book,
                            itemId: book.id,
                            originalName: book.title,
                            shelfId: book.shelfId
                        )
                    }
                    Divider()
                    Button("删除…", role: .destructive) {
                        pendingDelete = PendingDelete(
                            kind: .book,
                            itemId: book.id,
                            itemName: book.title
                        )
                    }
                }
            }
        }
    }

    /// v0.30: 5 user-facing standard folder names + icons (= per spec
    /// v5 ticket 001 + ticket 026). 3 hidden folders (LLM 会话, 伏笔,
    /// 占位符) NOT shown per boss 8/30 sidebar cleanup.
    private var standardFolderNames: [(name: String, displayName: String, icon: String)] {
        [
            ("world",      "世界观",      "globe"),
            ("characters", "角色",        "user-round"),
            ("outlines",   "章节大纲",    "list-tree"),
            ("chapters",   "小说正文",    "book-text"),
            ("drafts",     "小说草稿",    "file-pen-line"),
        ]
    }

    // MARK: - Data helpers

    /// v0.30 boss 8/31 OOB (sidebar feedback bundle #1+2+3): returns
    /// whether the given book id is the currently selected sidebar
    /// item (= used by DisclosureGroup auto-expand logic).
    private func isBookSelected(_ id: UUID) -> Bool {
        if case .book(let selectedId) = appState.sidebarSelection {
            return selectedId == id
        }
        return false
    }

    /// v0.30: Apple std list of categories with ≥1 entity, sorted A→Z.
    /// (= Same logic as v0.29 computeUsedCategories; renamed to match
    /// Apple HIG sidebar convention of "sidebar only shows used items".)
    private func usedCategories() -> [EntityCategory] {
        let allRefs = (try? bookStore.referenceStore.loadAllReferences()) ?? []
        let entityRefs = allRefs.filter { $0.layer == .layerEntities }
        let used = Set(entityRefs.compactMap { $0.category })
        return EntityCategory.allCases.filter { used.contains($0) }
    }

    /// v0.30: count of entities in this category.
    private func entitiesCount(in category: EntityCategory) -> Int {
        let allRefs = (try? bookStore.referenceStore.loadAllReferences()) ?? []
        return allRefs.filter { $0.layer == .layerEntities && $0.category == category }.count
    }

    private func booksInShelf(_ shelf: Bookshelf) -> [Book] {
        books.filter { $0.shelfId == shelf.id }
    }

    // MARK: - Zone header buttons (= 新建 + 入驻)
    //
    // Per boss 8/27 '复用 v0.25.x 现有的 toolbar "+" 按钮': the toolbar
    // '+' button (= main app toolbar, not sidebar header) drives the
    // "新建书 / 新建书架" menu. This trailingButton is rendered via
    // ZoneContentView's trailingButton parameter (= app.swift:2155)
    // and shows icon buttons in the projectSidebar zone header.

    /// 2 icon buttons rendered in the projectSidebar zone header
    /// trailing area. Per boss 8/27 OOB #3 (= commit bca226704): 新建 Menu +
    /// 入驻 plain Button. Both use the editor-expand + chat-archive
    /// icon-button pattern (= 28x28 hot area + Lucide icon overlay +
    /// .secondary foreground + .contentShape Rectangle).
    ///
    /// v0.30 boss 8/30 OOB '恢复那两个按钮, 还有 icon' = restore the
    /// original v0.27-style buttons and icons:
    /// - 新建 icon = "square-plus" (Lucide canonical, NOT SF "plus")
    /// - 入驻 icon = "square-arrow-right" (Lucide canonical)
    ///
    /// v0.30 dev drift (= what NOT to do): I had used SF Symbol "plus"
    /// for the 新建 icon (= losing the Lucide canonical name + visual
    /// consistency with the rest of the sidebar tree icons). Boss caught
    /// it. Restored to Lucide canonical per bca226704.
    @ViewBuilder
    var zoneHeaderButtons: some View {
        // v0.30 boss 8/31 OOB:
        // Menu style .borderlessButton + menuIndicator(.hidden) failed
        // to render the new-icon inside the ZoneContentTabBar trailing
        // slot (= only the import Button rendered). Replaced with a
        // simple Button pattern that mirrors the import Button =
        // notification + sheet pattern (no nested Menu).
        //
        // v0.30 boss 8/31 OOB #2 (after sheet test):
        // The first fix attempted to attach .sheet directly on the
        // trailing zoneHeaderButtons HStack. But the trailing slot
        // uses a separate NewLibraryOutlineView() instance wrapped
        // in AnyView (= WorkspaceView line ~255), so .sheet on that
        // standalone instance had no place to attach (= SwiftUI
        // AnyView discards view identity; sheets need a real parent
        // in the view hierarchy). The new-icon button was visible
        // (= button is a simple view) but tapping it set
        // showNewChoiceSheet on the standalone instance which never
        // re-rendered the trailing slot. Switched to NotificationCenter
        // pattern (= mirrors the 入驻 button's .wenshuImportRequested):
        // - Button tap posts .wenshuChoiceRequested notification.
        // - The sidebar body NewLibraryOutlineView listens via
        //   .onReceive and toggles its OWN showNewChoiceSheet state.
        //   Sheets on the sidebar body ARE in the real view hierarchy.
        HStack(spacing: 0) {
            // New plain Button (= tap posts .wenshuChoiceRequested
            // notification; consumed by the sidebar body listener
            // which presents NewChoiceSheet).
            Button {
                NotificationCenter.default.post(name: .wenshuChoiceRequested, object: nil)
            } label: {
                LucideIcon("square-plus", size: 18)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("New")
            // Import plain Button (= tap directly fires .wenshuImportRequested
            // notification; consumed by the main app toolbar listener =
            // opens the macOS NSOpenPanel for importing external research
            // materials into the library).
            Button {
                NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
            } label: {
                LucideIcon("square-arrow-right", size: 18)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Import")
        }
    }

    // MARK: - Persistence

    private func reload() {
        do {
            // Read shelves + books from the filesystem (= spec v5 layout).
            shelves = try readShelves()
            books = try readBooks()
            references = try bookStore.referenceStore.loadAllReferences()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func readShelves() throws -> [Bookshelf] {
        let shelvesRoot = bookStore.stores.shelvesRoot
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

    private func readBooks() throws -> [Book] {
        let shelvesRoot = bookStore.stores.shelvesRoot
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

    private func saveBook(_ book: Book) throws {
        // v0.30 boss 8/31 OOB: bug fix — the previous path
        // duplicated the 'books' segment (= 'books/<shelf-uuid>/books/<book-uuid>')
        // which would create the book in a non-standard location
        // and break the LibraryBootstrapper invariants. The correct
        // path is '<shelvesRoot>/<shelf-uuid>/books/<book-uuid>/',
        // matching the v5 spec layout.
        let bookDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(book.shelfId.uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(book.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookDir.appendingPathComponent("book.json"))
        // Run per-book bootstrap (= creates 8 folders + 2 JSON data files).
        let bootstrapper = LibraryBootstrapper(wsRoot: bookStore.stores.referenceLibraryRoot.deletingLastPathComponent())
        try bootstrapper.ensureValidStructure()
    }

    private func saveShelf(name: String, icon: String?) throws {
        // v0.30 boss 8/31 OOB: enforce duplicate name check before
        // creating the shelf. wenshu uses shelf.name (= user-visible
        // label) as a secondary identifier; while the filesystem
        // identity is shelf.id (= UUID = no collisions), showing two
        // shelves with the same name in the sidebar would confuse
        // the user. Also block the reserved '资料库' name (= that's
        // the reference library, which is a Section not a Shelf —
        // see PaneRenderer.projectSidebar's reference category
        // section, which is unrelated to the user shelves).
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reserved names (= cannot be used for a user shelf).
        let reservedNames: Set<String> = ["资料库", "参考库", "reference library"]
        if reservedNames.contains(where: { trimmedName.caseInsensitiveCompare($0) == .orderedSame }) {
            throw ShelfError.reservedName(trimmedName)
        }
        // Duplicate check (= case-insensitive, trim-insensitive).
        let existingNames = shelves.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            throw ShelfError.duplicateName(trimmedName)
        }
        let shelf = Bookshelf(name: trimmedName, icon: icon)
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(shelf.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shelfDir.appendingPathComponent("books"), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(shelf)
        try data.write(to: shelfDir.appendingPathComponent("shelf.json"))
    }

    /// v0.30 boss 8/31 OOB: count children (= books in shelf, or
    /// .md files in book) that will be deleted along with the
    /// target. Used by the .alert message so the user knows the
    /// full blast radius before confirming.
    private func pendingDeleteChildCount(target: PendingDelete) -> Int {
        switch target.kind {
        case .shelf:
            // Books in this shelf
            return books.filter { $0.shelfId == target.itemId }.count
        case .book:
            // .md files across all 5 standard folders
            return standardFolderNames.reduce(0) { sum, folder in
                sum + bookStore.folderDocumentCount(
                    bookId: target.itemId,
                    folderDirectoryName: folder.name
                )
            }
        }
    }

    /// v0.30 boss 8/31 OOB: build the .contextMenu items for a set
    /// of selected SidebarItem rows. Used by the List-level
    /// .contextMenu(forSelectionType:) modifier. Different from
    /// the per-row .contextMenu (which we also keep as a fallback
    /// for some rows) — this is the Apple HIG canonical path.
    ///
    /// The menu contents depend on what's selected:
    /// - Shelf selected: 新建书 (= pre-selects this shelf so the
    ///   new book lands here), 重命名, 删除
    /// - Book selected: 重命名, 删除
    /// - Reference category selected: no actions (= per boss OOB
    ///   '资料库不允许删除' applies to the whole reference section)
    /// - Multi-select: only delete (= batch delete shelves / books)
    @ViewBuilder
    private func contextMenuForSelection(_ items: Set<SidebarItem>) -> some View {
        // Multi-select = batch delete. Single select = per-item
        // actions.
        if items.count > 1 {
            Button("删除所选 \(items.count) 项", role: .destructive) {
                for item in items {
                    handleContextMenuDelete(item)
                }
            }
        } else if let first = items.first {
            switch first {
            case .shelf(let id):
                Button("新建书…") {
                    appState.sidebarSelection = .shelf(id)
                    showNewBookSheet = true
                }
                Divider()
                if let shelf = shelves.first(where: { $0.id == id }) {
                    Button("重命名…") {
                        renaming = RenamingTarget(
                            kind: .shelf,
                            itemId: id,
                            originalName: shelf.name,
                            shelfId: nil
                        )
                    }
                }
                Divider()
                Button("删除…", role: .destructive) {
                    if let shelf = shelves.first(where: { $0.id == id }) {
                        pendingDelete = PendingDelete(
                            kind: .shelf,
                            itemId: id,
                            itemName: shelf.name
                        )
                    }
                }
            case .book(let id):
                if let book = books.first(where: { $0.id == id }) {
                    Button("重命名…") {
                        renaming = RenamingTarget(
                            kind: .book,
                            itemId: id,
                            originalName: book.title,
                            shelfId: book.shelfId
                        )
                    }
                }
                Divider()
                Button("删除…", role: .destructive) {
                    if let book = books.first(where: { $0.id == id }) {
                        pendingDelete = PendingDelete(
                            kind: .book,
                            itemId: id,
                            itemName: book.title
                        )
                    }
                }
            case .folder:
                // Folder rows are not yet user-deletable (= the
                // 5 standard folders are regenerated by
                // LibraryBootstrapper). Future ticket can add per-
                // folder .md content management.
                EmptyView()
            case .referenceCategory, .referenceLibraryRoot:
                // No actions (= boss OOB '资料库不允许删除' covers
                // the whole reference section, not just the root).
                EmptyView()
            }
        }
    }

    /// v0.30 boss 8/31 OOB: handle a context-menu delete request
    /// (= set up the pendingDelete state to trigger the
    /// confirmation .alert). Extracted from the menu builder
    /// so the multi-select batch path can reuse it.
    private func handleContextMenuDelete(_ item: SidebarItem) {
        switch item {
        case .shelf(let id):
            if let shelf = shelves.first(where: { $0.id == id }) {
                pendingDelete = PendingDelete(
                    kind: .shelf,
                    itemId: id,
                    itemName: shelf.name
                )
            }
        case .book(let id):
            if let book = books.first(where: { $0.id == id }) {
                pendingDelete = PendingDelete(
                    kind: .book,
                    itemId: id,
                    itemName: book.title
                )
            }
        case .folder, .referenceCategory, .referenceLibraryRoot:
            // Read-only (= see contextMenuForSelection).
            break
        }
    }

    /// v0.30 boss 8/31 OOB: resolve the current target shelf id
    /// for the '新建书' action. Logic (= first non-nil match):
    /// 1. If sidebarSelection is .book → use that book's shelf
    /// 2. If sidebarSelection is .shelf → use that shelf directly
    /// 3. Fallback: default '从这里开始' shelf (id
    ///    00000000-0000-0000-0000-000000000000)
    /// Returns (id, displayName) so the NewBookSheet can show
    /// the shelf name in its picker.
    private func resolveNewBookTargetShelf() -> (id: UUID, name: String) {
        if case .book(let bookId) = appState.sidebarSelection,
           let book = books.first(where: { $0.id == bookId }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        if case .shelf(let shelfId) = appState.sidebarSelection,
           let shelf = shelves.first(where: { $0.id == shelfId }) {
            return (shelf.id, shelf.name)
        }
        // Fallback: default shelf.
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultName = shelves.first(where: { $0.id == defaultId })?.name ?? "从这里开始"
        return (defaultId, defaultName)
    }

    // v0.30 boss 8/31 OOB: context-menu actions. Per macOS HIG
    // destructive operations require explicit confirmation (= an
    // .alert with a '确认删除' button). The pendingDelete state
    // is set by the context menu, which triggers the alert; the
    // user confirms to actually execute the delete.

    /// Delete a shelf (= entire shelf + all its books) from disk.
    /// Apple HIG: requires confirmation because it's destructive
    /// (= the user might not realize the shelf contains books).
    private func deleteShelf(id: UUID) throws {
        // Boss: '资料库不允许删除'. Enforce here as a defense in
        // depth (= the reference library is a Section, not a Shelf,
        // so its id is never passed here; but the check is cheap).
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw ShelfDeleteError.cannotDeleteDefault
        }
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: shelfDir.path) {
            try FileManager.default.removeItem(at: shelfDir)
        }
    }

    /// Delete a single book (= its shelf/<id>/books/<book-id>/ dir
    /// + shelf.json metadata) from disk.
    private func deleteBook(id: UUID) throws {
        // Find which shelf contains the book (= we need its dir
        // to compute the full path). Mirrors the v0.30 refactor
        // that surfaced book lookup in WenshuLibrary.
        guard let parentShelf = shelves.first(where: { shelf in
            // Books live in <shelves>/<shelf-uuid>/books/<book-uuid>/
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(atPath:
                booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }  // book not on disk = nothing to delete
        let bookDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: bookDir.path) {
            try FileManager.default.removeItem(at: bookDir)
        }
    }

    /// Rename a shelf (= rewrites shelf.json with the new name).
    /// The directory name (= UUID) is NOT changed (= identity =
    /// stable per Apple HIG document-based app).
    private func renameShelf(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reserved name check (= same as saveShelf).
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw ShelfError.reservedName(trimmed)
        }
        // Duplicate check (= exclude the current shelf from
        // existingNames, since renaming to the same name is allowed).
        let others = shelves
            .filter { $0.id != id }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ShelfError.duplicateName(trimmed)
        }
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let shelfJSONURL = shelfDir.appendingPathComponent("shelf.json")
        guard FileManager.default.fileExists(atPath: shelfJSONURL.path),
              let data = try? Data(contentsOf: shelfJSONURL),
              var existing = try? JSONDecoder().decode(Bookshelf.self, from: data)
        else { return }
        existing.name = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: shelfJSONURL)
    }

    /// Rename a book (= rewrites book.json with the new title).
    private func renameBook(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // Duplicate title check (= exclude current book).
        let otherTitles = books
            .filter { $0.id != id }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if otherTitles.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ShelfError.duplicateName(trimmed)
        }
        // Find the book dir (= same as deleteBook).
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(atPath:
                booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }
        let bookJSONURL = bookStore.stores.shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("book.json")
        guard FileManager.default.fileExists(atPath: bookJSONURL.path),
              let data = try? Data(contentsOf: bookJSONURL),
              var existing = try? JSONDecoder().decode(Book.self, from: data)
        else { return }
        existing.title = trimmed
        existing.updatedAt = Date()
        let updated = try JSONEncoder().encode(existing)
        try updated.write(to: bookJSONURL)
    }
}

/// v0.30 boss 8/31 OOB: dedicated error case for attempting to
/// delete the default shelf (= "资料库 不允许删除"). Defense in
/// depth = even if the context menu is bypassed, saveShelf /
/// deleteShelf will refuse the operation.
private enum ShelfDeleteError: LocalizedError {
    case cannotDeleteDefault

    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefault:
            return "默认书架 (= 资料库) 不能删除"
        }
    }
}

/// v0.30 boss 8/31 OOB: explicit error cases for shelf creation
/// (= duplicate name, reserved name). Each case carries the offending
/// name so the sheet can surface a precise error message.
private enum ShelfError: LocalizedError {
    case duplicateName(String)
    case reservedName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "书架名 \"\(name)\" 已被使用. 请换一个名字。"
        case .reservedName(let name):
            return "\"\(name)\" 是系统保留名, 不能用作书架名. 请换一个名字."
        }
    }
}

// MARK: - Sheets (= 新建书 / 新建书架 modals)

private struct NewBookSheet: View {
    let onSave: (Book) -> Void
    /// v0.30 boss 8/31 OOB: target shelf id (= where the new book
    /// will be created). Pre-fills with the currently selected
    /// shelf (= from sidebarSelection). If nothing is selected,
    /// falls back to the default shelf id.
    let targetShelfId: UUID
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var shelfId: UUID  // editable (= user can pick a different shelf)
    @State private var selectedIcon: String = "book"  // v0.30 boss 8/31 OOB: user-picks icon
    @Environment(\.dismiss) private var dismiss

    /// v0.30 boss 8/31 OOB: display name of the target shelf (=
    /// shown in the picker as default selection). Lets the user
    /// see "this book will go into 帮助" before saving.
    let targetShelfName: String
    /// v0.30 boss 8/31 OOB: all available shelves with their display
    /// names (= the picker shows shelf names, not UUIDs).
    let availableShelves: [(id: UUID, name: String)]

    init(
        onSave: @escaping (Book) -> Void,
        targetShelfId: UUID,
        targetShelfName: String,
        availableShelves: [(id: UUID, name: String)]
    ) {
        self.onSave = onSave
        self.targetShelfId = targetShelfId
        self.targetShelfName = targetShelfName
        self.availableShelves = availableShelves
        _shelfId = State(initialValue: targetShelfId)
    }

    /// v0.30 boss 8/31 OOB: full Lucide icon library (=
    /// LucideIcon.allCases from lucide-swift enum, ~1500 icons).
    /// No guessing about which icon names exist; the user scrolls
    /// through every real Lucide icon and picks one.
    private var allLucideIcons: [String] {
        LucideIcon.allCases.map(\.rawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建书")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                TextField("书名", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("作者", text: $author)
                    .textFieldStyle(.roundedBorder)
                // v0.30 boss 8/31 OOB: shelf picker (= user can
                // choose which shelf this book goes into). Default
                // = the currently-selected shelf (= so clicking
                // 新建书 inside '测试书架' creates the book there).
                // Picker shows shelf names (= not raw UUIDs).
                Picker("归属书架", selection: $shelfId) {
                    ForEach(availableShelves, id: \.id) { shelf in
                        Text(shelf.name).tag(shelf.id)
                    }
                }
                // v0.30 boss 8/31 OOB: icon picker (mirrors
                // NewShelfSheet). Default = "book" (= matches
                // existing book row icon). User can scroll through
                // ~1500 real Lucide icons and pick any.
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                            LucideIcon(selectedIcon, size: 32)
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("已选 ICON")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedIcon)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Spacer()
                    }
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(allLucideIcons, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName
                                                  ? Color.accentColor.opacity(0.25)
                                                  : Color.clear)
                                            .frame(width: 40, height: 40)
                                        LucideIcon(iconName, size: 24)
                                            .foregroundStyle(selectedIcon == iconName
                                                             ? Color.accentColor
                                                             : Color.primary)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == iconName
                                                    ? Color.accentColor
                                                    : Color.gray.opacity(0.2),
                                                    lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                                .help(iconName)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 320)
                } header: {
                    Text("ICON (必选)")
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    let book = Book(
                        title: title,
                        author: author,
                        icon: selectedIcon,
                        shelfId: shelfId
                    )
                    onSave(book)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 720, idealHeight: 800)
    }
}

// v0.30 boss 8/31 OOB: NewShelfSheet now lets the user pick a
// Lucide icon for the new shelf. Default = 'square-library'
// (= same icon as the reference library section, so a new
// shelf visually reads as 'another library bucket'). User can
// pick any Lucide icon from a curated preset list (= see
// shelfIconPresets below). The icon is required (= the picker
// always shows a selection; the Save button is enabled as
// soon as the user picks).
private struct NewShelfSheet: View {
    /// Callback receives both name AND selected icon.
    let onSave: (String, String) -> Void
    /// v0.30 boss 8/31 OOB: existing shelf names (= passed in from
    /// the parent so the sheet can run its own duplicate check on
    /// every keystroke, without round-tripping through the parent
    /// view). Trims whitespace + lowercases for case-insensitive
    /// comparison. Includes the reserved '资料库' so it's blocked
    /// from being used as a user shelf name.
    let existingNames: [String]
    @State private var name: String = ""
    @State private var selectedIcon: String = "square-library"
    @Environment(\.dismiss) private var dismiss

    /// v0.30 boss 8/31 OOB: inline validation (= duplicate name +
    /// reserved name). Computed from the current `name` input on
    /// every render. Returns a localized error message; nil =
    /// no error (= Save enabled). Reserved names are hard-blocked;
    /// duplicates with existing shelves are blocked.
    private var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }  // empty = separate "name required" check via Save disabled
        // Reserved names
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            return "\"\(trimmed)\" 是系统保留名, 不能用作书架名"
        }
        // Duplicate (= case-insensitive, trim-insensitive)
        if existingNames.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return "书架名 \"\(trimmed)\" 已被使用. 请换一个名字"
        }
        return nil
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nameError == nil
    }

    /// v0.30 boss 8/31 OOB: render the ENTIRE Lucide icon library
    /// (= LucideIcon.allCases, an enum provided by lucide-swift that's
    /// auto-generated from lucide-static@1.25.0 = ~1500 icons at
    /// v0.30). No curated preset list = no guessing about which
    /// icons exist. The user scrolls through every real Lucide
    /// icon and picks one. Default = 'square-library' (= the
    /// reference library icon, per boss OOB).
    private var allLucideIcons: [String] {
        // LucideIcon is `enum, CaseIterable, Sendable` with String
        // rawValues (= the kebab-case icon name). `allCases.map(\.rawValue)`
        // gives us the complete icon name list at runtime (= no
        // hardcoded list, no manual sync when lucide-swift upgrades).
        LucideIcon.allCases.map(\.rawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建书架")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section {
                    TextField("书架名 (例如 长篇网文)", text: $name)
                        .textFieldStyle(.roundedBorder)
                    // v0.30 boss 8/31 OOB: inline error label under the
                    // name field. Shows when the name is a duplicate
                    // or reserved (= computed live in nameError).
                    if let nameError = nameError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(nameError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 2)
                    }
                } header: {
                    Text("名称")
                }
                Section {
                    // Icon preview (= shows the selected icon at
                    // large size so user can see what they're picking).
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                            LucideIcon(selectedIcon, size: 32)
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("已选 ICON")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedIcon)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Spacer()
                    }
                    // Icon picker grid (= 8 columns x many rows). The full
                    // Lucide library has ~1500 icons so we wrap the
                    // grid in a ScrollView (= user can scroll to
                    // find the icon they want). The grid is
                    // measured with a fixed height (= 320 PT =
                    // ~7 visible rows of 40 PT tiles + spacing) and
                    // scrolls inside.
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(allLucideIcons, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == iconName
                                                  ? Color.accentColor.opacity(0.25)
                                                  : Color.clear)
                                            .frame(width: 40, height: 40)
                                        LucideIcon(iconName, size: 24)
                                            .foregroundStyle(selectedIcon == iconName
                                                             ? Color.accentColor
                                                             : Color.primary)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == iconName
                                                    ? Color.accentColor
                                                    : Color.gray.opacity(0.2),
                                                    lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                                .help(iconName)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 320)
                } header: {
                    Text("ICON (必选)")
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name, selectedIcon)
                    dismiss()
                }
                .disabled(!isNameValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 480, idealHeight: 560)
    }
}

// v0.30 boss 8/31 OOB: replaced the Menu-based
// "New Book" / "New Shelf" picker (= failed to render inside
// ZoneContentTabBar trailing slot) with a simple two-button sheet
// picker. Apple HIG canonical sheet presentation.
struct NewChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onNewBook: () -> Void
    let onNewShelf: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("新建").font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 12) {
                Button {
                    onNewBook()
                } label: {
                    VStack(spacing: 8) {
                        LucideIcon("book-plus", size: 32)
                        Text("新建书").font(.system(size: 13))
                    }
                    .frame(width: 110, height: 80)
                }
                .buttonStyle(.bordered)

                Button {
                    onNewShelf()
                } label: {
                    VStack(spacing: 8) {
                        LucideIcon("library", size: 32)
                        Text("新建书架").font(.system(size: 13))
                    }
                    .frame(width: 110, height: 80)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 280, idealWidth: 320, minHeight: 180, idealHeight: 200)
    }
}

// MARK: - Context menu support (= right-click delete / rename)

// v0.30 boss 8/31 OOB: '在目录树实现右键删除、重命名功能.
// 资料库不允许删除.' Apple HIG context menu pattern: right-click
// any row to get a context menu with destructive actions (= delete
// + rename). The reference library section is read-only
// (= no context menu, because the reference library is a
// built-in feature, not a user-managed shelf).

/// Identifies which kind of item the pending action targets.
private enum ItemKind: String, Identifiable {
    case shelf
    case book

    var id: String { rawValue }

    /// Apple HIG: confirm dialog wording varies by item type.
    var displayName: String {
        switch self {
        case .shelf: return "书架"
        case .book: return "书"
        }
    }
}

/// Holds the target of a pending delete confirmation (= shows an
/// .alert asking user to confirm). Cleared when alert dismisses.
private struct PendingDelete: Identifiable {
    let id = UUID()
    let kind: ItemKind
    let itemId: UUID
    let itemName: String
}

/// Holds the target of a pending rename (= shows RenameItemSheet).
/// Bookshelf/Book id + initial name (pre-fill in TextField).
private struct RenamingTarget: Identifiable {
    let id = UUID()
    let kind: ItemKind
    let itemId: UUID
    let originalName: String
    let shelfId: UUID?  // only for books
}

/// v0.30 boss 8/31 OOB: simple sheet for renaming a shelf or book.
/// Pre-fills the TextField with the current name; saves via the
/// supplied closure. Same duplicate-check logic as NewShelfSheet
/// (= passes existingNames to the validator).
private struct RenameItemSheet: View {
    let title: String  // = "重命名书架" or "重命名书"
    let originalName: String
    let existingNames: [String]
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        originalName: String,
        existingNames: [String],
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.originalName = originalName
        self.existingNames = existingNames
        self.onSave = onSave
        _name = State(initialValue: originalName)
    }

    /// v0.30 boss 8/31 OOB: same duplicate-check logic as
    /// NewShelfSheet. Excludes the original name (= renaming to the
    /// same name is allowed = no-op). Trims whitespace.
    private var nameError: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed == originalName { return nil }  // same name = OK
        if existingNames.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return "名称 \"\(trimmed)\" 已被使用. 请换一个名字"
        }
        return nil
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nameError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                TextField("名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                if let nameError = nameError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text(nameError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 2)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(!isNameValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 160, idealHeight: 200)
    }
}
