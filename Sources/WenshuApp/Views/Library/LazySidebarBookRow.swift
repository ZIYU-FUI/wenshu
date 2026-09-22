// LazySidebarBookRow.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the BOOK ROW rendering (= the disclosure indicator
// + the book title + the book icon + the context-menu for Rename /
// Delete + the nested-folder list). The row itself is a leaf (= no
// @State); the parent (= LazySidebarShelfRow when nested, or the
// direct caller for top-level books) owns the disclosure state + the
// rename / delete sheet-input state + the sidebarSelection.
//
// What lives here:
//   - LazySidebarBookRow : book disclosure row + nested folders.
//
// What does NOT live here:
//   - shelf row rendering (= LazySidebarShelfRow).
//   - business logic (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - view body composition (= LazySidebarView).
//
// v1.68 restore notes: the v1.67 LazySidebarView had `bookBlock` as
// a private func (= depended on @State + @Environment implicitly).
// Splitting it out makes it reusable from any caller.

import SwiftUI

struct LazySidebarBookRow: View {
    let book: Book
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let standardFolders: [(name: String, displayName: String, icon: String)]
    let onSelectFolder: (String) -> Void

    var body: some View {
        Button(action: onToggle) {
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
            .padding(.horizontal, DesignTokens.chromePaddingLeading)
            .padding(.leading, 14)
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

        // v1.67 boss 2026-09-18 '展开帮助的时候测试小说下面 5 项
        // 全没了，关上帮助就显示了' (=互斥) fix: hoist the
        // isExpanded check OUT of the parent ForEach so LazyVStack
        // sees N distinct view children instead of one collapsed
        // tuple. The previous v1.64 pattern =
        //   if isExpanded { ForEach(folders) { Button(...) } }
        // = SwiftUI @ViewBuilder collapses the ForEach into ONE
        // tuple slot (= first button only visually occupies).
        // Fix: the `if isExpanded` MUST wrap each folder row,
        // NOT the ForEach as a whole, so SwiftUI sees 5 distinct
        // view children (= each gets its own layout slot in the
        // parent LazyVStack).
        ForEach(standardFolders, id: \.name) { folder in
            if isExpanded {
                Button {
                    onSelectFolder(folder.name)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: folder.icon)
                            .frame(width: 18)
                        Text(folder.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, DesignTokens.chromePaddingLeading)
                    .padding(.leading, 28)
                    .frame(width: nil, height: DesignTokens.chromeHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                EmptyView()
            }
        }
    }
}