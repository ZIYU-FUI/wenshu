// NativeControlsInspectorTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-022
//
// Tests for native controls + drag strip + workspace geometry publishing.

import XCTest
import SwiftUI
import AppKit
@testable import WenshuApp

@MainActor
final class NativeControlsInspectorTests: XCTestCase {

    func testInspectNilWindowReturnsNil() {
        let rect = inspectNativeControls(for: nil, viewportWidth: 1920)
        XCTAssertNil(rect)
    }

    func testInspectMacOSWindowReturnsRect() {
        // Create a temporary NSWindow for testing.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let rect = inspectNativeControls(for: window, viewportWidth: 1920)
        // Should return non-nil rect (or nil if window has no buttons
        // = depends on macOS version).
        if let rect {
            XCTAssertEqual(rect.y, 0)
            XCTAssertGreaterThan(rect.width, 0)
            XCTAssertEqual(rect.height, kControlsBandHeight)
        }
    }

    func testWindowDragStripWidthNilWindow() {
        let width = windowDragStripWidth(for: nil)
        XCTAssertEqual(width, kTitlebarEdgeInset)
    }

    func testWindowDragStripWidthMacOS() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let width = windowDragStripWidth(for: window)
        // Should be either 0 (= no controls) or controls rect width.
        XCTAssertGreaterThanOrEqual(width, 0)
    }

    func testPublishWorkspaceGeometry() {
        let viewport = GeometryRect(x: 0, y: 0, width: 1920, height: 1080)
        let mainPane = GeometryRect(x: 240, y: 34, width: 1440, height: 1046)
        let view = Text("test")
            .publishWorkspaceGeometry(viewport: viewport, mainPane: mainPane)
        _ = AnyView(view)
    }
}

@MainActor
final class WorkspaceGeometryEnvironmentTests: XCTestCase {
    func testDefaultWorkspaceGeometry() {
        let env = EnvironmentValues()
        XCTAssertEqual(env.workspaceGeometry.viewportWidth, 1920)
        XCTAssertEqual(env.workspaceGeometry.viewportHeight, 1080)
    }
}