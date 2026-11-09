// Sources/WenshuApp/Shared/State/LayoutTreeState.swift = the recursive split tree.
// 1:1 port of /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/
// components/pane-shell/tree/model.ts (650 LOC TypeScript). Two node kinds: -
// SplitNode: children laid out along an orientation with fractional weights. -
// GroupNode: a stack of panes (tabs) with one active; may be minimized to its
// header strip; carries a standing choice for tab-strip mode. All operations are
// pure and return new trees; normalize keeps the structure canonical (no empty
// groups, no single-child or same- orientation nested splits). Atomic-coupling
// with LayoutTreeStore.swift (= the schema and its migration logic are
// inseparable — see ticket spec for the justification; = shipped together per the
// standing rule).
import Foundation

// MARK: - Tree node constructors (= hermes model.ts lines 63-86)

/// The sequence that hands out the node ids. It is `@unchecked Sendable`
/// because it mutates a counter, and that annotation is what the compiler
/// requires.
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

// MARK: - LayoutTreeState v2 (= hermes-tree-backed)

/// The state of the layout tree. Every mutation returns a new state.
struct LayoutTreeState: Codable, Equatable {
    /// The tree root. It is persisted as nested JSON, and the `type` field
    /// discriminates a split from a group.
    var root: LayoutNode
    /// The pane metadata (= keyed by PaneID). The tree references these through
    /// `GroupNode.panes`.
    var panes: [PaneNode]
    /// All the tabs (= keyed by TabID). Each `PaneNode.tabIDs` references
    /// entries here.
    var tabs: [TabSpec]
    /// Schema version (= current = 2).
    var version: Int

    // MARK: - 3-column NavigationSplitView migration (= M1 shell)

    /// Marked `Optional` (= Codable back-compat for old persisted JSON).
    var useThreeColumnSplit: Bool? = nil

    /// Lookup helper for a tab by ID (= O(n) over tabs; n is small).
    func tab(for id: TabID) -> TabSpec? {
        tabs.first(where: { $0.id == id })
    }

    /// Lookup helper for a pane by ID (= O(n) over panes).
    func pane(for id: PaneID) -> PaneNode? {
        panes.first(where: { $0.id == id })
    }

    /// A lookup helper for the currently active pane (= the front-most pane in
    /// the tree).
    var activePaneID: PaneID? {
        for case let .group(g) in walkRoot(root) {
            return g.active
        }
        return nil
    }

    /// All the PaneIDs in tree order (= a wrapper over the file-scope helper of
    /// the same name).
    var allPaneIDsInTree: [PaneID] {
        allPaneIDs(root)
    }
}

/// A private helper: it walks the tree breadth-first and yields each group.
/// The front-most group (= depth-first, first encountered) is the one it
/// returns.
private func walkRoot(_ node: LayoutNode) -> [LayoutNode] {
    var result: [LayoutNode] = []
    func walk(_ n: LayoutNode) {
        result.append(n)
        if case let .split(s) = n {
            s.children.forEach(walk)
        }
    }
    walk(node)
    return result
}

/// LayoutPreset — a named saved layout (= the user can have several). A
/// preset holds the layout. It is recreated on demand; the user cannot
/// delete it.
struct LayoutPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var workspace: LayoutTreeState
    var isBuiltIn: Bool

    /// Stable UUIDs for the 4 builtin presets. They are generated once here, at
    /// compile time, so the failure path is unreachable.
    static let builtinDefaultID = UUID.literal("00000000-0000-0000-0000-000000000001")
    static let builtinFocusID = UUID.literal("00000000-0000-0000-0000-000000000002")
    static let builtinTerminalDeckID = UUID.literal("00000000-0000-0000-0000-000000000003")
    static let builtinQuadID = UUID.literal("00000000-0000-0000-0000-000000000004")

    static func builtinDefault(_ workspace: LayoutTreeState) -> LayoutPreset {
        // Translated the legacy localized string "Default" → "Default" (= the
        // builtin preset name is in English; the localized version comes from the
        // i18n layer when shown to the user).
        LayoutPreset(id: builtinDefaultID, name: "Default", workspace: workspace, isBuiltIn: true)
    }
}
