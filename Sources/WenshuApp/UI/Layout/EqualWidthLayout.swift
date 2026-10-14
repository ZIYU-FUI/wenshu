// EqualWidthLayout.swift — Apple-canonical Layout protocol for equal-width
// tab strips. The `Layout` protocol (= WWDC22-10056
// "Compose custom layouts with SwiftUI") is the
// canonical way to size + place N subviews with equal
// width; = `sizeThatFits(proposal:)` divides the parent
// proposal across N cells; = `placeSubviews(...)`
// positions each cell. This re-computes live (= the
// `proposal.width` updates on NSV drag).
// the tab width once on layout; = it did NOT react to live
// `NavigationSplitView` column-resize drags; = the user reported the
// tabs don't re-split when the column is resized). The Apple canonical
// solution per WWDC22-10056 "Compose custom layouts with SwiftUI" and
// the developer.apple.com "Composing custom layouts with SwiftUI"
// article is the `Layout` protocol (= `sizeThatFits` + `placeSubviews`).
// The protocol gives the layout a `ProposedViewSize` (= the live parent
// size, updated on every layout pass; = the protocol is the Apple
// canonical way to react to NSV drag-resize) and a `Subviews` collection
// (= each tab pill). The `sizeThatFits` reports the total width as
// `parentWidth` (= the live proposed width; = the size update
// propagates from NSV → layout pass → `sizeThatFits` → re-place;
// = the tabs re-split live). The `placeSubviews` places each tab
// at `nextX = bounds.minX + cellWidth / 2` (= equal-width cells; =
// `cellWidth = (parentWidth - totalSpacing) / subviews.count`).
// Compared to `containerRelativeFrame` (= the iOS 17+/macOS 14+
// Apple canonical alternative), the `Layout` protocol is the
// pre-iOS-17 / pre-macOS-14 compatible primitive (= works on macOS 13+;
// = no `containerRelativeFrame`-induced NSV drag regressions; = the
// wenshu minimum target is macOS 14, but the `Layout` protocol
// doesn't have the same drag-stall behavior).

import SwiftUI

/// Layout that places subviews with equal width inside the parent's
/// proposed width. RATIONALE 2026-10-13: this is the wenshu 1:1
/// Safari-style tab strip layout (= each tab gets
/// `(parentWidth - totalSpacing) / subviews.count`; = the tabs
/// stay equal-width when the parent re-sizes; = the user can drag
/// the `NavigationSplitView` column divider and the tabs re-split
/// live). The `spacing` parameter (= the inter-cell gap; = the
/// wenshu canonical `DesignTokens.spacingCaption` = 2 PT) is
/// subtracted from the parent width before division.
struct EqualWidthLayout: Layout {
    var spacing: CGFloat = 2

    /// RATIONALE: the cache stores nothing (= the layout is
    /// pure-functional over `subviews` + `ProposedViewSize`; =
    /// the live `ProposedViewSize` change is picked up
    /// automatically by the protocol = no `@State` needed).
    /// The cache type is `Void` (= the wenshu 1:1 minimum).
    typealias Cache = Void

    func makeCache(subviews: Subviews) -> Cache {
        return ()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // No cache state to update; the layout is pure-functional
        // over `subviews` + `ProposedViewSize`.
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        // The parent width = `proposal.width` (= the live
        // parent size; = updated on every layout pass; = the
        // key property that makes this layout react to NSV
        // drag-resize). If the proposal is `nil` (= the parent
        // is unbounded), we fall back to summing the subviews'
        // intrinsic widths (= a sane default for an unbounded
        // proposal = the layout reports "as wide as my
        // subviews need individually").
        let parentWidth: CGFloat
        if let w = proposal.width {
            parentWidth = w
        } else {
            parentWidth = subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        }
        let totalSpacing = spacing * CGFloat(max(subviews.count - 1, 0))
        let cellWidth = (parentWidth - totalSpacing) / CGFloat(subviews.count)

        // The max height = the max of all subview sizes with
        // the per-cell width proposal (= the layout asks each
        // subview for its `sizeThatFits`; = the subview
        // decides its own height; = the layout reports the
        // tallest cell as the layout's height).
        var maxHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(
                ProposedViewSize(width: cellWidth, height: nil)
            )
            maxHeight = max(maxHeight, size.height)
        }

        return CGSize(
            width: parentWidth,
            height: maxHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        guard !subviews.isEmpty else { return }

        // The cell width = the parent's available width divided
        // by the subview count (= equal width). The
        // `bounds.width` (= the layout's actual drawable
        // rectangle; = updated live by the parent on
        // drag-resize; = the canonical way to react to NSV
        // column changes).
        let totalSpacing = spacing * CGFloat(max(subviews.count - 1, 0))
        let cellWidth = (bounds.width - totalSpacing) / CGFloat(subviews.count)

        // Place each subview at `nextX = bounds.minX + cellWidth / 2`
        // (= center of each cell; = the subview can fill the
        // cell horizontally via its own `.frame(width: cellWidth)`).
        var nextX = bounds.minX + cellWidth / 2
        for subview in subviews {
            subview.place(
                at: CGPoint(x: nextX, y: bounds.midY),
                anchor: .center,
                proposal: ProposedViewSize(
                    width: cellWidth,
                    height: bounds.height
                )
            )
            nextX += cellWidth + spacing
        }
    }
}
