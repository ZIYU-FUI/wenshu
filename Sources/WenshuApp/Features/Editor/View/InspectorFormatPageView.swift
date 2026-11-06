//
//  InspectorFormatPageView.swift
//  wenshu
//
//  The format page of the trailing inspector column.
//
//  WHAT THIS PAGE IS
//
//  The page used to be three groups of format commands (= the
//  character group, = the block group, = and the insert group), = with
//  a heading menu and a link field of their own. = It is now the
//  BOOK's style sheet: = the three commands a novel uses inline (=
//  bold, = italic, = and the highlight), = and then the style page,
//  = which names the book's twelve styles and the five knobs it is
//  fine-tuned with.
//
//  WHY THE RIGHT COLUMN AND NOT THE EDITOR
//
//  Measured against Apple Pages (Pages Creator Studio, com.apple.Pages)
//  with REA's native-UI and accessibility-tree readers: Pages puts its
//  format inspector in the RIGHT column, next to the document, and that
//  column is about 276 PT wide. The editor column's own chrome row (= a
//  strip of icons) is the shape Pages does NOT use.
//
//  WHAT PAGES LOOKS LIKE, AND WHAT THIS PAGE COPIES
//
//  Measured 2026-11-04 on the running Pages app: its inspector's "样式"
//  (= style) tab, in a 270 PT column, read from the accessibility tree
//  and from a 2x capture of the column.
//
//      字体                      <- a bold group heading, primary ink
//      [苹方-简              ⌄]   <- a full-width rounded control block
//      [常规体           ⌄][11⌄][⚙]
//      [·|B|U|U̲][⚙]
//      字符样式     [无        ⌄]   <- a label at the left, a block at the right
//      ──────────────            <- a hairline between the groups
//      [左][中][右][两]           <- related controls on ONE row
//      [减       ][增       ]
//      ──────────────
//      > 间距          [1.0 - 一倍 ⌄]
//
//  Five facts follow, and this page is built on them:
//
//    1. THE COLUMN HAS NO CARDS. Pages' controls sit directly on the
//       column's own background, in rounded blocks; nothing is drawn
//       behind a group or a row. So this page draws no card either
//       (= the column's other pages use `InspectorCard`, = and they are
//       a different subject with a different contract).
//    2. A GROUP IS A BOLD HEADING, A HAIRLINE, AND ROWS. The heading
//       is the primary ink at heading size; the hairline separates the
//       groups; the rows carry the controls.
//    3. RELATED CONTROLS SHARE ONE ROW, IN ONE BLOCK. Pages' bold /
//       italic / underline sit side by side in one rounded block, split
//       by vertical hairlines, and the whole group of them is one
//       row wide. So a command here is an icon in a slot, and the
//       slots of one group share a row.
//    4. A CONTROL IS A ROUNDED BLOCK, AND A VALUE-BEARING CONTROL IS
//       A FULL-WIDTH BLOCK. The knobs of the style page carry a
//       position, so they are full-width drop-downs, exactly like
//       Pages' font menu.
//    5. A LABEL SITS AT THE LEFT OF ITS CONTROL. Each knob reads as a
//       label, then the block that holds the position.
//
//  WHAT THE PAGE SHOWS, AND WHAT IT DELIBERATELY DOES NOT
//
//  The commands that are left are the ones a novel uses inline: =
//  bold, = italic, = and the highlight. = The other nine are GONE from
//  this page, = because a book sets them once (= in its style sheet,
//  = which the style page shows) = instead of one click at a time.
//
//  The page shows no current-value readout of the document's
//  selection (no "the selection is bold" indicator), because the
//  engine publishes no public current-value getters, and a value the
//  app cannot read is a value the app must not invent. = The values
//  this page DOES show are the book's own (= the sheet the book
//  carries), = and those the app reads.
//
//  That ruling also rules out Pages' segmented control here: a
//  segmented control SHOWS WHICH SLOT IS SELECTED, so a row of
//  segmented command buttons would claim a state the app cannot read.
//  The commands are therefore plain buttons in the slots, and they
//  never look selected.
//

import MarkdownEngine
import SwiftUI

/// The trailing inspector column's format page.
///
/// The Pages-style format inspector: = the commands a novel uses
/// inline, = and then the book's own style sheet.
struct InspectorFormatPageView: View {
    /// The editor's bus (= the engine's request channel).
    ///
    /// The bus names are the engine's own (= the fixed global
    /// notification names), so a command posted here reaches the editor
    /// the way it did from the icon row.
    let bus: MarkdownEditorBus = .buildWenshu()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
                characterGroup
                InspectorStylePageView()
            }
            .padding(.horizontal, DesignTokens.spacingLoose)
            .padding(.bottom, DesignTokens.spacingLoose)
        }
    }

    // MARK: - Character

    /// The character group's commands (= bold, italic, highlight).
    ///
    /// These are the commands that change the SELECTED TEXT's
    /// characters, so they sit together the way Pages groups its
    /// character-style controls (= one row, one block, one slot each).
    /// The commands a book sets once (= the strike, = the inline code,
    /// = the headings, = the lists, = the quote, = the code block, = the
    /// rule, = the image and = the link) = are the style sheet's rows
    /// now, = and they live on the style page.
    private var characterGroup: some View {
        InspectorFormatGroup(
            title: String(localized: "inspector.format.group.character"),
            showsDivider: false
        ) {
            InspectorFormatCommandStrip(actions: [.bold, .italic, .highlight]) { action in
                apply(action)
            }
        }
    }

    // MARK: - Command

    /// Post one format command.
    ///
    /// The commands that are left carry no value (= the engine takes
    /// bold, = italic and = the highlight as they are), = so nothing
    /// else rides along.
    ///
    /// - Parameter action: the command to apply.
    private func apply(_ action: EditorFormatAction) {
        action.dispatch(bus: bus)
    }
}

// MARK: - Group

/// One group of format commands (= the group's heading and its rows).
///
/// The heading is Pages' heading: = the primary ink at heading size, =
/// with no plate behind it. The hairline above the group is the
/// separator Pages draws between the groups of its inspector (= and the
/// FIRST group carries none, = because there is nothing above it to
/// separate from).
struct InspectorFormatGroup<Content: View>: View {
    /// The group's heading (= the group's own name).
    let title: String

    /// The group's rows.
    let content: Content

    /// Whether a hairline separates this group from the one above it.
    let showsDivider: Bool

    init(
        title: String,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingRelaxed) {
            if showsDivider {
                Divider()
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignTokens.textBody)
            content
        }
    }
}

// MARK: - Command strip

/// One row of format commands (= the commands of one kind, side by side).
///
/// Pages puts its related controls on ONE row, in ONE rounded block,
/// split by vertical hairlines (= its bold / italic / underline). This
/// is that row: = one block, = one slot per command, = a hairline
/// between the slots.
struct InspectorFormatCommandStrip: View {
    /// The commands the row carries (= in the order they are drawn).
    let actions: [EditorFormatAction]

    /// What a pressed command does.
    let perform: (EditorFormatAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                if index > 0 {
                    Divider()
                        .frame(height: DesignTokens.spacingSection)
                }
                InspectorFormatCommandButton(action: action) {
                    perform(action)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(InspectorFormatBlock())
    }
}

// MARK: - Command button

/// One format command, as a slot in a row (= the command's own glyph).
///
/// The glyph is the command's icon (= the one the editor zone's icon
/// row wore, = so the command reads the same wherever it is drawn), and
/// the command's NAME is the tooltip and the VoiceOver label, because
/// the slot is a glyph and a glyph needs its name spoken.
struct InspectorFormatCommandButton: View {
    /// The command this slot carries.
    let action: EditorFormatAction

    /// What pressing the slot does.
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            SFIcon(
                action.iconName,
                style: .small,
                color: IconColor.primary
            )
            .frame(height: DesignTokens.controlHeightLarge)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverWash()
        .help(action.localizedLabel)
        .accessibilityLabel(action.localizedAccessibilityLabel)
    }
}

// MARK: - Block

/// The rounded block a control sits in (= Pages' control surface).
///
/// Pages draws its inspector's controls as rounded blocks that are one
/// shade off the column's background (= the system's own control
/// surface, = which is what a hierarchical shape style already is on
/// macOS). So the block is the quaternary hierarchical style and the
/// radius is the design system's small-button radius (= the same radius
/// the rest of the app's buttons wear).
struct InspectorFormatBlock: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
            .fill(.quaternary)
    }
}
