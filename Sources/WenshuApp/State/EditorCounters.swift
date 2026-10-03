//
//  EditorCounters.swift · Wenshu
//
//  Per-window observable for the editor zone's live counter
//  (= editorWordCount).
//
//  Why a dedicated @Observable (= not just an Int on AppState):
//  - EditorWordCount is owned by the editor zone (= lives there
//    to track live changes via .onChange(of: draft)).
//  - The chrome bottom-bar left field reads the same counter via
//    @Environment(= cross-zone read; = the dedicated @Observable
//    matches the cross-zone pattern).
//  - Future expansion: e.g. characterCount, reading-time can
//    follow the same pattern (= this class becomes the canonical
//    home for editor-zone counters).
//
//  Persistence: none. Counter resets to 0 on relaunch (= editor
//  zone is empty at launch; = the counter recomputes on first
//  document load).
//
//  Environment injection: EditorCounters is injected once at the
//  AppRootScene root (= same .environment(...) chain as ShellState
//  + WorkspaceUIState + SheetRequestState); = descendants read via
//  @Environment(EditorCounters.self).
//
//  EditorCounters is the last of 4 new state classes added this arc
//  (= ShellState / WorkspaceUIState / SheetRequestState /
//  EditorCounters).
//

import Foundation

/// Per-window observable for editor-zone live counters (= word
/// count of the active document).
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(editorCounters)` on
/// WiredShell. Descendants read it with
/// `@Environment(EditorCounters.self) private var editorCounters`.
///
/// In-memory only (= no UserDefaults persistence); = editor zone
/// is empty at launch; = the counter recomputes on first document
/// load.
@MainActor
@Observable
final class EditorCounters {

    // Editor zone's live word count, owned globally so
    // both the chrome bottom-bar left field (= ": N" in
    // TabContentDispatcher.editor case) and any future editor-zone
    // status widgets share one source of truth. EditorView
    // writes via .onChange(of: draft); chrome reads via @Environment.
    var wordCount: Int = 0

    init() {
        // In-memory only (= no UserDefaults read).
    }
}