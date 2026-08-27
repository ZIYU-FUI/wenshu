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
        // v0.27 boss 8/27 OOB #3: 新建 + 导入 moved out of the macOS
        // window toolbar into the projectSidebar zone (= right-aligned
        // icon buttons in the zone header). Boss asked to follow the
        // same pattern as the editor zone's expand button (= ticket
        // 029c-trailing-button: Color.clear 28x28 hot area + icon
        // overlay, no capsule border, plain visual). The two buttons
        // sit in a trailingButton HStack on the zone's ZoneContentView
        // (= app.swift:2155; the ZoneContentView already accepts an
        // optional trailingButton parameter that renders at the right
        // edge of the zone tab bar). The menu bar File → 新建项目 +
        // File → 导入… entries remain (= macOS standard File menu);
        // right-click context menu on sidebar empty area remains.
        // Note: the macOS window toolbar no longer carries 新建 + 导入
        // (= removed in commit 6beb3c015 = boss 8/27 '在标题栏里去掉').
        Group {
            if let error = loadError {
                errorState(error)
            } else {
                List {
                    if shelves.isEmpty {
                        Text("暂无书架")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(shelves) { shelf in
                            shelfSection(shelf)
                        }
                    }
                    referenceLibrarySection
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .contextMenu(forSelectionType: UUID.self, menu: { _ in
                    Button {
                        showNewBookSheet = true
                    } label: {
                        Label("新建书", systemImage: "square.plus")
                    }
                    Button {
                        showNewShelfSheet = true
                    } label: {
                        Label("新建书架", systemImage: "books.vertical.fill")
                    }
                })
            }
        }
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
        HStack(spacing: 4) {
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