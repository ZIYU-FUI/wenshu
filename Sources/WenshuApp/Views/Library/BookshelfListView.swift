// BookshelfListView.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Shelf zone (= the left side of LIBRARY) real content: a list of the
// user's bookshelves, with new / rename / delete actions. Replaces the
// v0.01.x watermark that was just "SHELF".
//
// Apple HIG components used (= no custom UI):
//   - List + Section          for the shelf list (= Notes / Finder sidebar)
//   - Label + Image           for the row icon (= SF Symbol 'books.vertical')
//   - Button (toolbar)         for the '+' add action
//   - .sheet + Form            for the new-shelf modal (= standard macOS modal)
//   - .contextMenu             for right-click rename / delete (= Finder style)
//   - confirmationDialog       for destructive delete (= Apple HIG standard)
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The view is a thin shell over WenshuLibrary (= v40). Every
// mutation goes through WenshuLibrary; the view never touches the store.

import SwiftUI

struct BookshelfListView: View {
    @Bindable var library: WenshuLibrary

    /// Sheet presentation: .new for create, .rename(Bookshelf) for rename,
    /// .none for hidden. Avoids two separate @State bools (= single state
    /// model is easier to reason about and matches Apple HIG 'one source
    /// of truth for the modal flow').
    @State private var sheet: SheetKind?

    /// The shelf awaiting delete confirmation. Nil = no dialog visible.
    @State private var pendingDelete: Bookshelf?

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
            get: { library.selectedShelfId },
            set: { newID in
                if let id = newID { library.setSelectedShelf(id: id) }
                else { library.clearSelection() }
            }
        )) {
            Section("书架") {
                if library.shelves.isEmpty {
                    emptyState
                } else {
                    ForEach(library.shelves) { shelf in
                        BookshelfRow(shelf: shelf)
                            .tag(shelf.id)
                            .contextMenu {
                                Button("重命名") {
                                    sheet = .rename(shelf)
                                }
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting(
                                        [library.libraryRootURL.appendingPathComponent(shelf.directoryName)]
                                    )
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    pendingDelete = shelf
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160, idealWidth: 200)
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
            pendingDelete.map { "删除书架 \"\($0.name)\"？" } ?? "",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let s = pendingDelete {
                    try? library.deleteShelf(id: s.id)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("此操作不可撤销。书架及其下所有书籍都会被删除。")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            // Apple HIG empty-state icon: .font(.title) (= 22pt) +
            // .imageScale(.large) (= SF Symbol emphasis; matches Mail /
            // Notes / Reminders empty-state pattern). Dynamic Type-
            // respecting (a system font-size bump scales the icon too).
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
}

// MARK: - Row
//
// Single shelf row (= Apple HIG sidebar row: SF Symbol + name).
// Kept as a separate small view so it stays focused and reusable
// (= v0.02.1+ will use the same row shape inside ProjectListView).

private struct BookshelfRow: View {
    let shelf: Bookshelf

    var body: some View {
        Label {
            Text(shelf.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: "books.vertical")
                .foregroundStyle(.secondary)
        }
    }
}