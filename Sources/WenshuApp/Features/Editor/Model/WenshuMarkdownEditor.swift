// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// wenshu-side wrapper for swift-markdown-engine. Forwards link-click
// callbacks to the engine's NativeTextViewWrapper.
import SwiftUI
import AppKit
import MarkdownEngine

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let surface: EditorSurface
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
        var config = surface.configuration
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
    /// Apple HIG canonical editor body size). Sourced from
    /// `DesignTokens.bodyFontSize` (= single Apple HIG
    /// reference for body-text point size; = the chat zone's
    /// SwiftUI `.font(.body)` resolves to the same number, so
    /// the two zones render body text at byte-identical metrics).
    private var bodyBaseFontSize: CGFloat {
        DesignTokens.bodyFontSize
    }

    var body: some View {
        // Pass `isEditable` so the SAME NSTextView renders both
        // preview (= read-only) and edit (= editable) modes
        // (= zero visual scaling between modes; = Apple HIG
        // canonical for WYSIWYG surfaces).
        //
        // Forward the host-supplied `placeholder:` so the engine's own
        // scrolled container shows the start-writing ghost text while
        // the document is empty. The engine reserves its own scroll for
        // that slot; wenshu does NOT wrap the wrapper in any additional
        // `.padding(.all)` (= the previous `DesignTokens.zoneContentInset = 8`
        // wrap was what produced the "paper card" background under the
        // NSTextView = the visible white rectangle the user reports as
        // superfluous). Removing it lets the NSTextView sit flush against
        // the editor zone's own background (matches Pages / Numbers canvas
        // feel).
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
            documentId: surface.draftId,
            isEditable: surface.isEditable,
            onLinkClick: surface.onLinkClick,
            // T-03: forward caret-rect callback to the engine (= the
            // engine posts the live caret rect on every cursor move;
            // = the host writes it to `EditorTab.cursorRect` so the
            // status bar can read it back via `EditorView.cursorRect`).
            onCaretRectChange: surface.onCaretRectChange,
            placeholder: surface.placeholder,
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
