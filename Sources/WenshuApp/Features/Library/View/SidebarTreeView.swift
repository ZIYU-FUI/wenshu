//
//  SidebarTreeView.swift · Wenshu
//
//  The sidebar tree: the part's hierarchy, drawn with the app's own
//  expansion state.
//
//  Why: the framework's own outline keeps its expansion inside itself
//  (= a `List(data, children:)` exposes neither the open rows nor a way
//  to open one, = so a row named by a conversation cannot be revealed,
//  and the open rows are lost on every relaunch). The app keeps the
//  open rows itself: = the rows are drawn with Apple's own disclosure
//  control (= the platform's triangle and row chrome), = and the set of
//  open rows is the app's state (= a conversation that names a row opens
//  the path to it, = and the open rows survive a relaunch).
//

import SwiftUI

/// One row of the tree (= the row, = and the row's drawing identity).
///
/// ⇒ ⇒ ⇒ THE ROW CARRIES ITS OWN DRAWING IDENTITY: = the rows are
/// compared by their OWN data, = so two trees that differ only BELOW
/// the top compare equal, = and the tree that holds them would never
/// read them again (= the rows under the user would keep the text they
/// had). = ⇒ ⇒ ⇒ The entry is the row plus the digest of its subtree,
/// = so a row whose subtree changed is a NEW entry (= the tree draws it
/// again), = and a row whose subtree did not change is the SAME entry
/// (= the tree does not destroy the row under the user).
struct SidebarTreeEntry: Identifiable, Equatable {
    /// The row itself.
    let node: SidebarNode

    /// The row's drawing identity (= the digest of the row's subtree).
    let drawIdentity: String

    init(node: SidebarNode) {
        self.node = node
        drawIdentity = node.drawIdentity
    }

    /// The row's stable key (= the row's own id, = so the row keeps its
    /// place in the tree when its content changes).
    var id: UUID {
        node.id
    }

    /// ⇒ ⇒ ⇒ THE ENTRY'S EQUALITY IS ITS DRAWING IDENTITY: = the row's
    /// own data did not change when a book appeared under the shelf, =
    /// so the row compared EQUAL, = so the tree kept the row it had
    /// drawn, = and the book under it never appeared.
    static func == (lhs: SidebarTreeEntry, rhs: SidebarTreeEntry) -> Bool {
        lhs.drawIdentity == rhs.drawIdentity
    }

    /// The rows of a tree (= each with its own drawing identity).
    static func entries(of nodes: [SidebarNode]) -> [SidebarTreeEntry] {
        nodes.map(SidebarTreeEntry.init(node:))
    }
}

/// The sidebar tree (= one part's hierarchy).
struct SidebarTreeView: View {
    /// The part's tree (= the rows, = and the tree's shape).
    ///
    /// ⇒ ⇒ ⇒ THE VIEW HOLDS THE TREE, = NOT THE ROWS: = the rows
    /// compare by their OWN data, = so a tree whose rows differ only
    /// BELOW the top compares EQUAL, = and the view would never read
    /// the new rows (= the rows under the user would keep the text
    /// they had). = ⇒ ⇒ ⇒ The tree carries its shape (= the digest of
    /// every row's subtree), = so a tree that changed is a NEW tree
    /// (= the view draws it again), = and a tree that did not change is
    /// the same tree (= the view does not destroy the row under the
    /// user).
    let tree: SidebarTree

    /// The selected row (= the tree's selection binding).
    let selection: Binding<SidebarNode?>

    /// The per-row actions (= the context menu's bag).
    let callbacks: SidebarRowCallbacks?

    @Environment(WorkspaceUIState.self) private var workspaceUI

    /// The tree, hosted (= the rows carry their own drawing identity
    /// from here, = so the view and the rows it draws can never
    /// disagree about it).
    init(
        tree: SidebarTree,
        selection: Binding<SidebarNode?>,
        callbacks: SidebarRowCallbacks?
    ) {
        self.tree = tree
        self.selection = selection
        self.callbacks = callbacks
    }

    var body: some View {
        List(selection: selection) {
            ForEach(SidebarTreeEntry.entries(of: tree.nodes)) { entry in
                SidebarTreeRow(node: entry.node, callbacks: callbacks)
                    // ⇒ ⇒ ⇒ THE ROW IS DRAWN BY ITS SUBTREE'S SHAPE:
                    // = the row's own data did not change when a book
                    // appeared under the shelf, = so the row compared
                    // EQUAL, = so the tree kept the row it had drawn, =
                    // and the book under it never appeared. = ⇒ ⇒ ⇒ The
                    // identity the row is drawn by carries the
                    // subtree's content, = so a changed subtree is a
                    // changed row (= the subtree is drawn again), = and
                    // an unchanged subtree is the same row (= the tree
                    // does not destroy the row under the user).
                    .id(entry.drawIdentity)
            }
        }
        .listStyle(.sidebar)
        // The path to the selected row opens when the row is asked for
        // (= the conversation names it) and when the rows arrive (= the
        // tree is loaded after the launch's restored selection).
        .onChange(of: workspaceUI.revealRequestCount) { _, _ in revealSelectedPath() }
        .onChange(of: workspaceUI.sidebarSelection) { _, _ in revealSelectedPath() }
        .onChange(of: tree) { _, _ in revealSelectedPath() }
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
            in: tree.nodes
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
                ForEach(SidebarTreeEntry.entries(of: children)) { entry in
                    SidebarTreeRow(node: entry.node, callbacks: callbacks)
                        // ⇒ ⇒ ⇒ THE CHILD IS DRAWN BY ITS OWN SHAPE:
                        // = the same rule the top level follows, = so a
                        // child whose subtree changed is drawn again (= a
                        // grandchild that appeared under it is drawn
                        // with it).
                        .id(entry.drawIdentity)
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
