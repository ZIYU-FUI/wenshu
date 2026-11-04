//
//  InspectorFormatPageView.swift
//  wenshu
//
//  The format page of the trailing inspector column.
//
//  WHAT THIS PAGE IS
//
//  The editor's format commands used to live in a row of icons under the
//  document's tab strip. They now live here, in the column, as a
//  Pages-style format inspector: grouped, with named fields, menus and
//  drop-downs, instead of a strip of anonymous glyphs.
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
//       A FULL-WIDTH BLOCK. The heading command carries a level, so it
//       is a full-width menu, exactly like Pages' font menu.
//    5. A LABEL SITS AT THE LEFT OF ITS CONTROL. The link command
//       carries a target, so it reads as a label, then the field,
//       then the button that applies it.
//
//  WHAT THE PAGE SHOWS, AND WHAT IT DELIBERATELY DOES NOT
//
//  Every control here is a COMMAND: pressing it asks the engine to
//  apply a format to the document's selection. The page shows no
//  current-value readout of any kind (no "the selection is bold"
//  indicator), because the engine publishes no public current-value
//  getters, and a value the app cannot read is a value the app must not
//  invent. The OOB entry of 2026-10-18 removed the earlier
//  selection-state readout for the same reason, and that ruling stands:
//  this page carries commands, not readouts.
//
//  That ruling also rules out Pages' segmented control here: a
//  segmented control SHOWS WHICH SLOT IS SELECTED, so a row of
//  segmented command buttons would claim a state the app cannot read.
//  The commands are therefore plain buttons in the slots, and they
//  never look selected.
//
//  Font family, font size and the other Pages fields that display a
//  CURRENT value are therefore absent. Adding them means extending the
//  engine's public API first (= the engine is a remote SPM dependency,
//  = so the change lands upstream), not faking the value on the app
//  side.
//
//  THE TWO COMMANDS THAT CARRY A VALUE
//
//  Two of the twelve commands are not a single click:
//
//    - `.heading` carries a LEVEL. The engine drops a heading request
//      that carries no level (`userInfo["level"] as? Int`), so the
//      heading command asks for the level in its menu first.
//    - `.link` carries a TARGET. The engine writes `[text]()` for a
//      link request that carries no URL (`userInfo["url"]`), so the
//      link command asks for the target in its field first.
//
//  Both ask in the page, in the field the value belongs to, and the
//  command then carries the value to the engine.
//
//

import MarkdownEngine
import SwiftUI

/// The trailing inspector column's format page.
///
/// The Pages-style format inspector: the document's format commands,
/// grouped the way Pages groups them, with the two commands that need a
/// value asking for it in a field.
struct InspectorFormatPageView: View {
    /// The editor's bus (= the engine's request channel).
    ///
    /// The bus names are the engine's own (= the fixed global
    /// notification names), so a command posted here reaches the editor
    /// the way it did from the icon row.
    let bus: MarkdownEditorBus = .buildWenshu()

    /// The target the link command will apply (= the text field's own
    /// text; = an empty target means the link command stays disabled).
    @State private var linkTarget: String = ""

    /// The heading levels the menu offers (= the engine's own scale; =
    /// the engine's context menu builds its heading items from the same
    /// 1...6 range).
    static let headingLevels: [Int] = [1, 2, 3, 4, 5, 6]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLoose) {
                characterGroup
                blockGroup
                insertGroup
            }
            .padding(.horizontal, DesignTokens.spacingLoose)
            .padding(.bottom, DesignTokens.spacingLoose)
        }
    }

    // MARK: - Character

    /// The character group's commands (= bold, italic, strikethrough,
    /// highlight, inline code).
    ///
    /// These are the commands that change the SELECTED TEXT's
    /// characters, so they sit together the way Pages groups its
    /// character-style controls (= one row, one block, one slot each).
    private var characterGroup: some View {
        InspectorFormatGroup(
            title: String(localized: "inspector.format.group.character"),
            showsDivider: false
        ) {
            InspectorFormatCommandStrip(actions: [.bold, .italic, .strikethrough, .highlight, .inlineCode]) { action in
                apply(action)
            }
        }
    }

    // MARK: - Block

    /// The block group's commands (= heading, blockquote, bulleted list,
    /// numbered list).
    ///
    /// These change the line the selection sits on, so they sit
    /// together. The heading command is the one that carries a value,
    /// so it gets the full-width menu (= the way Pages gives a
    /// value-bearing control its own full-width block), and the other
    /// three share the row under it.
    private var blockGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.format.group.block")) {
            headingMenu
            InspectorFormatCommandStrip(actions: [.blockquote, .unorderedList, .orderedList]) { action in
                apply(action)
            }
        }
    }

    // MARK: - Insert

    /// The insert group's commands (= link, code block, horizontal rule).
    ///
    /// The link command is the one that carries a target, so its row
    /// reads as a label, then the field that holds the target, then the
    /// button that applies it (= the shape Pages gives a labelled
    /// control). The other two share the row under it.
    private var insertGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.format.group.insert")) {
            linkRow
            InspectorFormatCommandStrip(actions: [.codeBlock, .horizontalRule]) { action in
                apply(action)
            }
        }
    }

    // MARK: - The two value-bearing commands

    /// The heading command's menu (= the level is chosen here, = so the
    /// request carries a level).
    ///
    /// The menu is a full-width block (= Pages' font menu is a
    /// full-width block too, = and this one carries a value the way that
    /// one does).
    private var headingMenu: some View {
        ZStack(alignment: .leading) {
            headingMenuLabel
            Menu {
                ForEach(Self.headingLevels, id: \.self) { level in
                    Button {
                        apply(.heading, headingLevel: level)
                    } label: {
                        Text(headingLevelLabel(level))
                    }
                }
            } label: {
                Color.clear
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(EditorFormatAction.heading.localizedAccessibilityLabel)
        }
    }

    /// The heading menu's drawn block (= what Pages' full-width pop-up
    /// block looks like: = the command's name at the LEFT, = the
    /// drop-down's indicator at the RIGHT).
    ///
    /// SwiftUI draws a macOS menu's own title in the CENTRE of its
    /// button (= an `NSPopUpButton` centres its title, = and SwiftUI
    /// does not expose the alignment), = and Pages' pop-up block puts
    /// its title at the left. So the block is drawn here and the real
    /// menu rides on top of it as a transparent button (= the menu
    /// itself, = its items, = its keyboard behaviour and = its
    /// accessibility role all stay the system's).
    private var headingMenuLabel: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(EditorFormatAction.heading.localizedLabel)
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

    /// The link row (= the label, the field that holds the target, and
    /// the button that applies it).
    ///
    /// The field is the link's TARGET (= where the link points), and the
    /// button is the command (= apply the link to the selection using
    /// that target). The command stays disabled while the field is
    /// empty, because a link with no target is `[text]()`.
    private var linkRow: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Text(EditorFormatAction.link.localizedLabel)
                .font(.callout)
                .foregroundStyle(DesignTokens.textBody)
            TextField(
                String(localized: "inspector.format.link.placeholder"),
                text: $linkTarget
            )
            .textFieldStyle(.roundedBorder)
            Button {
                apply(.link, linkURL: linkTarget)
            } label: {
                SFIcon(
                    "link.badge.plus",
                    style: .inlineSmall,
                    color: IconColor.primary
                )
                .frame(width: DesignTokens.controlHeightLarge)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(InspectorFormatBlock())
            .disabled(linkTarget.isEmpty)
            .help(String(localized: "inspector.format.link.apply"))
            .accessibilityLabel(String(localized: "inspector.format.link.apply"))
        }
    }

    // MARK: - Command

    /// Post one format command.
    ///
    /// The two commands that carry a value get it here (= the level the
    /// menu names, = the target the field holds); the other ten need
    /// nothing.
    ///
    /// - Parameters:
    ///   - action: the command to apply.
    ///   - headingLevel: the level for `.heading` (= `nil` for every
    ///     command but the heading).
    ///   - linkURL: the link's target (= `nil` for every command but the
    ///     link).
    private func apply(
        _ action: EditorFormatAction,
        headingLevel: Int? = nil,
        linkURL: String? = nil
    ) {
        action.dispatch(
            bus: bus,
            headingLevel: headingLevel,
            linkURL: linkURL
        )
    }

    /// The menu's label for one level (= "Heading 2" / the translated
    /// equivalent).
    private func headingLevelLabel(_ level: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "inspector.format.heading.level",
                comment: "The heading level a format command applies"
            ),
            level
        )
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
