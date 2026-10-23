// Sources/WenshuApp/Views/Workspace/EditorEditContent.swift
//
// The SwiftUI live-edit surface for the editor pane. Wraps
// `nodes-app/swift-markdown-engine` (TextKit 2) via
// `WenshuMarkdownEditor` (`NSViewRepresentable`). Forwards the
// engine-side wiki-link clicks back to the host.
//
// One view per file (Apple HIG). `EditorEditContent` has 1 `@Binding`
// (draft: `String`) + 4 `let` parameters (`originalBody`,
//  onWordCountChange, onDirtyChange, surface) + 1 computed
// property (isDirty). No @State / @Environment / @Observable =
// pure rendering surface.
//
//  This struct is intentionally minimal (= all persistence /
//  routing / auto-save Task management lives in the host
//  WorkspaceView, which passes the let callbacks as the seam).
//  Per v0.34 B-22 decision (= (see OOB.md #2026-09-02)), the host owns Task
//  internals; EditorEditContent is decoupled from Task.
//
//  Only call site = WorkspaceView's editor pane edit mode;
//  invoked as `EditorEditContent(draft:..., originalBody:...,
//  onWordCountChange:..., onDirtyChange:..., surface:...)`.
//  Extracting it does not change any caller signature.
//
//  ed-smc-defaults T-02 (= the placeholder wiring for edit mode):
//  the preview-mode site already forwarded `editorEmptyDocumentPlaceholder`
//  in T-01. We mirror it here so edit mode shows the same start-writing
//  ghost text (= the placeholder stays present across the mode switch;
//  = the canonical Pages / Numbers
//  document-chrome-survives-WYSIWYG-toggle pattern).
//

import SwiftUI
import MarkdownEngine

struct EditorEditContent: View {
    @Binding var draft: String
    let originalBody: String
    // word count callback (= char count → host writes to
    // AppState.editorWordCount, which chrome reads for the bottom-bar
    // left field). Decoupled from AppState so EditorEditContent
    // stays a pure rendering surface (= no @Environment coupling).
    let onWordCountChange: (Int) -> Void
    // dirty-state change callback. Host routes true (= user
    // started editing) to schedule the auto-save Task; false (= document
    // is saved or just got saved via Cmd+S) to cancel any pending Task.
    // Replaces B-21's onAutoSaveTrigger (= that triggered on every
    // keystroke, wasting memory creating a fresh Task per char; = the
    // 9/2 OOB flagged as inefficient). Decoupled from Task internals
    // (= EditorEditContent doesn't know about Task).
    let onDirtyChange: (Bool) -> Void
    let surface: EditorSurface

    /// Read-only dirty flag (= computed from the binding's current value).
    private var isDirty: Bool { draft != originalBody }

    var body: some View {
        // `nodes-app/swift-markdown-engine` (TextKit 2,
        // live markdown styling, wiki-link resolution, image embeds,
        // code-fence syntax highlight via transitive HighlighterSwift
        // bridge) replaces Apple SwiftUI TextEditor. The engine's
        // NativeTextViewWrapper provides the NSTextView-based edit
        // surface (= Apple-standard undo, find, accessibility, IME).
        // WenshuMarkdownEditor is a thin NSViewRepresentable wrapper
        // (= keeps EditorEditContent a pure rendering surface).
        //
        // Pass the host's `onLinkClick` through the
        // `WenshuMarkdownEditor` seam so wiki-link clicks in the live
        // editor surface reach the navigation flow.
        WenshuMarkdownEditor(
            text: $draft,
            surface: surface
        )
            // (= per-keystroke; = Foundation-only recompute). Host
            // (EditorView) routes the value into
            // AppState.editorWordCount for the chrome bottom-bar left
            // field. WordCounter.count's charactersNoSpaces matches
            // Obsidian's default Word count plugin behavior (= exclude
            // whitespace, line breaks, tabs).
            .onChange(of: draft) { _, newValue in
                onWordCountChange(WordCounter.count(newValue).charactersNoSpaces)
                // auto-save is NOT triggered on every
                // keystroke (= that wastes memory creating a fresh
                // Task per keystroke; = Obsidian-style debounce that
                // the user 9/2 flagged as inefficient). Instead,
                // auto-save runs once per dirty→clean transition
                // (= Apple HIG standard auto-save = save when the
                // document transitions from dirty to saved, not on
                // every keystroke). The handler is wired below in
                // .onChange(of: isDirty) → onDirtyChange().
            }
            // wire auto-save to dirty-state transitions,
            // NOT to every keystroke. When dirty becomes true
            // (= user starts editing), schedule a 3-second Task.
            // When dirty becomes false (= either Cmd+S saved the
            // document or the auto-save Task fired), cancel any
            // pending Task (= no more writes; = matches Apple HIG
            // TextEdit / Pages behavior).
            .onChange(of: isDirty) { _, newDirty in
                onDirtyChange(newDirty)
            }
    }
}
