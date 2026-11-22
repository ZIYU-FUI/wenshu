//
//  InspectorStyleKnobView.swift · Wenshu
//
//  One fine-tuning knob of a book's style sheet: = the knob's name at
//  the left, = and the position the book sits at in a pop-up button at
//  the right.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the nine styles and the five knobs grew past
//  comfortable when the knobs became writable (= the write-back, = the
//  position's raw value and its label, = and the control's own action),
//  = so the knob's own view moved out. = The page keeps the MODEL
//  (= the rows, = the knobs, = and the positions), = and this file
//  draws one knob.
//
//  WHY THE CONTROL IS THE SYSTEM'S POP-UP BUTTON
//
//  A knob offers a flat list of positions, = all of them applying to the
//  same thing, = with one of them chosen at a time. = That is the shape
//  Apple's NSPopUpButton is built for (= HIG > Pop-up buttons > Best
//  practices: "Use a pop-up button to present a flat list of mutually
//  exclusive options or states"), = and the button
//  shows the chosen one in itself (= same page: = "the button can update
//  its content to indicate the current selection"). = Nothing a knob does
//  asks for more than that, = so the row carries Apple's own
//  `NSPopUpButton` (= `ValuePopUpButton`) = and the page invents no
//  control of its own.
//
//  WHY NOT A DRAWN FACSIMILE
//
//  A knob can be a block of the app's own drawing (= a rounded rectangle,
//  the position at its left, = a chevron at its right) with a borderless
//  `Menu` laid over it and the menu's own title painted out
//  (`.foregroundStyle(.clear)`). = That inversion exists only because a
//  drawn block wants the position at its LEFT and the system button paints
//  it in its CENTRE. = It costs a second painter for every position, = a
//  hack to silence the first one, = a hand-drawn chevron, = and a control
//  that stops following the system's own size, = tint, = or focus ring.
//  The position rides in the system's button, = at the system's own
//  position (see OOB.md #2026-11-19).
//

import SwiftUI

/// One fine-tuning knob: = the knob's name at the left, = and the
/// position the book sits at in a pop-up button at the right, = capped to
/// the width the page measured for the column.
struct InspectorStyleKnobView: View {
    /// The knob this row carries.
    let knob: InspectorStyleKnob

    /// The width every knob's pop-up is pinned to (= the widest of the
    /// column's buttons, = measured by `ValuePopUpButton.fittingWidth`).
    ///
    /// The five rows are one column of choices, = and a column whose
    /// controls start at five different x reads as five unrelated
    /// controls. = The width is handed in rather than asked for, = because
    /// only the page knows what its other knobs were offered.
    var columnWidth: CGFloat?

    /// What happens when a position is chosen (= the page writes the
    /// position back onto the book's sheet).
    let onChoose: (String) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingStandard) {
            Text(knob.name)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)

            Spacer(minLength: DesignTokens.spacingStandard)

            ValuePopUpButton(
                options: knob.positions.map {
                    ValuePopUpButton.Option(selection: $0.rawValue, label: $0.label)
                },
                selection: knob.current.rawValue,
                name: knob.name
            ) { position in
                onChoose(position)
            }
            //  `maxWidth` and not `width`: = every knob's button takes the
            //  one measured width the page computed for the whole column
            //  (= so the five agree), = and when the column is narrower
            //  than that the row's own leftover wins instead of the button
            //  drawing over the page's edge.
            .frame(maxWidth: columnWidth)
        }
    }
}
