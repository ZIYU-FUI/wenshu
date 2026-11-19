//
//  InspectorStylePresetPickerTests.swift · Wenshu
//
//  The three places a book's sheet can be, = in Apple's own segmented
//  control, = over the whole width of the column.
//
//  WHAT IS MEASURED
//
//  The control is a real AppKit `NSSegmentedControl` (= SwiftUI's
//  `SegmentedPickerStyle` builds one, = and it is visible in the view
//  tree), = so the selection is read where it lives: = the control's own
//  selected segment. = That is what answers the complaint this control
//  was written for: = one set's name, = three times, = in its own row.
//  = The control's segments ARE the names, = and each is painted once,
//  = by the control.
//
//  WHY 自定义 IS MEASURED AS A SEGMENT
//
//  A book fine-tuned off both sets used to be shown by lighting nothing
//  (= `selectedSegment == -1`). = That state had no door: = a reader could
//  see it and could not return to it. = The ruling this file now holds the
//  line on (= OOB.md #2026-11-19): = the fine-tuned book lights 自定义,
//  = and nothing else is lit.
//
//  swift test --filter InspectorStylePresetPickerTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector style page, the set control", .serialized)
struct InspectorStylePresetPickerTests {
    /// The control lights the place the book is at, = and a fine-tuned
    /// book is at 自定义.
    @Test("the control lights where the book is")
    func theControlLightsWhereTheBookIs() throws {
        let printBaseline = render(current: .preset(.printBaseline))
        let general = render(current: .preset(.general))
        let fineTuned = render(current: .custom)

        let order = BookStyleSelection.choices
        #expect(
            printBaseline.selectedSegment == order.firstIndex(of: .preset(.printBaseline)),
            "the set the book is at is the lit segment (= got \(printBaseline.selectedSegment))"
        )
        #expect(
            general.selectedSegment == order.firstIndex(of: .preset(.general)),
            "the other set lights its own segment (= got \(general.selectedSegment))"
        )
        #expect(
            fineTuned.selectedSegment == order.firstIndex(of: .custom),
            "a book fine-tuned off both sets lights 自定义 (= got \(fineTuned.selectedSegment))"
        )
        #expect(
            fineTuned.selectedSegment >= 0,
            "the fine-tuned state is a segment a reader can see (= and not an absence of one)"
        )
    }

    /// The segments carry the three names, = each once, = in the order the
    /// page lists them.
    @Test("the segments carry the three names, once each")
    func theSegmentsCarryTheNamesOnceEach() throws {
        let control = render(current: .preset(.general))
        let labels = (0 ..< control.segmentCount).map { control.label(forSegment: $0) ?? "" }
        #expect(
            labels == BookStyleSelection.choices.map(\.displayName),
            "one segment per place, = in the order the page lists them: \(labels)"
        )
        #expect(
            control.segmentCount == 3,
            "two sets and the reader's own tuning, = three segments"
        )
        #expect(
            labels.last == BookStyleSelection.custom.displayName,
            "自定义 is last (= the sets are where a book starts, = the tuning is where it ends up)"
        )
    }

    /// WHY THERE IS NO TEST THAT THE SWITCHER FILLS THE COLUMN
    ///
    /// The width the control is pinned to is the width its ROW was given,
    /// = and an offscreen `NSHostingView` never lays that row out: = the
    /// measurement recorded 612 PT for a 252 PT column, = which is the
    /// control's own fitting width (= and its fitting width is itself the
    /// catalog's KEYS here, = because a test process renders keys, = not
    /// words). = A number that only exists in a live window cannot be
    /// asserted from a headless one, = so the guard is structural
    /// (`theSetsAreTheSystemsControl`, = which fails the moment the region
    /// stops being passed in), = and the width itself is read off the
    /// running app.

    /// Where the book is, = read off the sheet the book carries.
    @Test("a tuned sheet reads as the reader's own")
    func aTunedSheetReadsAsTheReadersOwn() throws {
        var sheet = BookStyleSheet.default
        #expect(
            BookStyleSelection.select(sheet: sheet) == .preset(.printBaseline),
            "the print baseline is the printed set, = not a tuning"
        )
        sheet.bodySize = .large
        #expect(
            BookStyleSelection.select(sheet: sheet) == .custom,
            "a book whose own knob moved sits at none of the sets (= so the switcher says 自定义)"
        )
    }

    /// The choice is the system's control, = not a shape drawn here.
    ///
    /// WHY THIS IS READ OFF THE SOURCE
    ///
    /// The mark this replaces was ink, = and ink a screenshot of an
    /// offscreen render reads fine; = what a pixel test cannot see is a
    /// control that only LOOKS like the system's. = So the guard is
    /// structural: = the file names the picker style, = and it draws
    /// nothing of the selection itself.
    @Test("the sets are the system's control, not a drawing of one")
    func theSetsAreTheSystemsControl() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.pickerSourceURL(),
            encoding: .utf8
        ))
        #expect(
            code.contains("LabelSegmentedControl("),
            "the choice is Apple's own `NSSegmentedControl` (= the control the HIG names for an inspector pane), = hosted by the app's one wrapper for it"
        )
        #expect(
            code.contains("regionWidth:"),
            "the switcher is pinned to the width its row was given (= the boss's ruling: = 拉到全列宽, = and a segmented control that keeps its own fitting width is not that)"
        )
        #expect(
            !code.contains("checkmark") && !code.contains("InspectorFormatBlock"),
            "the selection state is the control's own (= nothing here draws a tick or a block)"
        )
        #expect(
            !code.contains("Menu {"),
            "three places are nothing to drop down (= and the drop-down is what painted a name twice)"
        )
    }

    /// The rendered control's segmented control.
    private func render(current: BookStyleSelection) -> NSSegmentedControl {
        let host = NSHostingView(rootView: AnyView(
            InspectorStylePresetPicker(
                choices: BookStyleSelection.choices,
                current: current
            ) { _ in }
            .frame(width: CGFloat(Self.columnWidth))
        ))
        host.frame = NSRect(x: 0, y: 0, width: Self.columnWidth, height: 40)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        guard let control = Self.segmented(in: host) else {
            Issue.record("the choice rendered no segmented control")
            return NSSegmentedControl()
        }
        return control
    }

    private static let columnWidth: CGFloat = 252

    private static func segmented(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for sub in view.subviews {
            if let found = segmented(in: sub) { return found }
        }
        return nil
    }

    /// The control's own source file (= where the picker style is named).
    private static func pickerSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorStylePresetPicker.swift")
    }
}
