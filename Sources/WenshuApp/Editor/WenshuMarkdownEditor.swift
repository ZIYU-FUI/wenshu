// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// v0.39 ticket 001 + SMC ticket 003 -- wenshu-side wrapper for
// swift-markdown-engine. SMC ticket 003 forwards onLinkClick.
import SwiftUI
import AppKit
import MarkdownEngine

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let draftId: String
    let configuration: MarkdownEditorConfiguration

    // SMC ticket 003 -- engine-side link-click callback forwarded
    // to the engine's NativeTextViewWrapper.
    var onLinkClick: ((String) -> Void)? = nil

    // v0.40 boss 9/7 OOB ', edit,
    // yes, ., editor,
    // yes, shouldgroup': preview mode and
    // edit mode should use the SAME component (= no separate
    // SwiftUI renderer). Previously preview used EditorPreviewContent
    // (= SwiftUI AttributedString renderer) and edit used
    // WenshuMarkdownEditor (= swift-markdown-engine NSTextView). Two
    // different renderers = different visual scaling (= the ""
    // boss described).
    //
    // Fix: both modes now use WenshuMarkdownEditor. The engine's
    // NativeTextViewWrapper has an `isEditable: Bool` parameter
    // (= "When false the editor renders read-only with no caret")
    // which toggles between edit + preview with the SAME NSTextView
    // (= zero visual scaling between modes; = Apple HIG canonical
    // for WYSIWYG / preview-vs-edit surfaces).
    //
    // Caller (= EditorPlaceholder / EditorEditContent) passes
    // `isEditable: (mode == .edit)`. Preview = read-only NSTextView,
    // edit = editable NSTextView, same component, same font scale,
    // same line height, same textContainerInset, same NSTextLayoutManager.
    var isEditable: Bool = true
    // v0.40 boss 9/7 OOB ', edit
    //, . ok apple api ':
    // the engine's NativeTextView has an internal `baseFont` field
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
        // v0.40 boss 9/7 OOB 'editor, cardtitle
        // ': align the editor's font scale to the card visual
        // density (= Apple HIG canonical reference card pattern
        // in PreviewPane.swift Card view).
        //
        // Card title   = SwiftUI .headline (= 13 PT on macOS 27)
        // Card summary = SwiftUI .caption  (= 10 PT on macOS 27
        //   = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        //   on macOS; = SwiftUI bridges .caption to .caption1 in NSFont)
        // (= boss 9/7 OOB screenshot: card with title
        // ~13 PT bold + summary ~10 PT regular).
        //
        // Strategy: use NSFont.preferredFont(forTextStyle: .caption1)
        // (= 10 PT = SwiftUI .caption on macOS) as the editor base
        // = matches card summary.
        // Heading multipliers then scale from this base via Apple
        // canonical NSFont.preferredFont(forTextStyle:):
        // - H1   = .headline     = 13 PT (= matches card title)
        // - H2   = .footnote     = 10 PT (= matches card summary)
        // - H3-H6= .footnote     = 10 PT (= flat with body)
        //
        // v0.40 boss 9/7 OOB ', edit,
        // ': both modes share this single
        // configuration (= unified component commit).
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

    /// EDITORFONT-002 (2026-09-07): engine base font = caption1
    /// (= 10 PT = SwiftUI `.caption` on macOS 27). Passed to
    /// `NativeTextViewWrapper(fontSize:)` below (= the engine
    /// default is 16 PT which broke the multiplier math).
    private var caption1BaseFontSize: CGFloat {
        NSFont.preferredFont(forTextStyle: .caption1).pointSize
    }

    var body: some View {
        // v0.40 boss 9/7 OOB 'edit, 18PT':
        // apply the same horizontal inset as preview mode (= 18 PT
        // each side = DesignTokens.chromePaddingLeading /
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
        // v0.40 boss 9/7 OOB 'editor, yes, should
        // group': pass `isEditable` (= boss param on
        // NativeTextViewWrapper) so the SAME NSTextView renders
        // both preview (= read-only) and edit (= editable) modes
        // (= zero visual scaling between modes; = Apple HIG
        // canonical for WYSIWYG surfaces).
        NativeTextViewWrapper(
            text: $text,
            configuration: adjustedConfiguration,
            // EDITORFONT-002 (2026-09-07): pass fontSize so the engine
            // base font matches the caption1 multiplier base (= 10 PT).
            // Without this, NativeTextViewWrapper defaults to 16 PT and
            // the multiplier math produces H1 = 16 × (13/10) = 20.8 PT
            // (= still visually dominant vs sidebar/kanban .headline
            // = 13 PT = the bug boss 9/7 saw). With fontSize=10 here,
            // engine base = 10 PT, multiplier H1 = 1.3 gives
            // H1 = 10 × 1.3 = 13 PT = matches Apple `.headline`.
            fontName: "SF Pro",
            fontSize: caption1BaseFontSize,
            documentId: draftId,
            isEditable: isEditable,
            onLinkClick: onLinkClick
        )
        // ZONE-INSET-002 round 2 (2026-09-07): ZoneContentView's
        // outer .padding(.all, zoneContentInset) was REMOVED in the
        // previous commit (= was doubled with Apple HIG built-in
        // insets in List / LazyVGrid zones = caused zone 1, 2, 4 to
        // look "too large"). The editor still needs an explicit inset
        // because WenshuMarkdownEditor wraps NativeTextViewWrapper
        // (= no Apple built-in content margins). Re-applied the
        // 18 PT all-sides inset here directly (= uses the same
        // canonical token DesignTokens.zoneContentInset = 18 PT
        // for consistency).
        //
        // History:
        //   - ab2b57021 (v0.40 apple-001 Q2): added .padding(.horizontal, 18)
        //   - f6655f2bc (EDITORTOP-001): added .padding(.top, 18)
        //   - 8a52378cc (ZONE-INSET-002): both removed (= absorbed
        //     into ZoneContentView's outer 18 PT)
        //   - this commit: re-added with .padding(.all, 18) (= the
        //     18-PT uniform value stayed the goal = the zone wrapper
        //     route was the wrong abstraction)
        .padding(.all, DesignTokens.zoneContentInset)
    }
}
