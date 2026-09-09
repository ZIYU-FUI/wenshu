// ThinDividerSplitView.swift
//
// v0.43: Pages-style column divider (Apple HIG "Prefer the thin divider style" + clear divider color).
//
// The default `NavigationSplitView` in SwiftUI uses NSSplitView with a
// visible divider color (NSSplitView's default = .separatorColor) on macOS 27
// SDK. Pages/Keynote/Numbers/Mail/Xcode all hide the divider visually
// (no color) while keeping it draggable. This is achieved by setting
// NSSplitView.dividerStyle = .thin (= 1pt) AND NSSplitView.dividerColor
// = .clear (= invisible).
//
// SwiftUI does NOT expose NavigationSplitView's divider style or color
// as a modifier in macOS 27 SDK (= the API is AppKit-level NSSplitView).
// To get the Apple HIG canonical Pages/Keynote look, walk the AppKit
// view tree at viewDidMoveToWindow + layout to find the underlying
// NSSplitView and apply both .dividerStyle = .thin and
// .dividerColor = .clear.
//
// Reference: https://developer.apple.com/design/human-interface-guidelines/macos/windows-and-views/split-views
// "Prefer the thin divider style. The thin divider measures one point in
// width, giving you maximum space for content while remaining easy for
// people to use."

import SwiftUI
import AppKit

/// An NSView that walks the window's view hierarchy at layout time to find
/// the enclosing NSSplitView (= the AppKit control that NavigationSplitView
/// uses internally on macOS) and applies:
/// - .dividerStyle = .thin (= 1pt; Apple HIG canonical thin divider)
/// - .dividerColor = .clear (= invisible; = Pages/Keynote look)
/// Walked on every layout pass because SwiftUI may regenerate the
/// underlying AppKit hierarchy.
final class ThinDividerPatcher: NSView {
    private var appliedSplitViews: Set<ObjectIdentifier> = []

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
        findSplitViews(in: window.contentView, applying: { splitView in
            splitView.dividerStyle = .thin
            // dividerColor is a get-only property on NSSplitView. Use
            // KVC to set it (= documented workaround for NSSplitView
            // get-only dividerColor; = matches Pages/Keynote look).
            splitView.setValue(NSColor.clear, forKey: "dividerColor")
        })
    }

    private func findSplitViews(in view: NSView?, applying action: (NSSplitView) -> Void) {
        guard let view = view else { return }
        if let splitView = view as? NSSplitView {
            let id = ObjectIdentifier(splitView)
            if !appliedSplitViews.contains(id) {
                action(splitView)
                appliedSplitViews.insert(id)
            }
        }
        for sub in view.subviews {
            findSplitViews(in: sub, applying: action)
        }
    }
}

/// SwiftUI helper that embeds a ThinDividerPatcher via .background.
struct ThinDividerApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ThinDividerPatcher()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ThinDividerPatcher)?.applyIfNeeded()
    }
}

extension View {
    /// Apply Apple HIG thin + clear divider style to any enclosing
    /// NSSplitView (= the AppKit control NavigationSplitView uses
    /// internally on macOS). Used on NavigationSplitView content to
    /// match Pages/Keynote/Mail look (= 1pt divider, invisible
    /// color, still draggable).
    ///
    /// Required hack: SwiftUI does not expose NavigationSplitView's
    /// divider style or color as a modifier in macOS 27 SDK. The
    /// boss explicit asked for "no divider line" (= matches the
    /// Pages screenshot exactly) and this is the minimum amount of
    /// AppKit interop needed to achieve it.
    func thinColumnDividers() -> some View {
        background(ThinDividerApplier())
    }
}
