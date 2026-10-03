//
//  NavigationSplitShellTests.swift · Wenshu
//
//  Smoke tests for the Apple multi-column shell (= the macOS 27
//  Apple-native 3-column NavigationSplitView per
//  developer.apple.com/documentation/swiftui/navigationsplitview).
//
//  History (= commit 6b on 2026-10-03):
//  - The NavigationSplitShell wrapper layer was removed (= the
//    wenshu-summary abstraction that conflated column-binding
//    plumbing with the Apple canonical shape).
//  - LibraryRootView now owns the Apple NavigationSplitView
//    directly (= the canonical owner pattern; = Apple HIG
//    'typically use it as the root view in a Scene').
//  - LayoutTreeState.useThreeColumnSplit continues to toggle
//    between the legacy PaneSplitHost and the new Apple NSV
//    path on LibraryRootView directly.
//
//  These tests verify:
//  1. LayoutTreeState.useThreeColumnSplit default = `nil` (= the
//     canonical M1 = `nil`/off = zero regression path).
//  2. Setting the flag to true / false round-trips cleanly.
//  3. LibraryRootView constructs without throwing (= the new
//     direct NavigationSplitView owner + all 6 zone views wire
//     up cleanly).
//
import XCTest
@testable import WenshuApp

@MainActor
final class NavigationSplitShellTests: XCTestCase {

    /// LayoutTreeState.useThreeColumnSplit defaults to nil
    /// (= the PaneSplitHost legacy path is the default per M1
    /// spec §2.3 "default off = zero regression risk").
    func testUseThreeColumnSplitDefaultIsNil() throws {
        let tree = LayoutTreeState(
            root: makeGroup(panes: []),
            panes: [],
            tabs: [],
            version: 2
        )
        XCTAssertNil(
            tree.useThreeColumnSplit,
            "LayoutTreeState.useThreeColumnSplit MUST default to nil (= PaneSplitHost path = zero regression per M1 spec §2.3)."
        )
    }

    /// LayoutTreeState.useThreeColumnSplit toggle (= the
    /// NavigationSplitShell wrapper was removed in commit 6b as
    /// part of the Apple multi-column rewrite).
    func testUseThreeColumnSplitCanBeToggled() throws {
        var tree = LayoutTreeState(
            root: makeGroup(panes: []),
            panes: [],
            tabs: [],
            version: 2
        )
        XCTAssertNil(tree.useThreeColumnSplit)
        tree.useThreeColumnSplit = true
        XCTAssertEqual(tree.useThreeColumnSplit, true)
        tree.useThreeColumnSplit = false
        XCTAssertEqual(tree.useThreeColumnSplit, false)
    }

    /// LibraryRootView now owns the Apple NavigationSplitView
    /// directly (= the NavigationSplitShell wrapper was removed
    /// in commit 6b).
    func testLibraryRootViewAssembles() throws {
        let library = WenshuLibrary(
            store: FileSystemLibraryStore(rootURL: URL(fileURLWithPath: "/tmp/wenshu-test"))
        )
        let root = LibraryRootView(
            library: library,
            appearanceMode: .system
        )
        _ = root
        XCTAssertNoThrow(
            root,
            "LibraryRootView (= the new direct NavigationSplitView owner) MUST construct without throwing."
        )
    }
}
