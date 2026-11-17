//
//  SidebarTreeView.swift · Wenshu
//
//  The sidebar tree: the part's hierarchy, drawn with the app's own
//  expansion state.
//
//  Why: the framework's own outline keeps its expansion inside itself
//  (= a `List(data, children:)` exposes neither the open rows nor a way
//  to open one, = so a row named by a conversation cannot be revealed,
//  = and the open rows are lost on every relaunch). The app keeps the
//  open rows itself: = the rows are drawn with Apple's own disclosure
//  control (= the platform's triangle and row chrome), = and the set of
//  open rows is the app's state (= a conversation that names a row opens
//  the path to it, = and the open rows survive a relaunch).
//

import SwiftUI

/// The sidebar tree (= one part's hierarchy).
struct SidebarTreeView: View {
    /// The part's top-level rows.
    let nodes: [SidebarNode]

    /// The selected row (= the tree's selection binding).
    let selection: Binding<SidebarNode?>

    /// The per-row actions (= the context menu's bag).
    let callbacks: SidebarRowCallbacks?

    @Environment(WorkspaceUIState.self) private var workspaceUI

    var body: some View {
        List(selection: selection) {
            ForEach(nodes) { node in
                SidebarTreeRow(node: node, callbacks: callbacks)
            }
        }
        .listStyle(.sidebar)
        // The path to the selected row opens when the row is asked for
        // (= the conversation names it) and when the rows arrive (= the
        // tree is loaded after the launch's restored selection).
        .onChange(of: workspaceUI.revealRequestCount) { _, _ in revealSelectedPath() }
        .onChange(of: workspaceUI.sidebarSelection) { _, _ in revealSelectedPath() }
        .onChange(of: nodes) { _, _ in revealSelectedPath() }
        .task { revealSelectedPath() }
    }

    /// Open the path to the selected row.
    ///
    /// The path = the rows above the selected row (= the ancestors, =
    /// the rows whose collapsed children hide it). The selected row
    /// itself is not opened (= a selection is not an expansion, = the
    /// disclosure triangle is the only control that opens a row).
    ///
    /// The reveal only ADDS (= the rows the user opened survive, = and
    /// it closes nothing: = a row the user closed comes back when a
    /// selection needs its path again).
    private func revealSelectedPath() {
        let keys = AppleSidebarView.revealExpansionKeys(
            for: workspaceUI.sidebarSelection,
            in: nodes
        )
        workspaceUI.openRows(keys)
    }
}

/// One row of the tree.
///
/// A row with children is a disclosure group (= the platform's triangle
/// opens it); a row without children is a plain row. The row's own tag
/// carries the tree's selection bridge, so a click on the title selects
/// the row and a click on the triangle opens it (= the two controls do
/// not fight each other).
struct SidebarTreeRow: View {
    let node: SidebarNode
    let callbacks: SidebarRowCallbacks?

    @Environment(WorkspaceUIState.self) private var workspaceUI

    var body: some View {
        if let children = node.children, !children.isEmpty, let key = node.expansionKey {
            DisclosureGroup(isExpanded: expansionBinding(for: key)) {
                ForEach(children) { child in
                    SidebarTreeRow(node: child, callbacks: callbacks)
                }
            } label: {
                SidebarRowView.rowContent(for: node)
                    .modifier(SidebarRowView.PerRowContextMenu(node: node, callbacks: callbacks))
            }
            .tag(node)
        } else {
            SidebarRowView(node: node, callbacks: callbacks)
        }
    }

    /// Whether the row is open.
    ///
    /// The set is read while the body is evaluated (= so the observable
    /// registers the dependency there, = and the row redraws when the
    /// set changes), = and the binding reads the set AGAIN (= a row the
    /// framework kept across a render pass must see the CURRENT
    /// state, = not the snapshot this call captured).
    private func expansionBinding(for key: SidebarItem) -> Binding<Bool> {
        _ = workspaceUI.expandedSidebarRows
        return Binding(
            get: { workspaceUI.expandedSidebarRows.contains(key) },
            set: { isExpanded in
                var updated = workspaceUI.expandedSidebarRows
                if isExpanded {
                    updated.insert(key)
                } else {
                    updated.remove(key)
                }
                workspaceUI.expandedSidebarRows = updated
            }
        )
    }
}
