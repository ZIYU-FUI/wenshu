// SidebarZoneHeaderButtons.swift · Wenshu · v1.69
//
// v1.69 sidebar MVVM cleanup (= boss 2026-09-22 OOB '老的文件没
// 删, UI/业务/数据没分离的删掉'): extracted from
// NewLibraryOutlineView.swift (the v0.30 legacy 2520-LOC sidebar
// that packed 8 mixed concerns into one file).
//
// The trailing zone header (= 'New' + 'Import' icon buttons) was
// the chrome that lived on the old sidebar's `zoneHeaderButtons`
// computed view. Used by:
//   - WorkspaceView's legacy `case .projectSidebar` render
//     (= LayoutEditMode split layout zone that is on the sunset path;
//     NavigationSplitShell's AppleSidebarView has its own bottom
//     '+' button via AppleSidebarBottomNewButton).
//   - ZoneModuleView's `case .projectSidebar` (= the legacy 6-zone
//     zone body = the same path as WorkspaceView's).
//
// Lives in its own file (= no domain data, no SwiftUI state
// beyond local hover) so the chrome can be unit-tested in
// isolation (= matches the v1.68b AppleSidebarView MVVM split:
// data = SidebarItem, business = SidebarService, view =
// AppleSidebarView + SidebarRowView + AppleSidebarBottomNewButton
// + this file).

import SwiftUI

/// NewLibraryOutlineView's `zoneHeaderButtons` (= the trailing
/// 'New' + 'Import' icon HStack that sat in the
/// ZoneContentView trailing slot). Same content as the v0.30
/// legacy implementation (= SF Symbols icon buttons + hover
/// tint via system `.buttonStyle(.borderless)`). Both buttons
/// post to AppState/NotificationCenter (= the canonical SwiftUI
/// side-effect surface; = the rest of the app observes via
/// `.onChange(of:)` / `.onReceive`).
///
/// Why HStack-only (= no surrounding chrome):
/// - Trailing slot in ZoneContentView already supplies the
///   horizontal frame + alignment.
/// - Per-button padding + icon size is auto-applied by
///   `.buttonStyle(.borderless)`.
struct SidebarZoneHeaderButtons: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            // New plain Button (= tap increments
            // appState.choiceRequestCount; consumed by the sidebar
            // body listener which presents NewChoiceSheet).
            SidebarZoneHeaderIconButton(
                iconName: "square-plus",
                    help: "New"
                ) {
                    appState.choiceRequestCount += 1
                }
            // Import plain Button (= tap directly fires
            // .wenshuImportRequested notification; consumed by the
            // main app toolbar listener = opens the macOS
            // NSOpenPanel for importing external research
            // materials into the library).
            SidebarZoneHeaderIconButton(
                iconName: "arrow.right.square",
                help: "Import"
            ) {
                NotificationCenter.default.post(
                    name: .wenshuImportRequested,
                    object: nil
                )
            }
        }
    }
}

/// Helper for sidebar zone header icon buttons (= New + Import).
/// Wraps the icon in a Button + .buttonStyle(.borderless) (= the
/// Apple canonical macOS 14+ sidebar / toolbar icon button style
/// = auto-applies hover tint + press tint + Liquid Glass
/// material backdrop on macOS 27). Per call site gets its own
/// hover tracking (= SwiftUI button identity).
private struct SidebarZoneHeaderIconButton: View {
    let iconName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .regular))
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}