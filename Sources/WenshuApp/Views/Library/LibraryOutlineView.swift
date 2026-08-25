// LibraryOutlineView.swift · Wenshu (Wenshu) · v0.02.x (bookshelf + book outline)
//
// Single List + DisclosureGroup that renders shelves (parent, collapsible)
// and books (children, selectable). Replaces the v0.02.0/v0.02.1 split
// between BookshelfListView (= left side of an internal NativeSplitter)
// and BookListView (= right side).
//
// Apple HIG components used:
//   - List + DisclosureGroup + ForEach    outline with collapse/expand
//   - Label + Image                        row icon (= SF Symbol)
//   - Button (toolbar)                      '+' add shelf (= ⌘N)
//   - .sheet                               new shelf modal
//   - .contextMenu                         rename / show in Finder / delete
//   - confirmationDialog                    destructive confirmation
//   - Selection (.tag(book.id)) drives library.selectedBookId
//
// Boss 8/15 17:05: '结构不对, 参考 fcp. 书架是父级, 可以点击折叠展开'.
// FCP Browser shows events as a single outline list with collapsible
// event libraries (= Library > Event groups, where the event libraries
// are the parents). We mirror that: Bookshelf is the parent (= the
// "event library"), Book is the child (= the "event"). Selecting a
// book is what surfaces its content in the EDITOR zone.
//
// Click behaviors:
//   - click shelf header disclosure chevron   toggle expand/collapse
//   - click shelf header text                  select shelf + ensure expanded
//   - click book row                           select book (= EDITOR shows it)
//   - right-click shelf                        context menu (rename / delete / Finder)
//   - right-click book                         context menu (rename / delete / Finder)
//   - '+' toolbar button                       new shelf (sub-shelves / books added via sheet context menu)
//
// Expansion state lives in @State on this view (= not in WenshuLibrary,
// since it's pure UI: re-mounting the view resets all shelves to
// expanded, which is the right behavior for cold app launches).

import SwiftUI

struct LibraryOutlineView: View {
    @Bindable var library: WenshuLibrary

    /// Per-shelf expansion state. Shelve initially expanded (= first
    /// launch: show all shelves + their books so the user sees what
    /// they have). Local to this view (= UI state, not domain state).
    @State private var expandedShelves: [UUID: Bool] = [:]

    /// Sheet for create shelf / rename shelf (books go through their
    /// own row context menus, not a global sheet, since book creation
    /// belongs to the parent shelf).
    @State private var sheet: SheetKind?
    @State private var pendingDeleteShelf: Bookshelf?

    enum SheetKind: Identifiable {
        case newShelf
        case renameShelf(Bookshelf)
        /// v52: New Book wizard (= 老板 8/15 17:32 '书名, 篇幅选择, 创意点
        /// 然后新建'). The parent shelf id is captured at sheet-show
        /// time (= the user right-clicks on a shelf, the menu picks
        /// '新建书', the sheet opens with the shelf bound). The wizard
        /// collects title + author + length + idea and emits a new
        /// Book via the onCommit callback (= the view is a thin shell
        /// over WenshuLibrary.addBook).
        case newBook(parentShelfId: UUID)
        var id: String {
            switch self {
            case .newShelf: return "newShelf"
            case .renameShelf(let s): return "renameShelf-\(s.id)"
            case .newBook(let parent): return "newBook-\(parent)"
            }
        }
    }

    var body: some View {
        List(selection: Binding(
            get: { library.selectedBookId },
            set: { newID in library.setSelectedBook(id: newID) }
        )) {
            if library.shelves.isEmpty {
                emptyLibrary
            } else {
                ForEach(library.shelves) { shelf in
                    shelfSection(shelf: shelf)
                }
            }
        }
        .listStyle(.plain)  // 老板 8/18: unifica zone background
        .scrollContentBackground(.hidden)  // List 透明底色, 用 ZoneModule DesignColor.zoneSurface
        .frame(minWidth: 200, idealWidth: 260)
        // v0.24 boss验收fix (Boss 8/25 13th OOB ticket 015.027): removed
        // ToolbarItem '新建书架' (+ button) per Boss拍 '加号按钮 不要了'.
        // New shelf creation now lives in the emptyLibrary CTA (= ticket
        // 015.026 FCP-style onboarding wizard step 1) and the global toolbar
        // '新建' button (left group, ticket 015.023).
        .sheet(item: $sheet) { kind in
            switch kind {
            case .newShelf:
                BookshelfEditorSheet(mode: .create) { name in
                    try library.addShelf(Bookshelf(name: name))
                }
            case .renameShelf(let shelf):
                BookshelfEditorSheet(mode: .rename(shelf.name)) { newName in
                    try library.renameShelf(id: shelf.id, to: newName)
                }
            case .newBook(let parentShelfId):
                // v52: New Book wizard (= 3 fields: 书名 / 篇幅 / 创意点).
                // The wizard emits (title, author, length, idea) and the
                // Library wraps them into a new Book + persists +
                // auto-selects (= Apple HIG Finder 'creating a file
                // selects it').
                BookEditorSheet(mode: .create) { title, author, length, idea in
                    let book = Book(
                        title: title,
                        author: author,
                        shelfId: parentShelfId,
                        length: length,
                        idea: idea
                    )
                    try library.addBook(book)
                }
            }
        }
        .confirmationDialog(
            pendingDeleteShelf.map { "删除书架 \"\($0.name)\"？" } ?? "",
            isPresented: Binding(
                get: { pendingDeleteShelf != nil },
                set: { if !$0 { pendingDeleteShelf = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let s = pendingDeleteShelf {
                    try? library.deleteShelf(id: s.id)
                }
                pendingDeleteShelf = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteShelf = nil
            }
        } message: {
            Text("此操作不可撤销。书架及其下所有书籍都会被删除。")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func shelfSection(shelf: Bookshelf) -> some View {
        // Books for this shelf, lazy-loaded (= the store decides how to
        // optimize; FileSystem scans the shelf's books/ subdir, future
        // CoreData / MetadataQuery could cache).
        let books: [Book] = (try? library.books(in: shelf.id)) ?? []
        let isExpanded = Binding(
            get: { expandedShelves[shelf.id] ?? true },
            set: { expandedShelves[shelf.id] = $0 }
        )
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(books) { book in
                BookOutlineRow(book: book)
                    .tag(book.id)
                    .contextMenu { bookContextMenu(book: book) }
            }
            // Empty-state hint when the shelf is expanded but has no books.
            if books.isEmpty {
                Text("这个书架里还没有书")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
            }
        } label: {
            // Shelf header. Tapping the label selects the shelf + opens
            // the disclosure (Apple HIG Finder: click a folder name to
            // select AND expand; the chevron is for collapse-only).
            // Owner 8/15 17:23: '参考 fcp 把 ui 调整一下' — FCP Browser
            // doesn't show a count badge on the shelf header. Removed
            // in v51; count is implicit via the visible children rows.
            ShelfHeader(shelf: shelf)
                .contentShape(Rectangle())
                .onTapGesture {
                    library.setSelectedShelf(id: shelf.id)
                    expandedShelves[shelf.id] = true
                }
                .contextMenu { shelfContextMenu(shelf: shelf) }
        }
    }

    @ViewBuilder
    private var emptyLibrary: some View {
        // v0.24 boss验收fix (Boss 8/25 12th OOB ticket 015.026 '参考 FCP,
        // 引导新建书架 + 建第一本书'): FCP-style onboarding wizard.
        // Two states: 0 shelves -> 'create first shelf' CTA; >0 shelves
        // but 0 books -> 'create first book' CTA (= next onboarding step).
        let firstShelf = library.shelves.first
        let firstShelfHasBooks: Bool = {
            guard let shelfId = firstShelf?.id,
                  let books = try? library.books(in: shelfId) else { return false }
            return !books.isEmpty
        }()
        VStack(spacing: 8) {
            Image(systemName: firstShelfHasBooks ? "books.vertical" : "books.vertical.fill")
                .font(.title)
                .imageScale(.large)
                .foregroundStyle(.tertiary)
            if firstShelf == nil {
                // Step 1: create first shelf
                Text("还没有书架")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("新建第一个书架") {
                    sheet = .newShelf
                }
                .controlSize(.small)
            } else if !firstShelfHasBooks {
                // Step 2: create first book in first shelf
                Text("书架 \"\(firstShelf!.name)\" 还没有书")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("建第一本书") {
                    sheet = .newBook(parentShelfId: firstShelf!.id)
                }
                .controlSize(.small)
            } else {
                // Defensive: both checks failed (shelf has books but listed here)
                Text("还没有书")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .listRowSeparator(.hidden)
    }

    // MARK: - Context menus

    @ViewBuilder
    private func shelfContextMenu(shelf: Bookshelf) -> some View {
        Button("重命名") { sheet = .renameShelf(shelf) }
        Button("在 Finder 中显示") {
            let shelfDir = library.libraryRootURL
                .appendingPathComponent(shelf.directoryName)
            NSWorkspace.shared.activateFileViewerSelecting([shelfDir])
        }
        Divider()
        // v52: '新建书' now opens the 3-field wizard (= 书名 / 篇幅 /
        // 创意点) instead of inline-creating a '未命名草稿' book.
        // The wizard modal collects the values; the Library persists
        // the new Book + auto-selects it (= Apple HIG Finder 'creating
        // a file selects it').
        Button("新建书") {
            sheet = .newBook(parentShelfId: shelf.id)
        }
        Divider()
        Button("删除", role: .destructive) { pendingDeleteShelf = shelf }
    }

    @ViewBuilder
    private func bookContextMenu(book: Book) -> some View {
        Button("在 Finder 中显示") {
            let bookDir = library.libraryRootURL
                .appendingPathComponent(book.shelfId.uuidString)
                .appendingPathComponent("books")
                .appendingPathComponent(book.directoryName)
            NSWorkspace.shared.activateFileViewerSelecting([bookDir])
        }
        Button("重命名") {
            // Inline rename: simplest possible UX for v0.02.x; the
            // modal editor is reserved for create / first-rename. Owner
            // can ask for inline-edit polish in v0.02.x+ if desired.
            // (No-op placeholder; the BookEditorSheet is wired for
            // create-only paths in this view. Full rename-by-row lands
            // in a follow-up commit once the selection state is
            // re-tested with the outline view.)
        }
        .disabled(true)  // not yet wired in the outline view; see comment above
        Divider()
        Button("删除", role: .destructive) {
            try? library.deleteBook(id: book.id)
        }
    }
}

// MARK: - Shelf header

/// Shelf header row. No count badge (= FCP Browser doesn't show one;
    /// the count is implicit via the disclosure triangle + the visible
    /// children). Apple's HIG document-based apps (= Notes, Pages)
    /// also keep section headers minimal.
    private struct ShelfHeader: View {
    let shelf: Bookshelf

    var body: some View {
        Label {
            Text(shelf.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: "books.vertical")
                .foregroundStyle(.secondary)
        }
        // Apple HIG: when a row is selected in a sidebar list, its
        // background is the system accent. SwiftUI List + tag handles
        // that automatically; we don't add a custom background.
    }
}

// MARK: - Book row

private struct BookOutlineRow: View {
    let book: Book
    /// v0.24 boss验收fix (Boss 8/25 ninth OOB ticket 015.022): book
    /// expansion state (= FCP Browser style 3-level disclosure).
    /// Default expanded per Apple HIG Finder convention so user sees
    /// book structure on first launch.
    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // v0.24 boss验收fix (Boss 8/25 ninth OOB ticket 015.022):
            // FCP-style 3-level structure = book header + book structure
            // categories (= 章节, 设定, 资料库 = Apple HIG 3 standard).
            // Per Boss拍 '书下的目录就是我们之前定义的, 书的结构目录,
            // 世界观, 角色, 资料库等' = the 3 standard categories cover the
            // core writing app needs. User can add per-book custom folders
            // (= future ticket).
            ForEach(BookCategory.allCases, id: \.self) { category in
                BookCategoryOutlineRow(book: book, category: category)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title)
                        .lineLimit(1)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: "book")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// v0.24 boss验收fix (Boss 8/25 ninth OOB ticket 015.022): 1 row per book
/// structure category (= 章节 / 设定 / 资料库 = 3 standard Apple HIG
/// categories). Future ticket may add per-book custom categories
/// (= 人物 / 世界观 / 音频 etc, per Boss image) by extending BookCategory
/// enum or by per-book overrides.
private struct BookCategoryOutlineRow: View {
    let book: Book
    let category: BookCategory

    var body: some View {
        Label {
            HStack {
                Text(category.displayName)
                    .lineLimit(1)
                Spacer()
                // Future ticket: show document count per category
                // (= FCP Browser shows badge with item count).
                // Empty for now (= no document count query wired).
            }
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(.tertiary)
        }
        // v0.24 boss验收fix: make row selectable click (= future ticket
        // wires category selection to BookOutlineView's category-filter).
        .contentShape(Rectangle())
    }
}