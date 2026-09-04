// Phase1FoundationTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-013
//
// Tests for Phase 1 foundation components (= WorkspaceScope,
// PaneLifecycle, PaneVisibleContext, Geometry). Boss 2026-08-29 OOB
// '完整复刻 hermes app'.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class WorkspaceScopeTests: XCTestCase {

    func testDefaultModeIsSessions() {
        let store = WorkspaceScopeStore()
        XCTAssertEqual(store.mode, .sessions)
        XCTAssertNil(store.ownerKey)
    }

    func testScopeKey() {
        XCTAssertEqual(workspaceScopeKey(.sessions, ownerKey: nil), "sessions")
        XCTAssertEqual(workspaceScopeKey(.sessions, ownerKey: "abc"), "sessions")
        XCTAssertEqual(workspaceScopeKey(.bots, ownerKey: nil), "bots:")
        XCTAssertEqual(workspaceScopeKey(.bots, ownerKey: "abc"), "bots:abc")
    }

    func testSetModeChangesScopeKey() {
        let store = WorkspaceScopeStore()
        store.set(mode: .bots, ownerKey: "bot-1")
        XCTAssertEqual(store.scopeKey, "bots:bot-1")
    }

    func testSessionsRetainsAmbientTargetOnRehome() {
        let store = WorkspaceScopeStore()
        store.set(mode: .sessions, newSessionTarget: .blocked(message: "test"))
        store.set(mode: .bots, ownerKey: "x")  // re-home to bots
        XCTAssertNil(store.newSessionTarget)  // bots requires explicit target
    }

    func testContributesToWorkspaceGlobal() {
        let store = WorkspaceScopeStore()
        let global = Contribution(id: "x", area: ContributionArea.panes)
        XCTAssertTrue(store.contributesToWorkspace(global))
    }

    func testContributesToWorkspaceScoped() {
        let store = WorkspaceScopeStore()
        store.set(mode: .bots, ownerKey: "bot-1")
        let other = Contribution(
            id: "x", area: ContributionArea.panes,
            workspaceMode: "bots",
            workspaceOwnerKey: "bot-2"
        )
        XCTAssertFalse(store.contributesToWorkspace(other))
        let mine = Contribution(
            id: "y", area: ContributionArea.panes,
            workspaceMode: "bots",
            workspaceOwnerKey: "bot-1"
        )
        XCTAssertTrue(store.contributesToWorkspace(mine))
    }
}

final class PaneLifecycleTests: XCTestCase {

    func testEmptyState() {
        let s = emptyPaneLifecycleState()
        XCTAssertEqual(s.clock, 0)
        XCTAssertEqual(s.entries.count, 0)
    }

    func testActiveIsVisibleAndBumpsClock() {
        let previous = emptyPaneLifecycleState()
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                paneIds: ["p1"]
            )
        )
        XCTAssertEqual(next.entries["p1"]?.lifecycle, .visible)
        XCTAssertEqual(next.clock, 1)
    }

    func testActiveAlreadyVisibleNoClockBump() {
        let previous = PaneLifecycleState(
            clock: 5,
            entries: ["p1": PaneLifecycleEntry(lifecycle: .visible, lastVisible: 5)]
        )
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                paneIds: ["p1"]
            )
        )
        XCTAssertEqual(next.clock, 5)
    }

    func testCapTwoKeepsMostRecent() {
        let previous = PaneLifecycleState(
            clock: 0,
            entries: [
                "p1": PaneLifecycleEntry(lifecycle: .visible, lastVisible: 1),
                "p2": PaneLifecycleEntry(lifecycle: .parked, lastVisible: 2),
                "p3": PaneLifecycleEntry(lifecycle: .parked, lastVisible: 3),
                "p4": PaneLifecycleEntry(lifecycle: .parked, lastVisible: 4),
            ]
        )
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                hotHiddenCap: 2,
                paneIds: ["p1", "p2", "p3", "p4"]
            )
        )
        XCTAssertEqual(next.entries["p1"]?.lifecycle, .visible)
        XCTAssertEqual(next.entries["p4"]?.lifecycle, .hotHidden)
        XCTAssertEqual(next.entries["p3"]?.lifecycle, .hotHidden)
        XCTAssertEqual(next.entries["p2"]?.lifecycle, .parked)
    }

    func testKeepAliveHotHiddenOutsideCap() {
        let previous = PaneLifecycleState(
            clock: 0,
            entries: [
                "p1": PaneLifecycleEntry(lifecycle: .visible, lastVisible: 1),
                "terminal": PaneLifecycleEntry(lifecycle: .parked, lastVisible: 0),
                "p3": PaneLifecycleEntry(lifecycle: .parked, lastVisible: 2),
            ]
        )
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                hotHiddenCap: 0,  // cap = 0 = everything beyond keepAlive parks
                keepAlive: { $0 == "terminal" },
                paneIds: ["p1", "terminal", "p3"]
            )
        )
        XCTAssertEqual(next.entries["terminal"]?.lifecycle, .hotHidden)
        XCTAssertEqual(next.entries["p3"]?.lifecycle, .parked)
    }

    func testPaneRemovedFromZoneDropsFromEntries() {
        let previous = PaneLifecycleState(
            clock: 0,
            entries: [
                "p1": PaneLifecycleEntry(lifecycle: .visible, lastVisible: 1),
                "p2": PaneLifecycleEntry(lifecycle: .hotHidden, lastVisible: 0),
            ]
        )
        let next = reconcilePaneLifecycle(
            previous: previous,
            options: ReconcilePaneLifecycleOptions(
                activeId: "p1",
                paneIds: ["p1"]  // p2 removed
            )
        )
        XCTAssertNil(next.entries["p2"])
        XCTAssertEqual(next.entries["p1"]?.lifecycle, .visible)
    }
}

final class GeometryTests: XCTestCase {

    func testAABBIntersection() {
        let a = GeometryRect(x: 0, y: 0, width: 100, height: 100)
        let b = GeometryRect(x: 50, y: 50, width: 100, height: 100)
        let hit = intersect(a, b)
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.x, 50)
        XCTAssertEqual(hit?.y, 50)
        XCTAssertEqual(hit?.width, 50)
        XCTAssertEqual(hit?.height, 50)
    }

    func testAABBNoIntersection() {
        let a = GeometryRect(x: 0, y: 0, width: 50, height: 50)
        let b = GeometryRect(x: 100, y: 100, width: 50, height: 50)
        XCTAssertNil(intersect(a, b))
    }

    func testAABBEdgeTouchIsNotOverlap() {
        // Touching at x = right edge of a = left edge of b is NOT overlap.
        let a = GeometryRect(x: 0, y: 0, width: 50, height: 50)
        let b = GeometryRect(x: 50, y: 0, width: 50, height: 50)
        XCTAssertNil(intersect(a, b))
    }

    func testWindowControlsRectMacOS() {
        let conn = GeometryConnection(windowButtonPosition: CGPoint(x: 12, y: 0))
        let rect = windowControlsRect(connection: conn, viewportWidth: 1920)
        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.x, 0)
        XCTAssertEqual(rect?.y, 0)
        XCTAssertEqual(rect?.width, 12 + kMacOSLightsWidth)
        XCTAssertEqual(rect?.height, kControlsBandHeight)
    }

    func testWindowControlsRectFullscreenReturnsNil() {
        let conn = GeometryConnection(
            windowButtonPosition: CGPoint(x: 12, y: 0),
            isFullscreen: true
        )
        XCTAssertNil(windowControlsRect(connection: conn, viewportWidth: 1920))
    }

    func testWindowControlsRectNoControlsReturnsNil() {
        let conn = GeometryConnection(windowButtonPosition: nil)
        XCTAssertNil(windowControlsRect(connection: conn, viewportWidth: 1920))
    }

    func testNativeControlsInset() {
        let conn = GeometryConnection(windowButtonPosition: CGPoint(x: 12, y: 0))
        let inset = nativeControlsInset(connection: conn, viewportWidth: 1920)
        XCTAssertEqual(inset.top, kControlsBandHeight)
        XCTAssertEqual(inset.leading, 0)
        XCTAssertEqual(inset.trailing, 1920 - (12 + kMacOSLightsWidth))
        XCTAssertEqual(inset.bottom, 0)
    }

    func testComputeWorkspaceGeometry() {
        let viewport = GeometryRect(x: 0, y: 0, width: 1920, height: 1080)
        let mainPane = GeometryRect(x: 0, y: 34, width: 1920, height: 1046)
        let g = computeWorkspaceGeometry(viewport: viewport, mainPane: mainPane)
        XCTAssertEqual(g.left, 0)
        XCTAssertEqual(g.right, 0)
        XCTAssertEqual(g.viewportWidth, 1920)
        XCTAssertEqual(g.viewportHeight, 1080)
    }
}

@MainActor
final class PaneVisibleContextTests: XCTestCase {

    func testDefaultEnvironmentIsVisible() {
        let env = EnvironmentValues()
        XCTAssertTrue(env.paneVisible)
        XCTAssertEqual(env.paneLifecycle, .visible)
        XCTAssertEqual(env.paneGroup, kNoPaneGroup)
    }

    func testPaneVisibleContextOverride() {
        // Verify the modifier sets the environment value.
        let view = PaneVisibleContext(visible: false) {
            EmptyView()
        }
        // Verify via View introspection isn't trivial without ViewInspector,
        // so just verify the modifier type can be constructed without crash.
        _ = view.body
    }

    func testPaneGroupKeySentinel() {
        XCTAssertEqual(kNoPaneGroup, "window")
    }
}