//
//  InspectorStyleKnobView.swift · Wenshu
//
//  One fine-tuning knob of a book's style sheet: = the knob's name at
//  the left, = and the position the book sits at in a drop-down at
//  the right.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the twelve styles and the five knobs grew past
//  comfortable when the knobs became writable (= the write-back, = the
//  position's raw value and its label, = and the menu's own action),
//  = so the knob's own view moved out. = The page keeps the MODEL (=
//  the rows, = the knobs, = and the positions), = and this file draws
//  one knob.
//

import SwiftUI

/// One fine-tuning knob: = the knob's name at the left, = and the
/// position the book sits at in a drop-down at the right.
struct InspectorStyleKnobView: View {
    /// The knob this row carries.
    let knob: InspectorStyleKnob

    /// What happens when a position is chosen (= the page writes the
    /// position back onto the book's sheet).
    let onChoose: (String) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(knob.name)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)
            Spacer(minLength: DesignTokens.spacingTight)
            knobMenu
        }
    }

    /// The knob's drop-down.
    ///
    /// The menu carries the positions the knob can take, = and choosing
    /// one writes it back onto the book's sheet (= the page's own
    /// action). = The menu shows the position's LABEL (= what the
    /// reader sees) = and carries its RAW value (= what the sheet
    /// reads back). = The position the book already sits at is the
    /// menu's label, = so the accessibility tree publishes that
    /// position (= a SwiftUI `Menu` publishes its label, = and a
    /// `Text` publishes nothing).
    private var knobMenu: some View {
        ZStack(alignment: .leading) {
            knobBlock
            Menu {
                ForEach(knob.positions) { position in
                    Button {
                        onChoose(position.rawValue)
                    } label: {
                        Text(position.label)
                    }
                }
            } label: {
                Text(knob.current.label).opacity(0)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    /// The drawn block the drop-down rides on (= Pages' drop-down: =
    /// the position at the left, = the indicator at the right).
    ///
    /// SwiftUI draws a macOS menu's own title in the CENTRE of its
    /// button, = and Pages' block puts its title at the left, = so the
    /// block is drawn here and the real menu rides on top of it as a
    /// transparent button (= the menu itself, = its items, = and its
    /// accessibility role all stay the system's).
    private var knobBlock: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(knob.current.label)
            Spacer(minLength: 0)
            SFIcon(
                "chevron.down",
                style: .inlineSmall,
                color: IconColor.secondary
            )
        }
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(height: DesignTokens.controlHeightLarge)
        .background(InspectorFormatBlock())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
