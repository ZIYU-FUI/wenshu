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
        case new
        case rename(Bookshelf)
        var id: String {
            switch self {
            case .new: return "new"
            case .rename(let s): return "rename-\(s.id)"
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
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 260)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = .new
                } label: {
                    Label("新建书架", systemImage: "plus")
                }
                .help("新建书架 (= ⌘N)")
            }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new:
                BookshelfEditorSheet(mode: .create) { name in
                    try library.addShelf(Bookshelf(name: name))
                }
            case .rename(let shelf):
                BookshelfEditorSheet(mode: .rename(shelf.name)) { newName in
                    try library.renameShelf(id: shelf.id, to: newName)
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
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.title)
                .imageScale(.large)
                .foregroundStyle(.tertiary)
            Text("还没有书架")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("新建第一个书架") {
                sheet = .new
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .listRowSeparator(.hidden)
    }

    // MARK: - Context menus

    @ViewBuilder
    private func shelfContextMenu(shelf: Bookshelf) -> some View {
        Button("重命名") { sheet = .rename(shelf) }
        Button("在 Finder 中显示") {
            let shelfDir = library.libraryRootURL
                .appendingPathComponent(shelf.directoryName)
            NSWorkspace.shared.activateFileViewerSelecting([shelfDir])
        }
        Divider()
        Button("新建书") {
            let book = Book(title: "未命名草稿", author: "", shelfId: shelf.id)
            try? library.addBook(book)
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

    var body: some View {
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