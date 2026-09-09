// ThinDividerSplitView.swift
//
// v0.42: Pages-style column divider (Apple HIG "Prefer the thin divider style").
//
// The default `NavigationSplitView` in SwiftUI uses a thick divider between
// columns (= NSSplitView.dividerStyle = .thick). Pages/Keynote/Mail use
// .thin (1 point) — visually barely visible but still draggable.
//
// This is a minimal NSSplitView subclass that overrides dividerStyle to .thin
// (= Apple HIG canonical thin divider) and applies it via .background
// modifier that walks the view tree to find the enclosing NSSplitView.
//
// Reference: https://developer.apple.com/design/human-interface-guidelines/macos/windows-and-views/split-views
// "Prefer the thin divider style. The thin divider measures one point in
// width, giving you maximum space for content while remaining easy for
// people to use."

import SwiftUI
import AppKit

/// NSSplitView subclass that uses the .thin divider style (= 1pt) instead
/// of the default .thick. Apple HIG canonical for column dividers.
final class ThinDividerNSSplitView: NSSplitView {
    override var dividerThickness: CGFloat {
        get { 1.0 }  // Apple HIG thin = 1 point
        set { /* read-only */ }
    }

    override var dividerColor: NSColor {
        get { .separatorColor }  // Apple HIG default separator color
    }
}

/// SwiftUI helper that finds the enclosing NSSplitView in the view hierarchy
/// and applies .thin divider style (= Apple HIG canonical thin divider).
/// Applied via .background modifier on the NavigationSplitView's content.
/// No-op for non-split views.
struct ThinDividerApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ThinDividerPatcher()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ThinDividerPatcher)?.applyIfNeeded()
    }
}

/// An NSView that walks up the view tree at layout time to find the
/// enclosing NSSplitView and applies .thin divider style to it. The walk
/// is repeated on every layout pass because the NSSplitView may be
/// re-created on view updates (= SwiftUI regenerates the underlying
/// AppKit hierarchy).
final class ThinDividerPatcher: NSView {
    private var appliedSplitView: NSSplitView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyIfNeeded()
    }

    override func layout() {
        super.layout()
        applyIfNeeded()
    }

    func applyIfNeeded() {
        guard let window = window else { return }
        // Find the first NSSplitView in the window's view hierarchy that
        // is NOT the one we've already patched.
        if let splitView = findEnclosingSplitView(in: window.contentView),
           splitView !== appliedSplitView {
            splitView.dividerStyle = .thin
            appliedSplitView = splitView
        }
    }

    private func findEnclosingSplitView(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }
        if let splitView = view as? NSSplitView {
            return splitView
        }
        for sub in view.subviews {
            if let found = findEnclosingSplitView(in: sub) {
                return found
            }
        }
        return nil
    }
}

extension View {
    /// Apply Apple HIG thin divider style to any enclosing NSSplitView.
    /// Used on NavigationSplitView content to match Pages/Keynote look.
    func thinColumnDividers() -> some View {
        background(ThinDividerApplier())
    }
}
