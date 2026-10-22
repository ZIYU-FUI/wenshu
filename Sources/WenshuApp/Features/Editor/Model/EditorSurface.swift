import SwiftUI
import MarkdownEngine

// EditorSurface.swift · Wenshu
//
// The markdown editor's surface: everything the engine needs to render
// one document, independent of whether the document is editable.
//
// The editor pane builds this surface ONCE and hands it to both modes.
// Before this type existed, preview mode and edit mode each spelled out
// the same eight arguments at their own call site, and the engine
// configuration was built twice (= once per mode) for two surfaces that
// differ by two flags.
//
// A value, not a view: the surface is data the engine consumes, and
// both modes consume the same data with a different `isEditable`.
struct EditorSurface {
    /// Stable per-tab id, passed to the engine as its document id
    /// (= scoped to this tab).
    let draftId: String

    /// Pre-built markdown engine configuration (= the 4 service
    /// protocols the engine owns).
    ///
    /// The host (= EditorView) builds this once per active-tab switch
    /// via `WenshuEditorServicesFactory.make(bookStore:bus:)`. The
    /// configuration owns the 4 service protocols (= wenshu implements
    /// 2: WikiLinkResolver + EmbeddedImageProvider; the engine's
    /// HighlighterSwiftBridge is transitive via MarkdownEngineCodeBlocks;
    /// LaTeX is rendered by SwiftMathBridge (see OOB.md #2026-10-11)).
    let configuration: MarkdownEditorConfiguration

    /// Forwarded engine-side link-click callback (= forwarded to
    /// NativeTextViewWrapper).
    ///
    /// The engine fires this when the user clicks a `[[Name]]` token in
    /// the live editor surface.
    let onLinkClick: ((String) -> Void)?

    /// The engine's own scrolled-container chrome slot (= a SwiftUI
    /// view hosted inside the engine, sibling of the NSTextView).
    ///
    /// Lets the embedder (= wenshu) sit the EditorHeaderView chrome
    /// band above the typing surface. Default nil = no header (= the
    /// engine draws no chrome and the NSTextView fills the full
    /// container height).
    ///
    /// The host (= EditorView) supplies this once per active-tab switch
    /// (= the header is decoupled from draft text edits), so the chrome
    /// band (= EditorHeaderView) sits above the typing surface without
    /// ever scrolling away. nil = engine draws no chrome.
    let header: AnyView?

    /// The engine's first-line ghost-text slot.
    ///
    /// First-line ghost text shown while the document is empty; the
    /// first typed character hides it. Native attribute-string surface
    /// (= supports tinted / styled placeholders = the wenshu
    /// start-writing placeholder line). Default nil = no placeholder
    /// text.
    let placeholder: NSAttributedString?

    /// The engine posts the live caret rect on every cursor move.
    ///
    /// The host forwards it to `EditorTab.cursorRect` so the status bar
    /// can show the current line number (= the status bar reads it back
    /// via `EditorView.cursorRect`).
    var onCaretRectChange: ((CGRect) -> Void)?

    /// Whether the surface accepts typing.
    ///
    /// Preview and edit modes share the same component (= no separate
    /// SwiftUI renderer). Previously preview used EditorPreviewContent
    /// (= SwiftUI AttributedString renderer) and edit used
    /// WenshuMarkdownEditor (= swift-markdown-engine NSTextView). Two
    /// different renderers meant different visual scaling.
    ///
    /// Both modes now use WenshuMarkdownEditor. The engine's
    /// NativeTextViewWrapper has an `isEditable: Bool` parameter which
    /// toggles between edit + preview with the SAME NSTextView (= zero
    /// visual scaling between modes; = Apple HIG canonical for WYSIWYG
    /// / preview-vs-edit surfaces).
    ///
    /// chapter-focus-lock 2026-09-28: the caller (= EditorView)
    /// computes this from AppState.focusedChapterPath vs the tab's
    /// documentPath. When the LLM holds the cursor for this chapter
    /// path (= the user has the editor focused); = the editor flips to
    /// read-only so the user can't type. Pure rendering surface (= no
    /// AppState coupling) is preserved by keeping the predicate
    /// decision at the caller boundary.
    var isEditable: Bool
}
