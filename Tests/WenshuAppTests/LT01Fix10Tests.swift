// LT01Fix10Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix10
//
// NativeSplitterView mouse tracking contract:
// - entering the complete divider hit area sets the orientation cursor and hover state
// - exiting restores the previous cursor and clears hover state
// - tracking is active for entered/exited events in the key window

import XCTest
import AppKit
@testable import WenshuApp

@MainActor
final class LT01Fix10Tests: XCTestCase {

    func testNativeSplitterView_mouseExited_resetsCursor() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal
        let previousCursor = NSCursor.current
        let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: 4, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )!

        view.mouseEntered(with: event)
        XCTAssertTrue(view.isHovered)
        XCTAssertTrue(
            NSCursor.current === NSCursor.resizeLeftRight,
            "horizontal divider hover must push resizeLeftRight"
        )

        view.mouseExited(with: event)
        XCTAssertTrue(
            NSCursor.current === previousCursor,
            "mouseExited must pop the cursor pushed by mouseEntered"
        )
    }

    func testNativeSplitterView_mouseExited_resetsHover() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: 4, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )!

        view.mouseEntered(with: event)
        XCTAssertTrue(view.isHovered)
        let enteredRedraws = view.redrawRequestCount

        view.mouseExited(with: event)

        XCTAssertFalse(view.isHovered)
        XCTAssertGreaterThan(
            view.redrawRequestCount, enteredRedraws,
            "mouseExited must schedule a hover redraw (count incremented after exit)"
        )
    }

    func testNativeSplitterView_trackingArea_options() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.updateTrackingAreas()

        XCTAssertEqual(view.trackingAreas.count, 1)
        guard let trackingArea = view.trackingAreas.first else {
            return XCTFail("NativeSplitterView must install a divider tracking area")
        }
        XCTAssertTrue(trackingArea.options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(trackingArea.options.contains(.activeInKeyWindow))
        XCTAssertEqual(trackingArea.rect, view.bounds)
    }
}
