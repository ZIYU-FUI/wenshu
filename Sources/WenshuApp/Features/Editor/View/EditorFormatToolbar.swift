// Sources/WenshuApp/UI/Editor/EditorFormatToolbar.swift
// … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
// while typing).
import SwiftUI
import MarkdownEngine

// / One button on the editor format toolbar. Each button is keyed to
// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / NSTextView with native undo support (= engine-internal).
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

    var id: String { rawValue }

    // / SF Symbol shown on the button (= the toolbar is icon-only =
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / carry the textual affordance).
    var iconName: String {
        switch self {
        case .bold:              return "bold"
        case .italic:            return "italic"
        case .highlight:         return "highlighter"
        case .strikethrough:     return "strikethrough"
        case .inlineCode:        return "chevron.left.forwardslash.chevron.right"
        case .heading:           return "textformat.size"
        case .blockquote:        return "text.quote"
        case .unorderedList:     return "list.bullet"
        case .orderedList:       return "list.number"
        case .link:              return "link"
        case .codeBlock:         return "note.text"
        case .horizontalRule:    return "minus"
        }
    }

    // / Localized tooltip (= "editor.format.bold.tooltip" etc.).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `editor.format.<action>.tooltip`).
    var localizedLabel: String {
        String(localized: "editor.format.\(rawValue).tooltip")
    }

    // / Accessibility label (= used by VoiceOver; = the same
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / future punctuation tweaks don't conflict).
    var localizedAccessibilityLabel: String {
        String(localized: "editor.format.\(rawValue).a11y")
    }

    // / Bus notification name this action posts. `FormatDispatcher`
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the single owner of the 12-button contract.
    func dispatch(bus: MarkdownEditorBus) {
        let dispatcher = FormatDispatcher(bus: bus)
        let post: (Notification.Name?) -> Void = { name in
            guard let name else { return }
            NotificationCenter.default.post(name: name, object: nil)
        }
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
            post(bus.applyHeadingRequest)
        case .blockquote:
            post(bus.applyBlockquoteRequest)
        case .unorderedList:
            post(bus.applyUnorderedListRequest)
        case .orderedList:
            post(bus.applyOrderedListRequest)
        case .link:
            post(bus.applyLinkRequest)
        case .codeBlock:
            post(bus.applyCodeBlockRequest)
        case .horizontalRule:
            post(bus.applyHorizontalRuleRequest)
        }
    }

    // / Apple HIG tooltip key per icon (= the wenshu canonical
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / that ships without the key.
    var tooltipKey: String {
        switch self {
        case .bold: "editor.format.bold.tooltip"
        case .italic: "editor.format.italic.tooltip"
        case .highlight: "editor.format.highlight.tooltip"
        case .strikethrough: "editor.format.strikethrough.tooltip"
        case .inlineCode: "editor.format.inlineCode.tooltip"
        case .heading: "editor.format.heading.tooltip"
        case .blockquote: "editor.format.blockquote.tooltip"
        case .unorderedList: "editor.format.unorderedList.tooltip"
        case .orderedList: "editor.format.orderedList.tooltip"
        case .link: "editor.format.link.tooltip"
        case .codeBlock: "editor.format.codeBlock.tooltip"
        case .horizontalRule: "editor.format.horizontalRule.tooltip"
        }
    }

    // / Per-icon SF Symbols point size (= the wenshu 1:1
    // … (= 52 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the same VISUAL width inside the 28 PT hot area.
    var iconPointSize: CGFloat {
        switch self {
        case .bold: 16
        case .italic: 16
        case .highlight: 12
        case .strikethrough: 16
        case .inlineCode: 14
        case .heading: 14
        case .blockquote: 16
        case .unorderedList: 18
        case .orderedList: 18
        case .link: 12
        case .codeBlock: 16
        case .horizontalRule: 14
        }
    }

    // / Chunked action list (= the 12 buttons grouped into 3
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / chunk lands in one place).
    static let chunked: [(Int, [EditorFormatAction])] = [
        (0, [.bold, .italic, .highlight, .strikethrough, .inlineCode]),
        (1, [.heading, .blockquote, .unorderedList, .orderedList]),
        (2, [.link, .codeBlock, .horizontalRule])
    ]
}

// / 28 PT Apple HIG document-format toolbar (= the canonical
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / editor zone's outer VStack (= does NOT scroll with the document).
struct EditorFormatToolbar: View {
    // / MarkdownEditorBus passed down from `MarkdownEditorBus.buildWenshu()`
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / selection-state events).
    let bus: MarkdownEditorBus
    // / RATIONALE: the 1 trailing icon
    // … (= 41 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / dropped with the button).
    let onClose: (() -> Void)?

    var body: some View {
        // RATIONALE: matches the `EditorStatusBarView` chunk
        // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // provided by `ChromeTopBar`).
        ChromeTopBar {
            HStack(spacing: DesignTokens.spacingStandard) {
                ForEach(EditorFormatAction.chunked, id: \.0) { chunkIndex, chunk in
                    HStack(spacing: DesignTokens.spacingCaption) {
                    ForEach(chunk) { action in
                        formatButton(for: action)
                    }
                }
                if chunkIndex < EditorFormatAction.chunked.count - 1 {
                    // RATIONALE: a vertical `Divider` (= the
                    // … (= 17 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // asked for a visible chunk separator).
                    Divider()
                }
            }
            // RATIONALE: the 2 trailing icons
            // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // `square.and.arrow.down`).
            Spacer()
            trailingIconGroup
        }
        }  // close ChromeTopBar
        // RATIONALE: the outer `ChromeTopBar`
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // wenshu canonical 28 PT button hot area).
        .frame(height: 28)
    }
        // RATIONALE: the chrome surface Material
        // … (= 238 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / fallback if a future locale ships without the key).
    @ViewBuilder
    private func formatButton(for action: EditorFormatAction) -> some View {
        Button {
            action.dispatch(bus: bus)
        } label: {
            SFIcon(
                action.iconName,
                style: .inlineSmall,
                color: IconColor.primary,
                pointSizeOverride: action.iconPointSize
            )
            .frame(
                width: DesignTokens.paneTabHotArea,
                height: DesignTokens.paneTabHotArea
            )
        }
        // RATIONALE 2026-10-13: the tooltip is keyed by
        // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // developer-facing hint for the xcstrings extractor).
        .help(NSLocalizedString(
            action.tooltipKey,
            bundle: .main,
            value: action.localizedLabel,
            comment: "Format toolbar button tooltip"
        ))
        .accessibilityLabel(action.localizedAccessibilityLabel)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                .fill(Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
        .hoverWash()
        .buttonStyle(.plain)
    }
}
// MARK: - Trailing toolbar icons
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// the 12 format buttons).
extension EditorFormatToolbar {
    // / RATIONALE 2026-10-13 OOB: the
    // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / redundant).
    private var trailingIconGroup: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            trailingCloseButton
        }
    }

    // / RATIONALE 2026-10-13: the close icon
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / behind).
    private var trailingCloseButton: some View {
        trailingToolbarButton(
            iconName: "xmark.circle",
            tooltipKey: "editor.format.close_tab.tooltip",
            defaultLabel: "Close"
        ) {
            onClose?()
        }
    }

    // / RATIONALE 2026-10-13: the shared
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the callback).
    @ViewBuilder
    private func trailingToolbarButton(
        iconName: String,
        tooltipKey: String,
        defaultLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SFIcon(
                iconName,
                style: .inlineSmall,
                color: IconColor.primary
            )
            .frame(
                width: DesignTokens.paneTabHotArea,
                height: DesignTokens.paneTabHotArea
            )
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                .fill(Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton))
        .hoverWash()
        .help(NSLocalizedString(
            tooltipKey,
            bundle: .main,
            value: defaultLabel,
            comment: "Trailing toolbar button tooltip"
        ))
    }
}
