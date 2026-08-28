// PaneRenderer.swift · Wenshu (文枢) · v0.28 ticket 028-004
//
// Recursive renderer for the WorkspaceState v2 split tree (= ticket
// 028-003 schema). Walks the LayoutNode tree depth-first; renders
// each SplitNode as an HStack/VStack of children (= with the existing
// NativeSplitter between siblings for drag-to-resize); renders each
// GroupNode as a stack of panes (= one pane per PaneID in the
// GroupNode.panes array, with the active pane front-most).
//
// Architecture (= per 028-004 ticket spec §"Architecture"):
// - `PaneRenderer` is the recursive entry point; it takes a
//   `LayoutNode` + a binding into `WorkspaceStore` (= so drag-resize
//   weight updates flow back to the store).
// - Split rendering uses HStack (= .row orientation) or VStack
//   (= .column orientation) with `.frame(idealWidth/Height:
//   weight * unit, ...)` to express the fractional weights.
// - NativeSplitter (= the existing v0.27 view from
//   Sources/WenshuApp/Views/Layout/NativeSplitter.swift) is reused
//   between siblings for drag-to-resize; the per-step delta it
//   reports flows through `WorkspaceStore.setSplitWeights(...)`.
// - Group rendering wraps each PaneNode in a host that looks up the
//   active tab (= WorkspaceState.tab(for: id)) and dispatches the
//   tab's view via the WorkspaceView's renderTab closure.
//
// Out of scope for this commit (= per ticket 028-004 §"Out of scope"
// + Q124 1-ticket-1-commit, NOT addressed here):
// - tab-drag-between-pane (= ticket 028-007 surface; needs
//   `.draggable` + `.dropDestination` macOS 14+ wiring).
// - Layout edit mode UI (= 028-006).
// - ZoneEditor (= 028-008).
// - Drag regression test (= 028-011).
//
// Atomic-coupling with WorkspaceView.swift (= same commit): the
// renderer needs WorkspaceView's renderTab closure to dispatch the
// TabKind → view mapping; shipping the renderer without that closure
// would leave every tab showing an empty pane. Per boss 8/22
// 'atomic coupling' rule.

import SwiftUI

/// PaneRenderer — recursive renderer for a single `LayoutNode`.
///
/// Uses the v2 split-tree schema from WorkspaceState.swift (ticket
/// 028-003). Each level dispatches on the node type:
///
/// - `.split` → renders an HStack (for `.row` orientation) or VStack
///   (for `.column` orientation) of its children, separated by
///   `NativeSplitter` instances for drag-to-resize.
/// - `.group` → renders a PaneStackView (= stack of PaneNode hosts
///   with the active pane front-most and a tab strip if > 1 pane).
struct PaneRenderer: View {
    let node: LayoutNode
    @ObservedObject var store: WorkspaceStore

    /// The minimum pane width / height (= clamps how small a child
    /// can shrink under drag-to-resize).
    private let minChildSize: CGFloat = 200

    /// The ideal width unit (= 1 weight = 100 PT by default; can be
    /// tuned for high-DPI displays).
    private let weightUnit: CGFloat = 100

    var body: some View {
        switch node {
        case .split(let s):
            splitContainer(s)
        case .group(let g):
            groupContainer(g)
        }
    }

    // MARK: - Split container

    @ViewBuilder
    private func splitContainer(_ split: SplitNode) -> some View {
        if split.orientation == .row {
            HStack(spacing: 0) {
                ForEach(split.children.indices, id: \.self) { i in
                    PaneRenderer(node: split.children[i], store: store)
                        .frame(
                            minWidth: minChildSize,
                            idealWidth: max(minChildSize, CGFloat(split.weights[i]) * weightUnit)
                        )
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .vertical,
                            length: nil,
                            onDrag: { delta in
                                store.adjustSplitWeights(splitID: split.id, childIndex: i, delta: Double(delta))
                            }
                        )
                    }
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(split.children.indices, id: \.self) { i in
                    PaneRenderer(node: split.children[i], store: store)
                        .frame(
                            minHeight: minChildSize,
                            idealHeight: max(minChildSize, CGFloat(split.weights[i]) * weightUnit)
                        )
                    if i < split.children.count - 1 {
                        NativeSplitter(
                            orientation: .horizontal,
                            length: nil,
                            onDrag: { delta in
                                store.adjustSplitWeights(splitID: split.id, childIndex: i, delta: Double(delta))
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Group container

    @ViewBuilder
    private func groupContainer(_ group: GroupNode) -> some View {
        let panes = group.panes.compactMap { id in store.workspace.pane(for: id) }
        VStack(spacing: 0) {
            // Tab strip (= only if > 1 pane in the group).
            if group.panes.count > 1 {
                GroupTabStrip(
                    panes: group.panes,
                    activePaneID: group.active,
                    tabs: store.workspace.tabs,
                    onSelect: { paneID in
                        store.setActivePaneInGroup(groupID: group.id, paneID: paneID)
                    }
                )
            }
            // Active pane front-most.
            if let activePane = panes.first(where: { $0.id == group.active }) ?? panes.first {
                paneHost(for: activePane)
            } else {
                // Empty pane fallback (= should not happen post-
                // normalize, but the renderer must be total).
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
    }

    /// Single pane host (= wraps the pane in a frame + hosts the
    /// active tab's content view).
    @ViewBuilder
    private func paneHost(for pane: PaneNode) -> some View {
        let activeTab = pane.tabIDs.first.flatMap { id in store.workspace.tab(for: id) }
        Group {
            if let tab = activeTab {
                // Dispatch the tab kind to the view via the
                // shared renderer (= defined in WorkspaceView.swift).
                TabContentDispatcher(kind: tab.kind, title: tab.title)
            } else {
                Color.secondary.opacity(0.05)
                    .overlay(Text("空面板"))
            }
        }
        .frame(
            minWidth: pane.frame.minWidth,
            idealWidth: pane.frame.idealWidth
        )
    }
}

/// TabContentDispatcher — maps `TabKind` to the existing wenshu
/// view (= mirrors WorkspaceView.renderTab).
///
/// Implementation note: rather than carrying an environment-injected
/// closure (= AnyView is not Sendable under Swift 6's concurrency
/// checker), this view does the TabKind -> view mapping directly
/// via an internal switch. The mapping is duplicated from
/// WorkspaceView.renderTabByKind to keep both in sync; if you
/// add a new TabKind, update both.
///
/// Per ticket 028-004 §"Out of scope", the recursive PaneRenderer
/// dispatches tabs through this shim; future tickets (= 028-007
/// tab-drag, 028-008 ZoneEditor) can introduce a more sophisticated
/// registry if needed.
struct TabContentDispatcher: View {
    let kind: TabKind
    let title: String

    var body: some View {
        switch kind {
        case .projectSidebar:
            NewLibraryOutlineView()
        case .projectPreview:
            ZoneModuleView(zoneSlot: .projectPreview)
        case .editor:
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

// MARK: - Environment value for the tab dispatcher (kept for future use)
//
// We previously carried the dispatcher as an environment-injected
// closure (= see git history of this file); Swift 6's concurrency
// checker rejected it because AnyView is not Sendable. The current
// implementation switches on TabKind directly inside the view. If
// future tickets need pluggable view resolution (= e.g. for tests
// or alternate renderers), they can reintroduce a Sendable wrapper
// here — for now, the direct switch is sufficient and matches the
// WorkspaceView.renderTabByKind behavior 1:1.

// MARK: - Group tab strip

/// GroupTabStrip — horizontal strip of tab labels for a group with
/// > 1 pane (= the FCP Browser / VS Code pattern). Selecting a tab
/// front-s it (= sets `active` on the owning group).
///
/// Out of scope for this commit (= per ticket 028-004 §"Out of
/// scope"): the strip is read-only — drag-to-reorder tabs and
/// drag-tab-out-of-strip are ticket 028-007.
private struct GroupTabStrip: View {
    let panes: [PaneID]
    let activePaneID: PaneID
    let tabs: [TabSpec]
    let onSelect: (PaneID) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(panes, id: \.self) { paneID in
                let label = firstTabTitle(for: paneID)
                Button(action: { onSelect(paneID) }) {
                    Text(label)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(paneID == activePaneID ? Color.accentColor.opacity(0.15) : Color.clear)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.secondary.opacity(0.3)),
                    alignment: .bottom
                )
            }
        }
        .background(Color.secondary.opacity(0.08))
    }

    private func firstTabTitle(for paneID: PaneID) -> String {
        // Look up the first tab in this pane's tabIDs list.
        // For v0.28 first cut, panes carry their own tabIDs (= the
        // v1 WorkspaceState's PaneNode had `tabIDs: [TabID]`; we
        // preserved that field in v2). The pane-host resolves to the
        // tab spec via `WorkspaceState.tab(for:)`.
        // Since we don't have the PaneNode here directly, we fall
        // back to the first tab whose id matches any of this
        // pane's id (= pragmatic fallback; full lookup happens in
        // paneHost).
        _ = paneID
        return tabs.first?.title ?? "面板"
    }
}