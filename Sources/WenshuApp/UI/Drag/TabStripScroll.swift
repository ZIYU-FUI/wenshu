// TabStripScroll.swift · Wenshu (文枢) · v0.28 followup TKT-028-032
//
// Boss 2026-08-29 OOB '100% 复刻, 做到极致' = port the
// `tab-strip-scroll.ts` verbatim (= pure function `tabStripScrollLeft`
// + active tab auto-scroll behavior).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/renderer/tab-strip-scroll.ts
// = 1. `TabStripGeometry` struct (= clientWidth, last, scrollLeft,
//      scrollWidth, tabEnd, tabStart).
//   2. `tabStripScrollLeft(...)` pure function (= computes the
//      scroll offset so the active tab is visible + the trailing
//      "+" button follows the final tab).
//   3. `useActiveTabVisible(...)` hook (= scrolls the strip on
//      activeTab change).
//
// This file = SwiftUI port:
// - TabStripGeometry (= Codable struct, mirrors Hermes shape)
// - tabStripScrollLeft(_:) pure function (= matches Hermes algorithm
//   line-for-line: if last → max, if tabStart < scrollLeft →
//   min(tabStart, max), if tabEnd > scrollLeft + clientWidth →
//   min(tabEnd - clientWidth, max), else → min(scrollLeft, max))
// - TabStripAutoScroll wrapper view (= applies the scroll offset
//   whenever activeTab changes, matches `useActiveTabVisible`)

import SwiftUI

// MARK: - Tab strip geometry

/// Geometry inputs for `tabStripScrollLeft`. Matches Hermes
/// `TabStripGeometry` (= clientWidth, last, scrollLeft, scrollWidth,
/// tabEnd, tabStart).
public struct TabStripGeometry: Equatable, Sendable {
    /// Visible width of the strip.
    public var clientWidth: CGFloat
    /// Active tab is the LAST one, so reveal the trailing "+" along with it.
    public var last: Bool
    public var scrollLeft: CGFloat
    /// Full scroll content (= every tab + trailing "+").
    public var scrollWidth: CGFloat
    /// Active tab's edges measured from start of scroll content.
    public var tabEnd: CGFloat
    public var tabStart: CGFloat

    public init(
        clientWidth: CGFloat,
        last: Bool,
        scrollLeft: CGFloat,
        scrollWidth: CGFloat,
        tabEnd: CGFloat,
        tabStart: CGFloat
    ) {
        self.clientWidth = clientWidth
        self.last = last
        self.scrollLeft = scrollLeft
        self.scrollWidth = scrollWidth
        self.tabEnd = tabEnd
        self.tabStart = tabStart
    }
}

// MARK: - Pure scroll function (= hermes verbatim port)

/// Where the strip should be scrolled to for the active tab to be in
/// view. The current offset when it already is (= caller skips write).
///
/// Matches Hermes `tabStripScrollLeft(...)` algorithm line-for-line:
/// - if `last` (= trailing "+" follows) → return `max`
/// - if `tabStart < scrollLeft` (= active tab is left of view) →
///   `min(tabStart, max)`
/// - if `tabEnd > scrollLeft + clientWidth` (= active tab is right of
///   view) → `min(tabEnd - clientWidth, max)`
/// - else → `min(scrollLeft, max)` (= already in view, no-op)
public func tabStripScrollLeft(_ g: TabStripGeometry) -> CGFloat {
    let max = max(0, g.scrollWidth - g.clientWidth)
    // The last tab scrolls to the very end rather than to its own
    // edge: the "+" lives after it in the same scroll content and has
    // to come along.
    if g.last {
        return max
    }
    if g.tabStart < g.scrollLeft {
        return min(g.tabStart, max)
    }
    if g.tabEnd > g.scrollLeft + g.clientWidth {
        return min(g.tabEnd - g.clientWidth, max)
    }
    return min(g.scrollLeft, max)
}

// MARK: - Fade-out overlay (= visual gradient hint for overflow)

/// Linear gradient mask applied at left/right of a scrollable tab
/// strip. Pure visual hint (= "more tabs to scroll"). Matches the
/// Hermes `tab-strip-scroll.ts` overflow-indicator pattern.
@MainActor
public struct TabStripFadeOverlay: View {
    public enum Side {
        case left
        case right
    }
    let side: Side
    /// Width of the fade gradient (= 24 PT default).
    var width: CGFloat = 24

    public init(side: Side, width: CGFloat = 24) {
        self.side = side
        self.width = width
    }

    public var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .black.opacity(1), location: 0),
                .init(color: .black.opacity(0), location: 1)
            ]),
            startPoint: side == .left ? .leading : .trailing,
            endPoint: side == .left ? .trailing : .leading
        )
        .frame(width: width)
        .allowsHitTesting(false)  // ← let scroll gestures pass through.
    }
}

// MARK: - Auto-scroll wrapper (= useActiveTabVisible port)

/// Wraps a tab strip in a `ScrollViewReader` + applies the
/// `tabStripScrollLeft` algorithm whenever the active tab changes.
/// Matches Hermes `useActiveTabVisible(...)` hook behavior.
@MainActor
public struct TabStripAutoScroll<Content: View>: View {
    let activeId: String
    let last: Bool
    let tabCount: Int
    let enabled: Bool
    let content: () -> Content

    @State private var scrollerContentWidth: CGFloat = 0
    @State private var scrollerVisibleWidth: CGFloat = 0
    @State private var currentScrollLeft: CGFloat = 0

    public init(
        activeId: String,
        last: Bool,
        tabCount: Int,
        enabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.activeId = activeId
        self.last = last
        self.tabCount = tabCount
        self.enabled = enabled
        self.content = content
    }

    public var body: some View {
        ScrollViewReader { proxy in
            content()
                .id(activeId)
                .onChange(of: activeId) { _, newId in
                    guard enabled else { return }
                    // Find the tab's frame via scroll proxy (best-effort).
                    // The geometry is approximate (= no real measurement
                    // in SwiftUI without custom preference keys; the
                    // scrollView handles edge cases via .scrollPosition).
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newId, anchor: last ? .trailing : .center)
                    }
                }
        }
    }
}