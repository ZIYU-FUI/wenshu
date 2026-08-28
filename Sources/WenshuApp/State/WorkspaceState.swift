// WorkspaceState.swift · Wenshu (文枢) · v0.28 ticket 028-003
//
// Bumped from v1 (= flat array of panes) to v2 (= recursive split tree).
// 1:1 port of /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/
// components/pane-shell/tree/model.ts (650 LOC TypeScript).
//
// Two node kinds:
// - SplitNode: children laid out along an orientation with fractional weights.
// - GroupNode: a stack of panes (tabs) with one active; may be minimized to
//   its header strip; carries a standing choice for tab-strip mode.
//
// All operations are pure and return new trees; normalize() keeps the
// structure canonical (no empty groups, no single-child or same-
// orientation nested splits).
//
// Atomic-coupling with WorkspaceStore.swift (ticket 028-003, same commit):
// the schema and its migration logic are inseparable — see ticket spec
// §"Atomic-coupling justification". Shipped together per boss 8/22 rule.

import Foundation
import CoreGraphics

// MARK: - Tab + Pane primitives (unchanged from v1)

/// PaneID — type-safe identifier for a workspace pane (= same as v1).
struct PaneID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
}

/// TabID — type-safe identifier for a workspace tab (= same as v1).
struct TabID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
}

/// SplitDirection — v0.27 enum kept; v2 reads it as `Orientation`.
enum SplitDirection: String, Codable {
    /// Pane is to the LEFT or RIGHT of its sibling (= horizontal axis = 'row' in v2).
    case horizontal
    /// Pane is ABOVE or BELOW its sibling (= vertical axis = 'column' in v2).
    case vertical
}

/// PaneFrame — sizing rules for a single pane (= same as v1; untouched).
struct PaneFrame: Codable, Equatable {
    var minWidth: CGFloat
    var idealWidth: CGFloat
    var flex: CGFloat

    static var defaultFrame: PaneFrame { PaneFrame(minWidth: 320, idealWidth: 600, flex: 1.0) }
}

/// TabKind — which view a tab renders (= same as v1; untouched).
enum TabKind: String, Codable {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case aiChat
    case aiDynamic
}

/// PaneNode — a single pane (= holds 0 or more tabs).
///
/// Carried over from v1 (= ticket 027-32) unchanged: a pane owns
/// its sizing (frame) and the ordered list of tab IDs it renders.
/// The tree in v2 (= `LayoutNode`) does NOT carry this metadata
/// directly; instead, the tree references panes via `PaneID`, and
/// the per-pane metadata lives in `WorkspaceState.panes` (keyed by
/// PaneID). This separation keeps the tree lightweight (= only ids
/// + structure; no per-node frame data) and lets the renderer look
/// up frame + tab info per-pane.
struct PaneNode: Codable, Equatable, Identifiable {
    var id: PaneID
    /// Orientation of the split (= which axis the pane's flex
    /// applies along). For a root pane, split is irrelevant (= the
    /// root pane owns its parent's split direction).
    var split: SplitDirection
    var frame: PaneFrame
    /// Ordered list of tabs in this pane (= first is the selected
    /// tab when the pane becomes active).
    var tabIDs: [TabID]

    static func make(split: SplitDirection = .horizontal, frame: PaneFrame = .defaultFrame, tabs: [TabID] = []) -> PaneNode {
        PaneNode(id: PaneID(), split: split, frame: frame, tabIDs: tabs)
    }
}

/// TabSpec — a tab's identity + the content view it renders (= same as v1).
struct TabSpec: Codable, Equatable, Identifiable {
    var id: TabID
    var kind: TabKind
    var title: String
    var contextBookID: UUID?

    static func make(kind: TabKind, title: String, bookID: UUID? = nil) -> TabSpec {
        TabSpec(id: TabID(), kind: kind, title: title, contextBookID: bookID)
    }
}

// MARK: - Tree node kinds (= hermes model.ts lines 16-56)

/// TabStripMode — a zone's STANDING CHOICE about its tab strip.
/// Absent is the third value and the default: AUTO, where the strip's
/// presence is a pure function of what the zone currently holds.
///
/// Replaces the v0.27 WorkspaceState's flat-pane `tabIDs` array; this
/// is the user's deliberate choice (= absent = auto; only the user
/// writes `tabStrip`; everything else asks AUTO).
enum TabStripMode: String, Codable {
    case always
    case never
}

/// Orientation — how a split lays out its children.
enum Orientation: String, Codable {
    /// children laid out LEFT-TO-RIGHT (row)
    case row
    /// children laid out TOP-TO-BOTTOM (column)
    case column
}

/// DropPosition — where a dragged pane lands relative to a target group.
enum DropPosition: String, Codable {
    /// joins the stack as a tab (= append or before)
    case center
    case left
    case right
    case top
    case bottom
}

/// LayoutNode — recursive tree node. Sum type: SplitNode | GroupNode.
///
/// Codable conformance: encoded as a JSON object with a `type`
/// discriminator (= "split" | "group") so the on-disk format is
/// self-describing and forward-compatible. Decoding picks the right
/// branch by the `type` field.
indirect enum LayoutNode: Codable, Equatable {
    case split(SplitNode)
    case group(GroupNode)

    var id: String {
        switch self {
        case .split(let n): return n.id
        case .group(let n): return n.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum Discriminator: String, Codable {
        case split
        case group
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .split(let s):
            try container.encode(Discriminator.split, forKey: .type)
            try s.encode(to: encoder)
        case .group(let g):
            try container.encode(Discriminator.group, forKey: .type)
            try g.encode(to: encoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(Discriminator.self, forKey: .type)
        switch discriminator {
        case .split:
            let s = try SplitNode(from: decoder)
            self = .split(s)
        case .group:
            let g = try GroupNode(from: decoder)
            self = .group(g)
        }
    }
}

/// SplitNode — children laid out along an orientation with fractional weights.
struct SplitNode: Codable, Equatable, Identifiable {
    var type: String = "split"
    var id: String
    var orientation: Orientation
    var children: [LayoutNode]
    /// Parallel to `children`; relative flex weights.
    var weights: [Double]
}

/// GroupNode — a stack of panes (tabs) with one active.
struct GroupNode: Codable, Equatable, Identifiable {
    var type: String = "group"
    var id: String
    /// Pane ids stacked in this group (= rendered as tabs when > 1).
    var panes: [PaneID]
    /// The visible pane (= first id in `panes` if absent).
    var active: PaneID
    /// Collapsed to header strip (= chevron restores).
    var minimized: Bool?
    /// The user's standing choice for this zone's strip; absent = auto.
    /// Written only by the zone menu and the toggle command. Minimize
    /// ignores it — a minimized group IS its strip.
    var tabStrip: TabStripMode?
}

// MARK: - Tree node constructors (= hermes model.ts lines 63-86)

/// Monotonic sequence used to mint unique node ids within a session.
/// Persistent IDs come from the persisted JSON tree (= re-imported on
/// load); this sequence is only for new in-session allocations.
///
/// Uses a class-level lock-free atomic counter to satisfy Swift 6
/// concurrency checking. Since `nodeID` is only ever called from the
/// MainActor (= via WorkspaceStore mutations + the SwiftUI render
/// path) the counter is never actually raced, but Swift 6 still
/// requires the annotation.
private final class NodeIDSequence: @unchecked Sendable {
    static let shared = NodeIDSequence()
    private var value: UInt64 = 0
    private let lock = NSLock()
    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        value &+= 1
        return value
    }
}

func nodeID(kind: String) -> String {
    let seq = NodeIDSequence.shared.next()
    let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
    return "\(kind)-\(String(timestamp, radix: 36))-\(String(seq, radix: 36))"
}

func makeGroup(panes: [PaneID], active: PaneID? = nil, minimized: Bool? = nil, tabStrip: TabStripMode? = nil, id: String? = nil) -> LayoutNode {
    .group(GroupNode(
        id: id ?? nodeID(kind: "g"),
        panes: panes,
        active: active ?? panes.first ?? PaneID(),
        minimized: minimized,
        tabStrip: tabStrip
    ))
}

func makeSplit(orientation: Orientation, children: [LayoutNode], weights: [Double]? = nil, id: String? = nil) -> LayoutNode {
    .split(SplitNode(
        id: id ?? nodeID(kind: "s"),
        orientation: orientation,
        children: children,
        weights: weights ?? Array(repeating: 1.0, count: children.count)
    ))
}

// MARK: - Queries (= hermes model.ts lines 89-147)

/// Recursive lookup: returns the group with `groupId`, or nil.
func findGroup(_ node: LayoutNode, groupId: String) -> GroupNode? {
    if case .group(let g) = node {
        return g.id == groupId ? g : nil
    }
    if case .split(let s) = node {
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
    if case .group(let g) = node {
        return g.panes.contains(paneId) ? g : nil
    }
    if case .split(let s) = node {
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
    case .group(let g): return g.panes
    case .split(let s): return s.children.flatMap { allPaneIDs($0) }
    }
}

/// The split whose DIRECT child carries `childId`, or nil.
func findParentSplit(_ node: LayoutNode, childId: String) -> SplitNode? {
    if case .split(let s) = node {
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

/// Canonical form: unwrap single-child splits, flatten same-orientation
/// nesting (weights scaled into the parent's slot), and PRUNE EMPTY
/// GROUPS (= dragging the last pane out of a zone closes the zone and
/// its siblings absorb the space; VS Code semantics).
///
/// Returns nil when the tree is fully empty.
func normalize(_ node: LayoutNode) -> LayoutNode? {
    if case .group(let g) = node {
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
    if case .split(let s) = node {
        var children: [LayoutNode] = []
        var weights: [Double] = []
        for (i, child) in s.children.enumerated() {
            guard let kept = normalize(child) else { continue }
            // Flatten same-orientation nesting: distribute this slot's
            // weight across the flattened children proportionally.
            if case .split(let inner) = kept, inner.orientation == s.orientation {
                let total = inner.weights.reduce(0, +)
                let totalSafe = total > 0 ? total : 1
                for (j, grandchild) in inner.children.enumerated() {
                    children.append(grandchild)
                    let slotWeight = s.weights[s.weights.index(s.weights.startIndex, offsetBy: i, limitedBy: s.weights.endIndex).flatMap { $0 < s.weights.endIndex ? $0 : nil } ?? 0] ?? 1
                    let grandWeight = inner.weights[inner.weights.index(inner.weights.startIndex, offsetBy: j, limitedBy: inner.weights.endIndex).flatMap { $0 < inner.weights.endIndex ? $0 : nil } ?? 0] ?? 1
                    weights.append(slotWeight * (grandWeight / totalSafe))
                }
                continue
            }
            children.append(kept)
            let slotWeight = s.weights[s.weights.index(s.weights.startIndex, offsetBy: i, limitedBy: s.weights.endIndex).flatMap { $0 < s.weights.endIndex ? $0 : nil } ?? 0] ?? 1
            weights.append(slotWeight)
        }
        if children.isEmpty { return nil }
        if children.count == 1 { return children[0] }
        return .split(SplitNode(
            id: s.id, orientation: s.orientation, children: children, weights: weights
        ))
    }
    return nil
}

// MARK: - removePane (= hermes model.ts lines 219-241)

/// Remove a pane wherever it lives. Closing the ACTIVE tab leaves
/// selection on the neighbor that fills its slot (right; left when it
/// was last) — same rule as terminals and the preview rail.
func removePane(_ node: LayoutNode, paneId: PaneID) -> LayoutNode? {
    func walk(_ n: LayoutNode) -> LayoutNode {
        if case .group(let g) = n {
            guard let at = g.panes.firstIndex(of: paneId) else { return n }
            let panes = g.panes.filter { $0 != paneId }
            let fallbackIndex = min(at, max(0, panes.count - 1))
            let newActive: PaneID = (g.active == paneId) ? (panes.indices.contains(fallbackIndex) ? panes[fallbackIndex] : PaneID()) : g.active
            return .group(GroupNode(
                id: g.id, panes: panes, active: newActive,
                minimized: g.minimized, tabStrip: g.tabStrip
            ))
        }
        if case .split(let s) = n {
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

/// Insert `paneId` at `target` group: `center` joins the stack (as a
/// tab); an edge splits the group in that direction. If the
/// neighboring split already runs in that orientation the new group
/// is spliced in beside the target instead of nesting (= normalize
/// would flatten it anyway).
///
/// Returns nil when the target group does not exist or the tree
/// becomes empty.
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
        if case .group(let g) = n {
            guard g.id == targetGroupId else { return n }
            if pos == .center {
                let at: Int = {
                    if let b = before, let i = g.panes.firstIndex(of: b) { return i }
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
        if case .split(let s) = n {
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

/// The tree's VISIBLE shape: pane stacks + split orientations, with
/// empty groups skipped and single-child runs unwrapped. Two trees
/// with equal signatures are indistinguishable on screen regardless
/// of node ids.
private func shapeSignature(_ node: LayoutNode) -> String {
    if case .group(let g) = node {
        return g.panes.isEmpty ? "" : "[" + g.panes.map { $0.raw.uuidString }.joined(separator: ",") + "]"
    }
    if case .split(let s) = node {
        let children = s.children.map(shapeSignature).filter { !$0.isEmpty }
        if children.isEmpty { return "" }
        if children.count == 1 { return children[0] }
        let o: String = (s.orientation == .row) ? "row" : "column"
        return "\(o)(\(children.joined(separator: "|")))"
    }
    return ""
}

/// Move = remove + insert. If the target group vanished during
/// removal (the pane was its only occupant), the move is a no-op. A
/// move whose result LOOKS identical to the current layout is also
/// a no-op — e.g. a "split bottom" drop onto the zone the pane
/// already sits alone below would only rebuild the same arrangement
/// under a fresh zone id.
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

/// Move a SELECTION of panes together (multi-tab drag), preserving
/// their strip order. The lead pane lands exactly like a single
/// `movePane` (= center joins at `before`, an edge opens the split);
/// the rest stack in behind it. `activeID` (= the pressed tab) fronts
/// in the landing group. Same no-op guard as `movePane`: a drop that
/// rebuilds the visible arrangement returns `root`.
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
    var working: LayoutNode? = root
    for id in ids {
        guard let next = removePane(working!, paneId: id) else { return root }
        working = next
    }
    guard var working else { return root }
    guard findGroup(working, groupId: target.groupId) != nil else { return root }
    guard var next = insertAtGroup(working, targetGroupId: target.groupId, paneId: lead, pos: target.pos, before: target.before) else {
        return root
    }
    for i in 1..<ids.count {
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

// MARK: - groupLeafIds + findCover (= hermes model.ts lines 418-445)

/// Group ids of every leaf under a node, in tree order.
func groupLeafIDs(_ node: LayoutNode) -> [String] {
    if case .group(let g) = node { return [g.id] }
    if case .split(let s) = node { return s.children.flatMap { groupLeafIDs($0) } }
    return []
}

private func sameSet(_ ids: [String], _ set: Set<String>) -> Bool {
    return ids.count == set.count && ids.allSatisfy { set.contains($0) }
}

/// The node whose complete leaf set equals `set` (= a rectangular
/// region in a guillotine tree is always exactly one subtree), or nil.
private func findCover(_ node: LayoutNode, _ set: Set<String>) -> LayoutNode? {
    if sameSet(groupLeafIDs(node), set) { return node }
    if case .split(let s) = node {
        for child in s.children {
            if let hit = findCover(child, set) { return hit }
        }
    }
    return nil
}

// MARK: - mergeZonesWithPane (= hermes model.ts lines 447-505)

/// FancyZones span: merge the highlighted zones into ONE group
/// holding the dragged pane block (one pane, or a multi-tab selection
/// in strip order), absorbing any panes that lived in those zones as
/// tabs. Only works when the highlighted set forms a rectangular
/// subtree (it always does for a combined zone range on a guillotine
/// tree); returns nil otherwise so the caller can fall back to a
/// single-zone drop.
func mergeZonesWithPane(
    _ root: LayoutNode,
    groupIds: [String],
    paneId ids: [PaneID]
) -> LayoutNode? {
    let set = Set(groupIds)
    guard set.count > 1, findCover(root, set) != nil else { return nil }
    var panesInSet: [PaneID] = []
    func collect(_ n: LayoutNode) {
        if case .group(let g) = n {
            if set.contains(g.id) {
                panesInSet.append(contentsOf: g.panes.filter { !ids.contains($0) })
            }
        } else if case .split(let s) = n {
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
        if sameSet(groupLeafIDs(n), set) { return merged }
        if case .split(let s) = n {
            return .split(SplitNode(
                id: s.id, orientation: s.orientation,
                children: s.children.map(replace), weights: s.weights
            ))
        }
        return n
    }
    return normalize(replace(working))
}

// MARK: - Attribute edits (= hermes model.ts lines 507-587)

private func mapGroups(_ node: LayoutNode, _ fn: (GroupNode) -> GroupNode) -> LayoutNode {
    if case .group(let g) = node { return .group(fn(g)) }
    if case .split(let s) = node {
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

/// Reorder a block of panes within a group as one unit (browser-tab
/// drag semantics; a single-tab drag is a one-id block): the block
/// lands at `toIndex` among the remaining tabs, keeping its own
/// order.
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

/// Toggle a group's minimized state (= chevron expands / collapses
/// the group to a header strip).
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

/// Mirror the layout HORIZONTALLY (the titlebar flip toggle / ⌘\):
/// reverse every ROW split's child order at EVERY depth, so left↔right
/// flips everywhere. Its own involution: flipping twice is the identity.
func mirrorTreeHorizontal(_ root: LayoutNode) -> LayoutNode {
    if case .group = root { return root }
    if case .split(let s) = root {
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
    if case .split(let s) = root {
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

/// Bring a persisted tree onto the current attribute schema. For v2
/// (= initial public release), this is currently a no-op pass-through
/// (the schema already matches the runtime shape). Future schema
/// bumps should retire legacy attributes here (= analogous to the
/// hermes `headerHidden` → `tabStrip` retirement).
func migratePersistedTree(_ node: LayoutNode) -> LayoutNode {
    switch node {
    case .group(let g):
        return .group(GroupNode(
            id: g.id, panes: g.panes, active: g.active,
            minimized: g.minimized, tabStrip: g.tabStrip
        ))
    case .split(let s):
        return .split(SplitNode(
            id: s.id, orientation: s.orientation,
            children: s.children.map(migratePersistedTree), weights: s.weights
        ))
    }
}

/// Cheap structural validator for an unknown value (= used to gate
/// UserDefaults loads).
///
/// Validates only the top-level shape (= `type` discriminator +
/// presence of the structural keys). Deeper type validation lives in
/// the JSONDecoder call (= full type-safe decoding), so this gate
/// just rejects outright-corrupt blobs without paying the decode
/// cost. Returns true for both legal split and legal group shapes.
func isLayoutNode(_ value: Any) -> Bool {
    guard let n = value as? [String: Any], let type = n["type"] as? String else {
        return false
    }
    if type == "group" {
        return n["id"] is String && n["panes"] is [Any] && n["active"] is [String: Any]
    }
    if type == "split" {
        guard let orientation = n["orientation"] as? String,
                        (orientation == "row" || orientation == "column"),
                        let children = n["children"] as? [Any], !children.isEmpty,
                        let weights = n["weights"] as? [Double],
                        weights.count == children.count else {
            return false
        }
        return weights.allSatisfy { $0.isFinite && $0 > 0 }
    }
    return false
}

// MARK: - WorkspaceState v2 (= hermes-tree-backed)

/// WorkspaceState — the user's current pane tree + tabs.
///
/// Persisted to UserDefaults under `wenshu.workspace.json`. Version
/// field allows schema migrations (= on breaking schema changes,
/// bump version and migrate in WorkspaceStore.load).
///
/// v2 (= v0.28 ticket 028-003): backed by a recursive split tree
/// (`root`) per the hermes `LayoutNode` model. Pane metadata (frame,
/// minWidth, idealWidth, flex) lives in `panes` (= keyed by PaneID),
/// and tabs (= which view a pane renders) live in `tabs` (= keyed by
/// TabID). The tree references both via ids; pure functions mutate
/// the tree and return a new state.
struct WorkspaceState: Codable, Equatable {
    /// The tree root. Persisted as nested JSON (= split/group
    /// discriminated by `type` field).
    var root: LayoutNode
    /// Pane metadata (= keyed by PaneID). The tree references these
    /// via `GroupNode.panes`.
    var panes: [PaneNode]
    /// All tabs (= keyed by TabID). Each `PaneNode.tabIDs` references
    /// entries here.
    var tabs: [TabSpec]
    /// Schema version (= current = 2).
    var version: Int

    /// Lookup helper for a tab by ID (= O(n) over tabs; n is small).
    func tab(for id: TabID) -> TabSpec? {
        tabs.first(where: { $0.id == id })
    }

    /// Lookup helper for a pane by ID (= O(n) over panes).
    func pane(for id: PaneID) -> PaneNode? {
        panes.first(where: { $0.id == id })
    }

    /// Lookup helper for the currently active pane (= the front-most
    /// pane in the tree).
    var activePaneID: PaneID? {
        for case .group(let g) in walkRoot(root) {
            return g.active
        }
        return nil
    }

    /// All PaneIDs in tree order (= wrapper over the file-scope
    /// `allPaneIDs(_:)` helper; renamed locally to avoid clash with
    /// the helper's name).
    var allPaneIDsInTree: [PaneID] {
        allPaneIDs(root)
    }
}

/// Private helper: walks the tree breadth-first and yields each
/// node in encounter order. Used by `activePaneID` to find the
/// front-most (= depth-first, first encountered) group.
private func walkRoot(_ node: LayoutNode) -> [LayoutNode] {
    var result: [LayoutNode] = []
    func walk(_ n: LayoutNode) {
        result.append(n)
        if case .split(let s) = n {
            s.children.forEach(walk)
        }
    }
    walk(node)
    return result
}

/// LayoutPreset — a named saved layout (= user can have several).
///
/// Persisted to UserDefaults under `wenshu.workspace.presets`. The
/// `Default` preset (= isBuiltIn = true) is the FCP Browser 3-pane
/// layout per the v0.28 free-layout boss拍 (b/II). It is recreated
/// on demand; user cannot delete it.
struct LayoutPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var workspace: WorkspaceState
    var isBuiltIn: Bool

    /// Stable UUIDs for the 4 builtin presets (= ticket 028-005
    /// §"Acceptance criteria" = 'each preset has a stable UUID per
    /// app install'). Generated once here and reused forever; this
    /// keeps UserDefaults round-trips stable across launches.
    static let builtinDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let builtinFocusID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let builtinTerminalDeckID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let builtinQuadID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    static func builtinDefault(_ workspace: WorkspaceState) -> LayoutPreset {
        LayoutPreset(id: builtinDefaultID, name: "默认", workspace: workspace, isBuiltIn: true)
    }
}