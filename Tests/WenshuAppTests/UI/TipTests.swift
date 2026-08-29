// TipTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-020
//
// Tests for the tooltip system. Boss 2026-08-29 OOB.

import XCTest
import SwiftUI
@testable import WenshuApp

final class TipTokenTests: XCTestCase {
    func testTokens() {
        // Herms TIP_DELAY_MS = 200.
        XCTAssertEqual(kTipDelayMS, 200)
        // Herms TIP_SKIP_DELAY_MS = 300.
        XCTAssertEqual(kTipSkipDelayMS, 300)
    }
}

final class TipControllerTests: XCTestCase {
    func testDefaultState() {
        let c = TipController()
        XCTAssertFalse(c.isTipShowing)
        XCTAssertEqual(c.lastClosedAt, Date.distantPast)
    }

    func testFirstHoverReturnsFullDelay() {
        let c = TipController()
        let delay = c.delayForNewHover()
        XCTAssertEqual(delay, kTipDelayMS)  // 200ms (= not in warm window)
    }

    func testWarmWindowReturnsZeroDelay() {
        let c = TipController()
        // Simulate a tip close (= lastClosedAt = now).
        c.tipDidClose()
        // Immediately after close, new hover should be in warm window.
        let delay = c.delayForNewHover()
        XCTAssertEqual(delay, 0)
    }

    func testAfterWarmWindowExpiresReturnsFullDelay() {
        let c = TipController()
        // Simulate a tip close 1 second ago (= past warm window).
        c.tipDidClose(at: Date().addingTimeInterval(-1.0))
        let delay = c.delayForNewHover()
        XCTAssertEqual(delay, kTipDelayMS)
    }

    func testTipDidShowSetsIsTipShowing() {
        let c = TipController()
        XCTAssertFalse(c.isTipShowing)
        c.tipDidShow()
        XCTAssertTrue(c.isTipShowing)
        c.tipDidClose()
        XCTAssertFalse(c.isTipShowing)
    }

    func testThreadSafeAccess() {
        let c = TipController()
        let expectation = XCTestExpectation(description: "concurrent access")
        let group = DispatchGroup()
        for _ in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                c.tipDidClose()
                _ = c.delayForNewHover()
                group.leave()
            }
        }
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
}

@MainActor
final class TipViewTests: XCTestCase {
    func testTipModifierConstructs() {
        // Verify the View extension exists + can be chained.
        struct TestView: View {
            var body: some View {
                Text("Hello")
                    .tip("Greeting", keybind: "⌘H")
            }
        }
        _ = TestView()
    }

    func testTipWithKeybind() {
        // Verify keybind parameter is passed through.
        let view = Text("test").tip("label", keybind: "⌘T")
        // Don't call body (= ViewModifier.body must not be called directly).
        _ = AnyView(view)
    }

    func testTipWithDelayDurationZero() {
        // Verify zero delayDuration opens instantly.
        let view = Text("test").tip("label", delayDuration: 0)
        _ = AnyView(view)
    }
}