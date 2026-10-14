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
    /// T-03: caret-rect callback (= the engine posts the live caret
    /// rect on every cursor move via `onCaretRectChange`; = the
    /// host forwards it to `EditorTab.cursorRect` so the status
    /// bar can show the current line number).
    var onCaretRectChange: ((CGRect) -> Void)? = nil
    /// The engine's NativeTextView has an internal `baseFont` field
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
        // Apple HIG 1:1 editor font scale (= the canonical
        // macOS 27 typography table per
        // developer.apple.com/design/human-interface-guidelines/
        // typography). The engine's per-level heading
        // multipliers scale from the engine's base font
        // (= `NativeTextViewWrapper(fontSize:)` below = 13 PT
        // for `body`). Per Apple's text-style table:
        // - body     = 13 PT = canonical editor body
        // - title2   = 17 PT = H1 (one full step above body)
        // - title3   = 15 PT = H2 (half step above body)
        // - H3-H6    = 13 PT = flat with body (Apple's HIG
        //              standard markdown convention: only H1
        //              and H2 stand out from the body; =
        //              matches Pages / Numbers / Xcode source
        //              editor).
        //
        // Convert each Apple canonical size to a multiplier
        // of the body base font (= preserves the engine's
        // per-level scale semantics, = Apple canonical size
        // relationships).
        let base = NSFont.preferredFont(forTextStyle: .body).pointSize
        let h1 = NSFont.preferredFont(forTextStyle: .title2).pointSize
        let h2 = NSFont.preferredFont(forTextStyle: .title3).pointSize
        let m: (CGFloat) -> CGFloat = { base == 0 ? 1.0 : $0 / base }
        config.headings.fontMultipliers = [
            m(h1), m(h2), m(base), m(base), m(base), m(base),
        ]
        return config
    }

    /// Engine base font = `body` (= 13 PT on macOS 27 = the
    /// Apple HIG canonical editor body size). Passed to
    /// `NativeTextViewWrapper(fontSize:)` below (= the
    /// engine default is 16 PT which broke the multiplier
    /// math). The previous `caption1BaseFontSize` (= 10 PT)
    /// was 3 PT too small for editor body text (= the
    /// caption1 size is for non-essential metadata, = a
    /// marginal label or a tertiary annotation; = it is not
    /// the size for the main editor body of a writing tool).
    private var bodyBaseFontSize: CGFloat {
        NSFont.preferredFont(forTextStyle: .body).pointSize
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
            // Apple HIG `body` text style (= 13 PT on macOS 27).
            // Without this, `NativeTextViewWrapper` defaults to
            // 16 PT and the multiplier math produces H1 = 16 ×
            // (17/13) = 20.9 PT (= still visually dominant vs
            // sidebar/kanban `.headline` = 13 PT). With
            // `fontSize = 13` here, the engine base = 13 PT, the
            // multiplier H1 = 17/13 ≈ 1.308 gives H1 = 13 × 1.308
            // = 17 PT = matches Apple `.title2` = the canonical
            // H1 size.
            fontName: "SF Pro",
            fontSize: bodyBaseFontSize,
            documentId: draftId,
            isEditable: isEditable,
            onLinkClick: onLinkClick,
            // T-03: forward caret-rect callback to the engine (= the
            // engine posts the live caret rect on every cursor move;
            // = the host writes it to `EditorTab.cursorRect` so the
            // status bar can read it back via `EditorView.cursorRect`).
            onCaretRectChange: onCaretRectChange,
            placeholder: placeholder,
            header: header,
            // T-13: scroll-memory persistence (= the engine posts
            // (docId, offsetY) on every scroll via
            // `onPersistScrollOffset`; = the host writes the JSON
            // file via `EditorScrollMemory.persist`; =
            // `restoreScrollOffset` reads the JSON file so the host
            // app reopens at the last scroll position = the
            // canonical Apple HIG "remember what you were reading"
            // pattern = Pages / Numbers reopen at the last scroll).
            retainedScrollDocumentIds: EditorScrollMemory.retainedDocumentIds,
            onPersistScrollOffset: { documentId, offset in
                EditorScrollMemory.persist(offset, for: documentId)
            },
            restoreScrollOffset: { documentId in
                EditorScrollMemory.restore(for: documentId)
            }
        )
    }
}
