// ChatZoneTabBar.swift
//
// The chat zone's top bar (= the session tab bar).
//
// It shows one page per conversation scope: the repository conversation
// first, one page per ordinary book, and the reference-library conversation
// last. The pages come from the library's CURRENT books, so a new book gets
// a page the moment it is created and a deleted book leaves no page behind.
//
// The bar and the directory tree are two views over ONE selection
// (= `workspaceUI.sidebarSelection`), so clicking a page selects the
// matching tree row and clicking a tree row selects the matching page.
//
// The control is the house's `LabelSegmentedControl` (= an AppKit
// `NSSegmentedControl` in the `.valueSelection` role), inside a horizontal
// scroll view: that is the same shape the editor's tab strip uses, and the
// scroll is what keeps a growing page list inside the chat column.
//
// One view per file (per Apple HIG).

import SwiftUI

/// The chat zone's top bar (= one page per conversation scope).
@MainActor
struct ChatZoneTabBar: View {
    /// The pages to render, in display order.
    let pages: [ChatScopePage]

    /// The scope whose page is selected.
    ///
    /// A scope that has no page of its own (= the help book, which is
    /// read-only) names no segment, and the control then draws NO
    /// selection: the drawn selection can never name a different value
    /// than the bound one.
    let selectedScope: ChatScope

    /// Fired when the user picks a different page.
    let onSelect: (ChatScope) -> Void

    /// The width the bar was given (= the chat column's current width).
    @State private var columnWidth: CGFloat = 0

    /// The width each page's segment takes.
    ///
    /// The pages divide the width the bar was given (= the rule the
    /// editor's document strip follows), = so the bar fills its column
    /// instead of hugging its left edge, = and the overflow goes to the
    /// scroll container when the pages outgrow the column.
    private var segmentWidth: CGFloat {
        PaneTabStripWidth.segmentWidth(
            columnWidth: columnWidth,
            segmentCount: pages.count
        )
    }

    var body: some View {
        content
    }

    /// The bar's body (= the scroll container + the control).
    private var content: some View {
        ScrollView(.horizontal) {
            LabelSegmentedControl(
                selection: Binding(
                    get: { selectedScope },
                    set: { newScope in onSelect(newScope) }
                ),
                labels: pages.map(\.scope),
                displayStrings: pages.map(\.title),
                iconStyle: .paneTab,
                // Each page takes one share of the measured column width,
                // so the bar spans the column instead of hugging its
                // left edge. A zero width means the column has not been
                // measured yet, so the bar takes its own fitting width
                // until the first measurement lands.
                fixedSegmentWidth: segmentWidth,
                role: .valueSelection
            )
        }
        // Apple's own tab bars scroll the overflow without an indicator,
        // and a floating scroll bar is the one part of this bar that is not
        // a page name. Only the drawing goes: the container still scrolls
        // and still clips.
        .scrollIndicators(.hidden, axes: .horizontal)
        // The bar fills the width it is given, and measures it. The
        // measurement feeds the segment widths above, so the bar tracks
        // the column when the writer resizes it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        .frame(height: DesignTokens.paneTabHotArea)
    }
}
