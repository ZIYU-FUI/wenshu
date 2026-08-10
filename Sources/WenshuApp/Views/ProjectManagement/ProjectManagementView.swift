// ProjectManagementView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Left-top panel of the 5-zone shell (AGENTS.md §8.1). 5-tab root:
//   1. 项目    — list + create (实装, NavigationStack push)
//   2. 章节    — chapter tree (NavigationStack push 章节详情)
//   3. 设定    — read-only ProjectSnapshot fields (v0.01.0)
//   4. 资料    — 占位, "v0.04.0 实现"
//   5. 看板    — 占位, 最小信息 "项目: 章节 N + 设定 M"
//
// 拍板 (v0.02.0 LT-03 v2, 装机 user 8/10 拍 "清干净" 重派):
// - **不**用 .sheet(isPresented:) — WO-006~010 5 个 sheet 焦点 bug 全废
//   (AGENTS.md §6), 新建/打开走 NavigationStack push
// - 默认 tab = 项目 (tabIndex 0)
// - 沿用 ChatPanelView 4 子 tab 范式 (Picker(.segmented) + content),
//   但本卡 5 tab, 每 tab 自带 NavigationStack 避免 path 互相污染
//
// 已知边界 (本卡不修, 真根因已记):
// - projects/navPath 状态由本 view 持有, **不**挂 .ws (AGENTS §7 +
//   §5 "PM 改 .ws schema" 红线)。 装机 user 实机验: 杀进程后 projects
//   列表会清空, 这是 v0.02.0 LT-03 v2 的拍板边界, 后续 WO-005 接入
//   WenshuProjectStore 后持久化。
// - 章节 / 设定 / 资料 / 看板 tab 用 mock 数据, 不读 CDChapter /
//   CDNote — 真路径接 .ws 是 PM-direct 拍板, CC 不动 schema (AGENTS §5)。

import SwiftUI

enum ProjectManagementTab: String, CaseIterable, Identifiable {
    case projects = "项目"
    case chapters = "章节"
    case settings = "设定"
    case resources = "资料"
    case kanban = "看板"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .projects: return "folder"
        case .chapters: return "list.bullet.rectangle"
        case .settings: return "slider.horizontal.3"
        case .resources: return "books.vertical"
        case .kanban: return "rectangle.split.3x1"
        }
    }

    /// Tab 1 + 2 实装, Tab 3-5 占位 (v0.02.0 拍板边界)
    var isImplemented: Bool {
        switch self {
        case .projects, .chapters: return true
        case .settings, .resources, .kanban: return false
        }
    }

    /// Tab 3-5 占位文案
    var placeholder: String {
        switch self {
        case .projects: return ""
        case .chapters: return ""
        case .settings: return "v0.01.0 ProjectSnapshot 字段只读展示"
        case .resources: return "v0.04.0 实现"
        case .kanban: return "v0.04.0 实现"
        }
    }
}

struct ProjectManagementView: View {
    /// Tab 1 (项目) 共享 projects 状态 — 项目 tab 创建 / 进入详情
    /// 改这个 binding, 其他 tab 也跟着看到。
    @State private var projects: [ProjectSnapshot] = []

    /// Tab 1 + 2 各自的 NavigationStack path — 避免 path 互相污染
    /// (ChatPanelView 用同款做法, 见 ChatPanelView.swift)
    @State private var projectsNavPath = NavigationPath()
    @State private var chaptersNavPath = NavigationPath()

    /// Tab 3 (设定) 当前选中的 project (只读展示 ProjectSnapshot 字段)。
    /// 由 ProjectListTab 的 onSelectProject 回调更新。
    @State private var settingsProject: ProjectSnapshot?

    /// 默认 tab = 项目 (装机 user 8/10 拍板)
    @State private var activeTab: ProjectManagementTab = .projects

    var body: some View {
        VStack(spacing: 0) {
            Picker("项目管理视图", selection: $activeTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch activeTab {
                case .projects:
                    ProjectListTab(
                        projects: $projects,
                        navPath: $projectsNavPath,
                        onSelectProject: { settingsProject = $0 }
                    )
                case .chapters:
                    ChapterTreeTab(
                        projects: projects,
                        navPath: $chaptersNavPath
                    )
                case .settings:
                    ProjectSettingsTab(project: settingsProject)
                case .resources:
                    ResourceLibraryTab()
                case .kanban:
                    ProjectKanbanTab(projectCount: projects.count)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
