// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// wenshu-side wrapper for swift-markdown-engine. Forwards link-click
// callbacks to the engine's NativeTextViewWrapper.
import SwiftUI
import AppKit
import MarkdownEngine

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let draftId: String
    let configuration: MarkdownEditorConfiguration

    // Engine-side link-click callback forwarded to
    // NativeTextViewWrapper.
    var onLinkClick: ((String) -> Void)? = nil

    // Preview and edit modes share the same component (= no separate
    // SwiftUI renderer). Previously preview used EditorPreviewContent
    // (= SwiftUI AttributedString renderer) and edit used
    // WenshuMarkdownEditor (= swift-markdown-engine NSTextView). Two
    // different renderers meant different visual scaling.
    //
    // Both modes now use WenshuMarkdownEditor. The engine's
    // NativeTextViewWrapper has an `isEditable: Bool` parameter
    // which toggles between edit + preview with the SAME NSTextView
    // (= zero visual scaling between modes; = Apple HIG canonical
    // for WYSIWYG / preview-vs-edit surfaces).
    //
    // Caller (= EditorPlaceholder / EditorEditContent) passes
    // `isEditable: (mode == .edit)`. Preview = read-only NSTextView,
    // edit = editable NSTextView, same component, same font scale,
    // same line height, same textContainerInset, same NSTextLayoutManager.
    var isEditable: Bool = true
    // The engine's NativeTextView has an internal `baseFont` field
    // (= NSFont.systemFont(ofSize: NSFont.systemFontSize) by default,
    // = Apple canonical system default font size).
    // EditorPreviewContent (= preview mode) uses SwiftUI's Apple
    // canonical type-scale fonts: .title / .title2 / .title3 / .body
    // (= NSFont.systemFontSize scaled via Apple's standard type
    // scale). To make the edit mode visually match the preview
    // mode, derive the engine's heading multipliers from Apple
    // canonical NSFont.pointSize for each SwiftUI text style
    // (= no magic numbers; = compute multipliers from NSFont.
    // preferredFont(forTextStyle:) which is Apple AppKit API).
    //
    // Why not just set NSTextView.font: the engine's renderer reads
    // its private `baseFont` (= not NSTextView.font) for markdown
    // layout (= NSTextView.font would only affect text outside the
    // engine's layout pipeline).
    private var adjustedConfiguration: MarkdownEditorConfiguration {
        var config = configuration
        // Align the editor's font scale to the card visual density
        // (= Apple HIG canonical reference card pattern in
        // PreviewPane.swift Card view).
        //
        // Card title   = SwiftUI .headline (= 13 PT on macOS 27)
        // Card summary = SwiftUI .caption  (= 10 PT on macOS 27
        //   = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        //   on macOS; = SwiftUI bridges .caption to .caption1 in NSFont).
        //
        // Strategy: use NSFont.preferredFont(forTextStyle: .caption1)
        // (= 10 PT = SwiftUI .caption on macOS) as the editor base
        // = matches card summary.
        // Heading multipliers then scale from this base via Apple
        // canonical NSFont.preferredFont(forTextStyle:):
        // - H1   = .headline     = 13 PT (= matches card title)
        // - H2   = .footnote     = 10 PT (= matches card summary)
        // - H3-H6= .footnote     = 10 PT (= flat with body)
        let base = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        let h1 = NSFont.preferredFont(forTextStyle: .headline).pointSize
        let h2 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        let h3 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        let h4 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        let h5 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        let h6 = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        // Convert each Apple canonical size to a multiplier of the
        // body base font (= preserves the engine's per-level scale
        // semantics, = Apple canonical size relationships).
        let m: (CGFloat) -> CGFloat = { base == 0 ? 1.0 : $0 / base }
        config.headings.fontMultipliers = [
            m(h1), m(h2), m(h3), m(h4), m(h5), m(h6),
        ]
        return config
    }

    /// Engine base font = caption1 (= 10 PT = SwiftUI `.caption` on
    /// macOS 27). Passed to `NativeTextViewWrapper(fontSize:)` below
    /// (= the engine default is 16 PT which broke the multiplier math).
    private var caption1BaseFontSize: CGFloat {
        NSFont.preferredFont(forTextStyle: .caption1).pointSize
    }

    var body: some View {
        // Apply the same horizontal inset as preview mode (= 18 PT
        // each side = DesignTokens.spacingStandard /
        // chromePaddingTrailing = wenshu standard read-only text
        // inset per the sidebar / chrome spec). Edit mode
        // NativeTextView default textContainerInset is 0
        // horizontally, so the SwiftUI .padding(.horizontal) here
        // is the canonical way (= the engine wrapper inherits the
        // surrounding SwiftUI environment; = no need to reach into
        // the engine's private NSTextView).
        //
        // top/bottom = 0 (= matches preview mode; = matches
        // NSTextView tight top/bottom inset).
        //
        // Pass `isEditable` so the SAME NSTextView renders both
        // preview (= read-only) and edit (= editable) modes
        // (= zero visual scaling between modes; = Apple HIG
        // canonical for WYSIWYG surfaces).
        NativeTextViewWrapper(
            text: $text,
            configuration: adjustedConfiguration,
            // Pass fontSize so the engine base font matches the
            // caption1 multiplier base (= 10 PT). Without this,
            // NativeTextViewWrapper defaults to 16 PT and the
            // multiplier math produces H1 = 16 × (13/10) = 20.8 PT
            // (= still visually dominant vs sidebar/kanban .headline
            // = 13 PT). With fontSize=10 here, engine base = 10 PT,
            // multiplier H1 = 1.3 gives H1 = 10 × 1.3 = 13 PT =
            // matches Apple `.headline`.
            fontName: "SF Pro",
            fontSize: caption1BaseFontSize,
            documentId: draftId,
            isEditable: isEditable,            onLinkClick: onLinkClick
        )
        // ZoneContentView's outer .padding(.all, zoneContentInset)
        // was REMOVED in an earlier commit (= was doubled with Apple
        // HIG built-in insets in List / LazyVGrid zones = caused
        // zones to look "too large"). The editor still needs an
        // explicit inset because WenshuMarkdownEditor wraps
        // NativeTextViewWrapper (= no Apple built-in content margins).
        // Re-applied the 18 PT all-sides inset here directly (= uses
        // the same canonical token DesignTokens.zoneContentInset =
        // 18 PT for consistency).
        .padding(.all, DesignTokens.zoneContentInset)
    }
}
