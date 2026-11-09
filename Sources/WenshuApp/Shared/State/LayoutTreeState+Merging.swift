// LayoutTreeState+Merging.swift = part of the split tree model, = = moved out of LayoutTreeState.swift.
// The clusters below keep their own comments and their own MARK banners.

// MARK: - groupLeafIds + findCover (= hermes model.ts lines 418-445)

/// The group ids of every leaf under a node, in tree order.
func groupLeafIDs(_ node: LayoutNode) -> [String] {
    if case let .group(g) = node {
        return [g.id]
    }
    if case let .split(s) = node {
        return s.children.flatMap { groupLeafIDs($0) }
    }
    return []
}

private func sameSet(_ ids: [String], _ set: Set<String>) -> Bool {
    return ids.count == set.count && ids.allSatisfy { set.contains($0) }
}

/// Finds the node whose complete leaf set equals `set` (= a rectangular
/// region in a guillotine tree is always exactly one subtree), or nil.
private func findCover(_ node: LayoutNode, _ set: Set<String>) -> LayoutNode? {
    if sameSet(groupLeafIDs(node), set) {
        return node
    }
    if case let .split(s) = node {
        for child in s.children {
            if let hit = findCover(child, set) {
                return hit
            }
        }
    }
    return nil
}

// MARK: - mergeZonesWithPane (= hermes model.ts lines 447-505)

/// Merges the zone under a pane that was dropped on it (= a single-zone
/// drop).
func mergeZonesWithPane(
    _ root: LayoutNode,
    groupIds: [String],
    paneId ids: [PaneID]
) -> LayoutNode? {
    let set = Set(groupIds)
    guard set.count > 1, findCover(root, set) != nil else { return nil }
    var panesInSet: [PaneID] = []
    func collect(_ n: LayoutNode) {
        if case let .group(g) = n {
            if set.contains(g.id) {
                panesInSet.append(contentsOf: g.panes.filter { !ids.contains($0) })
            }
        } else if case let .split(s) = n {
            s.children.forEach(collect)
        }
    }
    collect(root)
    var working = root
    for id in ids {
        if let origin = findGroupOfPane(working, paneId: id), !set.contains(origin.id) {
            working = removePane(working, paneId: id) ?? working
        }
    }
    let merged = makeGroup(panes: ids + panesInSet)
    func replace(_ n: LayoutNode) -> LayoutNode {
        if sameSet(groupLeafIDs(n), set) {
            return merged
        }
        if case let .split(s) = n {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: s.children.map(replace), weights: s.weights
            ))
        }
        return n
    }
    return normalize(replace(working))
}
