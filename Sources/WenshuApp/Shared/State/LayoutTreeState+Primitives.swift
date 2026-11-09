// LayoutTreeState+Primitives.swift = part of the split tree model, = = moved out of LayoutTreeState.swift.
// The clusters below keep their own comments and their own MARK banners.

import CoreGraphics
import Foundation

// MARK: - Tab + Pane primitives (unchanged from v1)

/// PaneID — a type-safe identifier for a workspace pane.
struct PaneID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) {
        self.raw = raw
    }
}

/// TabID — type-safe identifier for a workspace tab (= same as v1).
struct TabID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) {
        self.raw = raw
    }
}

/// SplitDirection — kept; v2 reads it as `Orientation`.
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

    static var defaultFrame: PaneFrame {
        PaneFrame(minWidth: 320, idealWidth: 600, flex: 1.0)
    }
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

/// PaneNode — a single pane. It holds 0 or more tabs, and its frame and
/// its tab info live per-pane.
struct PaneNode: Codable, Equatable, Identifiable {
    var id: PaneID
    /// The orientation of the split (= which axis the pane's flex layout
    /// follows). The root pane owns its parent's split direction.
    var split: SplitDirection
    var frame: PaneFrame
    /// The ordered list of tabs in this pane. The first one is the selected tab
    /// when the pane becomes active.
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

/// The tab strip's mode. `tabStrip` is the explicit choice; every other
/// value asks for AUTO.
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

/// LayoutNode — recursive tree node. Sum type: SplitNode | GroupNode. Codable
/// conformance: encoded as a JSON object with a `type` discriminator (= "split" |
/// "group") so the on-disk format is self-describing and forward-compatible.
/// Decoding picks the right branch by the `type` field.
indirect enum LayoutNode: Codable, Equatable {
    case split(SplitNode)
    case group(GroupNode)

    var id: String {
        switch self {
        case let .split(n): return n.id
        case let .group(n): return n.id
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
        case let .split(s):
            try container.encode(Discriminator.split, forKey: .type)
            try s.encode(to: encoder)
        case let .group(g):
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
    /// The user's standing choice for this zone's strip. Absent = auto. A
    /// minimized group ignores it: a minimized group IS its strip.
    var tabStrip: TabStripMode?
}
