// EditorView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器主视图 (DESIGN-LT-N3.md §5.1 + §2.2):
//
// 整体结构 (FCP viewer 范式, 3 层):
//
//   ┌──────────────────────────────────────────────────┐
//   │ EditorTopToolbar (28pt, 字数 + 章节名 + 空槽)      │
//   ├──┬───────────────────────────────────────────┬──┤
//   │  │ EditorOutlineView (240pt default sidebar)│  │
//   │ES│              TextEditor (可编辑)         │  │
//   │  │              (剩余空间, maxHeight ∞)    │  │
//   ├──┴───────────────────────────────────────────┴──┤
//   │ EditorBottomToolbar (32pt, 全屏 ⤢)               │
//   └──────────────────────────────────────────────────┘
//
// EditorView 接 `projectId: UUID` + `chapterId: String` (沿派单 §Step 1
// + ChapterSnapshot.id P0-4 真值, NSManagedObjectID URI 稳定 String)。
// 中文项目用 NSManagedObjectID 而非 UUID 当 chapterId 跟 V0-fix-10 /
// LT-N1 全栈对齐。
//
// 派单硬规则 (派单 §Step 1):
//   ✅ 接 projectId: UUID + chapterId: String
//   ✅ TextEditor (@ObservedObject contentStore.content)
//   ✅ onAppear loadChapterContent (调 .load())
//   ✅ onChange(of: content) debounce save (调 .updateContent())
//   ✅ 不带快捷键 (留空, 等项目快完结统一)
//   ✅ FCP 4 角 toolbar MVP (顶 + 底, 沿 designer 拍板)

import SwiftUI

struct EditorView: View {
    let projectId: UUID
    let chapterId: String

    @StateObject private var contentStore: EditorContentStore
    @StateObject private var outlineStore: EditorOutlineStore
    @StateObject private var viewModel: EditorViewModel

    init(projectId: UUID, chapterId: String) {
        self.projectId = projectId
        self.chapterId = chapterId
        _contentStore = StateObject(wrappedValue: EditorContentStore(
            projectId: projectId,
            chapterId: chapterId
        ))
        _outlineStore = StateObject(wrappedValue: EditorOutlineStore(
            projectId: projectId
        ))
        _viewModel = StateObject(wrappedValue: EditorViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopToolbar(
                chapterTitle: activeChapterTitle,
                wordCount: contentStore.wordCount,
                isDirty: contentStore.isDirty
            )
            mainContent
            EditorBottomToolbar(
                isFullScreen: viewModel.isFullScreen,
                onToggleFullScreen: { viewModel.toggleFullScreen() }
            )
        }
        .background(Color(NSColor.textBackgroundColor))
        .task {
            await contentStore.load()
            await outlineStore.load()
        }
        .onDisappear {
            // 切走 / 关 app — 强制 flush pending debounced save
            Task { await contentStore.flush() }
        }
    }

    // MARK: - Subviews

    /// 当前编辑章节标题 (来自 outlineStore 拉的真数据, 找不到 = "未选章节")。
    private var activeChapterTitle: String {
        outlineStore.chapters.first(where: { $0.id == chapterId })?.title ?? "未选章节"
    }

    /// 主内容区: 全屏模式 (专注模式) → 无 sidebar; 否则 → 左 sidebar + 右 TextEditor。
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isFullScreen {
            textEditorView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                EditorOutlineView(
                    selectedChapterID: chapterId,
                    store: outlineStore
                )
                .frame(minWidth: 150, idealWidth: 240, maxWidth: 400)

                textEditorView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// TextEditor 视图 (含 debounced save binding)。
    private var textEditorView: some View {
        TextEditor(text: Binding(
            get: { contentStore.content },
            set: { contentStore.updateContent($0) }
        ))
        .font(.system(size: 17))
        .scrollContentBackground(.hidden)
        .padding(16)
    }
}
