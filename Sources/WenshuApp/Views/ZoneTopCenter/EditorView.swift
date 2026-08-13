// EditorView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 中上 (topCenter) 编辑器视图 (DESIGN-LT-N3.md §5.1)。
// 接管 LayoutShellView.topCenter, 渲染顶 toolbar + 章节 sidebar + TextEditor
// + 底 toolbar, 沿 FCP viewer 范式 (28pt 顶 + 32pt 底 + 1pt splitter + 240pt
// 章节 sidebar + 暗色 default)。
//
// 接收:
//   - selectedProjectID: 章节 sidebar 走 EditorOutlineStore.load() 拉项目下章节
//   - selectedChapterID: 切章节时 flush 旧 + 加载新
//
// 状态:
//   - sidebarStore: 中上章节 sidebar (@StateObject, 跟顶 toolbar 共享章节名)
//   - contentStore: 章节正文 store (selectedChapterID 变化时新建, 失焦 flush)
//
// 全屏 (⤢) toggle: 临时隐藏 4 个 panel, 仅本视野展示章节名 + sidebar + TextEditor。
// 沿 FCP viewer 范式 (DESIGN-LT-N3.md §7.3), 通过 LayoutShellView 的 panel
// visibility 切换 (走环境注入的 vm), 不在 EditorView 内自挂 NavigationStack。

import SwiftUI

struct EditorView: View {
    @Binding var selectedProjectID: UUID?
    @Binding var selectedChapterID: String?

    // B+ 重 (t_0f6bd6f6): @StateObject → @State (EditorOutlineStore 已 @Observable).
    @State private var sidebarStore: EditorOutlineStore
    @State private var sidebarStoreProjectId: UUID?
    @State private var contentStore: EditorContentStore?
    @State private var content: String = ""

    // v0.05.0 Zone 协议 (t_8fc5c872) ViewModel 收口 (沿 DECISION §4.2 #4 + DESIGN-Zone.md §7.3):
    // isFullScreen 从 @State 升 @StateObject EditorViewModel, 走 vm.isFullScreen
    // (private(set)) + vm.toggleFullScreen(), write access 收口到 VM 内部。
    // B+ 重 (t_0f6bd6f6): @StateObject → @State (EditorViewModel 已 @Observable).
    @State private var viewModel = EditorViewModel()

    private let projectStore: WenshuProjectStore

    init(
        selectedProjectID: Binding<UUID?>,
        selectedChapterID: Binding<String?>,
        store: WenshuProjectStore = .shared
    ) {
        self._selectedProjectID = selectedProjectID
        self._selectedChapterID = selectedChapterID
        self.projectStore = store
        // 初始 sidebarStore 用占位 projectId (nil), .onChange(of: selectedProjectID)
        // 真正重建。 这样 first paint 不会 nil-crash。
        _sidebarStore = State(wrappedValue: EditorOutlineStore(
            projectId: selectedProjectID.wrappedValue ?? UUID(),
            store: store
        ))
        _sidebarStoreProjectId = State(initialValue: selectedProjectID.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopToolbar(
                chapterTitle: sidebarStore.chapter(withId: selectedChapterID)?.title ?? "未选章节",
                wordCount: contentStore?.wordCount ?? 0
            )
            editorBody
            EditorBottomToolbar(
                isFullScreen: viewModel.isFullScreen,
                onFullScreenToggle: viewModel.toggleFullScreen
            )
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: selectedProjectID) { _, newProjectId in
            guard let projectId = newProjectId else { return }
            // projectId 变化: 重建 sidebarStore (新项目下章节列表)
            if sidebarStoreProjectId != projectId {
                sidebarStoreProjectId = projectId
                Task { await reloadSidebar(for: projectId) }
            }
        }
        .onChange(of: selectedChapterID) { _, newChapterId in
            // chapter 变化: flush 旧 store + 重建新 store
            let oldStore = contentStore
            Task {
                await oldStore?.flush()
                await switchContentStore(to: newChapterId)
            }
        }
        .task {
            // 首次出现: 如果 selectedProjectID 已经选了, 加载 sidebar
            if let projectId = selectedProjectID {
                sidebarStoreProjectId = projectId
                await sidebarStore.load()
            }
            // 首次出现: 如果 selectedChapterID 已经选了, 加载 content
            if let chapterId = selectedChapterID {
                await switchContentStore(to: chapterId)
            }
        }
    }

    // MARK: - Body (sidebar + TextEditor, 全屏时只显示编辑器)

    @ViewBuilder
    private var editorBody: some View {
        if viewModel.isFullScreen {
            fullScreenBody
        } else {
            splitBody
        }
    }

    private var fullScreenBody: some View {
        TextEditor(text: $content)
            .font(.system(size: 17))
            .padding(16)
            .onChange(of: content) { _, new in contentStore?.updateContent(new) }
    }

    private var splitBody: some View {
        HStack(spacing: 0) {
            EditorOutlineView(
                selectedChapterID: $selectedChapterID,
                store: sidebarStore
            )
            Divider()
            textEditorPane
        }
    }

    @ViewBuilder
    private var textEditorPane: some View {
        if let contentStore {
            TextEditor(text: $content)
                .font(.system(size: 17))
                .padding(16)
                .onChange(of: content) { _, new in contentStore.updateContent(new) }
        } else {
            VStack(spacing: 10) {
                // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.docItem
                // (`doc.text`) — 单一真值源。
                Image(systemName: IconLibrary.Action.docItem.symbolName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text("请先选择章节")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("在左侧章节列表中选择一个章节, 或在左上的「章节」tab 新建")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func reloadSidebar(for projectId: UUID) async {
        // 重建 sidebarStore 不可行 (StateObject 一次创建), 走 store.load() 复用
        // 同一 store 实例。 EditorOutlineStore 的 chapters 字段会被 load() 覆盖。
        _ = projectId  // 显式构造时已经 capture
        await sidebarStore.load()
    }

    private func switchContentStore(to chapterId: String?) async {
        guard let chapterId else {
            contentStore = nil
            content = ""
            return
        }
        let newStore = EditorContentStore(chapterId: chapterId, store: projectStore)
        contentStore = newStore
        await newStore.load()
        content = newStore.content
    }
}
