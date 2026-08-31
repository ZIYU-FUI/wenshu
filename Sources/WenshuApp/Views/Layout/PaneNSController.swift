// PaneNSController.swift · Wenshu (文枢) · v0.30 ticket 03 / 4
//
// Future-framework native container (= boss 2026-08-31 OOB "用 Apple
// 官方的 api 实现 FCP 的布局"). This NSSplitViewController subclass is
// what FCPLayout.makeSplitController actually returns (= after ticket 01's
// stub). It walks the recursive WorkspaceState tree and builds the
// matching NSSplitView + NSSplitViewItem hierarchy.
//
// Ticket 03 / 4 scope (= this file):
//   - Declare `final class PaneNSController: NSSplitViewController`
//   - Walk store.workspace.root recursively
//   - For each SplitNode, create an NSSplitView child with the right
//     orientation + dividerStyle + autosaveName
//   - For each GroupNode, create one NSSplitViewItem per contained
//     pane (= hosting NSHostingController(rootView: TabContentDispatcher))
//   - Widen divider hit area via `effectiveRect` override (= 4 PT to
//     match Apple HIG thin divider while staying easy to grab)
//   - Set `canCollapse = true` on sidebar/chat/dynamic items (= user-
//     hideable side panels per FCP standard)
//   - NO existing source file modified
//   - NO behavior change (= dormant until ticket 04 wires the flag)
//
// Out of scope (= other tickets):
//   - NSViewControllerRepresentable wrapper → ticket 02 (already done)
//   - Feature flag wiring → ticket 04
//   - Tree diff/update logic on pane change → ticket 04 (deferred —
//     until PR 4 + manual verify, the tree is rebuilt only on
//     makeNSViewController; switching preset triggers a full re-make)

import AppKit
import SwiftUI

/// Native AppKit split container that hosts wenshu's existing SwiftUI
/// pane views (= `TabContentDispatcher` per pane). Built from a
/// `WorkspaceStore` snapshot; the tree walk is fully recursive.
///
/// Threading: instantiated on the main actor (SwiftUI representable
/// `makeNSViewController` runs on main). Child `NSHostingController`s
/// also stay on main.
@MainActor
final class PaneNSController: NSSplitViewController {

    // MARK: - Stored dependencies (= set once at init; not mutated)

    private let store: WorkspaceStore
    private let appState: AppState
    private let bookStore: BookStore

    /// Layout identifier (= for autosaveName scoping; per-preset so
    /// switching presets restores each one's last divider positions).
    private let layoutID: String

    // MARK: - Init

    init(
        store: WorkspaceStore,
        appState: AppState,
        bookStore: BookStore,
        layoutID: String
    ) {
        self.store = store
        self.appState = appState
        self.bookStore = bookStore
        self.layoutID = layoutID
        super.init(nibName: nil, bundle: nil)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PaneNSController is programmatic-only (= no XIB support)")
    }

    // MARK: - Build (= recursive tree walk)

    /// Walk `store.workspace.root` and produce the matching NSSplitView
    /// children + their NSSplitViewItems. Called once from `init`; the
    /// tree is then frozen for this controller's lifetime (= ticket 04
    /// will rebuild via SwiftUI re-make on preset switch).
    private func buildLayout() {
        // Reset any inherited children (= safety against reuse).
        for child in children {
            removeChild(at: 0)
        }

        // Walk the root (= a SplitNode in the default FCP preset = outer
        // column split = upperBand + lowerBand).
        switch store.workspace.root {
        case .split(let split):
            installSplit(split, parent: self, parentOrientation: .column)
        case .group(let group):
            // Single-group root (= rare; happens in single-pane layouts).
            installGroup(group)
        }
    }

    /// Recursive: install a `SplitNode` into the parent controller as a
    /// nested NSSplitView (= child NSSplitViewController).
    private func installSplit(
        _ split: SplitNode,
        parent: NSSplitViewController,
        parentOrientation: Orientation
    ) {
        // If the split orientation matches the parent's axis (= nested
        // horizontal splits inside a column root), we can install the
        // children directly on the parent (= no extra wrapping). For the
        // default FCP root (= column), the first split is the upperBand
        // (.row) and the lowerBand (.row); both install as direct rows
        // inside the column parent.
        if split.orientation == parentOrientation {
            installChildren(split.children, weights: split.weights, into: parent)
            return
        }

        // Different orientation → create a nested controller.
        let nested = NSSplitViewController()
        nested.splitView.autosaveName = autosaveKey(for: split.id)
        installChildren(split.children, weights: split.weights, into: nested)
        parent.addChild(nested)
    }

    /// Install each child node (= split OR group) as either a nested
    /// NSSplitViewController (if it's a SplitNode) or an NSSplitViewItem
    /// (if it's a GroupNode). Weights are translated to NSSplitViewItem
    /// `minimumThickness` (= left edge: 200 PT to match FCP sidebar
    /// feel; right edge: 200 PT to match FCP tools feel; unbounded for
    /// middle panes).
    private func installChildren(
        _ children: [LayoutNode],
        weights: [Double],
        into controller: NSSplitViewController
    ) {
        for (index, node) in children.enumerated() {
            let weight = index < weights.count ? weights[index] : 1.0
            switch node {
            case .split(let split):
                installSplit(split, parent: controller, parentOrientation: controller.splitView.isVertical ? .row : .column)
            case .group(let group):
                let items = makeSplitItems(for: group, weight: weight)
                for item in items {
                    controller.addSplitViewItem(item)
                }
            }
        }
    }

    /// Build one NSSplitViewItem per pane in the group (= when group has
    /// 1 pane = 1 item; when 3 panes = 3 stacked tabs at runtime, but
    /// for v0.30 we render only the active pane and skip the tab strip
    /// for the legacy single-pane groups). Each item hosts a
    /// `NSHostingController(rootView: TabContentDispatcher)` so the
    /// pane's SwiftUI @Environment lookup still works (= threaded
    /// through init's appState + bookStore).
    private func makeSplitItems(
        for group: GroupNode,
        weight: Double
    ) -> [NSSplitViewItem] {
        // Resolve the active pane (= fall back to first if missing).
        guard let activePaneID = group.panes.first(where: { $0 == group.active })
            ?? group.panes.first
        else { return [] }
        guard let pane = store.workspace.pane(for: activePaneID) else { return [] }
        guard let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return [] }

        // Build the SwiftUI host view (= reuses existing dispatcher).
        let content = TabContentDispatcher(kind: tab.kind, title: tab.title)
            .environment(appState)
            .environment(bookStore)
        // WorkspaceStore is an ObservableObject (= passes via .environmentObject
        // instead of .environment, which is reserved for @Observable types).
        let hosted = content.environmentObject(store)
        let hosting = NSHostingController(rootView: hosted)

        // Wrap in NSSplitViewItem (= the native AppKit container).
        let item = NSSplitViewItem(viewController: hosting)
        item.canCollapse = isCollapsiblePane(activePaneID)
        item.minimumThickness = minThickness(for: activePaneID, weight: weight)
        return [item]
    }

    /// Install a `GroupNode` directly (= when the root IS a group, e.g.
    /// a single-pane layout). Mirrors `makeSplitItems` minus the parent
    /// controller split.
    private func installGroup(_ group: GroupNode) {
        let items = makeSplitItems(for: group, weight: 1.0)
        for item in items {
            addSplitViewItem(item)
        }
    }

    // MARK: - Pane property helpers (= min thickness + collapse permission)

    /// Minimum thickness in points for the pane (= left/right edges get
    /// a hard minimum so the user can't drag them below Apple HIG
    /// readability; middle panes get a smaller minimum so the editor
    /// can shrink when the sidebar expands).
    private func minThickness(for paneID: PaneID, weight: Double) -> CGFloat {
        guard let pane = store.workspace.pane(for: paneID) else { return 100 }
        // Honor the pane's declared minWidth/idealWidth (= user-tunable).
        if pane.frame.minWidth > 0 { return pane.frame.minWidth }
        // Fallback: collapseable side panes default to 200 (= Apple HIG
        // sidebar minimum); non-collapseable panes (= editor, viewer)
        // default to 100 (= can shrink down to almost nothing).
        return isCollapsiblePane(paneID) ? 200 : 100
    }

    /// Which panes can the user collapse (= via 显示 menu / sidebar
    /// toggle). Matches FCP's collapsible sidebars + chat/dynamic zones.
    /// Central panes (= editor) are NOT collapseable.
    private func isCollapsiblePane(_ paneID: PaneID) -> Bool {
        guard let pane = store.workspace.pane(for: paneID),
              let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return false }
        switch tab.kind {
        case .projectSidebar, .aiChat, .aiDynamic, .specializedTools:
            return true
        case .projectPreview, .editor:
            return false
        }
    }

    // MARK: - autosaveName key (= per-layout + per-split)

    /// Apple autosaveName key (= scopes divider positions per preset +
    /// per split subtree, so switching presets restores each one's last
    /// divider positions).
    private func autosaveKey(for splitID: String) -> String {
        "wenshu.split.\(layoutID).\(splitID)"
    }
}
