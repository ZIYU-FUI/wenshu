// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-010 → v0.02.0 LT-03 v2 → v0.03.0 V0-fix-2 (Fix J)
//
// 左上 panel 内容容器 — 5 tab 根 (沿用 v0.02.0 LT-03 v2 设计, 派单 §0.4
// 第 6 条拍板 "改写 ProjectListView, 不新建 ProjectManagement/ 目录")。
//
// 5 tab:
//   1. 项目    — list + create (实装, NavigationStack push)
//   2. 章节    — chapter tree (NavigationStack push 章节详情)
//   3. 设定    — 占位, "v0.04.0 实现" (LT-03 v2 placeholder 沿用)
//   4. 资料    — 占位, "v0.04.0 实现"
//   5. 看板    — 占位, "v0.04.0 实现"
//
// V0-fix-2 Fix J 改动:
//   - 新增 `ProjectManagementTab` enum (case 5 + symbolName 5 + isImplemented + placeholder)
//   - Picker.segmented 5 tab 容器 (跟 ChatPanelView 4 子 tab 同形态)
//   - 5 个 Tab 内容 (内嵌 private var, 不放独立文件)
//   - **删** 现有 `.toolbar { Button("新建项目", ...) }` (跟 Fix I title-bar
//     + 按钮重复, 按 §0.4 第 7 条合并为 1 个 — title-bar 按钮放
//     LayoutShellView.topLeftPanelWithTitleBar, 此处只保留 tab 容器)
//
// 拍板边界:
//   - **不**新建 ProjectManagement/ 目录 (5 tab 内容放 ProjectListView 内部)
//   - **不**接 + 按钮实际 NavigationStack push (Fix I 占位 no-op, 留给后续)
//   - **不**动 @Binding projects / @Binding navPath 签名 (避免越界改 v0.01.0 路由)
//   - Tab 1 走现有 `projectList` (空态 / 列表 / 行), Tab 2-5 占位
//
// 历史 (v0.01.0 WO-004 → WO-010):
// - WO-004:原本是 SwiftUI `.sheet(isPresented:)` 弹 ProjectCreateView。
// - WO-006/007/008/009:四次修 sheet 焦点 bug 全失败(装机 user 实机验)。
//   根因:SwiftPM-only `swift run` + macOS SwiftUI sheet + activation
//   policy 综合问题。
// - WO-010:回到 Apple HIG macOS 主路由范式——新建/打开 = 主路由 push
//   (NavigationStack),设置/偏好才用 sheet。push 是 SwiftUI 标准路由,
//   不需要任何 makeKey / activate hack,装机 user 实机验"键盘输入真进
//   WenshuApp"自然成立。
//
// Per WO-004 spec: project data lives in `@State` in MainView (in-memory).
// No `.ws` round-tripping yet — that's WO-005.

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

    /// Tab 1 + 2 实装 (沿用 LT-03 v2), Tab 3-5 占位 v0.04.0
    var isImplemented: Bool {
        switch self {
        case .projects, .chapters: return true
        case .settings, .resources, .kanban: return false
        }
    }

    var placeholder: String {
        switch self {
        case .projects: return ""
        case .chapters: return ""
        case .settings: return "v0.04.0 实现"
        case .resources: return "v0.04.0 实现"
        case .kanban: return "v0.04.0 实现"
        }
    }
}

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    /// 默认 tab = 项目 (沿用 LT-03 v2 拍板)
    @State private var activeTab: ProjectManagementTab = .projects

    var body: some View {
        VStack(spacing: 0) {
            // V0-fix-2 Fix J: 5 tab 根 Picker.segmented (沿用 LT-03 v2 范式,
            // 跟 ChatPanelView 4 子 tab 同形态). 这里**不**走 .iconOnly —
            // 装机 user 8/10 拍板 "5 tab 用 segmented 文字标签" (LT-03 v2
            // 拍板边界), 跟 4 chat tab + 2 inspector tab 风格刻意区分
            // (项目列表需要用户看清 5 类, chat/inspector 是频繁切换).
            Picker("", selection: $activeTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                        .disabled(!tab.isImplemented)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch activeTab {
                case .projects:
                    projectListTab
                case .chapters:
                    chapterTreeTab
                case .settings:
                    placeholderTab(for: .settings)
                case .resources:
                    placeholderTab(for: .resources)
                case .kanban:
                    placeholderTab(for: .kanban)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tab 1: 项目 (实装, 沿用 v0.01.0 projectList + emptyState)

    private var projectListTab: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无项目")
                .font(.title2)
            Text("点 + 新建")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var projectList: some View {
        List {
            Section("项目(\(projects.count))") {
                ForEach(projects) { project in
                    Button {
                        navPath.append(AppRoute.chat(project))
                    } label: {
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
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(project.style)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("注水 \(project.verbosity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !project.tags.isEmpty {
                        Text(project.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(formattedDate(project.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Tab 2: 章节 (占位, mock 章节树)

    private var chapterTreeTab: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("章节树 v0.04.0 实现")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Tab 3-5: 占位 (v0.04.0)

    private func placeholderTab(for tab: ProjectManagementTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text(tab.placeholder)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .disabled(true)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
