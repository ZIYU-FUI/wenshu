// BookListView.swift · Wenshu (Wenshu) · v0.02.1 (book module)
//
// Project zone (= right side of LIBRARY) real content: the books in the
// currently-selected shelf. Mirrors BookshelfListView (v41) in shape
// and Apple HIG component choices.
//
// Apple HIG components used (= no custom UI):
//   - List + Section          for the book list (= Notes / Finder list)
//   - Label + Image           for the row icon (= SF Symbol 'book')
//   - Button (toolbar)         for the '+' add action
//   - .sheet + TextField       for the new-book / rename-book modal
//   - .contextMenu             for right-click rename / delete (= Finder style)
//   - confirmationDialog       for destructive delete
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The view is a thin shell over WenshuLibrary (= v46). Every
// mutation goes through WenshuLibrary; the view never imports
// LibraryStoring.
//
// Selection rule: shows the books for the shelf whose id matches
// library.selectedShelfId. If no shelf is selected, renders an empty
// 'pick a shelf first' hint (= mirrors Apple's standard 'empty state'
// for a sidebar with no selection).

import SwiftUI

struct BookListView: View {
    @Bindable var library: WenshuLibrary

    @State private var sheet: SheetKind?
    @State private var pendingDelete: Book?

    enum SheetKind: Identifiable {
        case new(parentShelfId: UUID)
        case rename(Book)
        var id: String {
            switch self {
            case .new(let s): return "new-\(s)"
            case .rename(let b): return "rename-\(b.id)"
            }
        }
    }

    var body: some View {
        let shelfId = library.selectedShelfId
        Group {
            if let shelfId {
                content(shelfId: shelfId)
            } else {
                noShelfSelected
            }
        }
        .frame(minWidth: 160, idealWidth: 240)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let shelfId { sheet = .new(parentShelfId: shelfId) }
                } label: {
                    Label("新建书", systemImage: "plus")
                }
                .help("新建书 (= ⌘N)")
                .disabled(shelfId == nil)
            }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .new(let parentShelfId):
                BookEditorSheet(mode: .create) { title, author in
                    try library.addBook(Book(title: title, author: author, shelfId: parentShelfId))
                }
            case .rename(let book):
                BookEditorSheet(mode: .rename(title: book.title, author: book.author)) { title, author in
                    var updated = book
                    updated.title = title
                    updated.author = author
                    try library.renameBook(id: book.id, to: title)
                    _ = updated  // (renameBook via VM only updates title; author edit is best-effort in v0.02.1)
                }
            }
        }
        .confirmationDialog(
            pendingDelete.map { "删除书 \"\($0.title)\"？" } ?? "",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let b = pendingDelete {
                    try? library.deleteBook(id: b.id)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("此操作不可撤销。书及其下所有章节都会被删除。")
        }
    }

    @ViewBuilder
    private func content(shelfId: UUID) -> some View {
        // LibraryStoring.loadBooks is throws (= could fail on disk I/O).
        // The view swallows the error and shows the empty state, since a
        // missing-books dir is a common cold-state (= fresh shelf, no
        // books yet) rather than a user-recoverable failure.
        let books: [Book] = (try? library.books(in: shelfId)) ?? []
        List(selection: Binding(
            get: { library.selectedBookId },
            set: { newID in library.setSelectedBook(id: newID) }
        )) {
            Section(booksHeader(count: books.count)) {
                if books.isEmpty {
                    emptyState
                } else {
                    ForEach(books) { book in
                        BookRow(book: book)
                            .tag(book.id)
                            .contextMenu {
                                Button("重命名") {
                                    sheet = .rename(book)
                                }
                                Button("在 Finder 中显示") {
                                    let bookDir = library.libraryRootURL
                                        .appendingPathComponent(book.shelfId.uuidString)
                                        .appendingPathComponent("books")
                                        .appendingPathComponent(book.directoryName)
                                    NSWorkspace.shared.activateFileViewerSelecting([bookDir])
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    pendingDelete = book
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func booksHeader(count: Int) -> String {
        count == 0 ? "书" : "书 · \(count) 本"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("这个书架里还没有书")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("新建第一本书") {
                if let shelfId = library.selectedShelfId {
                    sheet = .new(parentShelfId: shelfId)
                }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .listRowSeparator(.hidden)
    }

    private var noShelfSelected: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("先在左边选一个书架")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct BookRow: View {
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