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
    // Caller (= EditorView / EditorEditContent) passes
    // `isEditable: (mode == .edit)`. Preview = read-only NSTextView,
    // edit = editable NSTextView, same component, same font scale,
    // same line height, same textContainerInset, same NSTextLayoutManager.
    var isEditable: Bool = true

    // SMC `header:` slot (= a SwiftUI view hosted inside the engine's
    // scrolled container, sibling of the NSTextView). Lets the embedder
    // (= wenshu) sit the EditorHeaderView chrome band above the typing
    // surface. Default nil = no header (= the engine draws no chrome
    // and the NSTextView fills the full container height).
    var header: AnyView? = nil

    // SMC `placeholder:` slot (= first-line ghost text shown while the
    // document is empty; the first typed character hides it). Native
    // attribute-string surface (= supports tinted / styled placeholders
    // = the wenshu "在此处撰写章节内容..." line). Default nil = no
    // placeholder text.
    var placeholder: NSAttributedString? = nil
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
        // Pass `isEditable` so the SAME NSTextView renders both
        // preview (= read-only) and edit (= editable) modes
        // (= zero visual scaling between modes; = Apple HIG
        // canonical for WYSIWYG surfaces).
        //
        // Forward the host-supplied `header:` and `placeholder:` so the
        // engine's own scrolled container hosts the chrome band (= 28 PT
        // EditorHeaderView, see UI/Editor/EditorHeaderView.swift) and
        // shows the "在此处撰写章节内容..." placeholder when the document
        // is empty. The engine reserves its own scroll for these slots;
        // wenshu does NOT wrap the wrapper in any additional `.padding(.all)`
        // (= the previous `DesignTokens.zoneContentInset = 8` wrap was
        // what produced the "paper card" background under the NSTextView
        // = the visible white rectangle the user reports as superfluous).
        // Removing it lets the NSTextView sit flush against the editor
        // zone's own background (matches Pages / Numbers canvas feel).
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
            isEditable: isEditable,
            onLinkClick: onLinkClick,
            placeholder: placeholder,
            header: header
        )
    }
}
