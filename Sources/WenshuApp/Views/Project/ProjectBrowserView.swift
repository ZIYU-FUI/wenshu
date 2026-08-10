import SwiftUI

struct ProjectBrowserView: View {
    enum ProjectTab: String, CaseIterable, Identifiable {
        case projects, chapters, settings, resources, kanban
        var id: String { rawValue }
        var title: String { ["项目", "章节", "设定", "资料", "看板"][Self.allCases.firstIndex(of: self)!] }
        var enabled: Bool { self == .projects || self == .chapters }
    }
    @StateObject private var projectStore = ProjectListStore()
    @State private var navPath = NavigationPath()
    @State private var selectedTab: ProjectTab = .projects
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
                case .detail(let id): ProjectDetailView(projectId: id)
                case .chat, .characterWorld: EmptyView()
                }
            }
        }
        .task { await projectStore.load() }
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .projects: ProjectListView(projects: $projectStore.projects, navPath: $navPath)
        case .chapters: ChapterTreeView(projectId: selectedProjectID, store: projectStore.store)
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
