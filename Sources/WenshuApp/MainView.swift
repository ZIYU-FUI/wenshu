// MainView.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-004
//
// Top-level layout. Two-pane `NavigationSplitView`:
//   - left  sidebar  = 项目 list (kept from WO-001, now shows count)
//   - right detail  = ProjectListView → push ChatView → push CharacterWorldView
//
// WO-004 changes:
// - Detail pane is now a `NavigationStack` rooted at ProjectListView.
// - ChatViewModel is read from the environment (injected by App.swift).
// - The project snapshot array is held in `@State` here (in-memory; WO-005
//   replaces this with a WenshuStoreActor-backed store).
//
// Per WO-004 spec: left sidebar structure is preserved.

import SwiftUI

/// Navigation destinations for the project's `NavigationStack`. Live
/// here (not in `MockLLMResponse.swift`) because they're a UI concern
/// that depends on `ProjectSnapshot`'s identifier.
enum AppRoute: Hashable {
    case chat(ProjectSnapshot)
    case characterWorld
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
