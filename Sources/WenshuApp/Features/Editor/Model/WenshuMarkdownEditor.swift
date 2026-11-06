// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// wenshu-side wrapper for swift-markdown-engine. Forwards link-click
// callbacks to the engine's NativeTextViewWrapper.
import AppKit
import MarkdownEngine
import SwiftUI

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let surface: EditorSurface

    /// The library's books (= the sheet the editor renders with).
    @Environment(BookStore.self) private var bookStore

    /// The sheet the editor renders with.
    ///
    /// The sheet is the BOOK's (= keyed by book id), = and the editor
    /// renders the book the store is on (= `selectedBookId`, = the book
    /// whose directory the engine's services are given). = A book with
    /// no sheet reads the print baseline (= the model's own
    /// `effectiveStyleSheet`), = so the editor never invents a sheet of
    /// its own.
    private var styleSheet: BookStyleSheet {
        guard let bookID = bookStore.selectedBookId,
              let book = bookStore.books.first(where: { $0.id == bookID })
        else { return .default }
        return book.effectiveStyleSheet
    }

    /// The engine's configuration, with the SHEET's own values in it.
    ///
    /// The engine's per-level heading sizes are MULTIPLIERS of its base
    /// font (= `headings.fontMultipliers`), = and the sheet's ladder
    /// holds the printed ABSOLUTE sizes, = so each level is divided by
    /// the body's size (= `EngineStyleSheetBridge`). = The paragraph
    /// spacing is the sheet's own (= the line spacing as a factor, =
    /// the segment spacing as an extra height).
    ///
    /// Why not just set NSTextView.font: the engine's renderer reads
    /// its private `baseFont` (= not NSTextView.font) for markdown
    /// layout (= NSTextView.font would only affect text outside the
    /// engine's layout pipeline). = So the base font is set where the
    /// engine takes it (= `NativeTextViewWrapper`'s `fontName:` and
    /// `fontSize:`, = below).
    private var adjustedConfiguration: MarkdownEditorConfiguration {
        var config = surface.configuration
        config.headings.fontName = EngineStyleSheetBridge
            .headingFontName(for: styleSheet)
        config.headings.fontMultipliers = EngineStyleSheetBridge
            .headingMultipliers(for: styleSheet)
        config.paragraph = EngineStyleSheetBridge.paragraphStyle(for: styleSheet)
        config.blockquote = EngineStyleSheetBridge.blockquoteStyle(for: styleSheet)
        return config
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
        //
        // `.fitsContent` needs an enclosing scroll view, and this is where
        // it goes. The engine's own contract (its `HeightBehavior` docs):
        // in `.fitsContent` the editor reports `headerHeight + content
        // height` to SwiftUI and the ENCLOSING scroll view owns the
        // paging (= its `ClampedScrollView` disables its own vertical
        // scroller and forwards wheel events to the responder chain's
        // enclosing scroll view). Without one, the reported height is
        // the only height the editor column has: the hosting view's
        // `height >= <content>` demand reaches the NSSplitViewController's
        // item wrapper (= measured: the split grew from 984 PT to 1032 PT),
        // the split view's top edge rose above the window's top edge, and
        // the editor column's tab strip + format toolbar were drawn off
        // the top of the window (= the measured clip: the editor column's
        // first ink row sat at y=0.0 while every other column started at
        // y=67.5).
        //
        // The scroll view is added ONLY in `.fitsContent` (= one mode
        // needs it; = the other mode's engine owns its own scroll and must
        // NOT be nested inside a second one). The horizontal axis stays
        // off: the engine's own NSScrollView provides horizontal scroll
        // (= the v1 wrapper's `ScrollView([.horizontal, .vertical])` is
        // what produced the 30 PT sliver = the engine's NSTextContainer
        // measured against an unbounded width).
        //
        // This is not the v3 "text not rendered" regression. That one's
        // root cause was the engine's `centerReadingColumn(forClipWidth: 0)`
        // call at `makeNSView` time (= the engine's `readingWidth` was
        // pinned to 600 PT then). `readingWidth` is nil today (=
        // `WenshuEditorServicesFactory` pins it), so `centerReadingColumn`
        // never runs (= the engine's own guard: `if configuration.readingWidth
        // != nil`), and the engine tracks the parent's width instead.
        if surface.configuration.heightBehavior == .fitsContent {
            ScrollView(.vertical) {
                engine
            }
        } else {
            engine
        }
    }

    /// The engine's own view (= the `NSViewRepresentable` the
    /// `NativeTextViewWrapper` provides; = the single mount point for
    /// both the preview and the edit surface).
    private var engine: some View {
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
            fontName: EngineStyleSheetBridge.fontName(for: styleSheet),
            fontSize: EngineStyleSheetBridge.fontSize(for: styleSheet),
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
        .id(EngineStyleSheetBridge.fingerprint(for: styleSheet))
    }
}
