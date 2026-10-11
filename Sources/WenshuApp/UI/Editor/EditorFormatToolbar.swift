// Sources/WenshuApp/UI/Editor/EditorFormatToolbar.swift
//
// Pages / Numbers / Keynote document-toolbar strip (= 12 small icon
// buttons keyed to the markdown engine's `MarkdownEditorBus`
// `applyXxxRequest` notifications). The toolbar posts via
// `FormatDispatcher(bus:)` (= a wenshu-side helper from
// Sources/WenshuApp/Editor/EditorActions.swift) and the SMC engine's
// own observer applies the change to the live NSTextView.
//
// Design constraints (= Apple HIG macOS document-toolbar idiom):
// - 28 PT fixed height (= matches EditorHeaderView so the two chrome
//   bands align vertically; = Safari tab-stop standard).
// - 8 PT horizontal padding (= matches `DesignTokens.spacingStandard`)
//   + 4 PT inter-button spacing (= `DesignTokens.spacingCaption`).
// - Icon size = `.inlineSmall` (= 14 PT per `SFIcon` factory).
// - No toggle / pressed-state logic (= the engine fires
//   `selectionBoldDidChange` etc. to drive toggle state in T-05;
//   = today the toolbar is a one-way request surface).
//
// Why this is pinned (= not inside the engine's `header:` slot):
// The engine reserves the `header:` slot for the SAME row as the
// NSTextView (= scrolls together with the document). Pinning the
// format toolbar here (= inside EditorView's outer VStack =
// ALWAYS visible regardless of scroll position) is the canonical
// Pages / Numbers / Xcode pattern: the toolbar never goes off-screen.
// Future tickets may move the toolbar into the engine's header slot
// if Apple HIG direction changes (= unlikely for the
// "formatting-affects-selection" toolbar which must stay visible
// while typing).
import SwiftUI
import MarkdownEngine

/// One button on the editor format toolbar. Each button is keyed to
/// exactly one `MarkdownEditorBus` request name (= the bus factory
/// in `MarkdownEditorBus.buildWenshu()` registers all 12 names).
/// Tapping the button = `FormatDispatcher(bus: bus).apply()` posts the
/// matching request; = the engine applies the change to the live
/// NSTextView with native undo support (= engine-internal).
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

    /// SF Symbol shown on the button (= the toolbar is icon-only =
    /// standard macOS document-toolbar idiom; = tooltip + a11y label
    /// carry the textual affordance).
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

    /// Localized tooltip (= "editor.format.bold.tooltip" etc.).
    /// We resolve the key once (= the catalog has the keys =
    /// `editor.format.<action>.tooltip`).
    var localizedLabel: String {
        String(localized: "editor.format.\(rawValue).tooltip")
    }

    /// Accessibility label (= used by VoiceOver; = the same
    /// localized key as the tooltip but with the `a11y` suffix so
    /// future punctuation tweaks don't conflict).
    var localizedAccessibilityLabel: String {
        String(localized: "editor.format.\(rawValue).a11y")
    }

    /// Bus notification name this action posts. `FormatDispatcher`
    /// (= `Sources/WenshuApp/Editor/EditorActions.swift`) currently
    /// only ships `applyBold` (= the canonical single-method
    /// dispatcher; the other 11 names are exercised via raw
    /// `NotificationCenter.default.post(name: bus.apply…Request…,
    /// object: nil)` until the delegate grows the symmetric methods in
    /// a future cleanup). We do that here so the toolbar source stays
    /// the single owner of the 12-button contract.
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
}

/// 28 PT Apple HIG document-format toolbar (= the canonical
/// Pages / Numbers / Keynote pinned toolbar shape). Hosted in the
/// editor zone's outer VStack (= does NOT scroll with the document).
struct EditorFormatToolbar: View {
    /// MarkdownEditorBus passed down from `MarkdownEditorBus.buildWenshu()`
    /// (= the engine's `MarkdownEditorServices.bus` slot, also wired
    /// to the same bus instance the engine observes internally for
    /// selection-state events).
    let bus: MarkdownEditorBus

    var body: some View {
        HStack(spacing: DesignTokens.spacingCaption) {
            // 12 buttons in the canonical Pages / Numbers order
            // (= most-used first: bold/italic/highlight/strike/code =
            // inline emphasis cluster, then heading/quote/list
            // = block cluster, then link/codeBlock/hr = insertion
            // cluster). Future tickets split these into sub-clusters
            // with separators (= T-03 finding-replace or T-09
            // spell-check toggle land here).
            ForEach(EditorFormatAction.allCases) { action in
                Button {
                    action.dispatch(bus: bus)
                } label: {
                    SFIcon(action.iconName, style: .inlineSmall, color: IconColor.primary)
                        .frame(
                            width: DesignTokens.tabCloseFrameSize,
                            height: DesignTokens.tabCloseFrameSize
                        )
                }
                .buttonStyle(.plain)
                .help(action.localizedLabel)
                .accessibilityLabel(action.localizedAccessibilityLabel)
            }
        }
        // 8 PT padding = matches the EditorHeaderView's horizontal
        // rhythm (= the two chrome bands line up vertically on the
        // editor zone's outer VStack).
        .padding(.horizontal, DesignTokens.spacingStandard)
        .frame(height: DesignTokens.paneTabHotArea)
        // Bottom hairline divider (= separates the format toolbar from
        // the NSTextView below; = the same Divider idiom Apple HIG
        // uses between toolbar rows).
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}