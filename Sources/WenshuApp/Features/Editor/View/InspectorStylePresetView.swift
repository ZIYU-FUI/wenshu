//
//  InspectorStylePresetView.swift · Wenshu
//
//  One of the two sets a book can be set to: = the set's name at the
//  left, = and the set in a drop-down at the right.
//
//  WHY IT IS ITS OWN FILE
//
//  The page that draws the eleven styles and the five knobs already
//  grew past comfortable, = so the set's own view lives here, = beside
//  the knob's. = The page keeps the MODEL (= the rows, = the knobs, =
//  and the sets), = and this file draws one set.
//
//

import SwiftUI

/// One set: = the set's name at the left, = and the set in a drop-down
/// at the right.
struct InspectorStylePresetView: View {
    /// The set this row carries.
    let preset: BookStylePreset

    /// Whether the book is already at this set.
    let isCurrent: Bool

    /// What happens when a set is chosen (= the page writes the whole
    /// sheet down).
    let onChoose: (BookStylePreset) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            // = The set the book is at is MARKED, = so the reader can
            // see where the book stands, = and the mark is in the
            // label itself (= a SwiftUI `Menu` publishes its label to
            // the accessibility tree, = and a `Text` publishes
            // nothing).
            Text(label)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)
            Spacer(minLength: DesignTokens.spacingTight)
            presetMenu
        }
    }

    /// The set's drop-down.
    ///
    /// The menu carries the two sets, = and choosing one writes the
    /// whole sheet down (= the page's own action). = The menu shows the
    /// set's LABEL, = and the set the book is at is marked, = so the
    /// reader can see where the book stands.
    /// The row's label: = the set's name, = and the mark when the
    /// book is at this set.
    private var label: String {
        isCurrent ? "\(preset.displayName) ✓" : preset.displayName
    }

    private var presetMenu: some View {
        ZStack(alignment: .leading) {
            presetBlock
            Menu {
                ForEach(BookStylePreset.allCases, id: \.rawValue) { choice in
                    Button {
                        onChoose(choice)
                    } label: {
                        Text(choice.displayName)
                    }
                }
            } label: {
                Text(label).opacity(0)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    /// The drawn block the drop-down rides on.
    private var presetBlock: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(label)
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
    }
}
