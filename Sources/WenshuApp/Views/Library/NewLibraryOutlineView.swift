// NewLibraryOutlineView.swift · Wenshu (文枢) · v0.27 wiring
//
// Replaces LibraryOutlineView in the projectSidebar zone. Renders:
// - User-named Bookshelves (= from BookStore.shelves)
//   └ books/<uuid>/ entries (Book objects)
// - ReferenceLibrary (= the library's default shelf per boss 8/26 OOB;
//   user CANNOT delete or rename; appears at library root)
//
// v0.27 MVP integration: this view lives in the projectSidebar zone
// (replacing the v0.25.x WenshuLibrary-backed LibraryOutlineView).
// Boss 8/26 Q1 = directory tree navigation per boss spec.

import SwiftUI
import Lucide

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
    @State private var selectedBookId: UUID?
    @State private var selectedReferenceLayer: ReferenceLayer = .layerEntities
    @State private var references: [Reference] = []
    @State private var loadError: String?
    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false

    var body: some View {
        // v0.27 boss 8/27 OOB: 目录树整体居左的边距，可以再小一些，让标
        // 题的 ICON 与顶部 Tab 的 ICON 对齐 (= shrink left padding +
        // indent so the shelf/book ICON aligns with the zone tab bar's
        // tab icons). 那个折叠展开的小箭头，不计入对齐计算，就正常往
        // 前挤就好 (= chevron is treated as an inline element, NOT as
        // part of the indent column; the indent starts AT the icon).
        VStack(spacing: 0) {
            ForEach(buildTreeNodes()) { node in
                FCPRowView(node: node, depth: 0)
            }
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 0)
        .padding(.vertical, 4)
        .onAppear(perform: reload)
        .onChange(of: bookStore.selectedBookId) { _, newValue in
            selectedBookId = newValue
        }
        // v0.27 cross-component sync (boss 8/27 OOB): receive macOS-standard
        // menu commands (= toolbar '+' + File → 新建项目 / Cmd+N) from
        // NotificationCenter and trigger the matching sheet. Without this
        // listener, the toolbar '+' and File menu would be placeholders.
        // Per boss 8/27 standing rule: 'a new feature, by macOS standard,
        // should appear everywhere = synced'.
        .onReceive(NotificationCenter.default.publisher(for: .wenshuNewBookRequested)) { _ in
            showNewBookSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wenshuNewShelfRequested)) { _ in
            showNewShelfSheet = true
        }
        // NOTE: Toolbar 新建按钮 = boss 8/27 OOB 红框的那个 (= 复用 v0.25.x
        // 现有的 toolbar '+' 按钮). 不要在这里重复加 menu, 避免红框 +
        // 我们的 menu 双入口.
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
    }

    // MARK: - Zone header buttons (= boss 8/27 OOB #3: 新建 + 入驻
    // rendered in the projectSidebar zone header via ZoneContentView's
    // trailingButton parameter, NOT in a custom sidebarTopBar. Per
    // boss 8/27 '参考编辑器区的展开' = use the same icon-button style
    // as the editor expand button (= ticket 029c-trailing-button:
    // Color.clear 28x28 hot area + Lucide icon overlay + .secondary
    // foreground + contentShape Rectangle for full hit area).
    // The two buttons are stacked in a trailingButton HStack (= the
    // trailingButton parameter is one AnyView; HStack wraps both).

    /// 2 icon buttons rendered in the projectSidebar zone header
    /// trailing area (= rendered via ZoneContentView's trailingButton
    /// parameter at app.swift:2155). Per boss 8/27 OOB: 新建 Menu +
    /// 导入 plain Button. Both use the editor-expand + chat-archive
    /// icon-button pattern (= Color.clear 28x28 hot area + Lucide
    /// icon overlay + .secondary foreground + .contentShape Rectangle
    /// + .buttonStyle(IconButtonStyle()) for empty pass-through; matches
    /// macOS zone-header icon style per Apple HIG zone-tab-bar pattern
    /// AND the wenshu IconButtonStyle convention used by ChatZoneTabBar
    /// + the editor expand button).
    @ViewBuilder
    var zoneHeaderButtons: some View {
        // v0.27 boss 8/27 OOB correction: HStack(spacing: 8) 太远
        // (= boss '现在是 4 吗，那就改成 0。改成 8 更远了'). Use
        // HStack(spacing: 0) = 紧贴 hot area (= 28x28 each; the visual
        // gap is the 10 PT (= 28-18) difference between hot area and
        // 18 PT icon).
        HStack(spacing: 0) {
            // 新建 Menu (= tap → menu with 新建书 / 新建书架).
            Menu {
                Button("新建书") {
                    showNewBookSheet = true
                }
                Button("新建书架") {
                    showNewShelfSheet = true
                }
            } label: {
                Color.clear
                    .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                    .overlay(alignment: .center) {
                        if let lucide = Lucide("square-plus") {
                            lucide
                                .aspectRatio(contentMode: .fit)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        } else {
                            // v0.27 boss 8/27 OOB: SF Symbol fallback → Lucide canonical.
                            LucideIconSystemFallback("square.and.pencil", size: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconButtonStyle())
            // 导入 plain Button (= tap directly fires .wenshuImportRequested).
            Button {
                NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
            } label: {
                Color.clear
                    .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                    .overlay(alignment: .center) {
                        if let lucide = Lucide("square-arrow-right") {
                            lucide
                                .aspectRatio(contentMode: .fit)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        } else {
                            // v0.27 boss 8/27 OOB: SF Symbol fallback → Lucide canonical.
                            LucideIconSystemFallback("arrow.down.doc", size: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconButtonStyle())
        }
    }

    // MARK: - Tree model (= boss 8/27 OOB: FCP Browser style rewrite)

    /// Recursive tree node (= FCP Browser projectSidebar model).
    /// Each node = one row in the tree (= shelf / book / Reference
    /// layer). Children rendered recursively via FCPRowView's ForEach.
    /// Identity-based equality (= id-based Hashable; rename-friendly).
    struct FCPTreeNode: Identifiable, Hashable {
        let id: UUID
        let label: String
        let icon: String           // Lucide icon name (with SF fallback)
        let count: Int?            // optional count badge (right-aligned)
        let children: [FCPTreeNode]
        let payloadKind: PayloadKind

        enum PayloadKind: Hashable {
            case shelf
            case book
            case referenceLibrary   // v0.27 boss 8/27 OOB: 资料库本身也是一个特别的书架
            case referenceLayer     // raw / entities / abstracts / indexes (= sub-node of referenceLibrary)
            case referenceCategory  // v0.29 boss 2026-08-30 OOB: 分类文件夹 (= 历史/科学/...) = sub-node of referenceLibrary
            case reference          // v0.29: 单个实体 (= leaf under referenceCategory)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: FCPTreeNode, rhs: FCPTreeNode) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Build the tree from current store state (= shelves + books +
    /// folder contents + reference layer counts). Per boss 8/26 OOB
    /// '项目点开 → 书下面向用户的文件夹' = each book has children
    /// representing its 8 standard folders (世界 / 角色 / 章节大纲 /
    /// 小说正文 / 小说草稿 / LLM 会话 / 伏笔 / 占位符); each folder
    /// has children representing the .md docs inside (= recursive
    /// tree = FCP Browser project view).
    private func buildTreeNodes() -> [FCPTreeNode] {
        var root: [FCPTreeNode] = []
        // Shelves (= user-named; book children = booksInShelf(shelf)).
        for shelf in shelves {
            let books = booksInShelf(shelf)
            let bookNodes = books.map { book in
                FCPTreeNode(
                    id: book.id,
                    label: book.title,
                    // v0.27 boss 8/27 OOB: Lucide has no 'filmstrip' (= FCP Browser
                    // project icon); closest match = 'notebook'.
                    icon: "notebook",
                    count: nil,
                    children: standardFolderNodes(for: book),
                    payloadKind: .book
                )
            }
            // v0.27 boss 8/27 OOB icon for the default '从这里开始' shelf:
            // square-dashed-mouse-pointer (= 'user starts here' visual
            // metaphor; per Lucide icon catalog this is a click-target
            // inside a dashed frame, matching the 'where the user
            // begins' onboarding affordance).
            let isDefaultShelf = (shelf.id.uuidString == "00000000-0000-0000-0000-000000000000")
            root.append(FCPTreeNode(
                id: shelf.id,
                label: shelf.name,
                icon: isDefaultShelf ? "square-dashed-mouse-pointer" : "books.vertical.fill",
                count: books.count,
                children: bookNodes,
                payloadKind: .shelf
            ))
        }
        // ReferenceLibrary (= library-public default shelf). v0.29
                // boss 2026-08-30 OOB: sidebar 显示分类文件夹 (历史/科学/...),
                // 不直接显示实体. categories = 仅含 ≥1 实体的 (增量显示).
                let usedCategories = computeUsedCategories()
                                // v0.29: load snapshot once (= used by both filter log + render
                                // below; avoids 2nd loadAllReferences() potentially returning
                                // a different list). categoryChildren is built from this
                                // same snapshot to ensure render matches the logged filter.
                                let allRefsDirect = (try? bookStore.referenceStore.loadAllReferences()) ?? []
                                let categoryChildren = usedCategories.map { cat -> FCPTreeNode in
                                    // Children = entity refs in this category (per boss OOB).
                                    // Uses the same snapshot (= allRefsDirect) for both the
                                    // category node and its children to keep the render
                                    // consistent with computeUsedCategories above.
                                    let entitiesInCategory = allRefsDirect
                                        .filter { $0.layer == .layerEntities && $0.category == cat }
                                    let entityChildren = entitiesInCategory.map { ref -> FCPTreeNode in
                                        // v0.30: prefix entity name with type badge
                                        // (= e.g. '[人] 李白' for character entities)
                                        // for visual at-a-glance distinction. Boss OOB
                                        // '为什么有联名实体, 比如李白与杜甫. 为什么这个是
                                        // 体会在一起' = solved by type + category
                                        // decomposition (= each entity is ONE type +
                                        // ONE category, never merged).
                                        let typeBadge = "[\(ref.entityType.shortName)]"
                                        let displayLabel = "\(typeBadge) \(ref.title)"
                                        return FCPTreeNode(
                                            id: ref.id,
                                            label: displayLabel,
                                            icon: ref.entityType.icon,
                                            count: nil,
                                            children: [],
                                            payloadKind: .reference  // = entity leaf (= preview/edit on click)
                                        )
                                    }
                                    return FCPTreeNode(
                                        id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", cat.directoryName.hashValue))") ?? UUID(),
                                        label: cat.displayName,
                                        icon: cat.icon,
                                        count: entitiesInCategory.count,
                                        children: entityChildren,
                                        payloadKind: .referenceCategory  // v0.29 new payload kind
                                    )
                                }
                // v0.27 boss 8/27 OOB icon for ReferenceLibrary root: square-library
                // (= Lucide icon: a square containing stacked horizontal lines
                // representing a library shelf; matches FCP Browser's
                // library-as-archive metaphor and Apple's library-app
                // vocabulary). payloadKind = .referenceLibrary (= treats
                // 资料库 as a 'special shelf' per boss 8/27; = same typography
                // as user-named shelves via the .referenceLibrary branch in
                // labelFont / labelWeight / labelForeground).
                root.append(FCPTreeNode(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    label: "资料库",
                    icon: "square-library",
                    count: categoryChildren.count,
                    children: categoryChildren,
                    payloadKind: .referenceLibrary
                ))
                return root
            }

            /// v0.29 boss OOB: 计算使用中的 categories (= 至少含 1 实体).
                /// 0 实体的 categories 不显示 (= 增量规则: '分类文件夹随着内容
                /// 逐渐增加, 而不是一下子铺满'). 按 CLC 字母顺序排序 (= A→Z).
                private func computeUsedCategories() -> [EntityCategory] {
                        let allRefs: [Reference]
                        do {
                            allRefs = try bookStore.referenceStore.loadAllReferences()
                        } catch {
                            return []
                        }
                        let entityRefs = allRefs.filter { $0.layer == .layerEntities }
                        let used = Set(entityRefs.compactMap { $0.category })
                        return EntityCategory.allCases.filter { used.contains($0) }
                    }

    /// Build the 8 standard folder children for a book node.
    /// Per spec v5 ticket 001 + ticket 026: every book has these 8
    /// standard folders (= user-facing per boss 8/26 OOB '面向用户的
    /// 文件夹'). Folder names are Chinese UI strings (= UI 全中文
    /// carve-out per boss 8/25). Per boss 8/27 OOB: doc files (= .md
    /// inside each folder) are NOT shown in the sidebar tree (= sidebar
    /// ends at folder; doc content is rendered as cards in the
    /// projectPreview zone per the 无边记-style layout decided 8/27).
    private func standardFolderNodes(for book: Book) -> [FCPTreeNode] {
        // v0.27 boss 8/27 OOB: Lucide does NOT have 'filmstrip' (=
        // FCP Browser project icon; wenshu needs a book-equivalent
        // Lucide icon); closest Lucide match = 'notebook' (= the
        // canonical Lucide 'book' icon, a notebook-shaped outline;
        // semantically closer to a novel project's container than
        // 'book' which is more of a closed-book visual metaphor).
        // For 小说草稿: Lucide has no 'file-edit'; closest match =
        // 'file-pen-line' (= a file with a pen overlay; semantically
        // = 'draft being edited').
        //
        // v0.29 boss 2026-08-30 OOB '库管理里, 伏笔占位, 这两个文件夹里
        // 的内容, 是计划放在工具区里展示的, 所有库目录树里隐藏. 还有
        // llm 记录, 是聊天加载用的, 文件夹也隐藏': removed 3 folders
        // from sidebar (= they live in tools/chat zone instead):
        // - 伏笔 (git-fork) → tools pane (= v0.30 will move)
        // - 占位符 (square-dashed) → tools pane (= v0.30 will move)
        // - LLM 会话 (message-square) → chat zone auto-load (= never
        //   user-facing in sidebar)
        let standardFolders: [(name: String, icon: String, directoryName: String)] = [
            ("世界观",       "globe",            "world"),
            ("角色",         "user-round",       "characters"),
            ("章节大纲",     "list-tree",        "outlines"),
            ("小说正文",     "book-text",        "chapters"),
            ("小说草稿",     "file-pen-line",    "drafts"),
        ]
        return standardFolders.map { (displayName, icon, directoryName) in
            // Stable UUID per (book, folder-name) tuple (= deterministic;
            // = avoids row re-creation on every render).
            let hashInput = displayName + book.id.uuidString
            let hashHex = String(format: "%012x", abs(hashInput.hashValue & 0xFFFFFFFFFFF))
            // v0.30 boss OOB '为什么角色, 世界观, 后面没有显示数字':
            // count = number of .md files in the on-disk folder.
            // Forgiving: missing folder / permission error = 0 (= no
            // crash, just no badge).
            let docCount = bookStore.folderDocumentCount(
                bookId: book.id,
                folderDirectoryName: directoryName
            )
            return FCPTreeNode(
                id: UUID(uuidString: "00000000-0000-0000-\(hashHex)") ?? UUID(),
                label: displayName,
                icon: icon,
                count: docCount,
                children: [],     // (= folder is leaf-level in sidebar; docs render in projectPreview).
                payloadKind: .book
            )
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func shelfSection(_ shelf: Bookshelf) -> some View {
        Section {
            DisclosureGroup {
                ForEach(booksInShelf(shelf)) { book in
                    bookRow(book)
                }
                if booksInShelf(shelf).isEmpty {
                    Button {
                        showNewBookSheet = true
                    } label: {
                        Label("新建书", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                }
            } label: {
                shelfHeader(shelf)
            }
        }
    }

    @ViewBuilder
    private var referenceLibrarySection: some View {
        // v0.29 boss 2026-08-30 OOB: 资料库 sidebar 显示分类文件夹
        // (历史/科学/...), 不直接显示实体. 分类文件夹 = 增量显示
        // (只有含 ≥1 实体的分类才出现 = '分类文件夹随着内容逐渐
        // 增加, 而不是一下子铺满'). 实体 layer (.layerEntities) 现在是
        // categories 的容器; 原始文件 (.layerRaw) 隐藏 = hidden by isUserFacing.
        Section {
            entityLayerWithCategories
        } header: {
            referenceLibraryHeader
        }
    }

    @ViewBuilder
    private var entityLayerWithCategories: some View {
        // Always show .layerEntities as the only user-facing layer.
        // Its children = categories (= 仅含 ≥1 实体的 categories).
        ForEach(usedCategories(), id: \.self) { category in
            categoryRow(category)
        }
    }

    /// 计算当前活跃的 categories (= 至少含 1 实体). v0.29 增量规则:
    /// 0 实体的 categories 不显示.
    private func usedCategories() -> [EntityCategory] {
        let allRefs = (try? bookStore.referenceStore.loadAllReferences()) ?? []
        let entityRefs = allRefs.filter { $0.layer == .layerEntities }
        let usedCategories = Set(entityRefs.compactMap { $0.category })
        // Sort by CLC standard order (= A, B, C, ..., Z)
        return EntityCategory.allCases.filter { usedCategories.contains($0) }
    }

    @ViewBuilder
    private func categoryRow(_ category: EntityCategory) -> some View {
        HStack {
            LucideIconSystemFallback(category.icon, size: 18)
                .foregroundStyle(.secondary)
            Text(category.displayName)
                .font(.callout)
            Spacer()
            Text("\(entitiesCount(in: category))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // v0.30: bubble category selection up to WorkspaceView (= drives
            // EntityPreviewPane's category-scoped grid mode).
            selectedEntityCategory = category
            selectedEntity = nil  // (= clear detail view when switching category)
        }
    }

    /// 计算某 category 下的实体数量.
    private func entitiesCount(in category: EntityCategory) -> Int {
        let allRefs = (try? bookStore.referenceStore.loadAllReferences()) ?? []
        return allRefs.filter { $0.layer == .layerEntities && $0.category == category }.count
    }

    @ViewBuilder
    private func shelfHeader(_ shelf: Bookshelf) -> some View {
        HStack {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
            LucideIconSystemFallback("books.vertical.fill", size: 18)
                .foregroundStyle(.tint)
            Text(shelf.name)
                .font(.headline)
            Spacer()
            Text("\(booksInShelf(shelf).count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func bookRow(_ book: Book) -> some View {
        Button {
            selectedBookId = book.id
            bookStore.selectedBookId = book.id
        } label: {
            HStack {
                // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
                LucideIconSystemFallback("book.closed", size: 18)
                    .foregroundStyle(selectedBookId == book.id ? Color.accentColor : .secondary)
                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.callout)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var referenceLibraryHeader: some View {
        HStack {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
            LucideIconSystemFallback("books.vertical.circle.fill", size: 18)
                .foregroundStyle(.tint)
            Text("资料库")
                .font(.headline)
            Spacer()
            Text("\(references.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func layerRow(_ layer: ReferenceLayer) -> some View {
        HStack {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical via helper.
            LucideIconSystemFallback(layer.icon, size: 18)
                .foregroundStyle(.secondary)
            Text(layer.displayName)
                .font(.callout)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedReferenceLayer = layer
            reloadReferences()
        }
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: SF Symbol → Lucide canonical.
            LucideIconSystemFallback("exclamationmark.triangle", size: 36)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Data

    private func booksInShelf(_ shelf: Bookshelf) -> [Book] {
        books.filter { $0.shelfId == shelf.id }
    }

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

    private func reloadReferences() {
        do {
            references = try bookStore.referenceStore.loadReferences(layer: selectedReferenceLayer)
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
        let shelfDirs = try FileManager.default.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for shelfDir in shelfDirs {
            let booksDir = shelfDir.appendingPathComponent("books", isDirectory: true)
            guard FileManager.default.fileExists(atPath: booksDir.path) else { continue }
            let bookDirs = try FileManager.default.contentsOfDirectory(
                at: booksDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for bookDir in bookDirs {
                let isDir = (try? bookDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDir else { continue }
                let jsonURL = bookDir.appendingPathComponent("book.json")
                guard let data = try? Data(contentsOf: jsonURL),
                      let book = try? JSONDecoder().decode(Book.self, from: data) else { continue }
                result.append(book)
            }
        }
        return result
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

// MARK: - Sheets

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
                TextField("作者 (可选)", text: $author)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    let shelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                    let book = Book(title: title, author: author, shelfId: shelfId)
                    do {
                        try saveToFile(book)
                        onSave(book)
                    } catch {
                        print("Save failed: \(error)")
                    }
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 240, idealHeight: 280)
    }

    private func saveToFile(_ book: Book) throws {
        // Defer to caller (= NewLibraryOutlineView) for file persistence.
        // We pass the Book back so the caller can persist it correctly.
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
// MARK: - FCP Browser style row (= boss 8/27 OOB: rewrite tree UI)

/// One row in the FCP Browser-style projectSidebar tree.
/// Layout (= Apple HIG + FCP convention):
/// ```
///   ▼  [icon]  [label]                  [count]
///       └─ [icon]  [child label]                [count]
/// ```
/// - Disclosure triangle on the left (Lucide chevron-right rotated
///   when expanded)
/// - Per-entity icon (= FCP convention: filmstrip for library/book,
///   books for bookshelf, book-stack for ReferenceLibrary)
/// - Right-aligned count badge for parent nodes (child count)
/// - Manual recursion via nested ForEach (= SwiftUI OutlineGroup
///   requires a selection binding that conflicts with the existing
///   BookStore.selectedBookId; nesting is cleaner here).
private struct FCPRowView: View {
    let node: NewLibraryOutlineView.FCPTreeNode
    let depth: Int

    @Environment(BookStore.self) private var bookStore
    @State private var isExpanded: Bool = true

    // v0.27 boss 8/27 OOB: indentPT 8 → 4 (= tighter; boss 8/27
    // '整体目录树，再往左 8 PT' = shrink left padding + indent
    // additionally by ~8 PT from previous state). chevron remains
    // INLINE (= not part of the indent column).
    private let indentPT: CGFloat = 4
    // v0.27 boss 8/27 OOB: 目录树里的 ICON，全都都改成 18*18 (= icon
    // visual size 18 PT + 18 PT frame; matches wenshu's primary
    // toolbar iconSize and the projectSidebar zone tab bar icons for
    // visual consistency across the shell).
    private let iconSize: CGFloat = 18
    private let rowHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indent (= boss 8/27: chevron is NOT part of the indent;
                // = the indent pushes the chevron+icon+label group right
                // by N×8 PT). Chevron + icon + label all start at the
                // same indent column.
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * indentPT)
                }
                // Disclosure chevron (= inline; takes 18 PT regardless
                // of disclosure state = layout stability for adjacent
                // rows that mix expanded + collapsed subtrees).
                if !node.children.isEmpty {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        // v0.27 boss 8/27 OOB: replace SF Symbol chevron
                        // with LucideIconSystemFallback (= closest Lucide
                        // equivalent 'chevron-right' / 'chevron-down';
                        // helper handles the lookup chain).
                        LucideIconSystemFallback(isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 18, height: 18)
                }
                // Per-entity icon.
                iconView(node.icon)
                    .frame(width: 18, height: 18)
                // Label (= boss 8/27 OOB: shelf text bigger than book
                // text = FCP Browser hierarchy style; .semibold shelf
                // vs .regular book vs .secondary folder/doc).
                Text(node.label)
                    .font(labelFont(for: node.payloadKind))
                    .fontWeight(labelWeight(for: node.payloadKind))
                    .foregroundStyle(labelForeground(for: node.payloadKind))
                    .lineLimit(1)
                Spacer(minLength: 4)
                // Count badge (= right-aligned; only for parent nodes).
                if let count = node.count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: rowHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.payloadKind == .book {
                    bookStore.selectedBookId = node.id
                }
            }
            // Children (= recursive render when expanded).
            if isExpanded {
                ForEach(node.children) { child in
                    FCPRowView(node: child, depth: depth + 1)
                }
            }
        }
    }

    @ViewBuilder
    private func iconView(_ name: String) -> some View {
        // v0.27 boss 8/27 OOB: use the project-wide LucideIcon helper
        // (= Sources/WenshuApp/Views/LucideIcon.swift) for visual
        // size consistency across the shell (= .frame(width:height:)
        // without .aspectRatio / .font = lucide-swift canonical
        // pattern). Boss 8/27 '看起来还是有大有小，官方没有什么解决
        // 方案吗？' = Lucide deliberately does NOT normalize visual
        // sizes across icons (= each icon's native outline geometry is
        // preserved). The official answer = use .frame(width:height:)
        // (= what we already do) and accept the natural size
        // variation as a design feature.
        LucideIcon(name, size: iconSize)
    }

    // MARK: - Hierarchy text style (= boss 8/27 OOB: shelf > book > folder/doc)

    /// Font size per payload kind (= boss 8/27 'shelf > book > folder/doc';
    /// + boss 8/27 followup '资料库本身也是一个特别的书架，所以资料库
    /// 的字号样式没改，对齐，要跟书架一样' = referenceLibrary root
    /// should look identical to a user-named shelf since it's a
    /// 'special shelf' per boss's taxonomy = same font size + weight
    /// + foreground as .shelf).
    /// - shelf: 13 PT semibold primary (= FCP Browser section header)
    /// - referenceLibrary: 13 PT semibold primary (= boss 8/27 '跟书
    ///   架一样'; = treat the reference library as a special shelf)
    /// - book: 12 PT regular primary (= FCP Browser item)
    /// - referenceLayer: 12 PT regular primary (= aligned with book per
    ///   boss 8/27; was 11 PT secondary in prior commit)
    private func labelFont(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Font {
        switch kind {
        case .shelf, .referenceLibrary: return .system(size: 13)
        case .book, .referenceLayer, .referenceCategory, .reference: return .system(size: 12)
        }
    }

    /// Font weight per payload kind (= shelf semibold = "section
    /// header" emphasis; referenceLibrary now ALSO semibold per boss
    /// 8/27 '资料库本身也是一个特别的书架'; book + referenceLayer
    /// regular).
    private func labelWeight(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Font.Weight {
        switch kind {
        case .shelf, .referenceLibrary: return .semibold
        case .book, .referenceLayer, .referenceCategory, .reference: return .regular
        }
    }

    /// Foreground color per payload kind (= shelf + book primary;
    /// referenceLibrary + referenceLayer now ALSO primary per boss 8/27
    /// '资料库本身也是一个特别的书架' = visual alignment with the
    /// projectSidebar user-named shelf rows).
    private func labelForeground(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Color {
        switch kind {
        case .shelf, .referenceLibrary, .book, .referenceLayer, .referenceCategory, .reference: return .primary
        }
    }
}
