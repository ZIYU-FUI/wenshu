// EditorOutlineView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
<<<<<<< HEAD
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
=======
// 编辑器章节 sidebar (DESIGN-LT-N3.md §5.3):
//
// 拍板真值 (DESIGN-LT-N3 §5.3 修真 + 派单 §Step 2):
//   ✅ 240pt 默认宽 sidebar, 1pt HSplitView 内置 splitter (沿 LT-N1
//      NativeSplitter 1pt 风格)
//   ✅ 章节 row 接 `WenshuProjectStore.listChapters(projectId:)` 真读
//      (沿用 LT-N1 store API, 不新加 actor method)
//   ✅ active chapter row 高亮 (跟随 `selectedChapterID` 值)
//   ✅ 空态: "暂无章节" + list.bullet.rectangle SF Symbol +
//      "v0.04.0 接新建章节" caption (沿 ChapterTreeView emptyState 范式)
//   ✅ 章节 row 仅文档 (visual list), 切章节走 ProjectDetailView 章节
//      tab row tap (本卡沿任务 body 派单, 不在 sidebar 内点切)
//
// 修真要拍板点 (DESIGN-LT-N3 §5.3):
//   ❌ 修真未实装的 LT-01-fix19 "+ 新建章节" toolbar (LT-N1 已在
//      ChapterTreeView 实装, 避免重复 — ProjectDetailView 章节 tab
//      的 ChapterListView 改接官方 toolbar 解决方案保留)
//
// 范式: 沿 LT-01-fix19 commit 71d28b779 + DESIGN-LT-N3 §5.3 出稿真值。
>>>>>>> wenshu/v0.03.0/LT-N3-cc

import SwiftUI

struct EditorOutlineView: View {
<<<<<<< HEAD
    @Binding var selectedChapterID: String?
    @ObservedObject var store: EditorOutlineStore

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
            Image(systemName: "list.bullet.rectangle")
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
=======
    /// 当前编辑章节 id (高亮用, 不可变 — 切换章节走 ProjectDetailView)。
    /// 类型 String: 跟 ChapterSnapshot.id (LT-N1 P0-4 拍板, NSManagedObjectID
    /// URI) 对齐; 派单 §Step 4 命名 "selectedChapterID" 但实际类型跟
    /// chapter.id 一致 (= String, 不 UUID)。 nil = 没选章节 (顶 toolbar
    /// 显示 "未选章节")。
    let selectedChapterID: String?

    /// Outline store (MainActor ObservableObject, 持有 chapters 列表)。
    @ObservedObject var store: EditorOutlineStore

    var body: some View {
        Group {
            if store.chapters.isEmpty {
                emptyState
            } else {
                List(selection: .constant(selectedChapterID)) {
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
        .frame(idealWidth: 240)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无章节").font(.title2)
            Text("v0.04.0 接新建章节").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
>>>>>>> wenshu/v0.03.0/LT-N3-cc
    }
}

private struct ChapterOutlineRow: View {
    let chapter: ChapterSnapshot
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "doc.text.fill" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
<<<<<<< HEAD
                Text(chapter.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
=======
                Text(chapter.title).font(.headline)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
>>>>>>> wenshu/v0.03.0/LT-N3-cc
        }
        .padding(.vertical, 2)
    }
}
