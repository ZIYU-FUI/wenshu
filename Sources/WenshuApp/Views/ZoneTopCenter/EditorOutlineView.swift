// EditorOutlineView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 中上编辑器内部章节 sidebar (DESIGN-LT-N3.md §5.3)。
// 修真 LT-01-fix19 原稿 (commit 71d28b779 + 2dc04ee58): 原本 `chapters: []`
// 永远空态, 修真后接 `EditorOutlineStore.chapters` (listChapters 真读),
// + active chapter 高亮 + selectedChapterID binding 双向同步。
//
// 视觉:
//   - 240pt 固定宽 (跟 DESIGN §6.4 真值)
//   - 顶 mini bar: "大纲" 标题 (沿 LT-01-fix19 真值)
//   - 章节 rows: SF Symbol doc.text / doc.text.fill + 标题 + "第 N 章 · N 字"
//   - ListStyle.sidebar 让 macOS native 出 active 高亮 (本卡拍板, 不靠手算)
//   - 空态: 居中 SF Symbol list.bullet.rectangle + hint 文字

import SwiftUI

struct EditorOutlineView: View {
    @Binding var selectedChapterID: String?
    // B+ 重 (t_0f6bd6f6): @ObservedObject → @Bindable (EditorOutlineStore 已 @Observable).
    @Bindable var store: EditorOutlineStore

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if store.chapters.isEmpty {
                emptyState
            } else {
                chapterList
            }
        }
        .frame(width: 240)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    private var headerBar: some View {
        HStack {
            Text("大纲")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.fileList
            // (`list.bullet.rectangle`) — 单一真值源。
            Image(systemName: IconLibrary.Action.fileList.symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无章节")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("在「章节」tab 中新建章节")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var chapterList: some View {
        List(selection: $selectedChapterID) {
            ForEach(store.chapters) { chapter in
                ChapterOutlineRow(
                    chapter: chapter,
                    isActive: chapter.id == selectedChapterID
                )
                .tag(chapter.id as String?)
            }
        }
        .listStyle(.sidebar)
    }
}

private struct ChapterOutlineRow: View {
    let chapter: ChapterSnapshot
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.docItem
            // (`doc.text` 描边) + IconLibrary.Action.docItemFillSymbol()
            // (`doc.text.fill` 选中态) — 单一真值源。
            Image(systemName: isActive
                ? IconLibrary.Action.docItemFillSymbol()
                : IconLibrary.Action.docItem.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
