// PaneVisibilityStoreTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-014
//
// Tests for the 3 visibility mechanisms (= hiddenTreePanes / dismissedPanes
// / collapsePanes) + bindings (bindPaneVisibility / bindToolPaneCollapse)
// + pane size persistence + statusbar per-item visibility. Boss
// 2026-08-29 OOB '完整复刻 hermes app'.

import XCTest
@testable import WenshuApp

@MainActor
final class PaneVisibilityStoreTests: XCTestCase {

    // MARK: - Hidden tree panes (= sidebar ⌘B / file browser ⌘G)

    func testSetTreePaneHiddenAdds() {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)
        XCTAssertTrue(s.hiddenTreePanes.contains("sidebar"))
    }

    func testSetTreePaneHiddenNoOpWhenSame() {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)
        let count1 = s.hiddenTreePanes.count
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)  // no-op
        XCTAssertEqual(s.hiddenTreePanes.count, count1)
    }

    func testSetTreePaneHiddenRemoves() {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)
        s.setTreePaneHidden(paneId: "sidebar", hidden: false)
        XCTAssertFalse(s.hiddenTreePanes.contains("sidebar"))
    }

    func testTogglePaneVisible() {
        let s = PaneVisibilityStore()
        s.togglePaneVisible(paneId: "sidebar")
        XCTAssertTrue(s.hiddenTreePanes.contains("sidebar"))
        s.togglePaneVisible(paneId: "sidebar")
        XCTAssertFalse(s.hiddenTreePanes.contains("sidebar"))
    }

    // MARK: - Dismissed panes (= Close button removes from tree)

    func testSetDismissed() {
        let s = PaneVisibilityStore()
        s.setDismissed(paneId: "files", dismissed: true)
        XCTAssertTrue(s.dismissedPanes.contains("files"))
        s.setDismissed(paneId: "files", dismissed: false)
        XCTAssertFalse(s.dismissedPanes.contains("files"))
    }

    func testRememberPaneShare() {
        let s = PaneVisibilityStore()
        s.rememberPaneShare(groupId: "g1", paneId: "files", position: 0)
        XCTAssertEqual(s.rememberedGroup(ofPane: "files"), "g1")
        XCTAssertEqual(s.rememberedPosition(ofPane: "files"), 0)
    }

    // MARK: - Collapse membership (= mark as tool panel)

    func testMarkCollapsePane() {
        let s = PaneVisibilityStore()
        s.markCollapsePane(paneId: "terminal")
        XCTAssertTrue(s.isCollapsePane("terminal"))
        XCTAssertFalse(s.isCollapsePane("files"))
    }

    // MARK: - Pane visibility query (= on-screen check)

    func testIsPaneVisibleFalseWhenDismissed() {
        let s = PaneVisibilityStore()
        s.setDismissed(paneId: "files", dismissed: true)
        XCTAssertFalse(s.isPaneVisible(
            paneId: "files", inTree: true,
            zoneMinimized: false, isActiveInGroup: true
        ))
    }

    func testIsPaneVisibleFalseWhenHidden() {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "files", hidden: true)
        XCTAssertFalse(s.isPaneVisible(
            paneId: "files", inTree: true,
            zoneMinimized: false, isActiveInGroup: true
        ))
    }

    func testIsPaneVisibleTrueWhenInTreeActive() {
        let s = PaneVisibilityStore()
        XCTAssertTrue(s.isPaneVisible(
            paneId: "files", inTree: true,
            zoneMinimized: false, isActiveInGroup: true
        ))
    }

    func testIsPaneVisibleFalseWhenZoneMinimized() {
        let s = PaneVisibilityStore()
        XCTAssertFalse(s.isPaneVisible(
            paneId: "files", inTree: true,
            zoneMinimized: true, isActiveInGroup: true
        ))
    }

    func testIsPaneVisibleFalseWhenNotActive() {
        let s = PaneVisibilityStore()
        XCTAssertFalse(s.isPaneVisible(
            paneId: "files", inTree: true,
            zoneMinimized: false, isActiveInGroup: false
        ))
    }

    // MARK: - Bindings (= chrome ↔ tree)

    func testBindPaneVisibility() {
        let s = PaneVisibilityStore()
        s.bindPaneVisibility(paneId: "sidebar", isOpen: true)
        XCTAssertFalse(s.hiddenTreePanes.contains("sidebar"))
        s.bindPaneVisibility(paneId: "sidebar", isOpen: false)
        XCTAssertTrue(s.hiddenTreePanes.contains("sidebar"))
    }

    func testBindToolPaneCollapseMarksAsCollapsePane() {
        let s = PaneVisibilityStore()
        s.bindToolPaneCollapse(
            paneId: "terminal",
            isOpen: true,
            close: {},
            open: {}
        )
        XCTAssertTrue(s.isCollapsePane("terminal"))
        XCTAssertFalse(s.hiddenTreePanes.contains("terminal"))
    }

    // MARK: - Pane size override (= sash drag persistence)

    func testPaneSizeOverride() {
        let s = PaneVisibilityStore()
        s.setPaneWidthOverride(paneId: "g1", width: 240)
        XCTAssertEqual(s.paneSizeSnapshot("g1")?.widthOverride, 240)
        s.setPaneHeightOverride(paneId: "g1", height: 100)
        XCTAssertEqual(s.paneSizeSnapshot("g1")?.heightOverride, 100)
    }

    func testClearAllPaneSizeOverrides() {
        let s = PaneVisibilityStore()
        s.setPaneWidthOverride(paneId: "g1", width: 240)
        s.setPaneWidthOverride(paneId: "g2", width: 300)
        s.clearAllPaneSizeOverrides()
        XCTAssertTrue(s.paneStates.isEmpty)
    }

    // MARK: - Statusbar per-item visibility

    func testStatusbarItemVisible() {
        let s = PaneVisibilityStore()
        s.setStatusbarItemVisible(itemId: "model", visible: false)
        XCTAssertTrue(s.statusbarHiddenIds.contains("model"))
        s.setStatusbarItemVisible(itemId: "model", visible: true)
        XCTAssertFalse(s.statusbarHiddenIds.contains("model"))
    }

    func testResetStatusbarLayout() {
        let s = PaneVisibilityStore()
        s.setStatusbarItemVisible(itemId: "a", visible: false)
        s.setStatusbarItemVisible(itemId: "b", visible: false)
        s.resetStatusbarLayout()
        XCTAssertTrue(s.isStatusbarLayoutDefault())
        XCTAssertTrue(s.statusbarHiddenIds.isEmpty)
    }

    // MARK: - Codable round-trip (= persistence)

    func testCodableRoundTrip() throws {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)
        s.setDismissed(paneId: "files", dismissed: true)
        s.markCollapsePane(paneId: "terminal")
        s.setPaneWidthOverride(paneId: "g1", width: 240)
        s.setStatusbarItemVisible(itemId: "model", visible: false)
        s.statusbarVisible = false

        let data = try s.encoded()
        let restored = PaneVisibilityStore()
        restored.restore(from: data)

        XCTAssertTrue(restored.hiddenTreePanes.contains("sidebar"))
        XCTAssertTrue(restored.dismissedPanes.contains("files"))
        XCTAssertTrue(restored.isCollapsePane("terminal"))
        XCTAssertEqual(restored.paneSizeSnapshot("g1")?.widthOverride, 240)
        XCTAssertTrue(restored.statusbarHiddenIds.contains("model"))
        XCTAssertFalse(restored.statusbarVisible)
    }

    func testCodableRoundTripIgnoresInvalidSchema() throws {
        let s = PaneVisibilityStore()
        s.setTreePaneHidden(paneId: "sidebar", hidden: true)

        let data = try s.encoded()
        // Tamper with schema version
        var json = String(data: data, encoding: .utf8)!
        json = json.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":99")
        let tampered = json.data(using: .utf8)!

        let restored = PaneVisibilityStore()
        restored.restore(from: tampered)
        // Tampered = ignored = empty state.
        XCTAssertTrue(restored.hiddenTreePanes.isEmpty)
    }
}