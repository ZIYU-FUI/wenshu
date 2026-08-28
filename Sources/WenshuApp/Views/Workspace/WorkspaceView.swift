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
    /// Layout edit mode state (= v0.28 ticket 028-006). Owned by
    /// the view (= fresh per window) so the per-window state stays
    /// self-contained. The hotkey binding lives in
    /// `EditModeHotkey.swift` (= ⌘⇧\ toggle, Escape exit).
    @State private var editMode = LayoutEditMode()

    /// The flat list of panes (= rendered as a horizontal HStack).
    /// The root split direction (= vertical) is applied at the
    /// WorkspaceView body level (= upper band vs lower band).
    ///
    /// For v0.27 we render the 6 panes in a fixed order (= the
    /// built-in Default preset). Boss can split / rearrange via
    /// drag-and-drop in 027-36+.
    var body: some View {
        // v0.28 ticket 028-004 (= this commit): WorkspaceView now
        // delegates to PaneRenderer (= recursive split-tree renderer
        // for the v2 schema from ticket 028-003). The legacy flat-
        // array rendering (= v0.27 LayoutShellView 6-zone shape)
        // is removed; v2 = the only path. The WorkspaceView body
        // is now a thin shim that hands off to PaneRenderer.
        PaneRenderer(node: store.workspace.root, store: store)
            .layoutEditHotkey(editMode)
            .overlay(alignment: .topTrailing) {
                // Edit mode indicator (= shows a small badge in
                // the top-right corner when edit mode is on; the
                // user can click it to toggle off, or press ⌘⇧\).
                if editMode.isEnabled {
                    EditModeBadge(isEnabled: $editMode.isEnabled)
                        .padding(8)
                }
            }
            // v0.28 ticket 028-006: View menu's "Layout edit mode"
            // entry posts this notification (= ⌘⇧\); WorkspaceView
            // listens and flips the LayoutEditMode singleton so the
            // menu and the hotkey share the same state.
            .onReceive(NotificationCenter.default.publisher(for: .wenshuToggleEditMode)) { _ in
                editMode.toggle()
            }
            // v0.28 ticket 028-007: floating TreeEditBar with the
            // LayoutPicker (= preset grid + new-grid button +
            // save-current-as-preset input reveal). Shown only
            // when edit mode is on (= per spec §"Acceptance
            // criteria" #2).
            .overlay {
                if editMode.isEnabled {
                    LayoutEditBar(store: store, editMode: editMode)
                }
            }
    }

    /// Render a tab's view (= dispatches on TabKind). Extracted
    /// from the original `renderTab(_ tab: TabSpec)` to take a bare
    /// `TabKind` (= PaneRenderer's TabContentDispatcher only knows
    /// the kind + title, not the full TabSpec).
    @ViewBuilder
    private func renderTabByKind(_ kind: TabKind) -> some View {
        switch kind {
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

    /// Legacy method kept for backward-compatibility (= no callers
    /// remain after the PaneRenderer refactor, but downstream
    /// extensions may still reference it via the `renderTab`
    /// closure). Forwards to `renderTabByKind` after looking up
    /// the tab spec.
    @ViewBuilder
    private func renderTab(_ tab: TabSpec) -> some View {
        renderTabByKind(tab.kind)
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
/// EditModeBadge — small visual indicator shown in the top-right
/// corner of WorkspaceView when layout edit mode is on. Click to
/// toggle off (= same effect as pressing ⌘⇧\ again).
///
/// Per ticket 028-006 §"Acceptance criteria": the badge is the
/// only edit-mode-related UI shipped in 028-006 (= the TreeEditBar
/// and LayoutPicker are 028-007 / 028-009).
private struct EditModeBadge: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                Text("Layout edit mode")
                    .font(.system(size: 11, weight: .medium))
                Text(HotkeyFormatter.editModeCombo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
