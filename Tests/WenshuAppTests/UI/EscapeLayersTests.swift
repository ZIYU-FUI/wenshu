// EscapeLayersTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-024
//
// Tests for escape layers + narrow viewport + floating panes. Boss
// 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一'.

import XCTest
import SwiftUI
@testable import WenshuApp

@MainActor
final class EscapePriorityTests: XCTestCase {
    func testPriorityOrder() {
        XCTAssertLessThan(EscapePriority.contextMenu, EscapePriority.dialog)
        XCTAssertLessThan(EscapePriority.dialog, EscapePriority.narrowOverlay)
        XCTAssertLessThan(EscapePriority.narrowOverlay, EscapePriority.layoutEdit)
    }

    func testPriorityValues() {
        // Herms ESCAPE_PRIORITY enum order.
        XCTAssertEqual(EscapePriority.contextMenu.rawValue, 0)
        XCTAssertEqual(EscapePriority.dialog.rawValue, 10)
        XCTAssertEqual(EscapePriority.narrowOverlay.rawValue, 20)
        XCTAssertEqual(EscapePriority.layoutEdit.rawValue, 30)
    }
}

@MainActor
final class EscapeLayerManagerTests: XCTestCase {
    func testEmptyManager() {
        let m = EscapeLayerManager()
        XCTAssertNil(m.topLayer)
        XCTAssertFalse(m.isTop(.dialog))
    }

    func testPushReturnsLayer() {
        let m = EscapeLayerManager()
        let layer = m.push(.dialog)
        XCTAssertNotNil(layer)
        XCTAssertEqual(layer.priority, .dialog)
    }

    func testIsTopReturnsTrueForTopLayer() {
        let m = EscapeLayerManager()
        let _ = m.push(.dialog)
        XCTAssertTrue(m.isTop(.dialog))
        XCTAssertFalse(m.isTop(.contextMenu))
    }

    func testHighestPriorityWins() {
        let m = EscapeLayerManager()
        let _ = m.push(.dialog)
        let _ = m.push(.narrowOverlay)
        XCTAssertTrue(m.isTop(.narrowOverlay))
        XCTAssertFalse(m.isTop(.dialog))
    }

    func testDismissRemovesLayer() {
        let m = EscapeLayerManager()
        let layer = m.push(.dialog)
        m.dismiss(layer)
        XCTAssertNil(m.topLayer)
    }
}

@MainActor
final class NarrowViewportStateTests: XCTestCase {
    func testDefaultIsNotNarrow() {
        let s = NarrowViewportState()
        XCTAssertFalse(s.isNarrow)
    }

    func testUpdateBelowBreakpointIsNarrow() {
        let s = NarrowViewportState()
        s.update(width: 800)  // < 1024
        XCTAssertTrue(s.isNarrow)
    }

    func testUpdateAboveBreakpointIsNotNarrow() {
        let s = NarrowViewportState()
        s.update(width: 1920)  // > 1024
        XCTAssertFalse(s.isNarrow)
    }

    func testUpdateAtBreakpoint() {
        let s = NarrowViewportState()
        s.update(width: kSidebarCollapseBreakpoint)  // = 1024
        XCTAssertFalse(s.isNarrow)  // not strictly less
    }

    func testSidebarCollapseBreakpoint() {
        XCTAssertEqual(kSidebarCollapseBreakpoint, 1024)
    }
}

@MainActor
final class FloatingPaneRegistryTests: XCTestCase {
    func testEmptyRegistry() {
        let r = FloatingPaneRegistry()
        XCTAssertNil(r.getPosition("foo"))
    }

    func testSetAndGetPosition() {
        let r = FloatingPaneRegistry()
        let placement = FloatingPanePlacement(x: 100, y: 200)
        r.setPosition("foo", placement)
        XCTAssertEqual(r.getPosition("foo")?.x, 100)
        XCTAssertEqual(r.getPosition("foo")?.y, 200)
    }

    func testRemove() {
        let r = FloatingPaneRegistry()
        r.setPosition("foo", FloatingPanePlacement(x: 0, y: 0))
        r.remove("foo")
        XCTAssertNil(r.getPosition("foo"))
    }

    func testToggleCollapsed() {
        let r = FloatingPaneRegistry()
        r.setPosition("foo", FloatingPanePlacement(x: 0, y: 0))
        r.toggleCollapsed("foo")
        XCTAssertEqual(r.getPosition("foo")?.collapsed, true)
        r.toggleCollapsed("foo")
        XCTAssertEqual(r.getPosition("foo")?.collapsed, false)
    }

    func testCodableRoundTrip() throws {
        let r = FloatingPaneRegistry()
        r.setPosition("foo", FloatingPanePlacement(x: 100, y: 200, collapsed: true))
        let data = try r.encoded()
        let restored = FloatingPaneRegistry()
        restored.restore(from: data)
        XCTAssertEqual(restored.getPosition("foo")?.x, 100)
        XCTAssertEqual(restored.getPosition("foo")?.y, 200)
        XCTAssertEqual(restored.getPosition("foo")?.collapsed, true)
    }
}

@MainActor
final class EscapeLayerViewTests: XCTestCase {
    func testEscapeLayerModifier() {
        let view = Text("test").escapeLayer(.dialog)
        _ = AnyView(view)
    }
}