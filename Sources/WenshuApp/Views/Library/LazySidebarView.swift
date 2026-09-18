// LazySidebarView.swift · Wenshu · v1.64
//
// Per boss 2026-09-18 'window drag crashes — fix the windows
// BUG first' + 'sidebar really has a problem — Apple API has
// other methods for hierarchical browsing, not necessarily
// outline tree': replace the NewLibraryOutlineView List(
// .sidebar) (= NSTableView under the hood = NSLayoutConstraint
// conflict on window resize per
// WenshuApp-2026-09-18-143621.ips) with a pure-SwiftUI
// LazyVStack of Button rows inside a ScrollView.
//
// Why this fixes the crash:
//   - List(.sidebar) on macOS 27 is rendered via NSTableView
//     (= SwiftUI List is a thin SwiftUI surface over AppKit's
//     NSTableView). When the NSWindow frame changes (= drag
//     resize), NSTableView's
//     _updateConstraintsAtColumn:row:rowView: rebuilds row
//     cell auto-layout. If any row modifier (= .badge,
//     .contextMenu, custom RowContent) introduces conflicting
//     constraints, CoreAutoLayout throws NSException from
//     -[NSLayoutConstraint setActive:] = app crash.
//   - LazyVStack is pure SwiftUI = no NSTableView = no
//     CoreAutoLayout conflict. SwiftUI uses its own layout
//     engine; SwiftUI's NSHostingView handles the resize
//     cache invalidation we already fixed in v1.63.
//
// Why LazyVStack (not OutlineGroup, not List(.plain)):
//   - OutlineGroup still renders as NSTableView (= same crash).
//   - List(.plain) ALSO renders as NSTableView on macOS.
//   - LazyVStack = pure SwiftUI view tree, no AppKit table.
//
// Visual: Apple's Mail / Notes / Finder sidebars use
// NSTableView (= can render thousands of rows efficiently).
// wenshu sidebar has at most a few shelves + a few books per
// shelf + 5 standard folders per book = < 100 rows total =
// LazyVStack performance is fine.
//
// Feature parity with NewLibraryOutlineView (= what we keep):
//   - shelves list (Section 1, with shelf DisclosureGroup)
//   - books per shelf (nested DisclosureGroup inside shelf)
//   - 5 standard folders per book (leaf rows inside book)
//   - reference library Section at the bottom
//   - .tag-based selection via a single @State variable that
//     mirrors appState.sidebarSelection
//   - sidebar bottom 'New' button via .safeAreaInset(edge: .bottom)
//
// Feature parity DELIBERATELY DROPPED (= simpler = no crash):
//   - .badge counts (= dropped in v1.61, not restored here)
//   - .contextMenu(forSelectionType:) (= drop; per-row
//     .contextMenu still works inside LazyVStack rows)
//   - list-level .contextMenu for empty area (= replaced with
//     a dedicated '+ New' bottom button which is more discoverable
//     anyway)

import SwiftUI

struct LazySidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(BookStore.self) private var bookStore

    @AppStorage("wenshu.sidebarState") private var persistedSidebarState: String = ""

    @State private var shelves: [Bookshelf] = []
    @State private var books: [Book] = []
    @State private var references: [Reference] = []
    @State private var loadError: String?

    @State private var shelfDisclosureStates: [UUID: Bool] = [:]
    @State private var bookDisclosureStates: [UUID: Bool] = [:]
    @State private var referenceLibraryDisclosureExpanded: Bool = false

    @State private var showNewBookSheet: Bool = false
    @State private var showNewShelfSheet: Bool = false
    @State private var showNewChoiceSheet: Bool = false
    @State private var renaming: LazyRenamingTarget?
    @State private var pendingDelete: LazyPendingDelete?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                sidebarHeader
                shelvesSection
                referenceLibrarySection
                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color.clear)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarBottomNewButton
        }
        .onAppear { onAppearLoad() }
        .onChange(of: appState.sidebarSelection) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: shelfDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: bookDisclosureStates) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: referenceLibraryDisclosureExpanded) { _, _ in
            persistedSidebarState = snapshotSidebarState().jsonString
        }
        .onChange(of: appState.newBookRequestCount) { _, _ in
            showNewBookSheet = true
        }
        .onChange(of: appState.newShelfRequestCount) { _, _ in
            showNewShelfSheet = true
        }
        .onChange(of: appState.choiceRequestCount) { _, _ in
            showNewChoiceSheet = true
        }
        .sheet(isPresented: $showNewBookSheet) {
            LazyNewBookSheet(
                targetShelfId: resolveNewItemTargetShelf().id,
                targetShelfName: resolveNewItemTargetShelf().name,
                availableShelves: shelves.map { ($0.id, $0.name) },
                onSave: { book in
                    do {
                        try bookStore.sidebarSaveBook(book)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .sheet(isPresented: $showNewShelfSheet) {
            LazyNewShelfSheet(
                existingNames: shelves.map { $0.name },
                onSave: { name, icon in
                    do {
                        try bookStore.sidebarSaveShelf(name: name, icon: icon)
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .sheet(isPresented: $showNewChoiceSheet) {
            LazyNewChoiceSheet(
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
        .sheet(item: $renaming) { target in
            LazyRenameItemSheet(
                title: target.kind == .shelf ? "重命名书架" : "重命名书",
                originalName: target.originalName,
                existingNames: target.kind == .shelf
                    ? shelves.filter { $0.id != target.itemId }.map { $0.name }
                    : books.filter { $0.id != target.itemId }.map { $0.title },
                onSave: { newName in
                    do {
                        if target.kind == .shelf {
                            try renameShelf(id: target.itemId, newName: newName)
                        } else {
                            try renameBook(id: target.itemId, newTitle: newName)
                        }
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
        .alert(
            "确认删除?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { target in
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("删除", role: .destructive) {
                do {
                    if target.kind == .shelf {
                        try deleteShelf(id: target.itemId)
                    } else {
                        try deleteBook(id: target.itemId)
                    }
                    reload()
                } catch {
                    loadError = error.localizedDescription
                }
                pendingDelete = nil
            }
        } message: { target in
            let count = pendingDeleteChildCount(target: target)
            Text(count > 0 ? "将一并删除 \(count) 个子项." : "")
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        Text(WenshuI18n.t("sidebar.section.shelves.title"))
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }

    // MARK: - Shelves Section

    private var shelvesSection: some View {
        ForEach(shelves) { shelf in
            shelfBlock(shelf)
        }
    }

    @ViewBuilder
    private func shelfBlock(_ shelf: Bookshelf) -> some View {
        let isExpanded = shelfDisclosureStates[shelf.id, default: false]
        let booksInShelf = books.filter { $0.shelfId == shelf.id }

        Button {
            shelfDisclosureStates[shelf.id, default: false].toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Image(systemName: shelf.displayIcon)
                    .frame(width: 18)
                Text(shelf.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(appState.sidebarSelection == .shelf(shelf.id)
                          ? Color.accentColor.opacity(0.18)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("重命名") {
                renaming = LazyRenamingTarget(
                    kind: .shelf,
                    itemId: shelf.id,
                    originalName: shelf.name
                )
            }
            Divider()
            Button("删除", role: .destructive) {
                pendingDelete = LazyPendingDelete(
                    kind: .shelf,
                    itemId: shelf.id,
                    itemName: shelf.name
                )
            }
        }
        .onTapGesture(count: 2) {
            appState.sidebarSelection = .shelf(shelf.id)
        }

        // v1.67 mutual-exclusion fix (= see bookBlock for full
        // rationale): hoist the isExpanded check OUT of the
        // ForEach so LazyVStack sees N distinct view children
        // instead of one collapsed tuple.
        ForEach(booksInShelf) { book in
            if isExpanded {
                bookBlock(book)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func bookBlock(_ book: Book) -> some View {
        let isExpanded = bookDisclosureStates[book.id, default: false]
        let folders = standardFolderNames

        Button {
            bookDisclosureStates[book.id, default: false].toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Image(systemName: book.displayIcon)
                    .frame(width: 18)
                Text(book.title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(appState.sidebarSelection == .book(book.id)
                          ? Color.accentColor.opacity(0.18)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("重命名") {
                renaming = LazyRenamingTarget(
                    kind: .book,
                    itemId: book.id,
                    originalName: book.title
                )
            }
            Divider()
            Button("删除", role: .destructive) {
                pendingDelete = LazyPendingDelete(
                    kind: .book,
                    itemId: book.id,
                    itemName: book.title
                )
            }
        }
        .onTapGesture(count: 2) {
            appState.sidebarSelection = .book(book.id)
        }

        // v1.67 boss 2026-09-18 '展开帮助的时候测试小说下面 5 项
        // 全没了，关上帮助就显示了' (=互斥) fix:
        // hoist the isExpanded check OUT of the parent ForEach.
        // The previous v1.64 pattern =
        //   if isExpanded { ForEach(folders) { Button(...) } }
        // = SwiftUI @ViewBuilder collapses the ForEach into ONE
        // tuple slot; = LazyVStack gives that slot ONE row's
        // height; = the buttons are rendered (= call chain runs,
        // = the v1.65 os_log confirmed this) but only the first
        // button visually occupies the slot. The "mutual exclusion"
        // symptom (= "打开帮助时 测试小说 folders 没显示") is
        // because LazyVStack's cell-reuse algorithm treats the
        // entire ForEach-tuple as a single id-less cell and
        // recycles it (= collapses to first row height) when the
        // parent shelf's button state toggles.
        // Fix: emit each folder as a SEPARATE view in the
        // @ViewBuilder tree by gating with a Group / empty view
        // trick (= empty View still counts as 1 slot so the layout
        // doesn't break; = the actual Button only appears when
        // isExpanded). The key change is = the `if isExpanded`
        // MUST wrap each folder row, NOT the ForEach as a whole,
        // so SwiftUI sees 5 distinct view children (= each gets
        // its own layout slot in the parent LazyVStack).
        ForEach(folders, id: \.name) { folder in
            if isExpanded {
                Button {
                    appState.sidebarSelection = .folder(
                        bookId: book.id, folderName: folder.name
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: folder.icon)
                            .frame(width: 18)
                        Text(folder.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .padding(.leading, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appState.sidebarSelection == .folder(bookId: book.id, folderName: folder.name)
                                  ? Color.accentColor.opacity(0.18)
                                  : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Reference Library Section

    @ViewBuilder
    private var referenceLibrarySection: some View {
        let isExpanded = referenceLibraryDisclosureExpanded

        Button {
            referenceLibraryDisclosureExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Image(systemName: "books.vertical")
                    .frame(width: 18)
                Text("资料库")
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // v1.67 mutual-exclusion fix (= see bookBlock for full
        // rationale): hoist the isExpanded check OUT of the
        // ForEach so LazyVStack sees N distinct view children
        // instead of one collapsed tuple.
        ForEach(usedCategories()) { category in
            if isExpanded {
                Button {
                    appState.sidebarSelection = .referenceCategory(category.rawValue)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                            .frame(width: 18)
                        Text(category.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appState.sidebarSelection == .referenceCategory(category.rawValue)
                                  ? Color.accentColor.opacity(0.18)
                                  : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Bottom New button

    private var sidebarBottomNewButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                appState.choiceRequestCount += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(WenshuI18n.t("sidebar.new_button.label"))
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("sidebar.new_button.help"))
        }
    }

    // MARK: - Data + Persistence

    private func onAppearLoad() {
        reload()
        let saved = LazySidebarState.from(jsonString: persistedSidebarState)
        shelfDisclosureStates = saved.shelfExpanded
        bookDisclosureStates = saved.bookExpanded
        referenceLibraryDisclosureExpanded = saved.referenceLibraryExpanded
        if let savedSel = saved.selection, appState.sidebarSelection == nil {
            appState.sidebarSelection = savedSel
        }
    }

    private func reload() {
        do {
            shelves = try bookStore.sidebarLoadShelves()
            books = try bookStore.sidebarLoadAllBooks()
            references = try bookStore.referenceStore.loadAllReferences()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func snapshotSidebarState() -> LazySidebarState {
        LazySidebarState(
            shelfExpanded: shelfDisclosureStates,
            bookExpanded: bookDisclosureStates,
            referenceLibraryExpanded: referenceLibraryDisclosureExpanded,
            selection: appState.sidebarSelection
        )
    }

    // MARK: - File ops

    private func pendingDeleteChildCount(target: LazyPendingDelete) -> Int {
        switch target.kind {
        case .shelf:
            return books.filter { $0.shelfId == target.itemId }.count
        case .book:
            return standardFolderNames.reduce(0) { sum, folder in
                sum + bookStore.folderDocumentCount(
                    bookId: target.itemId,
                    folderDirectoryName: folder.name
                )
            }
        }
    }

    private func resolveNewItemTargetShelf() -> (id: UUID, name: String) {
        if case .book(let bookId) = appState.sidebarSelection,
           let book = books.first(where: { $0.id == bookId }),
           let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return (shelf.id, shelf.name)
        }
        if case .shelf(let shelfId) = appState.sidebarSelection,
           let shelf = shelves.first(where: { $0.id == shelfId }) {
            return (shelf.id, shelf.name)
        }
        let defaultId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultName = shelves.first(where: { $0.id == defaultId })?.name ?? "从这里开始"
        return (defaultId, defaultName)
    }

    private func deleteShelf(id: UUID) throws {
        guard id.uuidString != "00000000-0000-0000-0000-000000000000" else {
            throw NSError(domain: "LazySidebar", code: 1)
        }
        let dir = bookStore.stores.shelvesRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    private func deleteBook(id: UUID) throws {
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(
                atPath: booksDir.appendingPathComponent(id.uuidString).path
            )
        }) else { return }
        let dir = bookStore.stores.shelvesRoot
            .appendingPathComponent(parentShelf.directoryName, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    private func renameShelf(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let reserved: Set<String> = ["资料库", "参考库", "reference library"]
        if reserved.contains(where: { trimmed.caseInsensitiveCompare($0) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 2)
        }
        let others = shelves
            .filter { $0.id != id }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if others.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 3)
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

    private func renameBook(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let otherTitles = books
            .filter { $0.id != id }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if otherTitles.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw NSError(domain: "LazySidebar", code: 4)
        }
        guard let parentShelf = shelves.first(where: { shelf in
            let booksDir = bookStore.stores.shelvesRoot
                .appendingPathComponent(shelf.directoryName, isDirectory: true)
                .appendingPathComponent("books", isDirectory: true)
            return FileManager.default.fileExists(
                atPath: booksDir.appendingPathComponent(id.uuidString).path
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

    // MARK: - Helpers

    private var standardFolderNames: [(name: String, displayName: String, icon: String)] {
        [
            ("world",      "世界观",   "globe"),
            ("characters", "角色",     "person"),
            ("outlines",   "章节大纲", "list.bullet.rectangle"),
            ("chapters",   "小说正文", "text.book.closed"),
            ("drafts",     "小说草稿", "pencil"),
        ]
    }

    private func usedCategories() -> [EntityCategory] {
        let entityRefs = references.filter { $0.layer == .layerEntities }
        let used = Set(entityRefs.compactMap { $0.category })
        return EntityCategory.allCases.filter { used.contains($0) }
    }
}

// MARK: - Persistence

private struct LazySidebarState: Codable, Equatable {
    var shelfExpanded: [UUID: Bool]
    var bookExpanded: [UUID: Bool]
    var referenceLibraryExpanded: Bool
    var selection: SidebarItem?

    init(
        shelfExpanded: [UUID: Bool] = [:],
        bookExpanded: [UUID: Bool] = [:],
        referenceLibraryExpanded: Bool = false,
        selection: SidebarItem? = nil
    ) {
        self.shelfExpanded = shelfExpanded
        self.bookExpanded = bookExpanded
        self.referenceLibraryExpanded = referenceLibraryExpanded
        self.selection = selection
    }

    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    static func from(jsonString: String) -> LazySidebarState {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let state = try? JSONDecoder().decode(LazySidebarState.self, from: data)
        else { return LazySidebarState() }
        return state
    }
}

// MARK: - Sheet / Dialog state types

private enum LazyItemKind: String {
    case shelf
    case book
}

private struct LazyRenamingTarget: Identifiable {
    let id = UUID()
    let kind: LazyItemKind
    let itemId: UUID
    let originalName: String
}

private struct LazyPendingDelete: Identifiable {
    let id = UUID()
    let kind: LazyItemKind
    let itemId: UUID
    let itemName: String
}

// MARK: - Sheets (= reused wenshu sheet types)

// Re-uses NewBookSheet / NewShelfSheet / NewChoiceSheet / RenameItemSheet
// from NewLibraryOutlineView.swift (= these sheets are private structs
// in that file). Importing them requires they be made internal. For
// v1.64 (= crash fix first), we copy the minimal sheet shells into
// this file (= simpler). A follow-up ticket can promote the sheets
// to internal and delete the duplicates.

private struct LazyNewBookSheet: View {
    let targetShelfId: UUID
    let targetShelfName: String
    let availableShelves: [(id: UUID, name: String)]
    let onSave: (Book) -> Void
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var shelfId: UUID
    @State private var selectedIcon: String = "book"
    @Environment(\.dismiss) private var dismiss

    init(
        targetShelfId: UUID,
        targetShelfName: String,
        availableShelves: [(id: UUID, name: String)],
        onSave: @escaping (Book) -> Void
    ) {
        self.targetShelfId = targetShelfId
        self.targetShelfName = targetShelfName
        self.availableShelves = availableShelves
        self.onSave = onSave
        _shelfId = State(initialValue: targetShelfId)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title).textFieldStyle(.roundedBorder)
                TextField("作者", text: $author).textFieldStyle(.roundedBorder)
                Picker("归属书架", selection: $shelfId) {
                    ForEach(availableShelves, id: \.id) { shelf in
                        Text(shelf.name).tag(shelf.id)
                    }
                }
                TextField("图标名 (SF Symbols 6)", text: $selectedIcon)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .navigationTitle("新建书")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let book = Book(
                            title: title, author: author,
                            icon: selectedIcon, shelfId: shelfId
                        )
                        onSave(book)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 360, idealHeight: 420)
    }
}

private struct LazyNewShelfSheet: View {
    let existingNames: [String]
    let onSave: (String, String) -> Void
    @State private var name: String = ""
    @State private var selectedIcon: String = "books.vertical"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("书架名", text: $name).textFieldStyle(.roundedBorder)
                TextField("图标名 (SF Symbols 6)", text: $selectedIcon)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .navigationTitle("新建书架")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 200, idealHeight: 240)
    }
}

private struct LazyNewChoiceSheet: View {
    let onNewBook: () -> Void
    let onNewShelf: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 12) {
                Button { onNewBook() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "book.badge.plus")
                            .font(.system(size: 32, weight: .regular))
                        Text("新建书").font(.body)
                    }
                    .frame(width: 120, height: 120)
                }
                .buttonStyle(.bordered)

                Button { onNewShelf() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 32, weight: .regular))
                        Text("新建书架").font(.body)
                    }
                    .frame(width: 120, height: 120)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .navigationTitle("新建")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 180, idealHeight: 200)
    }
}

private struct LazyRenameItemSheet: View {
    let title: String
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                TextField("新名字", text: $name).textFieldStyle(.roundedBorder)
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
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 160, idealHeight: 200)
    }
}