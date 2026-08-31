// PaneLayout.swift · Wenshu (文枢) · v0.30 ticket 01 / 4
//
// Future-framework pluggable shape (= boss 2026-08-31 OOB "用 Apple 官方的
// api 实现 FCP 的布局, 之后每一种布局等于定制化开发"). Each preset
// (= FCP / Xcode / Hermes / Quad / user-saved) becomes one PaneLayout
// implementation that knows how to build its native NSSplitViewController
// tree from a list of PaneNode.
//
// Ticket 01 / 4 scope (= this file):
//   - Declare `protocol PaneLayout`
//   - Declare `struct FCPLayout: PaneLayout` (= stub returning empty
//     NSSplitViewController; the real tree walk lands in ticket 03)
//   - NO existing source file modified
//   - NO behavior change (= WorkspaceView still calls PaneRenderer; new
//     code is dormant until ticket 04 wires the feature flag)
//
// Out of scope (= other tickets):
//   - NSViewControllerRepresentable wrapper → ticket 02
//   - NSSplitViewController subclass with pane content → ticket 03
//   - Feature flag wiring (`useNSSplitView`) → ticket 04

import AppKit
import Foundation

/// Pluggable shape for one layout preset (= FCP / Xcode / Hermes / Quad).
///
/// Each preset declares a `PaneLayout` struct that knows how to construct
/// its native `NSSplitViewController` (= and child NSSplitViewItems) from
/// the workspace's existing `PaneNode` list (= no schema change to
/// WorkspaceState; the existing preset tree stays the source of truth).
///
/// One preset = one struct, one file. Adding a new preset = new struct
/// implementing this protocol (= per boss "每一种布局等于定制化开发").
protocol PaneLayout {
    /// Stable identifier (= matches `LayoutPreset.name` for built-ins).
    /// Used by `autosaveName` so divider positions are persisted per
    /// preset (= switching presets restores each one's last layout).
    var layoutID: String { get }

    /// Build the native `NSSplitViewController` for this layout from the
    /// current pane list. Returned controller is the host SwiftUI embeds
    /// via `NSViewControllerRepresentable` (= ticket 02).
    ///
    /// `panes` = the current preset's `PaneNode` list (= all 6 for the
    /// FCP default). The implementation decides how to lay them out
    /// (= e.g. FCP: upper row 4 + lower row 2; Xcode: 1 + 1 with editor
    /// dominant).
    ///
    /// `store` = `WorkspaceStore` (read-only here; no writes from this
    /// method). Used to resolve `PaneNode.frame` (= minWidth / ideal /
    /// flex) into NSSplitViewItem constraints.
    ///
    /// `appState` + `bookStore` = environment values that must be
    /// propagated into each pane's SwiftUI view (= @Environment lookup
    /// chain breaks across AppKit bridge, so we thread them explicitly).
    func makeSplitController(
        panes: [PaneNode],
        store: WorkspaceStore,
        appState: AppState,
        bookStore: BookStore
    ) -> NSSplitViewController
}

// MARK: - FCP-style 6-zone layout (= current wenshu default)
//
// Upper band (row) = sidebar + preview + editor + tools
//   (= weights [1, 2, 6, 1] = sidebar 10%, preview 20%, editor 60%,
//    tools 10%; per builtinDefaultPreset).
// Lower band (row) = chat + dynamic
//   (= weights [1, 1] = chat 50%, dynamic 50%).
// Outer (column) = upper band (3/4 height) + lower band (1/4 height)
//   (= weights [3, 1]).
//
// This struct's `makeSplitController` is a stub returning an empty
// NSSplitViewController. The real implementation (= recursive
// WorkspaceState tree walk + NSSplitViewItem construction + autosaveName)
// lands in ticket 03. This ticket establishes the protocol + struct +
// file location so subsequent tickets have a home.
struct FCPLayout: PaneLayout {
    let layoutID = "FCPLayout"

    func makeSplitController(
        panes: [PaneNode],
        store: WorkspaceStore,
        appState: AppState,
        bookStore: BookStore
    ) -> NSSplitViewController {
        // Stub for ticket 01. Ticket 03 replaces this body with:
        //   1. walk store.workspace.root (= SplitNode tree)
        //   2. for each SplitNode.orientation = .row, create an
        //      NSSplitView with isVertical = true
        //   3. for each SplitNode.orientation = .column, create an
        //      NSSplitView with isVertical = false
        //   4. for each GroupNode, create NSSplitViewItem per pane
        //      hosting NSHostingController(rootView: ZoneContentView(...))
        //   5. set autosaveName = "wenshu.split.<layoutID>.<uuid>"
        //   6. set canCollapse = true on sidebar / chat / dynamic items
        // Until then: return an empty controller (= never wired until
        // ticket 04 sets useNSSplitView = true; user-visible UI stays on
        // the existing PaneRenderer path).
        return NSSplitViewController()
    }
}
