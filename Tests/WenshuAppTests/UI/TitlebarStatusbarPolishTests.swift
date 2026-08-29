// TitlebarStatusbarPolishTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-023
//
// Tests for titlebar/statusbar polish refinements. Boss 2026-08-29 OOB.

import XCTest
import SwiftUI
import AppKit
@testable import WenshuApp

@MainActor
final class TitlebarControlStyleTests: XCTestCase {
    func testStyleConstructs() {
        let style = TitlebarControlStyle()
        // Cannot construct ButtonStyleConfiguration directly; just verify
        // the type exists + can be instantiated (= SwiftUI internals handle
        // actual makeBody call).
        _ = style
    }
}

@MainActor
final class TitlebarControlsYNudgeTests: XCTestCase {
    func testPreTahoeReturnsNudge() {
        let nudge = titlebarControlsYNudge(
            darwinMajor: 24,  // Pre-Tahoe
            isFullscreen: false,
            windowButtonPosition: CGPoint(x: 12, y: 0)
        )
        XCTAssertEqual(nudge, kTitlebarMacTrafficLightsYNudge)
    }

    func testTahoeReturnsZero() {
        let nudge = titlebarControlsYNudge(
            darwinMajor: 25,  // Tahoe
            isFullscreen: false,
            windowButtonPosition: CGPoint(x: 12, y: 0)
        )
        XCTAssertEqual(nudge, 0)
    }

    func testFullscreenReturnsZero() {
        let nudge = titlebarControlsYNudge(
            darwinMajor: 24,
            isFullscreen: true,
            windowButtonPosition: CGPoint(x: 12, y: 0)
        )
        XCTAssertEqual(nudge, 0)
    }

    func testNilWindowButtonPositionReturnsZero() {
        let nudge = titlebarControlsYNudge(
            darwinMajor: 24,
            isFullscreen: false,
            windowButtonPosition: nil
        )
        XCTAssertEqual(nudge, 0)
    }
}

@MainActor
final class TitlebarToolsRightInsetTests: XCTestCase {
    func testNativeOverlayReturnsOverlayWidth() {
        let inset = titlebarToolsRightInset(nativeOverlayWidth: 100, darwinMajor: 24)
        XCTAssertEqual(inset, 100)
    }

    func testNoOverlayReturnsDefault() {
        let inset = titlebarToolsRightInset(nativeOverlayWidth: 0)
        XCTAssertEqual(inset, 12.0)
    }

    func testFullscreenTahoeReturnsEdgeInset() {
        let inset = titlebarToolsRightInset(nativeOverlayWidth: 0, darwinMajor: 25, isFullscreen: true)
        XCTAssertEqual(inset, kTitlebarEdgeInset)
    }
}

@MainActor
final class StatusbarActionStyleTests: XCTestCase {
    func testStyleConstructs() {
        let view = Text("test").statusbarActionStyle()
        _ = AnyView(view)
    }

    func testDisabledStyle() {
        let view = Text("test").statusbarActionStyle(disabled: true)
        _ = AnyView(view)
    }
}

@MainActor
final class TitlebarClusterTests: XCTestCase {
    func testLeftCluster() {
        let view = Text("test").titlebarCluster(.left)
        _ = AnyView(view)
    }

    func testRightCluster() {
        let view = Text("test").titlebarCluster(.right)
        _ = AnyView(view)
    }
}

final class MacOSTahoeTests: XCTestCase {
    @MainActor
    func testIsMacOSTahoeReturnsBool() {
        // Just verify it doesn't crash (= returns a bool).
        let isTahoe = isMacOSTahoe()
        XCTAssertNotNil(isTahoe as Bool)
    }
}