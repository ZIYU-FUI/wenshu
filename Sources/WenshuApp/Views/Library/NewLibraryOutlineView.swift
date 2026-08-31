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
enum SidebarItem: Hashable {
    case book(UUID)
    case referenceCategory(String)  // = EntityCategory.directoryName

    static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")
}

struct NewLibraryOutlineView: View {
    @Environment(BookStore.self) private var bookStore

    /// v0.30: parent passes binding (= WorkspaceView owns the state).
    /// When sidebar category is tapped, WorkspaceView's selectedEntityCategory
    /// updates → preview pane shows the category-scoped grid.
    /// Default-init available (= for non-workspace callers via `.constant(nil)`).
    @Binding var selectedEntityCategory: EntityCategory?
    @Binding var selectedEntity: Reference?

    /// v0.30: default initializer (= non-workspace callers = registered
    /// panes, zoneHeaderButtons, fallback render).
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

    /// v0.30: Apple std List selection. Mirrors both
    /// `bookStore.selectedBookId` (when a book is selected) and
    /// `selectedEntityCategory` (when a category is selected). Single
    /// selection per List (= Apple HIG).
    @State private var sidebarSelection: SidebarItem?

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
        List(selection: $sidebarSelection) {
            ForEach(shelves) { shelf in
                Section {
                    ForEach(booksInShelf(shelf)) { book in
                        bookRowWithFolders(book)
                    }
                } header: {
                    Label {
                        Text(shelf.name)
                    } icon: {
                        LucideIconSidebar(
                            shelf.id.uuidString == "00000000-0000-0000-0000-000000000000"
                                ? "square-dashed-mouse-pointer"
                                : "books.vertical.fill"
                        )
                        .foregroundStyle(.primary)
                    }
                }
            }
            // Reference library (= library's default shelf per boss 8/26
            // OOB; user CANNOT delete or rename). Treated as a single
            // Section per Apple HIG; categories expand via
            // DisclosureGroup (= 2-level hierarchy).
            Section {
                DisclosureGroup {
                    ForEach(usedCategories(), id: \.directoryName) { category in
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
        // v0.30 boss 8/31 OOB ('Sidebar 背景 不跟液态玻璃透明度调整 / 之前已经实现的,
        // 改目录树的时候动到了, 修复'):
        // Apple HIG .sidebar listStyle draws its own opaque background
        // (= macOS 26 Tahoe canonical sidebar material), which covers
        // the RegionContentBackground applied at ZonePerRegionChrome.
        // .scrollContentBackground(.hidden) makes the list itself
        // transparent so the parent's RegionContentBackground shows
        // through (= follows the liquid-glass opacity slider in Settings).
        .scrollContentBackground(.hidden)
        .onAppear(perform: reload)
        .onChange(of: sidebarSelection) { _, newValue in
            // v0.30: forward sidebar selection to bookStore.selectedBookId
            // (for books) and selectedEntityCategory binding (for
            // categories). Single onChange handler unifies both.
            switch newValue {
            case .book(let id):
                bookStore.selectedBookId = id
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
                sidebarSelection = .book(id)
            }
        }
        .onChange(of: selectedEntityCategory) { _, newValue in
            // Sync external category changes (= WorkspaceView → preview
            // pane state) into local List selection (= maintains
            // consistency between sidebar selection highlight and the
            // preview pane's category-scoped grid mode).
            if let cat = newValue {
                sidebarSelection = .referenceCategory(cat.directoryName)
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
            NewBookSheet(onSave: { book in
                do {
                    try saveBook(book)
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
            })
        }
        .sheet(isPresented: $showNewShelfSheet) {
            NewShelfSheet(onSave: { name in
                do {
                    try saveShelf(name: name)
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
            })
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
    }

    // MARK: - Row builders

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
                LucideIconSidebar("book")
                    .foregroundStyle(.primary)
            }
            .tag(SidebarItem.book(book.id))
        } else {
            DisclosureGroup {
                ForEach(folders, id: \.name) { folder in
                    Label {
                        Text(folder.displayName)
                    } icon: {
                        LucideIconSidebar(folder.icon)
                            .foregroundStyle(.primary)
                    }
                }
            } label: {
                Label {
                    Text(book.title)
                } icon: {
                    LucideIconSidebar("book")
                        .foregroundStyle(.primary)
                }
                .tag(SidebarItem.book(book.id))
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
        let bookDir = bookStore.stores.shelvesRoot
            .appendingPathComponent("books", isDirectory: true)
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

    private func saveShelf(name: String) throws {
        let shelf = Bookshelf(name: name)
        let shelfDir = bookStore.stores.shelvesRoot
            .appendingPathComponent(shelf.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shelfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: shelfDir.appendingPathComponent("books"), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(shelf)
        try data.write(to: shelfDir.appendingPathComponent("shelf.json"))
    }
}

// MARK: - Sheets (= 新建书 / 新建书架 modals)

private struct NewBookSheet: View {
    let onSave: (Book) -> Void
    @State private var title: String = ""
    @State private var author: String = ""
    @Environment(\.dismiss) private var dismiss

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
                        shelfId: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                    )
                    onSave(book)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 220, idealHeight: 260)
    }
}

private struct NewShelfSheet: View {
    let onSave: (String) -> Void
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

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
                TextField("书架名 (例如 长篇网文)", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 200, idealHeight: 240)
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
