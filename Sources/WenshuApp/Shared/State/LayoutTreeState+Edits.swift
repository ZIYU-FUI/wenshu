// LayoutTreeState+Edits.swift = part of the split tree model, = = moved out of LayoutTreeState.swift.
// The clusters below keep their own comments and their own MARK banners.

import CoreGraphics
import Foundation

// MARK: - Attribute edits (= hermes model.ts lines 507-587)

private func mapGroups(_ node: LayoutNode, _ fn: (GroupNode) -> GroupNode) -> LayoutNode {
    if case let .group(g) = node {
        return .group(fn(g))
    }
    if case let .split(s) = node {
        return .split(SplitNode(
            id: s.id, orientation: s.orientation,
            children: s.children.map { mapGroups($0, fn) }, weights: s.weights
        ))
    }
    return node
}

/// Set the active pane in a group.
func setActivePane(_ root: LayoutNode, groupId: String, paneId: PaneID) -> LayoutNode {
    return mapGroups(root) { g in
        (g.id == groupId && g.panes.contains(paneId)) ? GroupNode(
            id: g.id, panes: g.panes, active: paneId,
            minimized: g.minimized, tabStrip: g.tabStrip
        ) : g
    }
}

/// Reorders a block of panes within a group as one unit (browser-tab
/// order).
func reorderPanesInGroup(
    _ root: LayoutNode,
    groupId: String,
    paneIds ids: [PaneID],
    toIndex: Int
) -> LayoutNode {
    return mapGroups(root) { g in
        guard g.id == groupId, ids.allSatisfy({ g.panes.contains($0) }) else { return g }
        let without = g.panes.filter { !ids.contains($0) }
        let clampedIndex = max(0, min(without.count, toIndex))
        let panes = Array(without[..<clampedIndex]) + ids + Array(without[clampedIndex...])
        return GroupNode(
            id: g.id, panes: panes, active: g.active,
            minimized: g.minimized, tabStrip: g.tabStrip
        )
    }
}

/// Toggles a group's minimized state (= a chevron expands or collapses the
/// group to a header strip).
func setGroupMinimized(_ root: LayoutNode, groupId: String, minimized: Bool) -> LayoutNode {
    return mapGroups(root) { g in
        (g.id == groupId) ? GroupNode(
            id: g.id, panes: g.panes, active: g.active,
            minimized: minimized, tabStrip: g.tabStrip
        ) : g
    }
}

/// Write a zone's standing strip choice; `nil` returns it to auto.
func setGroupTabStrip(_ root: LayoutNode, groupId: String, tabStrip: TabStripMode?) -> LayoutNode {
    return mapGroups(root) { g in
        (g.id == groupId) ? GroupNode(
            id: g.id, panes: g.panes, active: g.active,
            minimized: g.minimized, tabStrip: tabStrip
        ) : g
    }
}

/// Mirrors the layout HORIZONTALLY (the titlebar flip toggle / the
/// command-backslash shortcut): the pane that was on the left is on the
/// right, and it flips everywhere. Its own involution: flipping twice is the
/// identity.
func mirrorTreeHorizontal(_ root: LayoutNode) -> LayoutNode {
    if case .group = root {
        return root
    }
    if case let .split(s) = root {
        let children = s.children.map(mirrorTreeHorizontal)
        if s.orientation == .row {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: children.reversed(),
                weights: s.weights.reversed()
            ))
        }
        return .split(SplitNode(
            id: s.id, orientation: s.orientation,
            children: children, weights: s.weights
        ))
    }
    return root
}

/// Update split weights (= drag-resize weight update).
func setSplitWeights(_ root: LayoutNode, splitId: String, weights: [Double]) -> LayoutNode {
    if case let .split(s) = root {
        if s.id == splitId {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: s.children, weights: weights
            ))
        }
        return .split(SplitNode(
            id: s.id, orientation: s.orientation,
            children: s.children.map { setSplitWeights($0, splitId: splitId, weights: weights) },
            weights: s.weights
        ))
    }
    return root
}

// MARK: - Validation + persisted-tree migration (= hermes model.ts lines 589-650)

/// Migrates a persisted tree onto the current shape (= the hermes
/// `headerHidden` → `tabStrip` retirement).
func migratePersistedTree(_ node: LayoutNode) -> LayoutNode {
    switch node {
    case let .group(g):
        return .group(GroupNode(
            id: g.id, panes: g.panes, active: g.active,
            minimized: g.minimized, tabStrip: g.tabStrip
        ))
    case let .split(s):
        return .split(SplitNode(
            id: s.id, orientation: s.orientation,
            children: s.children.map(migratePersistedTree), weights: s.weights
        ))
    }
}

/// A cheap structural validator for an unknown value (= used to gate the
/// decode). It returns true for both legal split and legal group shapes.
func isLayoutNode(_ value: Any) -> Bool {
    guard let n = value as? [String: Any], let type = n["type"] as? String else {
        return false
    }
    if type == "group" {
        return n["id"] is String && n["panes"] is [Any] && n["active"] is [String: Any]
    }
    if type == "split" {
        guard let orientation = n["orientation"] as? String,
              orientation == "row" || orientation == "column",
              let children = n["children"] as? [Any], !children.isEmpty,
              let weights = n["weights"] as? [Double],
              weights.count == children.count
        else {
            return false
        }
        return weights.allSatisfy { $0.isFinite && $0 > 0 }
    }
    return false
}
