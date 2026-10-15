//
//  Persistence/WSLayoutTreeState.swift
//
//  SwiftData @Model for the workspace layout tree (= the persistent
//  shape of the 6-zone editor + the recursive split/group tree).
//
//  Apple HIG canonical pattern for structured state (= boss
//  2026-10-05 OOB ' 8  9' = complete the SwiftData migration
//  = the layout tree replaces the hand-rolled JSON file
//  persistence in LayoutTreeStore.swift with a single
//  SwiftData @Model row per workspace = easier to query
//  (= SwiftData @Query auto-observes), easier to migrate
//  (= SwiftData handles schema versions), no JSON parse
//  overhead per access).
//
//  Tree shape (= recursive):
//    WSLayoutTreeState 1---* WSLayoutNode (via parentState inverse)
//    WSLayoutNode has:
//      - id (UUID, unique)
//      - kind ("split" or "group" — discriminator for the recursive
//              enum that v2 uses; SwiftData can't store indirect enums
//              directly, so we use a discriminator + optional relationship)
//      - orientation (String, only for split nodes)
//      - childrenWeight (Data, only for split nodes = parallel array
//                        of Double; SwiftData doesn't store [Double]
//                        natively)
//      - panes ([WSPaneNode] via inverse)
//      - parentSplit (WSLayoutNode?, inverse on splitChildren)
//      - parentGroup (WSLayoutNode?, inverse on groupChildren)
//      - parentState (WSLayoutTreeState?, inverse on rootNodes)
//      - splitChildren [WSLayoutNode] (= recursive self-ref inverse)
//      - groupChildren [WSLayoutNode] (= recursive self-ref inverse)
//
//  WSPaneNode 1---* WSTabSpec (= same shape as the v2 PaneNode +
//  TabSpec struct pair; = SwiftData replaces the Codable JSON file).
//  WSPaneNode and WSTabSpec are kept as @Model classes (= not in the
//  recursive tree) because they hold per-pane metadata (= frame +
//  ordered tab list) that the tree references by id.
//
//  See Container.swift:65 for the schema entry. See
//  State/LayoutTreeState.swift for the canonical tree operations
//  (= the v2 pure functions in that file still apply; = they
//  just operate on @Model class instances instead of struct copies).
//

import Foundation
import SwiftData

/// The persistent workspace layout tree (= one row per workspace).
/// Recursive child layout nodes hang off this state via the
/// `rootNodes` relationship (= a workspace can have multiple root
/// nodes if the user has multiple split-trees at the top level).
@Model
public final class WSLayoutTreeState {
    /// Workspace identifier (= the .ws library UUID; = the tree
    /// belongs to a specific workspace).
    @Attribute(.unique) public var id: UUID
    /// When this tree was last persisted.
    public var updatedAt: Date

    /// Root nodes of the tree (= usually one; = recursive split/
    /// group nodes hang off these via the inverse relationships on
    /// WSLayoutNode.parentSplit / parentGroup).
    @Relationship(deleteRule: .cascade, inverse: \WSLayoutNode.parentState)
    public var rootNodes: [WSLayoutNode] = []

    /// All panes in this workspace (= the per-pane metadata that the
    /// tree references by PaneID). Owned by the workspace state (= a
    /// workspace owns its panes; = a pane has no parent group until
    /// a group node references it).
    @Relationship(deleteRule: .cascade, inverse: \WSPaneNode.parentState)
    public var panes: [WSPaneNode] = []

    public init(id: UUID = UUID(), updatedAt: Date = Date()) {
        self.id = id
        self.updatedAt = updatedAt
    }
}

/// A single node in the recursive layout tree (= either a split
/// node with weighted children, or a group node with stacked
/// panes). SwiftData replaces the v2 `indirect enum LayoutNode`
/// with a unified @Model class + discriminator field (= SwiftData
/// doesn't support indirect enums natively).
@Model
public final class WSLayoutNode {
    @Attribute(.unique) public var id: UUID

    /// Discriminator: "split" (= has `orientation` + weighted
    /// `splitChildren`) or "group" (= has `panes` + `active` +
    /// `minimized` + `tabStrip`). Kept as a String rather than an
    /// enum because SwiftData @Model doesn't support Swift enums
    /// natively (= enum-as-string does work in SwiftData but only
    /// for rawValue enums stored as String).
    public var kind: String

    /// Split-only: `row` (left-to-right) or `column` (top-to-bottom).
    /// Empty string for group nodes (= ignored).
    public var orientation: String

    /// Split-only: parallel array of weights for `splitChildren`
    /// (encoded as Data because SwiftData doesn't store [Double]
    /// natively; = the store layer encodes/decodes on access).
    /// Empty `Data` for group nodes.
    public var childrenWeightsData: Data

    /// Split-only: child layout nodes (= recursive self-ref).
    /// Empty for group nodes.
    @Relationship(deleteRule: .nullify, inverse: \WSLayoutNode.parentSplit)
    public var splitChildren: [WSLayoutNode] = []

    /// Group-only: panes stacked in this group (= rendered as
    /// tabs when more than 1). Empty for split nodes.
    @Relationship(deleteRule: .nullify, inverse: \WSPaneNode.parentGroup)
    public var panes: [WSPaneNode] = []

    /// Group-only: the visible pane (= first id in `panes` if absent).
    @Relationship public var activePane: WSPaneNode?

    /// Group-only: collapsed to header strip (= chevron restores).
    public var minimized: Bool

    /// Group-only: the user's standing choice for this zone's strip;
    /// `""` = auto (= the v2 TabStripMode absent value), `always`,
    /// or `never`.
    public var tabStrip: String

    /// Inverse: when this node is a split child, the parent split node.
    /// Nil for root nodes.
    @Relationship public var parentSplit: WSLayoutNode?

    /// Inverse: when this node's `panes` belong to a group, the parent
    /// group node (= the panes' owning group). Nil for split nodes
    /// (= group nodes own panes, not the other way around).
    @Relationship public var parentGroup: WSLayoutNode?

    /// Inverse: when this node is a root, the workspace state it
    /// belongs to. Nil for non-root nodes (= nodes that hang off a
    /// split or group).
    @Relationship public var parentState: WSLayoutTreeState?

    public init(
        id: UUID = UUID(),
        kind: String,
        orientation: String = "",
        minimized: Bool = false,
        tabStrip: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.orientation = orientation
        self.childrenWeightsData = Data()
        self.minimized = minimized
        self.tabStrip = tabStrip
    }
}

/// Per-pane metadata (= frame sizing + ordered tab list). Kept
/// separate from WSLayoutNode because panes have their own
/// per-pane state (= the recursive tree only references panes by
/// id; = metadata lives here).
@Model
public final class WSPaneNode {
    @Attribute(.unique) public var id: UUID
    /// The split direction of the pane (= which axis the pane's flex
    /// applies along). For a root pane, split is irrelevant (= the
    /// root pane owns its parent's split direction).
    public var split: String
    /// Minimum pane width.
    public var minWidth: Double
    /// Ideal pane width.
    public var idealWidth: Double
    /// Flex weight (relative to siblings).
    public var flex: Double
    /// Ordered list of tabs in this pane (= first is the selected tab).
    /// Stored as Data (= encoded JSON array of UUIDs) because SwiftData
    /// doesn't store [UUID] natively.
    public var tabIDsData: Data

    /// Inverse: the parent group node (= the group that owns this pane).
    @Relationship public var parentGroup: WSLayoutNode?

    /// Inverse: the workspace state this pane belongs to.
    @Relationship public var parentState: WSLayoutTreeState?

    /// Tab specs (= the kind + title + contextBookID per tab). Tabs
    /// are owned by the pane (= cascade delete when the pane is
    /// deleted).
    @Relationship(deleteRule: .cascade, inverse: \WSTabSpec.parentPane)
    public var tabs: [WSTabSpec] = []

    public init(
        id: UUID = UUID(),
        split: String = "horizontal",
        minWidth: Double = 320,
        idealWidth: Double = 600,
        flex: Double = 1.0
    ) {
        self.id = id
        self.split = split
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.flex = flex
        self.tabIDsData = Data()
    }
}


/// A single tab (= kind + title + contextBookID). Kept separate
/// from WSPaneNode so the pane's tab order can reference tab ids
/// while the tabs themselves are independent entities (= a tab
/// can be moved between panes without losing its identity).
@Model
public final class WSTabSpec {
    @Attribute(.unique) public var id: UUID
    /// Which view the tab renders. Raw string (= the v2 TabKind
    /// enum's rawValue; = SwiftData stores it as String).
    public var kind: String
    /// Display title (= can be edited by the user).
    public var title: String
    /// Optional book context (= tabs can be pinned to a specific book).
    public var contextBookID: UUID?

    /// Inverse: the parent pane (= the pane that contains this tab).
    @Relationship public var parentPane: WSPaneNode?

    public init(
        id: UUID = UUID(),
        kind: String,
        title: String,
        contextBookID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.contextBookID = contextBookID
    }
}
