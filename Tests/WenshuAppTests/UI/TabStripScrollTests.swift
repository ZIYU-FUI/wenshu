// TabStripScrollTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-032

import XCTest
import SwiftUI
@testable import WenshuApp

final class TabStripScrollLeftTests: XCTestCase {
    /// When the active tab is the last one, return `max` (= scroll to the end
    /// so the trailing "+" comes along).
    func testLastTabScrollsToMax() {
        let g = TabStripGeometry(
            clientWidth: 200,
            last: true,
            scrollLeft: 0,
            scrollWidth: 500,
            tabEnd: 480,
            tabStart: 460
        )
        XCTAssertEqual(tabStripScrollLeft(g), 300)  // max = 500 - 200
    }

    /// When the active tab is left of the visible viewport, scroll so its
    /// start aligns with the left edge.
    func testTabLeftOfViewScrollsRight() {
        let g = TabStripGeometry(
            clientWidth: 200,
            last: false,
            scrollLeft: 100,
            scrollWidth: 500,
            tabEnd: 130,
            tabStart: 50
        )
        XCTAssertEqual(tabStripScrollLeft(g), 50)
    }

    /// When the active tab is right of the visible viewport, scroll so its
    /// end aligns with the right edge.
    func testTabRightOfViewScrollsLeft() {
        let g = TabStripGeometry(
            clientWidth: 200,
            last: false,
            scrollLeft: 0,
            scrollWidth: 500,
            tabEnd: 400,
            tabStart: 380
        )
        // tabEnd - clientWidth = 400 - 200 = 200
        XCTAssertEqual(tabStripScrollLeft(g), 200)
    }

    /// When the active tab is already in view, return the current scroll
    /// offset (no change).
    func testTabInViewReturnsCurrentScroll() {
        let g = TabStripGeometry(
            clientWidth: 200,
            last: false,
            scrollLeft: 100,
            scrollWidth: 500,
            tabEnd: 220,
            tabStart: 200
        )
        // tabStart (200) >= scrollLeft (100) AND tabEnd (220) <= scrollLeft + clientWidth (300)
        XCTAssertEqual(tabStripScrollLeft(g), 100)
    }

    /// When scrollWidth <= clientWidth, max = 0 (no scroll possible).
    func testNoOverflowReturnsZero() {
        let g = TabStripGeometry(
            clientWidth: 500,
            last: false,
            scrollLeft: 0,
            scrollWidth: 300,  // less than clientWidth → max = 0
            tabEnd: 100,
            tabStart: 80
        )
        XCTAssertEqual(tabStripScrollLeft(g), 0)
    }

    /// When tabStart would exceed max, clamp to max.
    func testTabStartClampedToMax() {
        let g = TabStripGeometry(
            clientWidth: 100,
            last: false,
            scrollLeft: 50,
            scrollWidth: 200,
            tabEnd: 150,
            tabStart: 80
        )
        // tabStart (80) < scrollLeft (50)? No, 80 > 50.
        // tabEnd (150) > scrollLeft + clientWidth (150)? No, 150 == 150.
        // → return min(scrollLeft, max) = min(50, 100) = 50
        XCTAssertEqual(tabStripScrollLeft(g), 50)
    }

    /// When scrollWidth equals clientWidth, max = 0 and scrollLeft = 0.
    func testExactFitReturnsZero() {
        let g = TabStripGeometry(
            clientWidth: 200,
            last: false,
            scrollLeft: 0,
            scrollWidth: 200,
            tabEnd: 200,
            tabStart: 180
        )
        XCTAssertEqual(tabStripScrollLeft(g), 0)
    }
}

@MainActor
final class TabStripGeometryTests: XCTestCase {
    func testConstruction() {
        let g = TabStripGeometry(
            clientWidth: 100,
            last: true,
            scrollLeft: 50,
            scrollWidth: 200,
            tabEnd: 80,
            tabStart: 60
        )
        XCTAssertEqual(g.clientWidth, 100)
        XCTAssertTrue(g.last)
        XCTAssertEqual(g.scrollLeft, 50)
        XCTAssertEqual(g.scrollWidth, 200)
        XCTAssertEqual(g.tabEnd, 80)
        XCTAssertEqual(g.tabStart, 60)
    }

    func testEquatable() {
        let a = TabStripGeometry(clientWidth: 100, last: true, scrollLeft: 0, scrollWidth: 200, tabEnd: 100, tabStart: 80)
        let b = TabStripGeometry(clientWidth: 100, last: true, scrollLeft: 0, scrollWidth: 200, tabEnd: 100, tabStart: 80)
        XCTAssertEqual(a, b)
    }
}

@MainActor
final class TabStripFadeOverlayTests: XCTestCase {
    func testLeftSideRenders() {
        let view = TabStripFadeOverlay(side: .left)
        XCTAssertNotNil(view)
    }

    func testRightSideRenders() {
        let view = TabStripFadeOverlay(side: .right)
        XCTAssertNotNil(view)
    }

    func testCustomWidth() {
        let view = TabStripFadeOverlay(side: .right, width: 40)
        XCTAssertNotNil(view)
    }
}