// Sources/WenshuApp/State/AppState.swift
//
// v0.30 boss 8/31 OOB "option A for cross-zone communication"
// (= adopted = global @Observable + @Environment injection).
// This file centralizes cross-zone UI state (formerly scattered
// as @Binding across 4 view layers = WorkspaceView -> PaneRenderer
// -> TabContentDispatcher -> ZoneModuleView -> NewLibraryOutlineView,
// per commit d845fe9c9).
//
// Why a global @Observable (= per Apple Observation framework,
// Swift 5.9+):
// 1. Instant reactivity (= any descendant view that reads
//    `appState.sidebarSelection` auto-re-renders on change).
// 2. Single source of truth (= one place for cross-zone signals).
// 3. Zero plumbing (= no @Binding chain to thread through new
//    views).
// 4. Boss can debug = `print(appState.sidebarSelection)` directly
//    (= vs grep NotificationCenter post names across N files).
// 5. Apple-native (= no 3rd-party dep, AGENTS.md §11.1 stays
//    unchanged).
//
// Per-window ownership: each WindowGroup instance creates its own
// AppState via `@State private var appState = AppState()` (= per
// boss 8/27 OOB multi-window future-proofing).
//
// Adding a new cross-zone signal = add 1 var here, done. No init
// signature changes, no binding chain updates.

import SwiftUI

/// App-wide observable state for cross-zone UI communication.
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(appState)` on
/// WiredShell. Descendants read it with
/// `@Environment(AppState.self) private var appState`.
///
/// All cross-zone UI state (= sidebar selection, sort order, etc.)
/// lives here. Persistence is handled at the observer (= typically
/// WorkspaceView writes to `@AppStorage` via `.onChange`).
@MainActor
@Observable
final class AppState {

    /// Sidebar tree selection (= 5 cases: .book(UUID) / .folder / .shelf
    /// / .referenceCategory / .referenceLibraryRoot, nil = nothing
    /// selected). Drives preview pane scope (= see
    /// WorkspaceView.previewScope).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape, = set by WorkspaceView's `.onChange`).
    var sidebarSelection: SidebarItem? = nil

    // v0.34 B-18 (= boss 9/2 OOB '现在用的, 这个编辑器, 是否自带
    // 字数统计'): editor zone's live word count, owned globally so
    // both the chrome bottom-bar left field (= "字数: N" in
    // TabContentDispatcher.editor case) and any future editor-zone
    // status widgets share one source of truth. EditorPlaceholder
    // writes via .onChange(of: draft); chrome reads via @Environment.
    var editorWordCount: Int = 0

    init() {}
}