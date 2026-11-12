// PaneTabStripWidth.swift
//
// The width rule a pane tab strip follows when it fills the column it
// was given.
//
// Two strips ask this question: the editor's document strip and the
// chat zone's session bar. The answer lives here so the two strips
// cannot drift (= one door per question = one answer).

import CoreGraphics

/// The width rule for a pane tab strip.
enum PaneTabStripWidth {
    /// The narrowest segment that still shows a name.
    ///
    /// MEASURED on the app's own control (= a real `NSSegmentedControl`
    /// at the `.large` control size): a four-character Chinese title
    /// claims 80 PT of the control's fitting width, = so 88 PT keeps
    /// such a title whole.
    static let minimumSegmentWidth: CGFloat = 88

    /// The width one segment takes when the strip divides the width it
    /// was given.
    ///
    /// The segments take an equal share of the measured width, = so the
    /// strip fills its column instead of hugging its left edge. Below
    /// the readable floor the width stops shrinking, = and the overflow
    /// goes to the strip's scroll container instead.
    ///
    /// A zero column width (= the strip has not been measured yet) and
    /// a zero segment count both yield zero, = which leaves the control
    /// on its own fitting width until the first measurement lands.
    static func segmentWidth(columnWidth: CGFloat, segmentCount: Int) -> CGFloat {
        guard columnWidth > 0, segmentCount > 0 else { return 0 }
        return max(columnWidth / CGFloat(segmentCount), minimumSegmentWidth)
    }
}
