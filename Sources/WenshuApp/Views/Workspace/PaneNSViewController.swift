//
//  PaneNSViewController.swift · Wenshu · v1.28 C3.5.1
//
//  v1.28 C3.5.1: extract the `PaneNSViewController` NSViewControllerRepresentable
//  wrapper from WorkspaceView.swift into a focused file.
//
//  Originally inlined at WorkspaceView.swift:849-868 (= 20 LOC; = the
//  `PaneNSViewController` private struct with `makeNSViewController` +
//  `updateNSViewController`). The struct was inlined 2026-09-17 (= the
//  v1.27 component-architecture sweep) from a separate
//  `Views/Layout/PaneSplitHost.swift` file because the only caller was
//  WorkspaceView (= no external API surface to preserve).
//
//  v1.28 C3.5.1 reverses the inlining (= extracts it back to its own
//  file under the new `Workspace/PaneNSViewController.swift` path) so
//  WorkspaceView.swift's god-view surface area drops.
//
//  Behavior preserved (= same struct; = same `makeNSViewController`
//  that constructs `PaneNSController` with `layoutID: "fcp-default"`;
//  = same `updateNSViewController` no-op).
//

import AppKit
import SwiftUI

struct PaneNSViewController: NSViewControllerRepresentable {
    let store: LayoutTreeStore
    let appState: AppState
    let bookStore: BookStore

    func makeNSViewController(context: Context) -> NSSplitViewController {
        PaneNSController(
            store: store,
            appState: appState,
            bookStore: bookStore,
            layoutID: "fcp-default"
        )
    }

    func updateNSViewController(_ nsViewController: NSSplitViewController, context: Context) {
        // No-op (= matches PaneSplitHost's prior behavior; = tree
        // is rebuilt only on make; = preset switches trigger a full
        // re-make via SwiftUI's view identity system).
    }
}
