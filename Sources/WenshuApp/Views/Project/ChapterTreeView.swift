// ChapterTreeView.swift · 文枢 (Wenshu) · v0.02.0 LT-N1-revise → v0.03.0 LT-N3-cc
//
// topLeft "章节" tab 章节树 (LT-N1 P0-2/3/4 真修真值)。
// LT-N3 修真: 加 `onSelectChapter` 回调 — ChapterTreeView 用于 ProjectDetailView
// 章节 tab 时, chapter row click 触发回调 (→ 驱动 selectedChapterID + pop back);
// 用于 ProjectListView 章节 tab 时, 回调 nil (沿 LT-N1 旧行为, 不动)。
//
// 行为契约:
//   - onSelectChapter = nil    → 章节 row click 无副作用 (LT-N1 旧行为)
//   - onSelectChapter != nil  → 章节 row click = 调 callback(chapterId) + 反高亮
//
// 视觉 (LT-N1 P0-2 真值): SF Symbol list.bullet.rectangle + 标题 + "第 N 章 · N 字"
// caption + listStyle .inset。

import SwiftUI

struct ChapterTreeView: View {
    /// **P0-2 fix (LT-N1-revise, 2026-08-11)**: `projectId` is now `UUID`
    /// (was `UUID?`). Previously the optional default of `nil` + a
    /// fabricated `UUID()` fallback made the chapters tab a dead path —
    /// see reviewer §3.3.1. The owning view (`ProjectBrowserView`) is
    /// responsible for providing a real projectId from the current
    /// navigation route (or showing its own "no project selected" state).
    let projectId: UUID
    let store: WenshuProjectStore
    /// LT-N3: 章节 row click 回调 (驱动 selectedChapterID). nil = 旧行为 (不真接).
    let onSelectChapter: ((String) -> Void)?

    @StateObject private var chapterStore: ChapterTreeStore

    init(
        projectId: UUID,
        store: WenshuProjectStore = .shared,
        onSelectChapter: ((String) -> Void)? = nil
    ) {
        self.projectId = projectId
        self.store = store
        self.onSelectChapter = onSelectChapter
        _chapterStore = StateObject(wrappedValue: ChapterTreeStore(projectId: projectId, store: store))
    }

    var body: some View {
        Group {
            if chapterStore.chapters.isEmpty { emptyState } else {
                List(chapterStore.chapters) { chapter in
                    Button {
                        onSelectChapter?(chapter.id)
                    } label: {
                        chapterRow(chapter)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelectChapter == nil)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("章节")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("新建章节", systemImage: "plus") { }.disabled(true).help("v0.04.0 长篇工具 阶段实装") } }
        .task(id: projectId) { await chapterStore.load() }
    }

    private func chapterRow(_ chapter: ChapterSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 14)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title).font(.headline)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
            Text("暂无章节").font(.title2)
            Text("v0.04.0 接新建章节").font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}
