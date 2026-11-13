// PaneTabStripWidth.swift
//
// The width rule a pane tab strip follows when it fills the column it
// was given.
//
// The shared segmented control asks this question of the region it was
// given (= the editor's document strip and the chat zone's session bar
// both go through it, = and so do the inspector body and the toolbar
// picker). The answer lives here so those callers cannot drift (= one
// door per question = one answer).

import CoreGraphics

/// The width rule for a pane tab strip.
enum PaneTabStripWidth {
    /// The smallest segment width AppKit honours when a width is set
    /// explicitly (`NSSegmentedControl.setWidth(_:forSegment:)`).
    ///
    /// MEASURED on the real control: a 16.67 PT share (= 12 tabs in a
    /// 200 PT region) came out 20.5 PT per cell, = and a 20.5 PT share
    /// came out 20.5 PT per cell, = so the floor is 20.5 PT at the
    /// `.small` control size.
    ///
    /// Below the floor a strip must NOT set widths, = and AppKit's own
    /// `.fillEqually` distribution divides the region exactly (= MEASURED:
    /// 16.5 PT and 17 PT per cell for 12 tabs in a 200 PT region, = and
    /// 6.5 PT and 7 PT per cell for 30 tabs in the same region).
    static let minimumExplicitSegmentWidth: CGFloat = 20.5

    /// The width one segment takes when the strip divides the width it
    /// was given.
    ///
    /// The segments take an equal share of the measured width, = so the
    /// strip fills its column instead of hugging its left edge.
    ///
    /// THE SHARE IS NOT FLOORED. The boss's rule (= 2026-11-12) is the
    /// browser's mechanism: the region is divided into as many equal
    /// shares as there are tabs, the strip never exceeds the region, and
    /// a tab label has no minimum width (= a tab may end up showing not
    /// one character, = and that is fine).
    ///
    /// MEASURED on the real control in a real app (the AX radio
    /// buttons' POSITIONS, = which are the truth; the AX FRAME clamps
    /// to 24 PT whatever the real width is):
    /// - 16 tabs in a 200 PT region -> the cells step by 12.5 PT
    ///   (= 200 / 16, = exact)
    /// - 30 tabs in a 120 PT region -> the cells step by 4.0 PT
    ///   (= 120 / 30, = exact)
    /// - 16 tabs in a 40 PT region -> the cells step by 2.5 PT
    ///   (= 40 / 16, = exact)
    /// So the division is genuinely unbounded, and the strip's total
    /// width is the region's width at any tab count.
    ///
    /// A zero column width (= the strip has not been measured yet) and
    /// a zero segment count both yield zero, = which leaves the control
    /// on its own fitting width until the first measurement lands.
    static func segmentWidth(columnWidth: CGFloat, segmentCount: Int) -> CGFloat {
        guard columnWidth > 0, segmentCount > 0 else { return 0 }
        return columnWidth / CGFloat(segmentCount)
    }
}
