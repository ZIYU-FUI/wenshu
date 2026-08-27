// OpenWindowActionBridge.swift · Wenshu (文枢) · v0.27 splitter test launcher
//
// PURPOSE:
//
//   SwiftUI's @Environment(\.openWindow) action can ONLY be captured
//   inside a View body (= requires the OpenWindowAction via
//   @Environment). The `.commands { ... }` block in the App body
//   (= where menu bar buttons live) is NOT inside a View body, so
//   @Environment(\.openWindow) cannot be captured there.
//
//   Solution (= standard SwiftUI workaround for the App's commands
//   block needing OpenWindowAction): inject OpenWindowAction from
//   the main window's view body via the singleton bridge pattern.
//
//   Per the SwiftUI docs for @Environment(\.openWindow):
//   'Opens a window that you create with the Window(_:id:) or
//   WindowGroup(_:) scene, or opens a single window if you use the
//   Window(_:id:) modifier.'
//
//   Bridge protocol:
//   1. The main WindowGroup view body captures the @Environment(\.
//      openWindow) action and stores it in OpenWindowActionBridge.
//   2. The .commands block (= menu bar) calls
//      OpenWindowActionBridge.openSplitterTest() which forwards to
//      the captured action.
//
//   This pattern is per Apple HIG for app-level menus triggering
//   programmatic window opens.

import SwiftUI
import AppKit

/// Bridge for opening SwiftUI Window scenes from the App's commands
/// block (= where SwiftUI menu bar items live).
///
/// Usage:
///   1. In the main window's view body (= the WindowGroup's content):
///      ```
///      .onAppear {
///          OpenWindowActionBridge.openWindowAction = openWindow
///      }
///      ```
///   2. In the .commands block (= menu bar Button handlers):
///      ```
///      OpenWindowActionBridge.openSplitterTest()
///      ```
@MainActor
enum OpenWindowActionBridge {
    /// Captured from the main window's view body via .onAppear.
    /// nil if the main window hasn't loaded yet (= no harm — the
    /// menu item just does nothing).
    nonisolated(unsafe) static var openWindowAction: OpenWindowAction?

    /// Opens the 'splitter-test' window (= the window added in
    /// commit f7cb45397 + its app wiring in App.swift). Boss 8/27
    /// pre-adoption smoke test for SplitView dependency.
    @MainActor
    static func openSplitterTest() {
        if let action = openWindowAction {
            action(id: "splitter-test")
        } else {
            // Fallback: post a NotificationCenter event so the main
            // window's view body (= where the bridge is registered)
            // can react.
            NotificationCenter.default.post(
                name: .wenshuOpenSplitterTestRequested,
                object: nil
            )
        }
    }
}

extension Notification.Name {
    static let wenshuOpenSplitterTestRequested = Notification.Name(
        "wenshu.openSplitterTestRequested"
    )
}

/// View modifier that captures the @Environment(\.openWindow) action
/// into the OpenWindowActionBridge singleton. Apply this to the main
/// window's root view.
struct OpenWindowBridgeModifier: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    func body(content: Content) -> some View {
        content
            .onAppear {
                OpenWindowActionBridge.openWindowAction = openWindow
            }
    }
}

extension View {
    /// Captures the @Environment(\.openWindow) action into the
    /// OpenWindowActionBridge singleton. Apply once to the main
    /// window's root view (= inside the WindowGroup body).
    func installOpenWindowBridge() -> some View {
        modifier(OpenWindowBridgeModifier())
    }
}