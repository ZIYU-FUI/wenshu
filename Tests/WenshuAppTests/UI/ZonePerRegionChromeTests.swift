// ZonePerRegionChromeTests.swift · Wenshu (文枢) · v0.28 followup Boss UX round 3
//
// Tests for per-region top + bottom toolbar components. Boss 2026-08-29
// OOB '按老六区已经实现的复刻' = port the OLD 6区 ZoneTopToolbar +
// ZoneBottomToolbar exactly (= 30 PT each, per-slot icons + status
// text from v0.27 ZoneModule).

import XCTest
import SwiftUI
@testable import WenshuApp

final class ZoneToolbarHeightTests: XCTestCase {
    func testToolbarHeight() {
        XCTAssertEqual(kZoneToolbarHeight, 30)
    }

    func testIconSize() {
        XCTAssertEqual(kZoneToolbarIconSize, 18)
    }
}

@MainActor
final class ZonePerRegionChromeViewTests: XCTestCase {
    func testChromeRenders() {
        _ = ZonePerRegionChrome {
            Text("test")
        }
    }

    func testChromeWithTopAndBottom() {
        _ = ZonePerRegionChrome(
            topActions: [
                ZoneTopAction(id: "test", label: "Test", icon: "plus")
            ],
            bottomStatus: ZoneBottomStatus(left: "Status", right: "")
        ) {
            Text("test")
        }
    }

    func testChromeBottomSkip() {
        _ = ZonePerRegionChrome(
            bottomSkip: true
        ) {
            Text("test")
        }
    }
}

final class DefaultZoneChromeTests: XCTestCase {
    func testSidebarChrome() {
        let (top, bottom) = projectSidebarChrome(shelfCount: 5, bookCount: 12)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].id, "templates")
        XCTAssertEqual(top[0].icon, "doc.badge.plus")
        XCTAssertEqual(top[1].id, "new-book")
        XCTAssertEqual(top[1].icon, "book-open")
        XCTAssertEqual(top[2].id, "archive")
        XCTAssertEqual(top[2].icon, "archive")
        XCTAssertEqual(bottom.left, "书架: 5")
        XCTAssertEqual(bottom.right, "书: 12")
    }

    func testPreviewChrome() {
        let (top, bottom) = projectPreviewChrome(chapterCount: 12)
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].id, "preview")
        XCTAssertEqual(top[0].icon, "book-open-check")
        XCTAssertEqual(top[1].id, "graph")
        XCTAssertEqual(top[1].icon, "waypoints")
        XCTAssertEqual(bottom.left, "章节: 12")
        XCTAssertEqual(bottom.right, "")
    }

    func testEditorChrome() {
        let (top, bottom) = editorChrome(wordCount: 3500, progress: 0.42)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].id, "edit")
        XCTAssertEqual(top[0].icon, "book-open-text")
        XCTAssertEqual(top[1].id, "outline")
        XCTAssertEqual(top[1].icon, "puzzle")
        XCTAssertEqual(top[2].id, "backlinks")
        XCTAssertEqual(top[2].icon, "link")
        XCTAssertEqual(bottom.left, "字数: 3500")
        XCTAssertEqual(bottom.right, "42%")
    }

    func testSpecializedToolsChrome() {
        let (top, bottom) = specializedToolsChrome()
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].id, "canvas")
        XCTAssertEqual(top[0].icon, "scribble")
        XCTAssertEqual(top[1].id, "database")
        XCTAssertEqual(top[1].icon, "tablecells")
        XCTAssertEqual(bottom.left, "工具就绪")
        XCTAssertEqual(bottom.right, "")
    }

    func testAIChatChrome() {
        let (top, bottom) = aiChatChrome()
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].id, "bot")
        XCTAssertEqual(top[0].icon, "bot")
        XCTAssertEqual(top[1].id, "inbox")
        XCTAssertEqual(top[1].icon, "inbox")
        XCTAssertEqual(bottom.left, "")
        XCTAssertEqual(bottom.right, "")
    }

    func testAIDynamicChrome() {
        let (top, bottom) = aiDynamicChrome()
        XCTAssertEqual(top.count, 0)  // dynamic uses internal DynamicZoneTabBar
        XCTAssertEqual(bottom.left, "看板")
        XCTAssertEqual(bottom.right, "")
    }
}

final class ZoneTopActionTests: XCTestCase {
    func testConstruction() {
        let action = ZoneTopAction(
            id: "test",
            label: "Test",
            icon: "plus",
            onSelect: { print("clicked") }
        )
        XCTAssertEqual(action.id, "test")
        XCTAssertEqual(action.label, "Test")
        XCTAssertEqual(action.icon, "plus")
    }
}

final class ZoneBottomStatusTests: XCTestCase {
    func testDefaultEmpty() {
        let s = ZoneBottomStatus()
        XCTAssertEqual(s.left, "")
        XCTAssertEqual(s.right, "")
    }

    func testConstruction() {
        let s = ZoneBottomStatus(left: "书架: 3", right: "书: 12")
        XCTAssertEqual(s.left, "书架: 3")
        XCTAssertEqual(s.right, "书: 12")
    }
}

final class ZoneChromeIconTests: XCTestCase {
    @MainActor
    func testLucideIcon() {
        _ = ZoneChromeIcon(systemName: "waypoints")
    }

    @MainActor
    func testSFFallbackIcon() {
        // SF Symbol that Lucide doesn't have
        _ = ZoneChromeIcon(systemName: "magnifyingglass")
    }

    @MainActor
    func testCustomSize() {
        _ = ZoneChromeIcon(systemName: "plus", size: 24)
    }
}
