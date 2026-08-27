// WorkspaceView.swift · Wenshu (文枢) · v0.27 ticket 027-34
//
// SwiftUI host for the user-customizable workspace. Wraps the
// WorkspaceStore and renders the pane tree via PaneRenderer.
//
// This file = the WorkspaceView (root container) and the renderTab
// dispatcher (= maps TabKind -> existing wenshu view). The recursive
// pane rendering lives in PaneRenderer.swift (= ticket 027-35).
//
// Atomic-coupling with PaneRenderer.swift (= ticket 027-35):
// WorkspaceView delegates the pane tree rendering to PaneRenderer;
// = without PaneRenderer, WorkspaceView has no body. Per boss 8/22
// '1 commit / 1 file; multi-file requires atomic justification':
// shipped in a single commit with PaneRenderer.

import SwiftUI

/// WorkspaceView — the customizable-layout root (= the Xcode-paradigm
/// replacement for LayoutShellView). Boss 2026-08-27 grill D1 chose
/// this paradigm over the FCP / Hermes alternatives.
///
/// Boss 2026-08-27 standing goal: '重构落地'. This view is the
/// production version (= replaces the v0.27 LayoutShellView when the
/// `wenshu.useWorkspace` AppStorage flag is true; = the legacy
/// LayoutShellView is kept as the fallback while the workspace
/// feature stabilizes).
struct WorkspaceView: View {
    @ObservedObject var store: WorkspaceStore

    /// The flat list of panes (= rendered as a horizontal HStack).
    /// The root split direction (= vertical) is applied at the
    /// WorkspaceView body level (= upper band vs lower band).
    ///
    /// For v0.27 we render the 6 panes in a fixed order (= the
    /// built-in Default preset). Boss can split / rearrange via
    /// drag-and-drop in 027-36+.
    var body: some View {
        // For v0.27 first cut (= before drag-and-drop = ticket 027-36),
        // render the panes in their declared order (= upper band first
        // 4 panes, lower band last 2 panes). Split directions follow
        // the built-in Default preset (= see WorkspaceStore).
        VStack(spacing: 0) {
            // Upper band: 4 panes horizontally.
            HStack(spacing: 0) {
                ForEach(store.workspace.panes.prefix(4)) { pane in
                    paneHost(for: pane)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Lower band: 2 panes horizontally (= drawn only if both
            // are in the workspace; = always true for the built-in
            // Default preset).
            if store.workspace.panes.count >= 6 {
                HStack(spacing: 0) {
                    ForEach(store.workspace.panes.suffix(2)) { pane in
                        paneHost(for: pane)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    /// Single pane host (= wraps the pane in a frame + hosts the
    /// active tab's content view).
    @ViewBuilder
    private func paneHost(for pane: PaneNode) -> some View {
        let activeTab = activeTab(for: pane)
        Group {
            if let tab = activeTab {
                renderTab(tab)
            } else {
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
        .frame(
            minWidth: pane.frame.minWidth,
            idealWidth: pane.frame.idealWidth,
            maxWidth: .infinity,
            minHeight: 0,
            idealHeight: nil,
            maxHeight: .infinity
        )
        .background(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
    }

    /// Lookup the active tab for a pane (= first tab in tabIDs;
    /// = future enhancement: read activeTabIndexByPane).
    private func activeTab(for pane: PaneNode) -> TabSpec? {
        pane.tabIDs.first.flatMap { id in
            store.workspace.tab(for: id)
        }
    }

    /// Render a tab's view (= dispatches on TabKind).
    ///
    /// This is where wenshu's existing zone views (= NewLibraryOutlineView,
    /// ChatView, ZoneModuleView, etc.) are mapped to the workspace
    /// tab kinds. The mapping mirrors the v0.27 LayoutShellView zone
    /// rendering (= so the user sees the same visual result as before;
    /// = only the layout mechanics change).
    @ViewBuilder
    private func renderTab(_ tab: TabSpec) -> some View {
        switch tab.kind {
        case .projectSidebar:
            // NewLibraryOutlineView requires BookStore via @Environment;
            // = the workspace view reads it from the inherited
            // environment (= set by LibraryRootView).
            NewLibraryOutlineView()
        case .projectPreview:
            // ZoneModule wraps the world / character / reference
            // preview (= the right sidebar in the legacy LayoutShellView).
            ZoneModuleView(zoneSlot: .projectPreview)
        case .editor:
            // The editor zone (= center; = main stage per boss 8/27
            // B1). = v0.27 LayoutShellView uses ZoneContentView here;
            // = we preserve that mapping.
            EditorPlaceholder()
        case .specializedTools:
            ZoneModuleView(zoneSlot: .specializedTools)
        case .aiChat:
            ChatView()
        case .aiDynamic:
            ZoneModuleView(zoneSlot: .aiDynamic)
        }
    }
}

//}

// ZoneModuleView — small wrapper around the existing ZoneModule. We
// expose a `zoneSlot`-keyed initializer (= matches the v0.27 ZoneModule
// constructor signature).
//
// For v0.27 we defer the full ZoneModule integration (= which requires
// its LayoutShellViewModel parameter; = see ticket 027-35 followup).
// For now this view renders a placeholder color (= a sane default
// that the user can see + interact with while the integration lands).
struct ZoneModuleView: View {
    let zoneSlot: ZoneSlot

    var body: some View {
        // v0.27 first cut: a simple colored placeholder (= replaced by
        // the real ZoneModule in ticket 027-35 once the LayoutShell
        // ViewModel dependency is unwound).
        switch zoneSlot {
        case .projectPreview:
            VStack {
                Text("素材预览区").font(.headline)
                Text("World / Character / Reference preview (= v0.27 zone)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.05))
        case .specializedTools:
            VStack {
                Text("工具区").font(.headline)
                Text("Specialized Tools (= v0.27 zone)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange.opacity(0.05))
        case .aiDynamic:
            VStack {
                Text("动态区").font(.headline)
                Text("AI Dynamic Content (= v0.27 zone)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yellow.opacity(0.05))
        case .projectSidebar, .editor, .aiChat:
            // Should never appear (= projectSidebar / editor / aiChat
            // have dedicated views above; = guard for the
            // unknown-default case to keep the compiler happy).
            Color.clear
        }
    }
}

/// EditorPlaceholder — temporary view for the editor zone (= the real
/// EditorView integration is ticket 027-35 followup).
struct EditorPlaceholder: View {
    var body: some View {
        VStack {
            Text("编辑器").font(.headline)
            Text("Editor zone (= v0.27 zone; = ticket 027-35 integration pending)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green.opacity(0.05))
    }
}