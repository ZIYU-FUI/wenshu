//
//  EditorEditContent.swift · Wenshu · v0.40 apple-001 Q2 slice 8
//
//  Extracted from WorkspaceView.swift (formerly inline private
// struct at line 1820). Q2 boss split WorkspaceView. Slice 8
//  = the SwiftUI live-edit surface for the editor pane. Wraps
//  nodes-app/swift-markdown-engine (TextKit 2) via
//  WenshuMarkdownEditor (NSViewRepresentable). Forwards the
//  engine-side wiki-link clicks back to the host.
//
//  Apple HIG = one view per file. EditorEditContent has 1 @Binding
//  (draft: String) + 7 let parameters (originalBody, onSave,
//  onWordCountChange, onDirtyChange, configuration, draftId,
//  onLinkClick) + 1 computed property (isDirty). No @State /
//  @Environment / @Observable = pure rendering surface.
//
//  This struct is intentionally minimal (= all persistence /
//  routing / auto-save Task management lives in the host
//  WorkspaceView, which passes the 7 let callbacks as the seam).
//  Per v0.34 B-22 decision (= boss 9/2 OOB), the host owns Task
//  internals; EditorEditContent is decoupled from Task.
//
//  Only call site = WorkspaceView's editor pane edit mode;
//  invoked as `EditorEditContent(draft:..., originalBody:...,
//  onSave:..., onWordCountChange:..., onDirtyChange:...,
//  configuration:..., draftId:..., onLinkClick:...)`.
//  Extracting it does not change any caller signature.
//

import SwiftUI
import MarkdownEngine

struct EditorEditContent: View {
    @Binding var draft: String
    let originalBody: String
    let onSave: () -> Void
    // v0.34 B-18: word count callback (= char count → host writes to
    // AppState.editorWordCount, which chrome reads for the bottom-bar
    // left field). Decoupled from AppState so EditorEditContent
    // stays a pure rendering surface (= no @Environment coupling).
    let onWordCountChange: (Int) -> Void
    // v0.34 B-22: dirty-state change callback. Host routes true (= user
    // started editing) to schedule the auto-save Task; false (= document
    // is saved or just got saved via Cmd+S) to cancel any pending Task.
    // Replaces B-21's onAutoSaveTrigger (= that triggered on every
    // keystroke, wasting memory creating a fresh Task per char; = boss
    // 9/2 OOB flagged as inefficient). Decoupled from Task internals
    // (= EditorEditContent doesn't know about Task).
    let onDirtyChange: (Bool) -> Void
    // v0.39 ticket 001: pre-built markdown engine configuration. Host
    // (WorkspaceView) builds this once per active-tab switch via
    // WenshuEditorServicesFactory.make(referenceLibraryRoot:activeBookRoot:).
    // The configuration owns the 4 service protocols (= wenshu implements
    // 2: WikiLinkResolver + EmbeddedImageProvider; the engine's
    // HighlighterSwiftBridge is transitive via MarkdownEngineCodeBlocks;
    // LaTeX is not wired in 001).
    let configuration: MarkdownEditorConfiguration
    // v0.39 ticket 001: stable per-tab id, passed to engine as
    // `documentId` so undo history + pending replacements are scoped
    // to each editor instance (= prevents cross-tab state bleed).
    let draftId: String
    // SMC ticket 003: forwarded engine-side link-click callback.
    // The engine fires this when the user clicks a `[[Name]]`
    // token in the live editor surface.
    var onLinkClick: ((String) -> Void)? = nil

    /// Read-only dirty flag (= computed from the binding's current value).
    private var isDirty: Bool { draft != originalBody }

    var body: some View {
        // v0.39 ticket 001: nodes-app/swift-markdown-engine (TextKit 2,
        // live markdown styling, wiki-link resolution, image embeds,
        // code-fence syntax highlight via transitive HighlighterSwift
        // bridge) replaces Apple SwiftUI TextEditor. The engine's
        // NativeTextViewWrapper provides the NSTextView-based edit
        // surface (= Apple-standard undo, find, accessibility, IME).
        // WenshuMarkdownEditor is a thin NSViewRepresentable wrapper
        // (= keeps EditorEditContent a pure rendering surface).
        //
        // SMC ticket 003: pass the host's onLinkClick through the
        // WenshuMarkdownEditor seam so wiki-link clicks in the live
        // editor surface reach the navigation flow.
        WenshuMarkdownEditor(
            text: $draft,
            draftId: draftId,
            configuration: configuration,
            onLinkClick: onLinkClick,
            // v0.40 boss 9/7 OOB 'editor, yes,
            // shouldgroup': edit mode = editable NSTextView
            // (= same engine wrapper as preview, = no scaling
            // between modes).
            isEditable: true
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // v0.34 B-18: write live character count via host callback
            // (= per-keystroke; = Foundation-only recompute). Host
            // (EditorPlaceholder) routes the value into
            // AppState.editorWordCount for the chrome bottom-bar left
            // field. WordCounter.count's charactersNoSpaces matches
            // Obsidian's default Word count plugin behavior (= exclude
            // whitespace, line breaks, tabs).
            .onChange(of: draft) { _, newValue in
                onWordCountChange(WordCounter.count(newValue).charactersNoSpaces)
                // v0.34 B-22: auto-save is NOT triggered on every
                // keystroke (= that wastes memory creating a fresh
                // Task per keystroke; = Obsidian-style debounce that
                // the boss 9/2 flagged as inefficient). Instead,
                // auto-save runs once per dirty→clean transition
                // (= Apple HIG standard auto-save = save when the
                // document transitions from dirty to saved, not on
                // every keystroke). The handler is wired below in
                // .onChange(of: isDirty) → onDirtyChange().
            }
            // v0.34 B-22: wire auto-save to dirty-state transitions,
            // NOT to every keystroke. When dirty becomes true
            // (= user starts editing), schedule a 3-second Task.
            // When dirty becomes false (= either Cmd+S saved the
            // document or the auto-save Task fired), cancel any
            // pending Task (= no more writes; = matches Apple HIG
            // TextEdit / Pages behavior).
            .onChange(of: isDirty) { _, newDirty in
                onDirtyChange(newDirty)
            }
            // Dirty status surfaced to the host via the `onSave` closure
            // (= not strictly needed by the editor itself; the host reads
            // `draft` and `originalBody` to decide dirty highlighting
            // on the Save button at ticket 08). Kept here so future
            // status-bar additions (= line count, dirty indicator)
            // have a clear anchor.
    }
}
