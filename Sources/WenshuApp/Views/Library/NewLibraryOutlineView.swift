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

    @State private var shelves: [Bookshelf] = []
    @State private var books: [Book] = []
    @State private var selectedBookId: UUID?
    @State private var selectedReferenceLayer: ReferenceLayer = .layerEntities
    @State private var references: [Reference] = []
    @State private var loadError: String?
    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false

    var body: some View {
        // v0.27 boss 8/27 OOB: rewrite the directory tree UI to follow
        // FCP Browser style (= macOS 10.x ~ 14.x Finder sidebar + FCP
        // project-sidebar style). Per Apple HIG (developer.apple.com/
        // design/human-interface-guidelines/components/layout-and-
        // organization/outline-views) + FCP Browser conventions:
        // - Compact row height (~24 PT vs SwiftUI .sidebar default ~28)
        // - Lucide chevron-right disclosure indicator (NOT NSOutlineView
        //   triangle, NOT caret)
        // - Left-aligned icon + title + right-aligned count badge
        // - Per-entity icon (= filmstrip for library / bookshelf, book
        //   for books, stack for ReferenceLibrary; matches FCP where
        //   each entity type has a distinct icon)
        // - Recursive tree rendered via custom FCPRowView + nested ForEach
        //   (= SwiftUI OutlineGroup requires selection binding that
        //   conflicts with the existing BookStore.selectedBookId
        //   architecture; manual nesting is cleaner)
        // - Plain .background without List chrome (= macOS HIG sidebar
        //   is a flat tree, not a List).
        VStack(spacing: 0) {
            ForEach(buildTreeNodes()) { node in
                FCPRowView(node: node, depth: 0)
            }
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
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
                                .font(.system(size: LayoutTokens.iconSize))
                                .imageScale(.large)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        } else {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: LayoutTokens.iconSize))
                                .imageScale(.large)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
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
                                .font(.system(size: LayoutTokens.iconSize))
                                .imageScale(.large)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                                .foregroundStyle(Color.secondary)
                        } else {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: LayoutTokens.iconSize))
                                .imageScale(.large)
                                .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
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
            case referenceLayer
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
                    icon: "filmstrip",
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
        // ReferenceLibrary (= library-public default shelf; layer
        // children = 2 user-facing layers per spec v5).
        let layerChildren = ReferenceLayer.allCases
            .filter { $0.isUserFacing }
            .map { layer in
                FCPTreeNode(
                    id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", layer.hashValue))") ?? UUID(),
                    label: layer.displayName,
                    icon: layer.icon,
                    count: nil,
                    children: [],
                    payloadKind: .referenceLayer
                )
            }
        // v0.27 boss 8/27 OOB icon for ReferenceLibrary root: square-library
        // (= Lucide icon: a square containing stacked horizontal lines
        // representing a library shelf; matches FCP Browser's
        // library-as-archive metaphor and Apple's library-app
        // vocabulary).
        root.append(FCPTreeNode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            label: "资料库",
            icon: "square-library",
            count: layerChildren.count,
            children: layerChildren,
            payloadKind: .referenceLayer
        ))
        return root
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
        let standardFolders: [(name: String, icon: String)] = [
            ("世界观",       "globe"),
            ("角色",         "user-round"),
            ("章节大纲",     "list-tree"),
            ("小说正文",     "book-text"),
            ("小说草稿",     "file-edit"),
            ("LLM 会话",     "message-square"),
            ("伏笔",         "git-fork"),
            ("占位符",       "square-dashed"),
        ]
        return standardFolders.map { (displayName, icon) in
            // Stable UUID per (book, folder-name) tuple (= deterministic;
            // = avoids row re-creation on every render).
            let hashInput = displayName + book.id.uuidString
            let hashHex = String(format: "%012x", abs(hashInput.hashValue & 0xFFFFFFFFFFF))
            return FCPTreeNode(
                id: UUID(uuidString: "00000000-0000-0000-\(hashHex)") ?? UUID(),
                label: displayName,
                icon: icon,
                count: nil,
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
        Section {
            DisclosureGroup {
                ForEach(ReferenceLayer.allCases.filter { $0.isUserFacing }, id: \.self) { layer in
                    layerRow(layer)
                }
            } label: {
                referenceLibraryHeader
            }
        }
    }

    @ViewBuilder
    private func shelfHeader(_ shelf: Bookshelf) -> some View {
        HStack {
            Image(systemName: "books.vertical.fill")
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
                Image(systemName: "book.closed")
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
            Image(systemName: "books.vertical.circle.fill")
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
            Image(systemName: layer.icon)
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
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
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

    private let indentPT: CGFloat = 16
    private let iconSize: CGFloat = 13
    private let rowHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indent (= each level pushes 16 PT right per FCP).
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * indentPT)
                }
                // Disclosure chevron (= only if has children).
                if !node.children.isEmpty {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }
                // Per-entity icon.
                iconView(node.icon)
                    .frame(width: 14, height: 14)
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
        if let lucide = Lucide(name) {
            lucide
                .font(.system(size: iconSize))
                .imageScale(.large)
                .foregroundStyle(Color.secondary)
        } else {
            Image(systemName: "folder")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.secondary)
        }
    }

    // MARK: - Hierarchy text style (= boss 8/27 OOB: shelf > book > folder/doc)

    /// Font size per payload kind (= boss 8/27 'shelf text bigger than
    /// book text'; FCP Browser-style hierarchy).
    /// - shelf: 13 PT (= FCP Browser section header)
    /// - book: 12 PT (= FCP Browser item)
    /// - referenceLayer: 11 PT (= indented children)
    private func labelFont(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Font {
        switch kind {
        case .shelf: return .system(size: 13)
        case .book: return .system(size: 12)
        case .referenceLayer: return .system(size: 11)
        }
    }

    /// Font weight per payload kind (= shelf semibold = "section
    /// header" emphasis; book + referenceLayer regular).
    private func labelWeight(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Font.Weight {
        switch kind {
        case .shelf: return .semibold
        case .book, .referenceLayer: return .regular
        }
    }

    /// Foreground color per payload kind (= shelf primary = section
    /// header; book primary; folder/doc secondary = visually
    /// de-emphasized child rows).
    private func labelForeground(for kind: NewLibraryOutlineView.FCPTreeNode.PayloadKind) -> Color {
        switch kind {
        case .shelf, .book: return .primary
        case .referenceLayer: return .secondary
        }
    }
}
