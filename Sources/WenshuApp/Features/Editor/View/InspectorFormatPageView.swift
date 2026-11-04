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
//      link command asks for the target in a field first.
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
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.bottom, DesignTokens.spacingStandard)
        }
    }

    // MARK: - Character

    /// The character group's commands (= bold, italic, strikethrough,
    /// highlight, inline code).
    ///
    /// These are the commands that change the SELECTED TEXT's
    /// characters, so they sit together the way Pages groups its
    /// character-style controls.
    private var characterGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.format.group.character")) {
            InspectorFormatCommandRow(action: .bold) { apply(.bold) }
            InspectorFormatCommandRow(action: .italic) { apply(.italic) }
            InspectorFormatCommandRow(action: .strikethrough) { apply(.strikethrough) }
            InspectorFormatCommandRow(action: .highlight) { apply(.highlight) }
            InspectorFormatCommandRow(action: .inlineCode) { apply(.inlineCode) }
        }
    }

    // MARK: - Block

    /// The block group's commands (= heading, blockquote, bulleted list,
    /// numbered list).
    ///
    /// These change the line the selection sits on, so they sit
    /// together. The heading command is the one that carries a value,
    /// so its row asks for the level in a menu.
    private var blockGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.format.group.block")) {
            headingRow
            InspectorFormatCommandRow(action: .blockquote) { apply(.blockquote) }
            InspectorFormatCommandRow(action: .unorderedList) { apply(.unorderedList) }
            InspectorFormatCommandRow(action: .orderedList) { apply(.orderedList) }
        }
    }

    /// The heading row (= the command's own menu of levels).
    ///
    /// The menu is the ONLY place the level is chosen, because the
    /// engine needs one: a heading request without a level is dropped by
    /// the engine, so the command cannot be a plain button.
    private var headingRow: some View {
        InspectorFormatGroupRow(action: .heading) {
            Menu {
                ForEach(Self.headingLevels, id: \.self) { level in
                    Button {
                        apply(.heading, headingLevel: level)
                    } label: {
                        Text(headingLevelLabel(level))
                    }
                }
            } label: {
                action(.heading, style: .body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            // The menu's OWN name is the command's name (= "Heading"),
            // never the level format string (= "Heading %d"), = which
            // would be read out loud with the placeholder in it.
            .accessibilityLabel(EditorFormatAction.heading.localizedAccessibilityLabel)
        }
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

    // MARK: - Insert

    /// The insert group's commands (= link, code block, horizontal rule).
    ///
    /// The link command is the one that carries a target, so its row
    /// asks for the target in a field.
    private var insertGroup: some View {
        InspectorFormatGroup(title: String(localized: "inspector.format.group.insert")) {
            linkRow
            InspectorFormatCommandRow(action: .codeBlock) { apply(.codeBlock) }
            InspectorFormatCommandRow(action: .horizontalRule) { apply(.horizontalRule) }
        }
    }

    /// The link row (= the target field and the command that uses it).
    ///
    /// The field is the link's TARGET (= where the link points), and
    /// the button is the command (= apply the link to the selection
    /// using that target). The command stays disabled while the field
    /// is empty, because a link with no target is `[text]()`.
    private var linkRow: some View {
        InspectorFormatGroupRow(action: .link) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                action(.link, style: .body)
                HStack(spacing: DesignTokens.spacingTight) {
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
                            color: IconColor.tint
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(linkTarget.isEmpty)
                    .help(String(localized: "inspector.format.link.apply"))
                    .accessibilityLabel(String(localized: "inspector.format.link.apply"))
                }
            }
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

    /// One command's name, at the given text style.
    private func action(_ action: EditorFormatAction, style: Font) -> Text {
        action.label(style: style)
    }
}

// MARK: - Group

/// One group of format commands (= the group's title and its rows).
///
/// The groups are the page's structure (= the way Pages breaks its
/// format inspector into named sections), and the title is what makes
/// the page readable without a legend.
struct InspectorFormatGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(DesignTokens.textMetadata)
                .padding(.horizontal, DesignTokens.spacingStandard)
                .padding(.top, DesignTokens.spacingTight)
            content
        }
    }
}

// MARK: - Row

/// One row of a format group (= the row's own content).
///
/// A row is a CARD (= the column's shared card), so every command in
/// the column reads as one family, and the command's glyph rides the
/// card's marker column (= the column's own marker column, = the same
/// place every other card's marker sits).
struct InspectorFormatGroupRow<Content: View>: View {
    /// The command the row is about (= the glyph the card carries).
    let action: EditorFormatAction
    @ViewBuilder let content: Content

    var body: some View {
        InspectorCard(marker: AnyView(marker), content: { content })
    }

    /// The card's marker (= the command's own glyph).
    ///
    /// The glyph is DECORATIVE here: the command's name sits right
    /// beside it in the card's own words, so a screen reader reading
    /// the glyph would say the symbol's own description (= "Lyrics" for
    /// the blockquote's bubble, = "Remove" for the rule's dash) and
    /// name the command twice, the second time wrongly.
    private var marker: some View {
        SFIcon(
            action.iconName,
            style: .inlineSmall,
            color: IconColor.primary
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Command row

/// One format command, as the page draws it (= the command's name, as
/// a button that applies it).
///
/// A command that needs a value draws that value IN its own row (= the
/// heading menu, = the link field), because the value belongs to the
/// command and to nothing else.
struct InspectorFormatCommandRow: View {
    /// The command this row is about.
    let action: EditorFormatAction

    /// The command's own action (= what pressing it posts).
    let perform: () -> Void

    var body: some View {
        InspectorFormatGroupRow(action: action) {
            Button {
                perform()
            } label: {
                action.label(style: .body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(action.localizedLabel)
            .accessibilityLabel(action.localizedAccessibilityLabel)
        }
    }
}
