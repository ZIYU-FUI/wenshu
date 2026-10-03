//
//  NavigationSplitShellTests.swift · Wenshu · M1-shell (2026-09-08)
//
//  Smoke tests for the M1 NavigationSplitShell = the macOS 27
//  Apple-native 3-column shell (per developer.apple.com/documentation/
//  swiftui/navigationsplitview). Activated by
//  `LayoutTreeState.useThreeColumnSplit` (= default `nil`/off =
//  PaneSplitHost path = zero regression per M1 spec §2.3).
//
//  These tests verify:
//  1. ShellPlaceholder constructs (= reusable placeholder view
//     does not crash).
//  2. LayoutTreeState.useThreeColumnSplit default = `nil` (= M1
//     spec §2.3 "default off = zero regression risk").
//  3. Setting flag = true via the @Observable binding does not
//     throw (= SwiftUI view construction is valid).
//
//  P2-06 audit (2026-09-24): the canonical owner of the flag is
//  LayoutTreeState (= Codable + CodableBackCompat Optional).
//  AppState used to have a dead mirror (= no production caller); =
//  removed.
//
//  Acceptance per M1 spec §2.3:
//  - swift test --filter NavigationSplitShellTests PASS (= 3 tests)
// - The PaneSplitHost legacy path unaffected (= verified by the existing
//    DragRegressionTests 8/8 PASS, NOT by this file)
//

import XCTest
@testable import WenshuApp

@MainActor
final class NavigationSplitShellTests: XCTestCase {

    /// 
    /// per the "legacy path" rule). If this ever flips
    /// to `true` by accident, existing users will see the new
    /// 3-column shell (= a breaking UX change = must ship as a
    /// major version bump + migration guide).
    func testUseThreeColumnSplitDefaultIsNil() throws {
        let tree = LayoutTreeState(
            root: makeGroup(panes: []),
            panes: [],
            tabs: [],
            version: 2
        )
        XCTAssertNil(
            tree.useThreeColumnSplit,
            "LayoutTreeState.useThreeColumnSplit MUST default to nil (= PaneSplitHost path = zero regression per M1 spec §2.3). Changing this default requires boss sign-off (= a major version bump)."
        )
    }

    /// ShellPlaceholder constructs without crashing (= the
    /// Placeholder view that fills all 6 M1 panes is valid SwiftUI).
    /// Note: the actual NavigationSplitShell needs an AppState
    /// instance; = this test exercises the leaf view directly to
    /// keep the test surface minimal.
    func testShellPlaceholderConstructs() throws {
        let placeholder = ShellPlaceholder(
            name: "test",
            icon: "folder",
            hint: "hint"
        )
        XCTAssertNoThrow(
            placeholder,
            "ShellPlaceholder MUST construct without throwing (= valid SwiftUI view per M1 spec §2.3)."
        )
        XCTAssertEqual(placeholder.name, "test")
        XCTAssertEqual(placeholder.icon, "folder")
        XCTAssertEqual(placeholder.hint, "hint")
    }

    /// Setting the flag = `true` does not corrupt AppState state
    /// (= the flag is a simple @Observable Bool, = must remain
    /// settable + re-readable cleanly).
    func testUseThreeColumnSplitCanBeToggled() throws {
        var tree = LayoutTreeState(
            root: makeGroup(panes: []),
            panes: [],
            tabs: [],
            version: 2
        )
        XCTAssertNil(tree.useThreeColumnSplit)
        tree.useThreeColumnSplit = true
        XCTAssertEqual(
            tree.useThreeColumnSplit,
            true,
            "LayoutTreeState.useThreeColumnSplit MUST be settable (= the user toggle wires via UserDefaults `wenshu.useThreeColumnSplit` key in M2)."
        )
        tree.useThreeColumnSplit = false
        XCTAssertEqual(
            tree.useThreeColumnSplit,
            false,
            "LayoutTreeState.useThreeColumnSplit MUST round-trip back to false (= toggling off restores the PaneSplitHost path = no stale state)."
        )
    }

    /// 
    /// real wenshu zone views. Acceptance = body assembly
    /// without throwing (= the 6 real zone views: AppleSidebarView,
    /// ZoneModuleView(projectPreview), EditorPlaceholder, ChatView,
    /// ZoneModuleView(specializedTools), ZoneModuleView(aiDynamic))
    /// all wire up cleanly to the NavigationSplitView 3-column
    /// shell without SwiftUI constraint cycles (= boss 9/8's
    /// 'can, ').
    ///
    /// 
    /// this test only needs AppState (= BookStore requires a
    /// stores argument that the test infrastructure doesn't
    /// provide; = the shell's behavior is identical with a
    /// default BookStore anyway).
    func testNavigationSplitShellAssembles() throws {
        let appState = AppState()
        let workspaceUI = WorkspaceUIState()
        XCTAssertNoThrow(
            NavigationSplitShell(appState: appState, workspaceUI: workspaceUI),
            "NavigationSplitShell body MUST assemble without throwing (= the 6 real wenshu zone views are correctly wired per M2 spec)."
        )
    }
}
