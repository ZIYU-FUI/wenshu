//
//  EditorFormatAction.swift
//  wenshu
//
//  The editor's format commands (= the twelve the engine's markdown
//  surface can apply).
//
//  WHY THIS LIVES IN ITS OWN FILE
//
//  The commands used to live inside the editor's icon row, a file named
//  after that row. The row is gone (= the commands moved to the
//  inspector column's format page, = the Pages-style format inspector),
//  and a vocabulary that outlives the row it was drawn in belongs in a
//  file named after the vocabulary.
//
//  WHAT A COMMAND CARRIES
//
//  Two of the twelve carry a value, and the engine reads that value out
//  of the notification's userInfo:
//
//    - `.heading` reads `userInfo["level"]` (= an Int). The engine DROPS
//      a heading request that carries no level, so the heading command
//      has to name its level.
//    - `.link` reads `userInfo["url"]` (= a String). The engine writes
//      `[text]()` for a link request that carries no URL, so the link
//      command has to name its target.
//
//  The other ten carry nothing: the request name is the whole message.
//

import Foundation
import MarkdownEngine

/// One format command the engine's markdown surface can apply.
///
/// The twelve cases are the engine's whole format surface, so this enum
/// is the single owner of that list (= a thirteenth command would have
/// no engine request to post, and a dropped case would take a command
/// with it).
enum EditorFormatAction: String, CaseIterable, Identifiable {
    case bold
    case italic
    case highlight
    case strikethrough
    case inlineCode
    case heading
    case blockquote
    case unorderedList
    case orderedList
    case link
    case codeBlock
    case horizontalRule

    var id: String {
        rawValue
    }

    /// The SF Symbol the command wears (= the command's own glyph).
    ///
    /// The glyph is the one the editor zone's icon row used, so the
    /// command reads the same wherever it is drawn.
    var iconName: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .highlight: return "highlighter"
        case .strikethrough: return "strikethrough"
        case .inlineCode: return "chevron.left.forwardslash.chevron.right"
        case .heading: return "textformat.size"
        case .blockquote: return "text.quote"
        case .unorderedList: return "list.bullet"
        case .orderedList: return "list.number"
        case .link: return "link"
        case .codeBlock: return "note.text"
        case .horizontalRule: return "minus"
        }
    }

    /// The command's name.
    ///
    /// The lookup is a RUNTIME key rather than `String(localized:)`: that
    /// form takes a compile-time literal, so a spliced key resolves to
    /// itself and the name reads "editor.format.bold.tooltip" instead of
    /// the translated name. Every one of the twelve keys exists in the
    /// catalog; the lookup form is what reaches them.
    ///
    /// The name is what the reader MEETS as the command's tooltip and as
    /// its VoiceOver name, = and as the words in the two places the page
    /// names a command in words (= the heading command's menu, = the link
    /// row's label). = The ten icon commands draw no words at all: = their
    /// slot IS the glyph, = and the name is spoken and hovered, = not read
    /// off the page.
    var localizedLabel: String {
        NSLocalizedString(
            "editor.format.\(rawValue).tooltip",
            comment: "The name of the \(rawValue) format command"
        )
    }

    /// The command's VoiceOver name.
    ///
    /// This is the string the accessibility tree publishes for the
    /// command, so it is what VoiceOver reads for a command whose glyph
    /// speaks no word (= the glyph is the icon, = and the icon's name is
    /// not a sentence).
    ///
    /// The key is SEPARATE from the visible name's key (= the tooltip's
    /// key), so a future punctuation tweak (= a name that must read
    /// differently when spoken than when shown) = can differ from the
    /// visible name without touching what the page shows. The two values
    /// are CURRENTLY identical for every command (= the page's visible
    /// name and the command's VoiceOver name are one string, = so the
    /// two cannot drift apart by accident).
    ///
    /// No probe reads this string: = the layout probe used to look for a
    /// command by its AXButton label, = and the format commands' move out
    /// of the editor zone took that lookup with it.
    var localizedAccessibilityLabel: String {
        NSLocalizedString(
            "editor.format.\(rawValue).a11y",
            comment: "VoiceOver label for the \(rawValue) format command"
        )
    }

    /// Post this command's request on the bus.
    ///
    /// - Parameters:
    ///   - headingLevel: the level for `.heading` (= 1...6, = the
    ///     engine's own heading scale). The command is NOT posted
    ///     without it, because the engine drops a heading request that
    ///     carries no level.
    ///   - linkURL: the target for `.link`. The command is NOT posted
    ///     without it, because the engine writes `[text]()` for a link
    ///     request that carries no URL.
    func dispatch(
        bus: MarkdownEditorBus,
        headingLevel: Int? = nil,
        linkURL: String? = nil
    ) {
        let dispatcher = FormatDispatcher(bus: bus)
        switch self {
        case .bold:
            dispatcher.applyBold()
        case .italic:
            post(bus.applyItalicRequest)
        case .highlight:
            post(bus.applyHighlightRequest)
        case .strikethrough:
            post(bus.applyStrikethroughRequest)
        case .inlineCode:
            post(bus.applyInlineCodeRequest)
        case .heading:
            guard let name = bus.applyHeadingRequest, let headingLevel else { return }
            post(name, userInfo: ["level": headingLevel])
        case .blockquote:
            post(bus.applyBlockquoteRequest)
        case .unorderedList:
            post(bus.applyUnorderedListRequest)
        case .orderedList:
            post(bus.applyOrderedListRequest)
        case .link:
            guard let name = bus.applyLinkRequest, let linkURL else { return }
            post(name, userInfo: ["url": linkURL])
        case .codeBlock:
            post(bus.applyCodeBlockRequest)
        case .horizontalRule:
            post(bus.applyHorizontalRuleRequest)
        }
    }

    /// Post one request name (= the engine watches the bus by name, =
    /// so the request carries no object).
    private func post(
        _ name: Notification.Name?,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        guard let name else { return }
        NotificationCenter.default.post(
            name: name,
            object: nil,
            userInfo: userInfo
        )
    }
}
