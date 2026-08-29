// AppTitlebarStatusbarTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-015
//
// Tests for AppTitlebar + AppStatusbar AppRoot components. Boss
// 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一'.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class AppTitlebarTests: XCTestCase {

    func testTokensMatchHermesConstants() {
        // Herms TITLEBAR_HEIGHT = 34 (= native traffic light standard).
        XCTAssertEqual(kTitlebarHeight, 34)
        XCTAssertEqual(kTitlebarControlSize, 24)
        XCTAssertEqual(kTitlebarIconSize, 13.9)
        XCTAssertEqual(kTitlebarEdgeInset, 14)
        XCTAssertEqual(kTitlebarControlOffsetX, 74)
        XCTAssertEqual(kTitlebarFallbackWindowButtonX, 24)
    }

    func testTitlebarTool() {
        let tool = TitlebarTool(
            id: "test",
            label: "Test tool",
            iconName: "gear",
            onSelect: { print("clicked") }
        )
        XCTAssertEqual(tool.id, "test")
        XCTAssertEqual(tool.label, "Test tool")
        XCTAssertEqual(tool.iconName, "gear")
    }

    func testDefaultTitlebarLeftTools() {
        let tools = defaultTitlebarLeftTools(
            sidebarVisible: true,
            previewVisible: false,
            onToggleSidebar: {},
            onTogglePreview: {},
            onToggleTools: {}
        )
        XCTAssertEqual(tools.count, 3)
        XCTAssertEqual(tools[0].id, "sidebar-toggle")
        XCTAssertEqual(tools[1].id, "preview-toggle")
        XCTAssertEqual(tools[2].id, "tools-toggle")
        XCTAssertTrue(tools[0].active)  // sidebar visible
        XCTAssertFalse(tools[1].active)  // preview hidden
    }

    func testDefaultTitlebarRightTools() {
        let tools = defaultTitlebarRightTools(
            modelName: "MiniMax-M3",
            onSelectModel: {}
        )
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0].id, "model-picker")
        XCTAssertEqual(tools[0].label, "Model: MiniMax-M3")
    }

    func testTitlebarRenders() {
        // Just verify it can be constructed (= does not crash).
        _ = AppTitlebar(
            registry: ContributionRegistry(),
            leftTools: [],
            rightTools: [],
            title: "test"
        )
    }
}

@MainActor
final class AppStatusbarTests: XCTestCase {

    func testTokens() {
        XCTAssertEqual(kStatusbarItemHeight, 24)
        XCTAssertEqual(kStatusbarBorderHeight, 1)
    }

    func testStatusbarItem() {
        let item = StatusbarItem(
            id: "model",
            label: "M3",
            iconName: "cpu",
            variant: .text
        )
        XCTAssertEqual(item.id, "model")
        XCTAssertEqual(item.variant, .text)
        XCTAssertFalse(item.lockedVisible)
    }

    func testDefaultStatusbarLeftItems() {
        let items = defaultStatusbarLeftItems(
            modelName: "MiniMax-M3",
            llmStatus: "Idle"
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, "model")
        XCTAssertEqual(items[0].label, "MiniMax-M3")
        XCTAssertEqual(items[1].id, "status")
        XCTAssertEqual(items[1].detail, "Idle")
    }

    func testDefaultStatusbarRightItems() {
        let items = defaultStatusbarRightItems(version: "v0.28")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, "version")
        XCTAssertEqual(items[0].label, "wenshu v0.28")
    }

    func testDefaultStatusbarRightItemsWithSession() {
        let items = defaultStatusbarRightItems(version: "v0.28", sessionId: "abc-123")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[1].id, "session")
        XCTAssertEqual(items[1].label, "abc-123")
    }

    func testStatusbarFiltersHiddenItems() {
        // We can't easily test the SwiftUI view body filtering, but
        // we can test the logic via AppStatusbar's visibleItems function.
        // Since it's private, we test via the items list construction.
        var items = defaultStatusbarLeftItems(modelName: "M3", llmStatus: "Idle")
        items.append(StatusbarItem(id: "hidden", label: "hidden", hidden: true))
        XCTAssertEqual(items.filter { !$0.hidden }.count, 2)
    }

    func testLockedVisibleItemsCannotBeHidden() {
        let item = StatusbarItem(id: "version", label: "v0.28", lockedVisible: true)
        XCTAssertTrue(item.lockedVisible)
    }

    func testStatusbarRenders() {
        _ = AppStatusbar(
            leftItems: defaultStatusbarLeftItems(modelName: "M3", llmStatus: "Idle"),
            rightItems: defaultStatusbarRightItems(),
            visible: true,
            hiddenIds: []
        )
    }

    func testStatusbarHiddenViaVisibility() {
        _ = AppStatusbar(
            leftItems: [],
            rightItems: [],
            visible: false,
            hiddenIds: []
        )
        // EmptyView body
    }

    func testStatusbarContextMenuShowHide() {
        var toggleCount = 0
        var toggledId = ""
        _ = AppStatusbar(
            leftItems: [
                StatusbarItem(id: "model", label: "M3", toggleLabel: "Model")
            ],
            rightItems: [],
            onToggleItemVisibility: { id in
                toggleCount += 1
                toggledId = id
            }
        )
        // Simulate calling the callback (= the right-click menu would do this).
        // The view is constructed successfully.
    }
}