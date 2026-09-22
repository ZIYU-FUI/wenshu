// LazySidebarShelfRow.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the SHELF ROW rendering (= the disclosure
// indicator + the shelf name + the shelf icon + the context-menu
// for Rename / Delete + the nested-book list). The row itself is a
// leaf (= no @State); the parent LazySidebarView owns the disclosure
// state + the rename / delete sheet-input state + the sidebarSelection
// + the books-in-this-shelf list (= state, no closures, no work).
//
// The row takes pure callbacks (= no @Binding / no @Environment) so
// the row can be rendered in isolation (= e.g. inside a future
// List(.sidebar) rewrite where each row is a RowContent closure).
//
// What lives here:
//   - LazySidebarShelfRow : shelf disclosure row + nested books.
//
// What does NOT live here:
//   - book row rendering (= LazySidebarBookRow).
//   - business logic (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - view body composition (= LazySidebarView).
//
// v1.68 restore notes: the v1.67 LazySidebarView had `shelfBlock` as
// a private func (= depended on @State + @Environment implicitly).
// Splitting it out (= parameterizing the row's own state + selection
// callbacks) makes it reusable from any caller (= the v1.68 sidebar
// Apple HIG rewrite that lists each shelf as a List row).

import SwiftUI

struct LazySidebarShelfRow: View {
    let shelf: Bookshelf
    let booksInShelf: [Book]
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let standardFolders: [(name: String, displayName: String, icon: String)]
    let bookDisclosureStates: [UUID: Bool]
    let onToggleBook: (UUID) -> Void
    let onSelectBook: (UUID) -> Void
    let onSelectFolder: (UUID, String) -> Void
    let onRenameBook: (UUID, String) -> Void
    let onDeleteBook: (UUID, String) -> Void

    var body: some View {
        Button(action: onToggle) {
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
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            .frame(width: nil, height: DesignTokens.chromeHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("重命名", action: onRename)
            Divider()
            Button("删除", role: .destructive, action: onDelete)
        }
        .onTapGesture(count: 2) {
            onSelect()
        }

        // v1.67 mutual-exclusion fix (= see LazySidebarView for full
        // rationale): hoist the isExpanded check OUT of the parent
        // ForEach so LazyVStack sees N distinct view children instead
        // of one collapsed tuple.
        ForEach(booksInShelf) { book in
            if isExpanded {
                LazySidebarBookRow(
                    book: book,
                    isSelected: false,
                    isExpanded: bookDisclosureStates[book.id, default: false],
                    onToggle: { onToggleBook(book.id) },
                    onSelect: { onSelectBook(book.id) },
                    onRename: { onRenameBook(book.id, book.title) },
                    onDelete: { onDeleteBook(book.id, book.title) },
                    standardFolders: standardFolders,
                    onSelectFolder: { folderName in
                        onSelectFolder(book.id, folderName)
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
}