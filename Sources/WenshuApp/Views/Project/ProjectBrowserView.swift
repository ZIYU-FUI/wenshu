// ProjectBrowserView.swift · 文枢 (Wenshu) · v0.02.0 LT-N1-cc + LT-N1-revise → LT-N1-merge
//
// LT-N1-merge (2026-08-11): 本视图原本是 LT-N1 派单拍板的 topLeft 容器
// (自挂 NavigationStack + 5 tab Picker + selectedProjectID 同步 + 项目
// store 真读)。 合并进 V0-fix-6 后, 拍板改为 `LayoutShellView.panel(.topLeft)
// = ProjectListView` (V0-fix-6 5 tab 容器, 5 tab Picker 在 LayoutShellView
// .topLeftHeaderBar 内), ProjectBrowserView 不再被引用 — **本视图在运行时
// 是 dead code**, 仅保留以保证编译通过 + 保留 LT-N1 派单原案以备后续派单
// 复用 (例如 v0.04.0 章节树强化 / 看板 5 tab 真读)。 详见 LayoutShellView
// panel(.topLeft) 拍板 comment + LT-N1-merge DESIGN-LT-N1.md §162 沿 V0-fix-6
// 拍板说明。

import SwiftUI

struct ProjectBrowserView: View {
    enum ProjectTab: String, CaseIterable, Identifiable {
        case projects, chapters, settings, resources, kanban
        var id: String { rawValue }
        // P2 fix (LT-N1-revise): switch 全枚举, 避免 [array][firstIndex]! 强解.
        var title: String {
            switch self {
            case .projects: return "项目"
            case .chapters: return "章节"
            case .settings: return "设定"
            case .resources: return "资料"
            case .kanban: return "看板"
            }
        }
        var enabled: Bool { self == .projects || self == .chapters }
    }
    @StateObject private var projectStore = ProjectListStore()
    // P0-2 fix (LT-N1-revise): use `[AppRoute]` instead of `NavigationPath`
    // so we can iterate the path in `syncSelectedProjectID(from:)`.
    // NavigationPath doesn't conform to Sequence publicly. AppRoute is
    // already Hashable (per MainView.swift enum), so NavigationStack(path:)
    // binding works the same.
    @State private var navPath: [AppRoute] = []
    @State private var selectedTab: ProjectTab = .projects
    /// **P0-2 fix (LT-N1-revise, 2026-08-11)**: selectedProjectID was always
    /// `nil` because ProjectListView row-tap only pushes .detail and never
    /// propagates the selection back. Now we observe navPath and extract
    /// the latest `.detail(projectId:)` so the chapters tab has a real id.
    @State private var selectedProjectID: UUID?

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) { ForEach(ProjectTab.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented).padding(8)
                Divider()
                content
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .createProject:
                    ProjectCreateView(onCreate: { snapshot in
                        Task { await projectStore.create(name: snapshot.name, style: snapshot.style, verbosity: snapshot.verbosity, tags: snapshot.tags) }
                        navPath.removeLast()
                    }, onCancel: { navPath.removeLast() })
                case .detail(let id): ProjectDetailView(projectId: id, selectedChapterID: .constant(nil))
                case .chat, .characterWorld: EmptyView()
                }
            }
        }
        .task { await projectStore.load() }
        .onChange(of: navPath) { _, newPath in
            syncSelectedProjectID(from: newPath)
        }
    }

    /// Walk the current NavigationStack path and capture the most recent
    /// `.detail(projectId:)` route into `selectedProjectID`. Called on
    /// every navPath change so row-tap (which only appends to navPath)
    /// implicitly selects the project for the chapters tab.
    private func syncSelectedProjectID(from path: [AppRoute]) {
        var lastDetail: UUID?
        for route in path {
            if case .detail(let id) = route {
                lastDetail = id
            }
        }
        if let id = lastDetail {
            selectedProjectID = id
        }
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .projects:
            // LT-N1-merge: ProjectListView 签名在 merge 后加 activeTab +
            // selectedProjectID binding (V0-fix-6 5 tab 容器真值)。 这里
            // ProjectBrowserView 自管 selectedTab + selectedProjectID,
            // 切到 .projects tab 时把 selectedProjectID 透传 + activeTab
            // 锁 .projects (因为本视图已用 selectedTab 决定走哪个 case)。
            ProjectListView(
                projects: $projectStore.projects,
                navPath: $navPath,
                activeTab: .constant(.projects),
                selectedProjectID: $selectedProjectID
            )
        case .chapters:
            // P0-2 fix: ChapterTreeView now requires non-optional projectId.
            // When no project has been selected yet (user hasn't tapped a
            // row in the projects tab), show a clear "please pick a project"
            // prompt instead of fabricating a UUID or silently empty.
            if let projectId = selectedProjectID {
                ChapterTreeView(projectId: projectId, store: projectStore.store)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
                    Text("请先选择项目").font(.title2)
                    Text("在「项目」tab 中点击一个项目后, 再切到「章节」tab 查看章节树").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            }
        case .settings, .resources, .kanban: PlaceholderTabContent(tab: selectedTab)
        }
    }
}

struct PlaceholderTabContent: View {
    let tab: ProjectBrowserView.ProjectTab
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
            Text(tab.title).font(.title2)
            Text(tab == .kanban ? "v0.04.0 长篇工具 阶段实装" : "v0.05.0 标记系统 阶段实装").font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}
