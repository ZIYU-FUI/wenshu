// LayoutTreeState+Operations.swift = part of the split tree model, = = moved out of LayoutTreeState.swift.
// The clusters below keep their own comments and their own MARK banners.

import CoreGraphics
import Foundation

// MARK: - Queries (= hermes model.ts lines 89-147)

/// Recursive lookup: returns the group with `groupId`, or nil.
func findGroup(_ node: LayoutNode, groupId: String) -> GroupNode? {
    if case let .group(g) = node {
        return g.id == groupId ? g : nil
    }
    if case let .split(s) = node {
        for child in s.children {
            if let hit = findGroup(child, groupId: groupId) {
                return hit
            }
        }
    }
    return nil
}

/// Recursive lookup: returns the group containing `paneId`, or nil.
func findGroupOfPane(_ node: LayoutNode, paneId: PaneID) -> GroupNode? {
    if case let .group(g) = node {
        return g.panes.contains(paneId) ? g : nil
    }
    if case let .split(s) = node {
        for child in s.children {
            if let hit = findGroupOfPane(child, paneId: paneId) {
                return hit
            }
        }
    }
    return nil
}

/// All pane IDs in the tree (= DFS-flattened leaf order).
func allPaneIDs(_ node: LayoutNode) -> [PaneID] {
    switch node {
    case let .group(g): return g.panes
    case let .split(s): return s.children.flatMap { allPaneIDs($0) }
    }
}

/// The split whose DIRECT child carries `childId`, or nil.
func findParentSplit(_ node: LayoutNode, childId: String) -> SplitNode? {
    if case let .split(s) = node {
        if s.children.contains(where: { $0.id == childId }) {
            return s
        }
        for child in s.children {
            if let hit = findParentSplit(child, childId: childId) {
                return hit
            }
        }
    }
    return nil
}

// MARK: - normalize (= hermes model.ts lines 153-217)

/// Returns nil when the tree is fully empty.
func normalize(_ node: LayoutNode) -> LayoutNode? {
    if case let .group(g) = node {
        if g.panes.isEmpty {
            return nil
        }
        // active must reference a pane that still exists; if not, fall
        // back to the first.
        let active = g.panes.contains(g.active) ? g.active : g.panes[0]
        if active == g.active {
            return node
        }
        return .group(GroupNode(
            id: g.id, panes: g.panes, active: active,
            minimized: g.minimized, tabStrip: g.tabStrip
        ))
    }
    if case let .split(s) = node {
        var children: [LayoutNode] = []
        var weights: [Double] = []
        for (i, child) in s.children.enumerated() {
            guard let kept = normalize(child) else { continue }
            // Flatten same-orientation nesting: distribute this slot's
            // weight across the flattened children proportionally.
            if case let .split(inner) = kept, inner.orientation == s.orientation {
                let total = inner.weights.reduce(0, +)
                let totalSafe = total > 0 ? total : 1
                for (j, grandchild) in inner.children.enumerated() {
                    children.append(grandchild)
                    let slotWeight = s.weights[s.weights.index(s.weights.startIndex, offsetBy: i, limitedBy: s.weights.endIndex).flatMap { $0 < s.weights.endIndex ? $0 : nil } ?? 0]
                    let grandWeight = inner.weights[inner.weights.index(inner.weights.startIndex, offsetBy: j, limitedBy: inner.weights.endIndex).flatMap { $0 < inner.weights.endIndex ? $0 : nil } ?? 0]
                    weights.append(slotWeight * (grandWeight / totalSafe))
                }
                continue
            }
            children.append(kept)
            let slotWeight = s.weights[s.weights.index(s.weights.startIndex, offsetBy: i, limitedBy: s.weights.endIndex).flatMap { $0 < s.weights.endIndex ? $0 : nil } ?? 0]
            weights.append(slotWeight)
        }
        if children.isEmpty {
            return nil
        }
        if children.count == 1 {
            return children[0]
        }
        return .split(SplitNode(
            id: s.id, orientation: s.orientation, children: children, weights: weights
        ))
    }
    return nil
}

// MARK: - removePane (= hermes model.ts lines 219-241)

/// Removes a pane from the tree. The pane that was removed last falls back
/// to the same rule the terminals and the preview rail use.
func removePane(_ node: LayoutNode, paneId: PaneID) -> LayoutNode? {
    func walk(_ n: LayoutNode) -> LayoutNode {
        if case let .group(g) = n {
            guard let at = g.panes.firstIndex(of: paneId) else { return n }
            let panes = g.panes.filter { $0 != paneId }
            let fallbackIndex = min(at, max(0, panes.count - 1))
            let newActive: PaneID = (g.active == paneId) ? (panes.indices.contains(fallbackIndex) ? panes[fallbackIndex] : PaneID()) : g.active
            return .group(GroupNode(
                id: g.id, panes: panes, active: newActive,
                minimized: g.minimized, tabStrip: g.tabStrip
            ))
        }
        if case let .split(s) = n {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: s.children.map(walk), weights: s.weights
            ))
        }
        return n
    }
    return normalize(walk(node))
}

// MARK: - insertAtGroup (= hermes model.ts lines 243-301)

/// Inserts a pane into a group. The group becomes empty when the pane that
/// was its last one leaves.
func insertAtGroup(
    _ node: LayoutNode,
    targetGroupId: String,
    paneId: PaneID,
    pos: DropPosition,
    before: PaneID? = nil,
    activate: Bool = true,
    edgeWeights: (Double, Double)? = nil
) -> LayoutNode? {
    func walk(_ n: LayoutNode) -> LayoutNode {
        if case let .group(g) = n {
            guard g.id == targetGroupId else { return n }
            if pos == .center {
                let at: Int = {
                    if let b = before, let i = g.panes.firstIndex(of: b) {
                        return i
                    }
                    return -1
                }()
                let panes: [PaneID] = at >= 0
                    ? Array(g.panes[..<at]) + [paneId] + Array(g.panes[at...])
                    : g.panes + [paneId]
                let newActive: PaneID = (activate || g.panes.isEmpty) ? paneId : g.active
                return .group(GroupNode(
                    id: g.id, panes: panes, active: newActive,
                    minimized: g.minimized, tabStrip: g.tabStrip
                ))
            }
            let orientation: Orientation = (pos == .left || pos == .right) ? .row : .column
            let leading = (pos == .left || pos == .top)
            let added = makeGroup(panes: [paneId])
            let children: [LayoutNode] = leading ? [added, n] : [n, added]
            let (targetWeight, addedWeight) = edgeWeights ?? (1, 1)
            let weights: [Double] = leading ? [addedWeight, targetWeight] : [targetWeight, addedWeight]
            return makeSplit(orientation: orientation, children: children, weights: weights)
        }
        if case let .split(s) = n {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: s.children.map(walk), weights: s.weights
            ))
        }
        return n
    }
    return normalize(walk(node))
}

// MARK: - movePane + movePanes (= hermes model.ts lines 303-416)

/// A signature of the tree's shape: the ordered list of node ids.
private func shapeSignature(_ node: LayoutNode) -> String {
    if case let .group(g) = node {
        return g.panes.isEmpty ? "" : "[" + g.panes.map { $0.raw.uuidString }.joined(separator: ",") + "]"
    }
    if case let .split(s) = node {
        let children = s.children.map(shapeSignature).filter { !$0.isEmpty }
        if children.isEmpty {
            return ""
        }
        if children.count == 1 {
            return children[0]
        }
        let o: String = (s.orientation == .row) ? "row" : "column"
        return "\(o)(\(children.joined(separator: "|")))"
    }
    return ""
}

/// Moves one pane. The move is a remove plus an insert. If the target
/// group vanished during the move, the pane lands under a fresh zone id.
func movePane(
    _ root: LayoutNode,
    paneId: PaneID,
    target: (groupId: String, pos: DropPosition, before: PaneID?)
) -> LayoutNode {
    guard let from = findGroupOfPane(root, paneId: paneId) else { return root }
    // No-op guard: dropping a pane onto its own single-pane group.
    if from.id == target.groupId && from.panes.count == 1 {
        return root
    }
    guard let without = removePane(root, paneId: paneId) else { return root }
    guard findGroup(without, groupId: target.groupId) != nil else { return root }
    let next = insertAtGroup(without, targetGroupId: target.groupId, paneId: paneId, pos: target.pos, before: target.before) ?? root
    return shapeSignature(next) == shapeSignature(root) ? root : next
}

/// Moves a SELECTION of panes together (a multi-tab drag), preserving their
/// order. The caller rebuilds the visible arrangement and gets `root` back.
func movePanes(
    _ root: LayoutNode,
    paneIds ids: [PaneID],
    target: (groupId: String, pos: DropPosition, before: PaneID?),
    activeID: PaneID? = nil
) -> LayoutNode {
    guard !ids.isEmpty else { return root }
    if ids.count == 1 {
        return movePane(root, paneId: ids[0], target: target)
    }
    let lead = ids[0]
    // Replaced the previous `working!` (= force-unwrap inside a loop that may
    // exit early on removePane failure) with explicit `guard let pending` (= the
    // loop-local name is `pending` to avoid shadowing the outer `current` var; =
    // pending is the in-loop current value before removePane, then re-assigned to
    // the outer current).
    var current: LayoutNode? = root
    for id in ids {
        guard let pending = current else { return root }
        guard let nextPending = removePane(pending, paneId: id) else { return root }
        current = nextPending
    }
    // Rebind to `working` (= the rest of the function uses this name).
    guard let working = current else { return root }
    guard findGroup(working, groupId: target.groupId) != nil else { return root }
    guard var next = insertAtGroup(working, targetGroupId: target.groupId, paneId: lead, pos: target.pos, before: target.before) else {
        return root
    }
    for i in 1 ..< ids.count {
        guard let leadGroup = findGroupOfPane(next, paneId: lead) else { return root }
        let before: PaneID? = (target.pos == .center) ? target.before : nil
        guard let updated = insertAtGroup(next, targetGroupId: leadGroup.id, paneId: ids[i], pos: .center, before: before, activate: false) else {
            return root
        }
        next = updated
    }
    if let activeID, let landed = findGroupOfPane(next, paneId: lead), landed.panes.contains(activeID) {
        next = setActivePane(next, groupId: landed.id, paneId: activeID)
    }
    return shapeSignature(next) == shapeSignature(root) ? root : next
}
