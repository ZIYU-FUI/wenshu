// DropAffordanceTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-021
//
// Tests for drop affordance + drag visuals. Boss 2026-08-29 OOB.

import XCTest
import SwiftUI
import AppKit
@testable import WenshuApp

final class DropAffordanceTokenTests: XCTestCase {
    func testTokens() {
        // Herms FADE_IN_DURATION_MILLIS = 200.
        XCTAssertEqual(kFadeInDurationMillis, 200)
        // Herms FLASH_ZONES_DURATION_MILLIS = 700.
        XCTAssertEqual(kFlashZonesDurationMillis, 700)
        // Herms DEFAULT_SENSITIVITY_RADIUS = 20.
        XCTAssertEqual(kDefaultSensitivityRadius, 20)
        // Herms OVERLAPPING_CENTERS_SENSITIVITY = 75.
        XCTAssertEqual(kOverlappingCentersSensitivity, 75)
    }
}

final class DropSheetAnimationAlphaTests: XCTestCase {
    func testInitialAlphaIsFloorValue() {
        // At t = 0, alpha = 0.001 (= floor, NOT 0 — avoids CSS flicker).
        let alpha = DropSheet.animationAlpha(
            startedAt: Date(),
            now: Date(),
            autoHide: false
        )
        XCTAssertGreaterThanOrEqual(alpha, 0.001)
    }

    func testAlphaRampsToOneAt200ms() {
        // At t = 200ms, alpha = 1.0 (= fully visible).
        let now = Date()
        let startedAt = now.addingTimeInterval(-0.2)  // 200ms ago
        let alpha = DropSheet.animationAlpha(
            startedAt: startedAt,
            now: now,
            autoHide: false
        )
        XCTAssertEqual(alpha, 1.0, accuracy: 0.001)
    }

    func testAlphaClampsAtOne() {
        // At t > 200ms, alpha stays at 1.0.
        let now = Date()
        let startedAt = now.addingTimeInterval(-1.0)  // 1 second ago
        let alpha = DropSheet.animationAlpha(
            startedAt: startedAt,
            now: now,
            autoHide: false
        )
        XCTAssertEqual(alpha, 1.0, accuracy: 0.001)
    }

    func testAutoHideReturnsZeroAfterFlash() {
        // autoHide + t > 700ms = 0 (= flash mode finished).
        let now = Date()
        let startedAt = now.addingTimeInterval(-1.0)  // 1 second ago
        let alpha = DropSheet.animationAlpha(
            startedAt: startedAt,
            now: now,
            autoHide: true
        )
        XCTAssertEqual(alpha, 0.0, accuracy: 0.001)
    }

    func testAutoHideRampsBeforeFlash() {
        // autoHide + t < 700ms = ramps normally.
        let now = Date()
        let startedAt = now.addingTimeInterval(-0.1)  // 100ms ago
        let alpha = DropSheet.animationAlpha(
            startedAt: startedAt,
            now: now,
            autoHide: true
        )
        XCTAssertGreaterThan(alpha, 0)
        XCTAssertLessThan(alpha, 1.0)
    }
}

@MainActor
final class DropSheetViewTests: XCTestCase {
    func testSheetRenders() {
        // Verify the view can be constructed (= does not crash).
        _ = DropSheet(active: true)
        _ = DropSheet(active: false)
        _ = DropSheet(active: true, autoHide: true)
    }

    func testSheetCustomization() {
        let sheet = DropSheet(
            active: true,
            cornerRadius: 8,
            borderWidth: 3
        )
        XCTAssertNotNil(sheet.body)
    }
}

@MainActor
final class VisualEffectBlurTests: XCTestCase {
    func testBlurConstructor() {
        let blur = VisualEffectBlur(material: .hudWindow)
        XCTAssertNotNil(blur)
    }

    func testBlurWithCustomMaterial() {
        let blur = VisualEffectBlur(material: .popover)
        XCTAssertNotNil(blur)
    }
}

@MainActor
final class DragSessionTests: XCTestCase {
    func testDragSessionBeginEnd() {
        let session = DragSession()
        // Begin: pushes cursor.
        session.begin()
        // End: pops cursor.
        session.end()
        // No assertions (= NSCursor push/pop is hard to test in isolation;
        // the test verifies the API exists + doesn't crash).
    }

    func testDragSessionMultipleBeginEnd() {
        let session = DragSession()
        session.begin()
        session.end()
        session.begin()
        session.end()
    }
}

@MainActor
final class DragCursorModifierTests: XCTestCase {
    func testDragCursorView() {
        let view = Text("test").dragCursor()
        XCTAssertNotNil(view)
    }
}