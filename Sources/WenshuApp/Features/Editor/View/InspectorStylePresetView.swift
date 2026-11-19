//
//  InspectorStylePresetView.swift · Wenshu
//
//  One of the two sets a book can be set to: = the row IS the choice.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the eleven styles and the five knobs already
//  grew past comfortable, = so the set's own view lives here, = beside
//  the knob's. = The page keeps the MODEL (= the rows, = the knobs, =
//  and the sets), = and this file draws one set.
//
//  WHY THE ROW IS A ROW AND NOT A ROW PLUS A DROP-DOWN
//
//  It used to be both: = the set's name was written at the left of the
//  row, = and again inside a block at the right, = and that block was a
//  menu that held the same two sets, = and the menu's own label wrote
//  the name a THIRD time (= measured on the page as it shipped: = one
//  set's name, = three times, = in its own row). = So a row named one
//  set, = and its drop-down asked which of the two sets to go to, =
//  which is the same question the row beside it already answers. = With
//  two sets there is nothing to drop down: = the two rows ARE the menu,
//  = one click each, = and the mark says where the book stands.
//  = (see OOB.md #2026-11-19.)
//
//  WHY NO THIRD STATE IS NAMED
//
//  Neither mark showing is a real state (= the book has been
//  fine-tuned off both sets), = and it is left unnamed: = a row that
//  named a third state would be a value the sheet does not hold
//  and a word the reader did not ask for.
//
//  WHY THE MARK IS AN ICON AND NOT A WORD
//
//  A tick says "this one" without adding a sentence to a page that is
//  already read aloud by its section's name (= the system's own menu
//  does the same with `NSMenuItem.state`), = and it is the one shape
//  the row can carry without pushing the set's name around.
//

import SwiftUI

/// One set: = its name at the left, = the mark when the book is at it,
/// = and the whole row is what applies it.
struct InspectorStylePresetView: View {
    /// The set this row carries.
    let preset: BookStylePreset

    /// Whether the book is already at this set.
    let isCurrent: Bool

    /// What happens when the row is chosen (= the page writes the whole
    /// sheet down).
    let onChoose: (BookStylePreset) -> Void

    var body: some View {
        Button(action: apply) {
            HStack(spacing: DesignTokens.spacingTight) {
                Text(preset.displayName)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.textBody)

                Spacer(minLength: DesignTokens.spacingTight)

                //  The mark rides at the trailing edge, = where the
                //  block used to ride, = so the two rows still read as
                //  a column and the name is painted exactly once.
                if isCurrent {
                    SFIcon("checkmark", style: .inlineSmall, color: IconColor.primary)
                }
            }
            //  The whole row answers the click, = not only the glyphs
            //  drawn in it (= a plain `HStack` of text hits only where
            //  there is ink, = which is the other half of why the block
            //  was there to begin with).
            .contentShape(Rectangle())
        }
        //  `.plain`: = this is a line of a list, = not a button drawn on
        //  a page of its own, = and the Pages look of this inspector is
        //  flat rows (= the boss's ruling on this page: = keep the flat
        //  Pages look, = fix what is drawn).
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    /// The row's label for a reader: = the set's name, = and the mark
    /// when the book is at this set.
    private var label: String {
        isCurrent ? "\(preset.displayName) ✓" : preset.displayName
    }

    private func apply() {
        onChoose(preset)
    }
}
