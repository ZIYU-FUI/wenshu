// ZonePerRegionChromeTests.swift · Wenshu (文枢) · v0.28 followup Boss UX round 2
//
// Tests for per-region top/bottom toolbar components. Boss 2026-08-29
// OOB '老的六区, 是顶栏底栏在各区域里都有配' = old 6区 = per-region
// top + bottom toolbars, new framework should match this pattern.

import XCTest
import SwiftUI
@testable import WenshuApp

final class RegionPerZoneChromeTokenTests: XCTestCase {
    func testRegionToolbarHeight() {
        XCTAssertEqual(kRegionPerZoneToolbarHeight, 30)
    }
}

@MainActor
final class RegionPerZoneChromeViewTests: XCTestCase {
    func testChromeRenders() {
        // Just verify it can be constructed.
        _ = RegionPerZoneChrome {
            Text("test")
        }
    }

    func testChromeWithTopAndBottom() {
        _ = RegionPerZoneChrome(
            topItems: [
                RegionTopItem(id: "test", iconName: "plus", label: "Test")
            ],
            bottomItems: [
                RegionBottomItem(id: "status", label: "Status")
            ]
        ) {
            Text("test")
        }
    }
}

final class DefaultPerRegionChromeTests: XCTestCase {
    func testSidebarChrome() {
        let (top, bottom) = defaultSidebarRegionChrome(bookCount: 5, shelfCount: 2)
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].id, "new-book")
        XCTAssertEqual(top[1].id, "search")
        XCTAssertEqual(bottom.count, 2)
        XCTAssertEqual(bottom[0].label, "书架: 2")
        XCTAssertEqual(bottom[1].label, "书: 5")
    }

    func testPreviewChrome() {
        let (top, bottom) = defaultPreviewRegionChrome(chapterCount: 12)
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].id, "search")
        XCTAssertEqual(top[1].id, "filter")
        XCTAssertEqual(bottom.count, 1)
        XCTAssertEqual(bottom[0].label, "章节: 12")
    }

    func testEditorChrome() {
        let (top, bottom) = defaultEditorRegionChrome(wordCount: 3500, progress: 0.42)
        XCTAssertEqual(top.count, 5)  // bold, italic, underline, list, more
        XCTAssertEqual(top[0].id, "bold")
        XCTAssertEqual(bottom.count, 2)
        XCTAssertEqual(bottom[0].label, "字数: 3500")
        XCTAssertEqual(bottom[1].detail, "42%")
    }

    func testToolsChrome() {
        let (top, bottom) = defaultToolsRegionChrome()
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(bottom.count, 1)
        XCTAssertEqual(bottom[0].label, "工具就绪")
    }

    func testChatChromeEmpty() {
        // Chat zone has its own internal toolbar (= in-child ChatBottomToolbar).
        let (top, bottom) = defaultChatRegionChrome()
        XCTAssertEqual(top.count, 0)
        XCTAssertEqual(bottom.count, 0)
    }

    func testDynamicChrome() {
        let (top, bottom) = defaultDynamicRegionChrome()
        XCTAssertEqual(top.count, 3)  // progress, todo, search
        XCTAssertEqual(bottom.count, 1)
        XCTAssertEqual(bottom[0].label, "看板")
    }
}

final class RegionTopItemTests: XCTestCase {
    func testItemConstruction() {
        let item = RegionTopItem(
            id: "test",
            iconName: "plus",
            label: "Test",
            onSelect: { print("clicked") }
        )
        XCTAssertEqual(item.id, "test")
        XCTAssertEqual(item.iconName, "plus")
        XCTAssertEqual(item.label, "Test")
    }
}

final class RegionBottomItemTests: XCTestCase {
    func testItemConstruction() {
        let item = RegionBottomItem(
            id: "status",
            label: "Active",
            detail: "5/10",
            iconName: "check"
        )
        XCTAssertEqual(item.id, "status")
        XCTAssertEqual(item.label, "Active")
        XCTAssertEqual(item.detail, "5/10")
        XCTAssertEqual(item.iconName, "check")
    }
}