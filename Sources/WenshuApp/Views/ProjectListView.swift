// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004 → WO-010
//
// Right-pane root: the project list. Tapping a row pushes `ChatView`.
// Tapping the + button pushes `ProjectCreateView` via NavigationStack
// (WO-010 — NOT a SwiftUI `.sheet(isPresented:)` container, NOT a
// NSHostingController + 显式 NSWindow either).
//
// 拍板历史:
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

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("项目")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // WO-010:NavigationStack push 进 ProjectCreateView(单 NSWindow 内)。
                    // 见 MainView.swift AppRoute.createProject navigationDestination。
                    // 不需要任何 sheet / NSWindow / makeKey hack。
                    navPath.append(AppRoute.createProject)
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
                .help("新建项目")
            }
        }
    }

    // MARK: - Subviews

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
}
