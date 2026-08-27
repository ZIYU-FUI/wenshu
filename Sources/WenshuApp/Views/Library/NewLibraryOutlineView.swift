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
        // window toolbar into the projectSidebar top bar (= right-
        // aligned icon buttons beside the '书架' title). The macOS
        // window toolbar now only carries the zone-toggle buttons
        // (= no ⌄ indicator fights; no .buttonStyle fights). Two icon
        // buttons in the sidebar top bar = direct invocation (= no
        // menu layer between icon and action). Menu bar File →
        // 新建项目 + File → 导入… remain (= macOS standard File menu).
        VStack(spacing: 0) {
            sidebarTopBar
            Divider()
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

    // MARK: - Top bar (= boss 8/27 OOB #3: 新建 + 导入 moved here
    // from the macOS window toolbar; now two right-aligned icon
    // buttons in the sidebar top bar).

    /// Sidebar top bar: 2 right-aligned icon buttons.
    /// Per boss 8/27 OOB correction:
    /// - 新建 (square-plus icon): Menu button (= tap to open a Menu
    ///   with 新建书 / 新建书架; matches the macOS-standard toolbar '+'
    ///   pattern where the '+' is a pull-down menu of file-creation
    ///   kinds).
    /// - 导入 (square-arrow-right icon): plain Button (= tap directly
    ///   triggers the import flow; per boss 8/27 OOB '导入等合并两
    ///   个库' the functionality is being planned in a followup; for
    ///   now, posts the .wenshuImportRequested NotificationCenter
    ///   event so the menu-bar 导入… entry + this button share one
    ///   implementation when the import logic ships).
    /// The macOS window toolbar no longer carries these buttons (= boss
    /// gave up fighting the SwiftUI toolbar's ⌄ indicator + capsule
    /// styling debate; per boss 8/27 '换个位置' = move to the sidebar).
    @ViewBuilder
    private var sidebarTopBar: some View {
        HStack(spacing: 4) {
            Spacer()
            // 新建 button = Menu (= tap → menu with 新建书 / 新建书架)
            Menu {
                Button("新建书") {
                    showNewBookSheet = true
                }
                Button("新建书架") {
                    showNewShelfSheet = true
                }
            } label: {
                if let lucide = Lucide("square-plus") {
                    lucide
                        .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                } else {
                    Image(systemName: "square.and.pencil")
                        .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .help("新建")
            // 导入 button = plain Button (= tap directly fires the
            // import flow; posts .wenshuImportRequested so the
            // menu-bar File → 导入… entry can share the same handler
            // when the import logic ships in a followup).
            Button {
                NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
            } label: {
                if let lucide = Lucide("square-arrow-right") {
                    lucide
                        .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                } else {
                    Image(systemName: "arrow.down.doc")
                        .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                }
            }
            .buttonStyle(.bordered)
            .help("导入")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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