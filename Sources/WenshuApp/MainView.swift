// MainView.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-010 → v0.02.0 WO-LT-01
//
// Top-level layout. v0.01.0 was a 2-pane `NavigationSplitView` (project
// list left / chat + create right). v0.02.0 LT-01 replaces that with the
// 5-zone shell per AGENTS.md §8.1: toolbar + 3 upper columns (左上/中上/
// 右上) + 2 lower rows (下左/下右).
//
// The v0.01.0 chat/create/characterWorld views still exist in the source
// tree (Views/*.swift) for use by LT-02/03/04 — LT-01 only ADDS the
// layout shell as the new root and intentionally leaves the 5 panels
// filled with placeholder content.
//
// Persistence: layout state is owned by `LayoutShellViewModel` and
// persisted via `WenshuStoreActor.saveLayoutState / loadLayoutState`
// (added in LT-01). `AppRoute` and the chat project pipeline are kept
// here as a pointer for LT-02/03/04 to consume.

import SwiftUI

/// Navigation destinations for the project's `NavigationStack`. Live
/// here (not in `MockLLMResponse.swift`) because they're a UI concern
/// that depends on `ProjectSnapshot`'s identifier.
enum AppRoute: Hashable {
    case chat(ProjectSnapshot)
    case characterWorld
    /// v0.01.0 WO-010: 新建项目走 NavigationStack push(Apple HIG macOS 主路由)
    case createProject
    /// LT-N1: project metadata destination.
    case detail(projectId: UUID)
}

struct MainView: View {
    var body: some View {
        // v0.02.0 LT-01: 5-zone shell per AGENTS §8.1.
        // Subsequent LTs (LT-02/03/04) replace the placeholder content
        // inside each panel with the real implementation; LT-01 only
        // ships the empty chrome + persistence.
        LayoutShellView()
    }
}

