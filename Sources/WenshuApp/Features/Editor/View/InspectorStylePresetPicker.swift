//
//  InspectorStylePresetPicker.swift · Wenshu
//
//  The three places a book's sheet can be, = in one segmented control:
//  = the printed set, = the screen's set, = and the book's own tuning.
//  One of them is lit, = and the lit one is where the book is.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the eleven styles and the five knobs already grew
//  past comfortable, = so the choice of set lives here, = beside the
//  knob's. = The page keeps the MODEL (= the rows, = the knobs, = the
//  positions, = and the three places), = and this file draws the choice.
//
//  WHY A SEGMENTED CONTROL
//
//  The three places are mutually exclusive, = they all apply to the same
//  thing (= the whole sheet), = and all of them are always worth seeing.
//  = That is the control Apple names for this corner of a window (= HIG, =
//  segmented-controls, = alert-date 2023-06-21: = "a segmented control in
//  an inspector could let people choose one or more attributes to apply to
//  a selection", = and for macOS, = "Consider using a segmented control to
//  help people switch views in a toolbar or inspector pane"), = and their
//  names are nouns, = which is what the same page asks of a segment's
//  label (= "Use nouns or noun phrases for segment labels"). = So this is
//  a `Picker` with `.pickerStyle(.segmented)` (= `SegmentedPickerStyle`),
//  = stretched over the column's whole width (= `.frame(maxWidth:)`), =
//  because three short names in a narrow inspector read as a strip of
//  buttons only when the strip is the column: = segments of unequal width
//  make the longest one the centre of attention.
//
//  WHY Custom IS A SEGMENT AND NOT AN ABSENCE
//
//  A book fine-tuned off both sets used to be shown by lighting NOTHING
//  (= measured: = AppKit reports `selectedSegment` as -1, = so the state
//  was expressible, = and it was the honest one). = It was also a state
//  the reader could only read and never choose: = the tuning had no door,
//  = and a reader who had gone to General and wanted their own settings back
//  had nothing to press. = The boss's ruling: = the state gets its own
//  segment, = the page lands on it by itself whenever the book's sheet
//  matches no set, = and the tuning is the book's own record
//  (= `Book.customStyleSheet`), = so General and back to Custom returns what
//  the reader had tuned, = not what the set in between said.
//  = (see OOB.md #2026-11-19.)
//
//  WHY THE DROP-DOWN AND THE MARKED ROWS ARE BOTH GONE
//
//  It was a drop-down once, = and one set's name was written three times
//  in its own row. = The drop-down went, = and two rows carrying a
//  hand-drawn tick took its place. = Both were facsimiles of the thing the
//  system ships: = a selection state, = restated by hand in a shape that
//  stops matching the operating system the day the operating system
//  changes.
//

import SwiftUI

/// The three places a book's sheet can be, = as one choice.
struct InspectorStylePresetPicker: View {
    /// The places the book can be taken to (= in the order they are drawn).
    let choices: [BookStyleSelection]

    /// Where the book is.
    let current: BookStyleSelection

    /// What happens when a place is chosen (= the page writes the whole
    /// sheet down).
    let onChoose: (BookStyleSelection) -> Void

    /// The width the row gave the control, = which is what the AppKit
    /// control is pinned to.
    ///
    /// WHY THE ROW IS MEASURED AND NOT WRITTEN DOWN
    ///
    /// `regionWidth` is the one argument `LabelSegmentedControl` needs to
    /// divide itself evenly (= MEASURED here: = a SwiftUI `Picker` with
    /// `.pickerStyle(.segmented)` handed its column of 252 PT asked AppKit
    /// for 594 PT and laid the control out at it, = over the edges of the
    /// inspector, = while this control divides the region it is given: =
    /// three names in 252 PT is three names in 252 PT). = The width is
    /// therefore read off the row (= `.background(GeometryReader)`), = and
    /// not one point of it is this file's number.
    @State private var regionWidth: CGFloat = 0

    var body: some View {
        LabelSegmentedControl(
            selection: selection,
            labels: choices,
            displayStrings: choices.map(\.displayName),
            //  The inspector body's own size: = a value switcher, = not a
            //  strip of tabs (= `LabelSegmentedControl`'s default `.large`
            //  is the tab pill, = and this row chooses the smaller control
            //  the way Apple's own inspectors do).
            regionWidth: regionWidth,
            controlSize: .regular
        )
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            regionWidth = width
        }
        //  The group's own heading names this choice on the page, = so the
        //  control carries no label of its own (= and HIG asks no
        //  introductory text of a segmented control that carries its own
        //  words: = "A segmented control that displays text labels doesn't
        //  need introductory text").
        .accessibilityLabel(String(localized: "inspector.style.group.presets"))
    }

    /// The book's place, = as the control's selection.
    ///
    /// The setter does not store anything here: = the book's sheet is the
    /// only record of where it is, = so the segment that ends up lit is the
    /// one the write-back left the book at (= a write that changed nothing
    /// leaves the old segment lit, = which is the truth).
    private var selection: Binding<BookStyleSelection> {
        Binding(
            get: { current },
            set: { picked in onChoose(picked) }
        )
    }
}
