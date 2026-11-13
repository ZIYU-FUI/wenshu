//
//  PaneTabStripTitleWriteTests.swift · WenshuAppTests
//
//  The title a pane tab strip's cell DRAWS is the app's own title, and
//  these are the guards on the PRODUCTION write that hands it over.
//
//  Why this file exists (= what it holds that the rule's own suite
//  does not):
//
//  - `PaneTabStripTitleTests` proves the RULE (= what title a cell of a
//    given share should draw) on a control the test builds itself. That
//    is the rule, but not the app's write of it.
//  - `EditorTabStripOverflowTests` hosts the REAL strip, but measures
//    GEOMETRY (= the cells, the dividers, the track), = not the title.
//
//  ⇒ ⇒ ⇒ So the write itself was unpinned: reverting
//  `LabelSegmentedControl.configure`'s
//  `control.setLabel(drawn, forSegment: index)` to the pre-diff
//  `control.setLabel(display, forSegment: index)` (= AppKit truncates,
//  = and at 12 to 25 PT it draws the lone '…' = the defect the boss
//  ruled out) left every suite green.
//
//  ⇒ ⇒ ⇒ SO THESE SUITES DRIVE THE PRODUCTION WRITE PATH: =
//  `LabelSegmentedControl.configure` is `internal` precisely so a test
//  can drive it (= the house's own precedent), = and the guard reads
//  the title the CONTROL HOLDS (= `label(forSegment:)`, = what AppKit
//  will draw) plus the pixels the control DRAWS.
//
//  MEASURED on the real control in a real window (= the ladder the
//  rule and the write agree on):
//
//  | the cell's share | the title the control holds | the ink |
//  | --- | --- | --- |
//  | 16.67 PT (= 12 cells in a 200 PT region) | U+200B (= nothing) | 0 pixels above 140 |
//  | 100 PT (= 12 cells in a 1200 PT region) | the whole title | 8447 pixels above 140 |
//
//  ⇒ So the control that the app writes at a narrow share holds NOTHING
//  (= no ink), = and the control it writes at a wide share holds the
//  WHOLE title (= ink). = A reverted write would hold the whole title
//  at BOTH shares (= the lone ellipsis at the narrow one, = ink where
//  the boss wants nothing).

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("The strip's title reaches the control")
struct PaneTabStripTitleWriteTests {
    // MARK: - The harness

    /// A real control, configured by the PRODUCTION write path.
    ///
    /// The titles are the long ones (= '十二地仙' = 52 PT as drawn), so
    /// a narrow cell cannot hold them and a wide one can.
    @MainActor
    private func configuredControl(
        regionWidth: CGFloat,
        cellCount: Int,
        title: String = "十二地仙"
    ) -> NSSegmentedControl {
        let labels = (0 ..< cellCount).map { "cell\($0)" }
        let control = NSSegmentedControl()
        let view = LabelSegmentedControl<String>(
            selection: .constant(labels[0]),
            labels: labels,
            displayStrings: Array(repeating: title, count: cellCount),
            regionWidth: regionWidth,
            controlSize: .small
        )
        view.configure(control, coordinator: LabelSegmentedControl<String>.Coordinator(parent: view))
        return control
    }

    /// The ink the control DRAWS (= the pixels above 140 in its own
    /// bounds, = inside a real window, = after a real layout pass).
    ///
    /// A text-bearing cell peaks near 223; a cell that holds nothing
    /// peaks at the background level.
    @MainActor
    private func drawnInk(of control: NSSegmentedControl) -> (maxLuminance: Int, pixelsAbove140: Int) {
        let width = max(control.fittingSize.width, 1)
        let height = max(control.fittingSize.height, 1)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let host = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        host.addSubview(control)
        control.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        control.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let bounds = host.bounds
        let result = host.bitmapImageRepForCachingDisplay(in: bounds).map { rep -> (Int, Int) in
            rep.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
            NSGraphicsContext.restoreGraphicsState()
            host.cacheDisplay(in: bounds, to: rep)

            guard let data = rep.bitmapData else { return (0, 0) }
            let bytesPerRow = rep.bytesPerRow
            let samples = rep.samplesPerPixel
            var maxLuminance = 0
            var pixelsAbove140 = 0
            for y in 0 ..< rep.pixelsHigh {
                for x in 0 ..< rep.pixelsWide {
                    let offset = y * bytesPerRow + x * samples
                    let luminance = (
                        Int(data[offset]) * 299
                            + Int(data[offset + 1]) * 587
                            + Int(data[offset + 2]) * 114
                    ) / 1000
                    if luminance > maxLuminance {
                        maxLuminance = luminance
                    }
                    if luminance > 140 {
                        pixelsAbove140 += 1
                    }
                }
            }
            return (maxLuminance, pixelsAbove140)
        }
        window.orderOut(nil)
        return result ?? (0, 0)
    }

    // MARK: - The write the app makes

    @Test("A narrow cell holds NOTHING (= the app's own title, = not AppKit's ellipsis)")
    @MainActor
    func narrowCellHoldsNothing() {
        // 12 cells in a 200 PT region (= a 16.67 PT share) = the share
        // the boss's rule says can hold neither a character nor a
        // meaningful ellipsis.
        let control = configuredControl(regionWidth: 200, cellCount: 12)

        let held = control.label(forSegment: 0) ?? ""
        #expect(
            held == PaneTabStripTitle.nothingMarker,
            """
            The narrow cell holds '\(held)' (= U+\
            {String(held.unicodeScalars.first?.value ?? 0, radix: 16)}). It must \
            hold the app's nothing marker, = because AppKit's own fallback \
            for a title that does not fit is the lone '…' (= the defect the \
            boss ruled out).
            """
        )
        // And the tooltip keeps the WHOLE title (= the canonical Apple
        // HIG inspector tab tooltip, = so the hover still names it).
        #expect(
            control.toolTip(forSegment: 0) == "十二地仙",
            "the tooltip must keep the whole title, = so a narrow cell can still be named on hover"
        )
    }

    @Test("A narrow cell PAINTS nothing (= the lone ellipsis is gone)")
    @MainActor
    func narrowCellPaintsNothing() {
        let control = configuredControl(regionWidth: 200, cellCount: 12)
        let measurement = drawnInk(of: control)

        #expect(
            measurement.pixelsAbove140 == 0,
            """
            The narrow cell painted \(measurement.pixelsAbove140) pixels above \
            140 (max luminance \(measurement.maxLuminance)). It must paint \
            NOTHING: = the boss's rule is that once only the '…' would \
            show, = even the '…' goes.
            """
        )
    }

    @Test("A wide cell holds and paints the WHOLE title (= the write is not a blank-out)")
    @MainActor
    func wideCellHoldsTheWholeTitle() {
        // 12 cells in a 1200 PT region (= a 100 PT share) = the share
        // that holds the 52 PT title whole.
        let control = configuredControl(regionWidth: 1200, cellCount: 12)

        #expect(
            control.label(forSegment: 0) == "十二地仙",
            "a cell that has room must hold the whole title"
        )
        let measurement = drawnInk(of: control)
        #expect(
            measurement.pixelsAbove140 > 0,
            """
            The wide cell painted no text (\(measurement.pixelsAbove140) pixels \
            above 140, = max luminance \(measurement.maxLuminance)). A cell that \
            has room must show the title, = so the narrow cell's blankness is \
            the rule at work and not a strip that never draws anything.
            """
        )
    }

    // MARK: - The write is the app's, = not the test's

    @Test("The title the control holds is the app's fitted title (= one door per question)")
    @MainActor
    func theControlHoldsTheAppsFittedTitle() {
        // The share the owner computes (= the region's share) is what
        // the title is fitted to, = so the control's title IS the rule's
        // answer for that share.
        let share = PaneTabStripWidth.segmentWidth(columnWidth: 200, segmentCount: 12)
        let expected = PaneTabStripTitle.fitted("十二地仙", share: share, font: NSFont.systemFont(ofSize: 13))
        let control = configuredControl(regionWidth: 200, cellCount: 12)

        #expect(
            control.label(forSegment: 0) == expected,
            "the control must hold the rule's answer for its own share"
        )
    }
}
