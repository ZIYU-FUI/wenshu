// ProjectDetailView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 项目详情视图 (沿 v0.02.0 LT-N1 + LT-N3 修真):
//
// 拍板真值 (DESIGN-LT-N3.md §3.2 + 派单 §Step 4):
//   ✅ 5 tab Picker.segmented (项目 / 章节 / 设定 / 资料 / 看板) — 沿
//      LT-N1 P0-1 拍板, 不用 TabView (reviewer §3.1.1 P0 阻塞)
//   ✅ 章节 tab 接 selectedChapterID state + 章节 row.onTapGesture
//      { selectedChapterID = chapter.id; navPath.append(.chapter(...)) }
//   ✅ NavigationStack (path: $navPath) push EditorView (projectId +
//      chapterId) — 沿派单 §Step 4 路由, 不动 LayoutShellView
//   ✅ EditorRoute enum (本地路由, 不动 AppRoute / LayoutShellView)
//
// 路由 (DESIGN-LT-N3 §3.2 派生 — 派单 §Step 4 真接):
//   - 用户在「章节」tab 点 row →
//     1. selectedChapterID = chapter.id (本地 @State, 章节 row 高亮)
//     2. navPath.append(.chapter(chapterId: chapter.id)) (push EditorView)
//   - EditorView 在内层 NavigationStack 渲染, 自管 content
//   - 出 EditorView (返回 back) → selectedChapterID 持续留存 (重新进入
//     时 EditorView 重新 init, 重新 loadChapterContent; 选中状态留存
//     给后续 v0.04.0 章节 tab 状态伸展)
//
// 不动 (派单 §边界):
//   - WenshuStoreActor / WenshuProjectStore 主文件 / CoreData entity
//   - Package.swift / Info.plist
//   - V0-fix-7/8/9/10/11 已重做的 view (LayoutShellView / ProjectListView /
//     ChatView / ProjectBrowserView)

import SwiftUI

enum EditorRoute: Hashable {
    case chapter(chapterId: String)
}

struct ProjectDetailView: View {
    let projectId: UUID
    @State private var selectedTab = 0
    /// 当前选中章节 (章节 tab row tap 设置, 跟 EditorView 路由联动)
    @State private var selectedChapterID: String?
    /// 内层 NavigationStack 路由 (push EditorView)
    @State private var navPath: [EditorRoute] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("项目").tag(0)
                    Text("章节").tag(1)
                    Text("设定").tag(2)
                    Text("资料").tag(3)
                    Text("看板").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                tabContent
            }
            .navigationTitle("项目详情")
            .navigationDestination(for: EditorRoute.self) { route in
                switch route {
                case .chapter(let chapterId):
                    EditorView(projectId: projectId, chapterId: chapterId)
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            Text("项目 \(projectId.uuidString)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case 1:
            // 章节 tab: ChapterListView (本地 mini-view, 章节 row 写
            // selectedChapterID + push EditorView)。
            ChapterListView(
                projectId: projectId,
                selectedChapterID: $selectedChapterID,
                onSelect: { chapterId in
                    selectedChapterID = chapterId
                    navPath.append(.chapter(chapterId: chapterId))
                }
            )
        default:
            Text("此功能将在后续阶段开放")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - ChapterListView (本地 mini-view, 章节 tab 内容)
//
// 沿 ChapterTreeView 范式但接 selectedChapterID binding + onSelect callback
// (ProjectDetailView 持有 selectedChapterID state + navPath, 本 view push
// EditorView)。 不修真 ChapterTreeView (LT-N1 真值, ProjectListView 章节
// tab 用)。
//
// 修真 vs LT-N1 ChapterTreeView:
//   - 加 @Binding selectedChapterID: 章节 row 高亮
//   - 加 onSelect: (String) -> Void — 章节 row tap 触发
//   - 删 toolbar (ProjectDetailView 已有 5 tab Picker, 不重复)

private struct ChapterListView: View {
    let projectId: UUID
    @Binding var selectedChapterID: String?
    let onSelect: (String) -> Void

    @StateObject private var store: ChapterTreeStore

    init(
        projectId: UUID,
        selectedChapterID: Binding<String?>,
        onSelect: @escaping (String) -> Void
    ) {
        self.projectId = projectId
        self._selectedChapterID = selectedChapterID
        self.onSelect = onSelect
        _store = StateObject(wrappedValue: ChapterTreeStore(projectId: projectId))
    }

    var body: some View {
        Group {
            if store.chapters.isEmpty {
                emptyState
            } else {
                List(selection: $selectedChapterID) {
                    ForEach(store.chapters) { chapter in
                        ChapterListRow(
                            chapter: chapter,
                            isActive: chapter.id == selectedChapterID
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(chapter.id)
                        }
                        .tag(chapter.id as String?)
                    }
                }
                .listStyle(.inset)
            }
        }
        .task(id: projectId) {
            await store.load()
        }
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
    }
}

private struct ChapterListRow: View {
    let chapter: ChapterSnapshot
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "doc.text.fill" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title).font(.headline)
                Text("第 \(chapter.index) 章 · \(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
