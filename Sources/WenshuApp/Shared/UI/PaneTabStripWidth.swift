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
    /// The room a segment spends on itself (= its side insets and the
    /// gap between its label and its edge), which its LABEL may not use.
    ///
    /// MEASURED on the control: a cell is the wider of its share and its
    /// label plus this inset. = 3 tabs in a 200 PT region (= a 66.67 PT
    /// share) with 60 PT titles drew 80.5 PT cells (= 239 PT of track in
    /// a 200 PT column, = so the strip overflowed by 39 PT), = and with
    /// 43.19 PT titles the same region drew exactly 200 PT. = The
    /// boundary sits between those two widths, = so a label is inside its
    /// cell only when `label + 20.5 <= share`.
    ///
    /// ⇒ ⇒ ⇒ SO THE TITLE BUDGET IS `share - 20.5`, = not `share`
    /// (`PaneTabStripTitle.fitted`), = and the two numbers are the SAME
    /// constant: = the cell's own floor and its own inset are one
    /// measurement of one edge.
    static let segmentLabelInset: CGFloat = 20.5

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
