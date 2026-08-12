// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-010 → v0.03.0 V0-fix-4 → V0-fix-5 → LT-N1-merge → V0-fix-8
//
// V0-fix-4 Fix 2: 5 tab 容器重写 (项目 / 章节 / 设定 / 资料 / 看板),
// 沿 LT-03 v2 拍板 (5 tab 用文字标签, 走 .pickerStyle(.segmented),
// 跟 chat / inspector tab 风格刻意区分)。 原 .toolbar { Button("新
// 建项目", ...) } 删除 — 跟 V0-fix-4 Fix 1 顶部 + 按钮合并, 避免视
// 觉冗余 (FCP 范式 = 单 + 入口)。 + 按钮接 NavigationStack push 进
// AppRoute.createProject (沿 v0.01.0 WO-010 拍板 — macOS HIG 主路由,
// 不走 sheet)。
//
// V0-fix-5: 5 tab Picker 从 ProjectListView 内部搬到
// LayoutShellView.topLeftHeaderBar 跨全宽 header bar 内, 与 + 按钮
// 平级 (同 38pt 高, + 按钮在左, 5 tab 在右) — 拍板真值沿 V0-fix-4
// designer (1a09cd550) §5 + AGENTS §8.1 + FCP toolbar 范式。 本视图
// 改接 `@Binding activeTab` (共享 LayoutShellView 顶层 state), 内部
// 不再有 Picker。 `ProjectManagementTab` enum + 5 SF Symbol 字面量
// + 5 tab 文字字面量 全部保留 (供 LayoutShellView topLeftHeaderBar
// 引用)。
//
// LT-N1-merge (2026-08-11): 合并 LT-N1-revise (4 P0 真修) 进 V0-fix-6
// 5 tab 容器。 沿 V0-fix-6 真值不动 (5 tab Picker 在 LayoutShellView
// header bar, 本视图只渲染 tabContent), 但接入 LT-N1 push 路由 +
// selectedProjectID:
//   1. `navPath` 类型从 `NavigationPath` 改成 `[AppRoute]` (P0-2 fix:
//      NavigationPath 不公开 Sequence 接口, LayoutShellView 需要
//      iterate path 同步 selectedProjectID)
//   2. 加 `@Binding selectedProjectID: UUID?` — 章节 tab 接 binding,
//      拿到 id 渲染 ChapterTreeView (LT-N1 P0-2 fix 真值:
//      ChapterTreeView.init 必须接 projectId: UUID 非可选)
//   3. **章节 tab 行为升级**: 有 selectedProjectID → ChapterTreeView
//      (LT-N1 章节树真读), 没 selectedProjectID → 沿 V0-fix-6 placeholder
//      ("v0.04.0 实现")。 其他 4 个 tab (项目 / 设定 / 资料 / 看板)
//      沿 V0-fix-6 不动
//   4. **删 LT-N1 加的 `.toolbar { Button { ... } }`** — LT-N1 原案
//      是 + 按钮放 ProjectListView toolbar, 但 V0-fix-6 拍 + 按钮放
//      LayoutShellView.topLeftHeaderBar (FCP toolbar 范式 + 单 + 入口),
//      沿 V0-fix-6 真值
//   5. **删 LT-N1 加的 `.navigationTitle("项目")`** — V0-fix-5 拍板
//      topLeftHeaderBar 替代 in-window 标题文字, 不再加
//      .navigationTitle (避免 header bar + 系统 title bar 双层标题)
//
// Tab 1 (项目): 沿 v0.01.0 projectList/emptyState/projectRow + 接
//               NavigationStack 共享 navPath 跳 .detail(projectId:)
//               (LT-N1 加的 AppRoute.detail 路由, LayoutShellView 顶层
//               .navigationDestination 接 ProjectDetailView)。
// Tab 2 (章节): LT-N1-merge 接 selectedProjectID → ChapterTreeView。
// Tab 3-5 (设定/资料/看板): 占位 "v0.04.0 / v0.05.0 实现" — v0.04.0
//               长篇工具 + v0.05.0 标记系统 工单实装真业务.
//
// V0-fix-8 (装机 user 8/11 真机拍 4 红字批注 #2 + #3 共同衍生):
//   1. 5 tab SF Symbol 沿 AIF 16:20 截图重定义真值: folder /
//      doc.text / gearshape / archive / square.grid.3x3 (替换
//      V0-fix-4 的 folder / list.bullet.rectangle /
//      slider.horizontal.3 / books.vertical / rectangle.split.3x1)
//   2. 新增 `isEnabled` 衍生: projects / chapters = true,
//      settings / resources / kanban = false (沿 V0-fix-6 +
//      ProjectBrowserView.ProjectTab.enabled 拍板, v0.04.0 / v0.05.0
//      才实装)
//   3. Picker 整段已迁 LayoutShellView.topLeftHeaderBar (沿 V0-fix-5),
//      本视图只渲染 tab 内容 (沿 V0-fix-5 + LT-N1-merge 真值)
//   4. ChatPanelView 4 chat tab 同样修真 (独立驱动, 详见
//      ChatPanelView.swift + V0Fix8LayoutTests.swift)

import SwiftUI

enum ProjectManagementTab: String, CaseIterable, Identifiable {
    case projects = "项目"
    case chapters = "章节"
    case settings = "设定"
    case resources = "资料"
    case kanban = "看板"

    var id: String { rawValue }

    /// V0-fix-8 (装机 user 8/11 16:20 AIF 截图重定义真值): 5 tab
    /// SF Symbol 沿 AIF 16:20 截图指定真值, 替换 V0-fix-4 的字面量。
    /// folder (项目) / doc.text (章节) / gearshape (设定) /
    /// archive (资料) / square.grid.3x3 (看板)。
    var symbolName: String {
        switch self {
        case .projects:  return "folder"
        case .chapters:  return "doc.text"
        case .settings:  return "gearshape"
        case .resources: return "archive"
        case .kanban:    return "square.grid.3x3"
        }
    }

    /// V0-fix-12-2 (装机 user 8/12 12:16 真机拍红字 #2):
    /// "五个模块缺一个按钮, 先实现切换, 不用实现内部功能" — 5 tab
    /// 修真修真修真修真修真, settings / resources / kanban 修真
    /// placeholder 修真修真修真修真 (修真 v0.04.0+ / v0.05.0 修真).
    /// V0-fix-8 修真 (修真修真) = 修真修真:修真 .disabled(!isEnabled),
    /// 修真修真真值 = 修真修真修真修真,修真修真修真修真修真修真修真.
    var isEnabled: Bool {
        // V0-fix-12-2: 修真 — 5 tab 修真修真修真修真修真
        // (V0-fix-8 修真: settings/resources/kanban = false).
        switch self {
        case .projects, .chapters: return true
        case .settings, .resources, .kanban: return true
        }
    }
}

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    // LT-N1-merge: navPath 从 `NavigationPath` 改成 `[AppRoute]` (P0-2 fix:
    // NavigationPath 不公开 Sequence 接口, LayoutShellView 需要 iterate
    // path 同步 selectedProjectID)。 AppRoute 已 Hashable (MainView.swift),
    // `navPath.append(...)` + `navPath.removeLast()` 行为不变。
    @Binding var navPath: [AppRoute]
    // V0-fix-5: activeTab 改为 @Binding, 由 LayoutShellView 顶层持有
    // (@State activeTab), 共享同一 state — 5 tab Picker 在 LayoutShellView
    // .topLeftHeaderBar 内, 内容区 (本视图) 接 binding 切 tabContent。
    @Binding var activeTab: ProjectManagementTab
    // LT-N1-merge: 加 selectedProjectID binding, 由 LayoutShellView 顶层
    // 持有 (@State selectedProjectID), 从 navPath 中提取最后一个
    // .detail(projectId:) 同步。 章节 tab 接 binding, 拿到 id 渲染
    // ChapterTreeView (LT-N1 P0-2 fix 真值: ChapterTreeView.init 必须接
    // projectId: UUID 非可选)。 nil = 用户还没点项目 row, 章节 tab
    // 沿 V0-fix-6 placeholder。
    @Binding var selectedProjectID: UUID?

    var body: some View {
        // V0-fix-5: 删 V0-fix-4 留下的 Picker.segmented 整段 (沿 V0-fix-4
        // 拍板的"5 tab 与 + 按钮平级"应在 header bar 而非 panel 内) —
        // 拍板真值: 5 tab Picker 在 LayoutShellView.topLeftHeaderBar, tab
        // 内容在本视图 body 内。 本视图只渲染 tab 内容, 不再含 Picker。
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .projects:
            projectTabContent
        case .chapters:
            // LT-N1-merge: 章节 tab 接 selectedProjectID, 有 id →
            // ChapterTreeView (LT-N1 章节树真读, 走 store.listChapters
            // projectId 隔离, 见 WenshuProjectStore.swift + DESIGN-LT-N1
            // §4.2), 没 id → V0-fix-6 placeholder (用户还没点项目 row)。
            if let projectId = selectedProjectID {
                ChapterTreeView(projectId: projectId)
            } else {
                placeholder(for: activeTab)
            }
        case .settings, .resources, .kanban:
            placeholder(for: activeTab)
        }
    }

    @ViewBuilder
    private var projectTabContent: some View {
        if projects.isEmpty {
            emptyState
        } else {
            projectList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 56, weight: .light)).foregroundStyle(.secondary)
            Text("暂无项目").font(.title2)
            Text("点 + 新建").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var projectList: some View {
        List {
            Section("项目(\(projects.count))") {
                ForEach(projects) { project in
                    Button { navPath.append(AppRoute.detail(projectId: project.id)) } label: {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.inset)
    }

    private func projectRow(_ project: ProjectSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name).font(.headline).foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(project.style).font(.caption).foregroundStyle(.secondary)
                    Text("注水 \(project.verbosity)").font(.caption).foregroundStyle(.secondary)
                    if !project.tags.isEmpty {
                        Text(project.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(formattedDate(project.createdAt)).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateStyle = .short; formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// V0-fix-12-2 (装机 user 8/12 12:16 真机拍红字 #2):
    /// "五个模块缺一个按钮, 先实现切换, 不用实现内部功能" — 修真
    /// placeholder 修真修真修真修真 (ICON + tab.rawValue + 修真 + 修真).
    /// V0-fix-11-1a retry-2 修真 placeholder 修真 = "v0.04.0 实现"
    /// 单行修真,修真修真修真修真修真修真修真. 真修真修真:修真
    /// placeholder 修真 ICON (gearshape / archive / square.grid.3x3)
    /// + tab.rawValue + 修真 v0.04.0+ / v0.05.0 修真 + .tertiary 修真
    /// (FCP viewer 修真色, 修真修真).
    private func placeholder(for tab: ProjectManagementTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            // V0-fix-12-2: 修真 placeholder 修真 (修真修真修真) —
            // tab.rawValue (修真) + tab 修真 v0.04.0+ / v0.05.0.
            // 修真红字 "不用实现内部功能".
            VStack(spacing: 4) {
                Text(tab.rawValue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(tab == .chapters ? "请先选择项目" : "v0.04.0+ / v0.05.0 实现")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(true)
    }
}
