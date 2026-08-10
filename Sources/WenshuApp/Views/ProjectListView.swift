// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-010 → v0.03.0 V0-fix-4 → V0-fix-6
//
// V0-fix-4 Fix 2: 5 tab 容器重写 (项目 / 章节 / 设定 / 资料 / 看板),
// 沿 LT-03 v2 拍板 (5 tab 用文字标签, 走 .pickerStyle(.segmented),
// 跟 chat / inspector tab 风格刻意区分)。 原 .toolbar { Button("新
// 建项目", ...) } 删除 — 跟 V0-fix-4 Fix 1 顶部 + 按钮合并, 避免视
// 觉冗余 (FCP 范式 = 单 + 入口)。 + 按钮接 NavigationStack push 进
// AppRoute.createProject (沿 v0.01.0 WO-010 拍板 — macOS HIG 主路由,
// 不走 sheet)。
//
// V0-fix-6 Fix 2 (B5 装机 user 8/10 17:35 OOB): 5 tab Picker 内容
// `Text(tab.rawValue)` → `Image(systemName: tab.symbolName)` (文字标签
// 改 ICON-only, 跟标题栏 iconOnly Picker 视觉一致)。 pickerStyle
// 保持 `.segmented` (跟 chat / inspector tab 风格刻意区分 — 沿用
// LT-03 v2 拍板, v0.04.0 才下沉标题栏版, 本期只 ICON 化)。
//
// V0-fix-6 Fix 5 (B5): 5 tab activeTab state 由 LayoutShellView 顶层
// 持有 (@State), @Binding 传 ProjectListView — 标题栏 iconOnly Picker
// 跟 ProjectListView segmented Picker 共享 activeTab state (FCP
// toolbar 范式)。
//
// Tab 1 (项目): 沿 v0.01.0 projectList/emptyState/projectRow + 接
//               NavigationStack 共享 navPath 跳 chat (下左 ChatPanelView)。
// Tab 2-5: 占位 "v0.04.0 实现" — v0.04.0 长篇工具工单实装真业务。

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
}

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath
    // V0-fix-6 Fix 5: activeTab state 顶层持有 (LayoutShellView), 标题栏
    // iconOnly Picker + 此处 segmented Picker 共享同一 @Binding — FCP
    // toolbar 范式 (两处切换同步)。
    @Binding var activeTab: ProjectManagementTab

    var body: some View {
        VStack(spacing: 0) {
            // V0-fix-6 Fix 2: 5 tab Picker 内容改 Image SF Symbol
            // (原 `Text(tab.rawValue)` 文字标签), pickerStyle 保持
            // `.segmented` (沿用 LT-03 v2 拍板, 不动风格)。 标题栏
            // 已有同 activeTab 的 iconOnly Picker, 两处共享 @Binding。
            Picker("", selection: $activeTab) {
                ForEach(ProjectManagementTab.allCases) { tab in
                    Image(systemName: tab.symbolName)
                        .tag(tab)
                        .help(tab.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            tabContent
                .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .projects:
            projectTabContent
        case .chapters, .settings, .resources, .kanban:
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func placeholder(for tab: ProjectManagementTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("v0.04.0 实现")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(true)
    }
}
