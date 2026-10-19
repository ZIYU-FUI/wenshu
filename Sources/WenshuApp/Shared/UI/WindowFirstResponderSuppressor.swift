// Shared/UI/WindowFirstResponderSuppressor.swift · WenshuApp
//
// macOS no-autofocus on launch helper. SwiftUI does not expose
// `NSWindow.initialFirstResponder`. Without an explicit nil, the first
// focusable TextField in the view tree (typically the assets column
// search field) is promoted to first responder when the main window
// mounts, which shows a blinking caret the moment the app opens.
//
// Catalog approach (= Apple-internal sample code shape): wrap a tiny
// transparent `NSView` via `NSViewRepresentable`, drop it on the root
// view tree, and inside `viewDidMoveToWindow` set
// `window.initialFirstResponder = nil` + `window.makeFirstResponder(nil)`.
// Tab key afterward still walks into the first focusable through the
// normal SwiftUI focus chain.
import AppKit
import SwiftUI

struct WindowFirstResponderSuppressor: NSViewRepresentable {
    private final class Helper: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // RATIONALE: nil + makeFirstResponder(nil) together suppress the
            // first focusable promotion; `window` itself becomes the implicit
            // first responder. Setting only `initialFirstResponder` does not
            // affect a window that is already mounted and has focus.
            window.initialFirstResponder = nil
            DispatchQueue.main.async {
                guard let current = window.firstResponder,
                      current !== window.contentView else { return }
                window.makeFirstResponder(nil)
            }
        }
    }

    func makeNSView(context: Context) -> NSView {
        Helper()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-apply on every SwiftUI hosting tree reconcile (= the helper
        // view can be re-parented into a new window during window restoration).
        guard let window = nsView.window else { return }
        window.initialFirstResponder = nil
        DispatchQueue.main.async {
            guard let current = window.firstResponder,
                  current !== window.contentView else { return }
            window.makeFirstResponder(nil)
        }
    }
}
