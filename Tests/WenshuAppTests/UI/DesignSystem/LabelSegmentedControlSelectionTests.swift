//  LabelSegmentedControlSelectionTests.swift · Wenshu
//
//  The close-document path's second invariant: a segmented control
//  must never report a selected segment that names a DIFFERENT value
//  than the one it is bound to.
//
//  Why this is its own file (= the wenshu test convention: 1 source +
//  1 test per ticket): `LabelSegmentedControl` is used by the editor's
//  tab strip (= whose labels are the open documents' ids) and by the
//  library sidebar's switcher. Both bind a value that can stop
//  naming a segment: the editor's tab strip binds the active
//  document's id, and closing that document removes the id from the
//  label list.
//
//  Measured 2026-10-27 with a headless AppKit probe (the same shape
//  the app uses):
//    - `NSSegmentedControl` clamps `selectedSegment` to -1 when the
//      segment COUNT shrinks (= 3 -> 2 -> 1 -> 0), so an index that
//      pointed past the end never survived the shrink;
//    - -1 is what the control reports when nothing is selected, and
//      writing -1 is accepted;
//    - the control's own size collapses to a 0x0 intrinsic size when
//      its count reaches zero (= the size collapse the close-document
//      crash is made of).
//
//  So the count-shrink case is AppKit's to handle, and it does. The
//  app's own bug was the OTHER case: the bound value stopped naming
//  a segment WITHOUT the count shrinking (= the value changed to one
//  that is not in the list), and the control kept drawing the old
//  segment. The bound value said one thing and the drawn selection
//  said another.

import Foundation
import Testing
@testable import WenshuApp

@Suite("LabelSegmentedControl selection (= the drawn selection names the bound value)")
struct LabelSegmentedControlSelectionTests {

    // MARK: - The pure index

    @Test("The bound value names a segment: the control selects that segment")
    func boundValueNamesItsSegment() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let labels = [a, b, c]

        #expect(LabelSegmentedControl<UUID>.selectedSegmentIndex(for: a, in: labels) == 0)
        #expect(LabelSegmentedControl<UUID>.selectedSegmentIndex(for: b, in: labels) == 1)
        #expect(LabelSegmentedControl<UUID>.selectedSegmentIndex(for: c, in: labels) == 2)
    }

    @Test("The bound value names NO segment: the control has NO selection (= not a stale one)")
    func boundValueNamesNoSegmentHasNoSelection() {
        // The closed-document case: the bound value is the id of a
        // document that is no longer open, so it is not among the
        // labels. The control must report -1 (= AppKit's "no segment
        // is selected"), NOT the index of whatever segment it had.
        let open = UUID()
        let closed = UUID()
        let labels = [open]

        #expect(LabelSegmentedControl<UUID>.selectedSegmentIndex(for: closed, in: labels) == -1,
                "a bound value that names no segment must leave the control with NO selection (= -1)")
    }

    @Test("No segments at all: the control has NO selection")
    func noSegmentsHasNoSelection() {
        #expect(LabelSegmentedControl<UUID>.selectedSegmentIndex(for: UUID(), in: []) == -1,
                "with no segments there is nothing to select")
    }

    @Test("The drawn selection never names a different value than the bound one")
    func drawnSelectionNeverNamesADifferentValue() {
        // The invariant itself, over the whole close sequence: the
        // bound value is the active document's id, and closing it
        // removes it from the label list. At every step, the index the
        // control would show must either be -1 or name the bound
        // value.
        var labels = [UUID(), UUID(), UUID()]
        let bound = labels[1]

        // The bound value names its segment.
        var index = LabelSegmentedControl<UUID>.selectedSegmentIndex(for: bound, in: labels)
        #expect(index == 1)
        #expect(index == -1 || labels[index] == bound,
                "the drawn selection must name the bound value")

        // The bound document is closed: it leaves the label list.
        labels.removeAll { $0 == bound }
        index = LabelSegmentedControl<UUID>.selectedSegmentIndex(for: bound, in: labels)
        #expect(index == -1,
                "after the bound document is closed the control must have NO selection")
        #expect(index == -1 || labels[index] == bound,
                "the drawn selection must never name a different value than the bound one")

        // The last document is closed too.
        labels.removeAll()
        index = LabelSegmentedControl<UUID>.selectedSegmentIndex(for: bound, in: labels)
        #expect(index == -1,
                "with no segments left the control must have NO selection")
    }
}
