// ProjectListView.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// Right-pane root: the project list. Tapping a row pushes `ChatView`.
// Tapping the + button presents `ProjectCreateView` as a sheet.
//
// Per WO-004 spec: project data lives in `@State` in MainView (in-memory).
// No `.ws` round-tripping yet — that's WO-005.

import SwiftUI

struct ProjectListView: View {
    @Binding var projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    @State private var showCreate: Bool = false

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
                    showCreate = true
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
                .help("新建项目")
            }
        }
        .sheet(isPresented: $showCreate) {
            ProjectCreateView(
                onCreate: { newProject in
                    projects.append(newProject)
                    showCreate = false
                },
                onCancel: {
                    showCreate = false
                }
            )
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
