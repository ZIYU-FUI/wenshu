// WorkspaceState.swift · Wenshu (文枢) · v0.27 ticket 027-32
//
// Public types for the user-customizable workspace layout (= wenshu
// UI paradigm decision from the boss 2026-08-27 grill session D1 =
// 'Xcode范式 + 用户自定义布局'). See .scratch/2026-08-27-xcode-
// paradigm-layout/spec.md for the full design.
//
// This file = data only. No runtime behavior (= no SwiftUI view
// code). The view-side rendering lives in PaneRenderer.swift
// (= ticket 027-35). Persistence lives in WorkspaceStore.swift
// (= ticket 027-33). Atomic-coupling rationale (= per boss 8/22
// '1 commit / 1 file; multi-file requires atomic justification'):
// these three files form one feature (= a tab + pane workspace that
// persists and renders); = shipped together in ticket 027-32 + 027-
// 33, not split across separate pull requests.

import Foundation
import CoreGraphics

/// PaneID — type-safe identifier for a workspace pane.
struct PaneID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
}

/// TabID — type-safe identifier for a workspace tab.
struct TabID: Codable, Equatable, Hashable {
    var raw: UUID
    init(_ raw: UUID = UUID()) { self.raw = raw }
}

/// SplitDirection — how a pane relates to its sibling.
enum SplitDirection: String, Codable {
    /// Pane is to the LEFT or RIGHT of its sibling (= horizontal axis).
    case horizontal
    /// Pane is ABOVE or BELOW its sibling (= vertical axis).
    case vertical
}

/// PaneFrame — sizing rules for a single pane.
///
/// Mirrors the v0.27 LayoutShellView LayoutTokens (= idealWidth /
/// minWidth / flex). The LayoutShellView's hardcoded 6-zone widths
/// become a parameter (= the WorkspaceStore's default preset seeds
/// the same widths).
struct PaneFrame: Codable, Equatable {
    /// Minimum width in PT (= pane cannot shrink below this).
    var minWidth: CGFloat
    /// Initial width in PT on first show (= pane starts at this width).
    var idealWidth: CGFloat
    /// Flex ratio (= share of leftover space; = 1.0 default).
    var flex: CGFloat

    static let defaultFrame = PaneFrame(
        minWidth: 200,
        idealWidth: 600,
        flex: 1.0
    )
}

/// TabKind — which view a tab renders.
///
/// Mirrors the 6 zones in LayoutShellView (= projectSidebar / project
/// Preview / editor / specializedTools / aiChat / aiDynamic). Adding
/// a new TabKind requires (1) a new case here, (2) a render branch in
/// WorkspaceView.renderTab, and (3) a constructor for the new view.
enum TabKind: String, Codable {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case aiChat
    case aiDynamic
}

/// TabSpec — a tab's identity + the content view it renders.
struct TabSpec: Codable, Equatable, Identifiable {
    var id: TabID
    var kind: TabKind
    /// User-facing label shown on the tab title bar.
    var title: String
    /// Optional book context (= nil = library-level tab; non-nil =
    /// tab is scoped to a specific book; = closed when the book is
    /// closed).
    var contextBookID: UUID?

    static func make(kind: TabKind, title: String, bookID: UUID? = nil) -> TabSpec {
        TabSpec(id: TabID(), kind: kind, title: title, contextBookID: bookID)
    }
}

/// PaneNode — a single pane (= holds 0 or more tabs).
struct PaneNode: Codable, Equatable, Identifiable {
    var id: PaneID
    /// Orientation of the split (= which axis the pane's flex applies
    /// along). For a root pane, split is irrelevant (= the root pane
    /// owns its parent's split direction).
    var split: SplitDirection
    var frame: PaneFrame
    /// Ordered list of tabs in this pane (= first is the selected
    /// tab when the pane becomes active).
    var tabIDs: [TabID]

    static func make(split: SplitDirection = .horizontal, frame: PaneFrame = .defaultFrame, tabs: [TabID] = []) -> PaneNode {
        PaneNode(id: PaneID(), split: split, frame: frame, tabIDs: tabs)
    }
}

/// WorkspaceState — the user's current pane tree + active pane selection.
///
/// Persisted to UserDefaults under `wenshu.workspace.json`. Version
/// field allows future schema migrations (= on breaking schema
/// changes, bump version and migrate in WorkspaceStore.load).
struct WorkspaceState: Codable, Equatable {
    /// Flat list of all panes (= they form a tree via their parent
    /// indices; = the v0.27 first cut uses a flat array for simplicity;
    /// = a true tree representation is deferred to v0.28 if boss wants
    /// complex nested splits).
    var panes: [PaneNode]
    /// The currently focused pane (= keyboard input + tab visibility).
    var activePaneID: PaneID
    /// Map from pane ID to selected tab index (= 0-based within
    /// pane.tabIDs; = first tab when pane becomes active if absent).
    var activeTabIndexByPane: [PaneID: Int]
    /// All tabs (= all panes' tabIDs must reference entries here).
    var tabs: [TabSpec]
    /// Schema version (= current = 1).
    var version: Int

    /// Lookup helper for a tab by ID (= O(n) over tabs; = n is small).
    func tab(for id: TabID) -> TabSpec? {
        tabs.first(where: { $0.id == id })
    }

    /// Lookup helper for a pane by ID (= O(n) over panes).
    func pane(for id: PaneID) -> PaneNode? {
        panes.first(where: { $0.id == id })
    }
}

/// LayoutPreset — a named saved layout (= user can have several).
///
/// Persisted to UserDefaults under `wenshu.workspace.presets`. The
/// `Default` preset (= isBuiltIn = true) is the 6-zone LayoutShellView
/// equivalent (= recreated on demand; = user cannot delete it).
struct LayoutPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var workspace: WorkspaceState
    var isBuiltIn: Bool

    static func builtinDefault(_ workspace: WorkspaceState) -> LayoutPreset {
        LayoutPreset(id: UUID(), name: "默认", workspace: workspace, isBuiltIn: true)
    }
}