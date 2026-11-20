//
//  InspectorStylePresetPicker.swift · Wenshu
//
//  The three places a book's sheet can be, = in one segmented control:
//  = the printed set, = the screen's set, = and the book's own tuning.
//  One of them is lit, = and the lit one is where the book is.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the nine styles and the five knobs already grew
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
//  the repo's own bridged `NSSegmentedControl` (`Shared/UI/LabelSegmentedControl`),
//  = pinned to the width its row was given (`regionWidth`, read off the row by
//  `onGeometryChange`, and negotiated in the control's `sizeThatFits`), =
//  because three short names in a narrow inspector read as a strip of
//  buttons only when the strip is the column: = segments of unequal width
//  make the longest one the centre of attention. = A SwiftUI `Picker` with
//  `.pickerStyle(.segmented)` was tried first and is NOT what ships here: =
//  handed a 252 PT column it asked AppKit for 594 PT and laid itself over the
//  inspector's edge, = because a representable's frame is not set by a
//  `.frame` modifier and the width has to be answered in `sizeThatFits`.
//
//  WHY Custom IS A SEGMENT AND NOT AN ABSENCE
//
//  A book fine-tuned off both sets CAN be shown by lighting NOTHING
//  (= measured: = AppKit reports `selectedSegment` as -1). = That is a
//  state the reader can only read and never choose: = a reader who has
//  gone to General and wants his own settings back has nothing to press.
//  = So the state gets a segment of its own, = and the page lands on it
//  by itself whenever the book's sheet
//  matches no set, = and the tuning is the book's own record
//  (= `Book.customStyleSheet`), = so General and back to Custom returns what
//  the reader had tuned, = not what the set in between said.
//
//  THE SAME RULING'S OTHER HALF: = CUSTOM IS ENTERED, = NOT EARNED
//
//  A segment the reader can see and cannot switch to is a bug he has no
//  name for. = So Custom is always reachable: = an untuned book that is
//  sent there takes the GENERAL set's values (= "reuse the general set at
//  the start") = and is then tuned by hand. = That is why the lit segment
//  is not read off the sheet alone: = a sheet that IS the general set
//  answers "General" to the click that chose Custom, = the segment springs
//  back under the finger, = and nothing was ever written. = The place the
//  reader chose is therefore recorded on the book (=
//  `Book.styleSelectionIdentifier`), = and the sheet's own reading is only
//  what a book that recorded nothing falls back to.
//  (see OOB.md #2026-11-19).
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
    /// The setter stores nothing itself: = it hands the gesture to the page
    /// (`onChoose`), = and the page takes it to
    /// `BookStyleSheetWriteBack.apply(selection:to:store:)`, = which writes
    /// the sheet AND the place in one save, = under a guard that skips a
    /// click that moved neither. = So the segment lights from the place
    /// recorded ON THE BOOK (= `InspectorStylePageModel.init` answers
    /// `recordedSelection ?? BookStyleSelection.select(sheet:)`), = which is
    /// what survives a reload; = reading the place off the sheet is only the
    /// fallback for a book that never recorded one (= every book written
    /// before the switcher recorded places).
    private var selection: Binding<BookStyleSelection> {
        Binding(
            get: { current },
            set: { picked in onChoose(picked) }
        )
    }
}
