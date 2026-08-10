// ProjectListTab.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Tab 1 = 项目. 沿用 v0.01.0 ProjectListView 范式:
//   - toolbar + 加号 push 进 ProjectCreateView (NavigationStack push,
//     不是 .sheet(isPresented:))
//   - row tap → onSelectProject 回调 (5-tab root 决定怎么联动,
//     LT-03 v2 默认让 settings tab 同步有数据看)
//
// 5-tab root 持有 @State projects + projectsNavPath, 通过 binding 传入。
// 新建项目 push 进 ProjectCreateView, onCreate 调 projects.append +
// pop 回列表 (pop 由 NavigationStack 自动完成)。

import SwiftUI

struct ProjectListTab: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    /// 选中项目回调 — 5-tab root (ProjectManagementView) 收到回调后同步
    /// settingsProject + 可选切到设定 tab。本卡默认不动 activeTab, 由用户
    /// 自己切 tab 去看设定 (装机 user 8/10 拍"清干净"原则: 不替用户决定)。
    var onSelectProject: (ProjectSnapshot) -> Void = { _ in }

    var body: some View {
        NavigationStack(path: $navPath) {
            ProjectListView(projects: $projects, navPath: $navPath)
                .navigationDestination(for: AppRoute.self) { route in
                    ProjectRouteResolver(
                        route: route,
                        projects: $projects,
                        navPath: $navPath,
                        onSelectProject: onSelectProject
                    )
                }
        }
    }
}

/// Resolver extracted as its own View so `navigationDestination` can
/// switch on `route` while still performing side-effects (callback +
/// `navPath.removeLast()`) without tripping SwiftUI's `@ViewBuilder`
/// "Void cannot conform to View" diagnostic.
private struct ProjectRouteResolver: View {
    let route: AppRoute
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath
    let onSelectProject: (ProjectSnapshot) -> Void

    var body: some View {
        Group {
            switch route {
            case .createProject:
                // AGENTS §6 + WO-006~010 历史教训: 新建项目 = push, 不是
                // sheet。 onCreate 回调 append 到 projects, onCancel 让
                // NavigationStack 自动 pop。
                ProjectCreateView(
                    onCreate: { newProject in
                        projects.append(newProject)
                        navPath.removeLast()
                    },
                    onCancel: {
                        navPath.removeLast()
                    }
                )
            case .chat(let project):
                // LT-03 v2 拍板: row tap = select (settings tab 联动),
                // 不强跳 ChatView (LT-04 已独立挂 chat)。 在 ViewBuilder
                // 上下文里不能直接调 closure + removeLast(), 所以包成
                // SelectProjectSink 让 onAppear 触发。
                SelectProjectSink(
                    project: project,
                    onSelect: onSelectProject,
                    onConsumed: {
                        navPath.removeLast()
                    }
                )
            case .characterWorld:
                // v0.01.0 遗留路由, LT-03 v2 不接
                EmptyView()
            }
        }
    }
}

/// Empty view that triggers a side-effect (callback + nav pop) on first
/// appear. We use this for the row-tap → select flow because the
/// `navigationDestination` builder can only return a View, but we want
/// to fire a callback and immediately pop without rendering anything.
private struct SelectProjectSink: View {
    let project: ProjectSnapshot
    let onSelect: (ProjectSnapshot) -> Void
    let onConsumed: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                onSelect(project)
                onConsumed()
            }
    }
}
