// MainView.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-010
//
// Top-level layout. Two-pane `NavigationSplitView`:
//   - left  sidebar  = 项目 list (kept from WO-001, now shows count)
//   - right detail  = ProjectListView → push ChatView → push CharacterWorldView
//                          → push ProjectCreateView (WO-010)
//
// WO-004 changes:
// - Detail pane is now a `NavigationStack` rooted at ProjectListView.
// - ChatViewModel is read from the environment (injected by App.swift).
// - The project snapshot array is held in `@State` here (in-memory; WO-005
//   replaces this with a WenshuStoreActor-backed store).
//
// WO-010 changes(per spec):
// - WO-006/007/008/009 四次修 sheet 焦点 bug 全失败(装机 user 实机验)。
// - 真根因:SwiftPM-only `swift run` + macOS SwiftUI sheet + activation
//   policy 综合问题,继续在 sheet 层修补 ROI 低。
// - 拍板依据:Apple HIG macOS 主路由,新建项目是**主操作**应该 push
//   不应该 sheet(参考 Pages / Numbers / Finder 范式)。
// - `AppRoute` 加 `.createProject` case,`navigationDestination` 用
//   NavigationStack push(不是 `.sheet(...)` 容器,不需要任何
//   `makeKey` / `activate` hack)。
// - `onCreate` closure:append `projects` + `navPath.removeLast()`(pop 回列表)
// - `onCancel` closure:`navPath.removeLast()`(pop 回列表)
//
// Per WO-004 spec: left sidebar structure is preserved.

import SwiftUI

/// Navigation destinations for the project's `NavigationStack`. Live
/// here (not in `MockLLMResponse.swift`) because they're a UI concern
/// that depends on `ProjectSnapshot`'s identifier.
enum AppRoute: Hashable {
    case chat(ProjectSnapshot)
    case characterWorld
    /// WO-010: 新建项目从 sheet 改回 NavigationStack push(Apple HIG macOS 主路由)。
    /// 不带参数——创建所需的 form state 都在 ProjectCreateView 自己内部管,
    /// 完成后用 onCreate closure 回传一个 `ProjectSnapshot` 给 MainView。
    case createProject
}

struct MainView: View {
    @EnvironmentObject var chatVM: ChatViewModel

    @State private var projects: [ProjectSnapshot] = []
    @State private var navPath: NavigationPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack(path: $navPath) {
                ProjectListView(projects: $projects, navPath: $navPath)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .chat(let project):
                            ChatView(vm: chatVM, project: project, navPath: $navPath)
                        case .characterWorld:
                            CharacterWorldView(vm: chatVM, navPath: $navPath)
                        case .createProject:
                            // WO-010: NavigationStack push(不是 SwiftUI sheet)。
                            // 走标准 SwiftUI 焦点行为,TextField 自动获焦,
                            // 不需要任何 macOS activation policy / makeKey hack。
                            ProjectCreateView(
                                onCreate: { newProject in
                                    projects.append(newProject)
                                    // 刚刚 push 进来的 .createProject 现在 pop 掉,
                                    // 回到 ProjectListView(用户看到新建的项目已在列表)。
                                    if !navPath.isEmpty {
                                        navPath.removeLast()
                                    }
                                },
                                onCancel: {
                                    // 用户取消 → 直接 pop 回列表,不写 projects。
                                    if !navPath.isEmpty {
                                        navPath.removeLast()
                                    }
                                }
                            )
                        }
                    }
            }
        }
    }

    // MARK: - Sidebar (kept from WO-001)

    private var sidebar: some View {
        List {
            Section("项目") {
                Text(sidebarSummary)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("文枢")
        .frame(minWidth: 220)
    }

    private var sidebarSummary: String {
        if projects.isEmpty {
            return "暂无项目"
        } else {
            return "\(projects.count) 个项目"
        }
    }
}
