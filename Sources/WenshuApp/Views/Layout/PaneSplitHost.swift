// PaneSplitHost.swift · Wenshu · v0.30 ticket 02 / 4
//
// Future-framework SwiftUI-to-AppKit bridge (= boss 2026-08-31 OOB:
// "Implement the FCP layout using Apple official APIs"; see spec.md
// for the verbatim Chinese quote). This wrapper is the seam SwiftUI
// uses to host the native NSSplitViewController (= ticket 03's
// PaneNSController).
//
// Ticket 02 / 4 scope (= this file):
//   - Declare `struct PaneSplitHost: NSViewControllerRepresentable`
//   - `makeNSViewController(context:)` calls
//     `layout.makeSplitController(panes:store:appState:bookStore:)` and
//     returns the NSSplitViewController (= stub from ticket 01, real
//     from ticket 03)
//   - `updateNSViewController(_:context:)` is a no-op for now (= content
//     is static; real impl in ticket 03 will diff pane tree + update)
//   - NO existing source file modified
//   - NO behavior change (= WorkspaceView still calls PaneRenderer;
//     PaneSplitHost is dormant until ticket 04 wires the feature flag)
//
// Why NSViewControllerRepresentable (= not just NSSplitView directly)?
//
// SwiftUI's AppKit bridge surfaces environment values into the SwiftUI
// tree. When you embed an NSView, the SwiftUI @Environment chain breaks
// at the AppKit boundary. We solve this by:
//   1. Listing the env values we need (= AppState, BookStore) in the
//      PaneSplitHost constructor's @Environment reads
//   2. Threading them explicitly into `makeSplitController(...)` (= the
//      ticket 03 PaneNSController then embeds each pane's SwiftUI view
//      inside an `NSHostingController(rootView: paneView.environment(...))`
//      so the pane's @Environment(AppState.self) still resolves)
//
// Out of scope (= other tickets):
//   - PaneNSController concrete tree walk → ticket 03
//   - Feature flag wiring (`useNSSplitView`) → ticket 04
//   - Diff/update logic on pane tree change → ticket 03

import AppKit
import SwiftUI

/// SwiftUI wrapper around an `NSSplitViewController` (= produced by a
/// `PaneLayout`). Lives dormant until ticket 04's `useNSSplitView`
/// feature flag flips on.
///
/// Construct at any SwiftUI site:
/// ```swift
/// PaneSplitHost(
///     layout: FCPLayout(),
///     store: store,
///     appState: appState,
///     bookStore: bookStore
/// )
/// .frame(maxWidth: .infinity, maxHeight: .infinity)
/// ```
///
/// The wrapper itself does no layout (= it just hands the controller to
/// AppKit). All structural decisions live in `PaneLayout.makeSplitController`.
struct PaneSplitHost: NSViewControllerRepresentable {
    let layout: PaneLayout
    let store: WorkspaceStore
    /// Required because SwiftUI's @Environment(AppState.self) lookup
    /// stops at the AppKit boundary. We thread it through explicitly so
    /// each pane's SwiftUI view (inside NSHostingController) can still
    /// resolve `@Environment(AppState.self)` (= ticket 03).
    let appState: AppState
    /// Same story as appState (= @Environment(BookStore.self) chain).
    let bookStore: BookStore

    func makeNSViewController(context: Context) -> NSSplitViewController {
        // `store.workspace.panes` = the current preset's full pane list
        // (= 6 for FCP default). Ticket 03's PaneNSController will walk
        // store.workspace.root (= the recursive SplitNode tree) to build
        // the real NSSplitView. For now the FCPLayout stub returns an
        // empty NSSplitViewController (= nothing to show; dormant).
        return layout.makeSplitController(
            panes: store.workspace.panes,
            store: store,
            appState: appState,
            bookStore: bookStore
        )
    }

    func updateNSViewController(
        _ nsViewController: NSSplitViewController,
        context: Context
    ) {
        // No-op for ticket 02. Ticket 03 will:
        //   1. detect a pane tree change (= diff current state vs
        //      nsViewController's child NSSplitViewItem count)
        //   2. re-walk the tree and rebuild children if mismatched
        //   3. forward any active tab / collapsed state changes
        //
        // Until then: the NSSplitViewController is built once at
        // make-time and stays frozen for the lifetime of the SwiftUI
        // view (= acceptable for v0.30 since users only switch presets
        // via the LayoutPicker, which triggers a full re-make).
    }
}
