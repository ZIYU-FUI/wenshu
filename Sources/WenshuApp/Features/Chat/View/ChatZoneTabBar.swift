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
                // The bar divides the column it was given: every page
                // takes one equal share of the measured column width, so
                // the bar's total width tracks the column the writer
                // dragged instead of the number of open pages.
                //
                // The region is what the control's frame is PINNED to
                // (= `LabelSegmentedControl.sizeThatFits`), = and
                // AppKit's `.fillEqually` then divides that frame
                // exactly, at any page count, with no per-cell minimum.
                // A zero width means the column has not been measured
                // yet, so the bar takes its own fitting width until the
                // first measurement lands.
                regionWidth: columnWidth,
                role: .valueSelection,
                // The bar's drawn capsule takes its height from the
                // segmented control the left and right columns already
                // use (= `.small`), = so all four columns' top bands
                // draw the same capsule height.
                controlSize: .small
            )
            // The control keeps its own height (= the `.small` capsule's
            // 20 PT), = the same way the sidebar's and the inspector's
            // switchers keep theirs: AppKit draws the capsule to fill the
            // control's height, = so a control stretched to the band row's
            // height would draw a full-height pill with no air.
            .fixedSize(horizontal: false, vertical: true)
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
