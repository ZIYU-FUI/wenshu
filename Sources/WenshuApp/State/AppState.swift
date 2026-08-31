// Sources/WenshuApp/State/AppState.swift
//
// v0.30 boss 8/31 OOB '各区域之间的联动' (= adopted option A = global
// @Observable + @Environment injection). This file centralizes
// cross-zone UI state (= formerly scattered as @Binding across
// 4 view layers = WorkspaceView → PaneRenderer →
// TabContentDispatcher → ZoneModuleView → NewLibraryOutlineView,
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

    /// Reference library entity detail selection (= the entity card
    /// currently being viewed in single-card detail mode). Separate
    /// from `sidebarSelection` (= = the sidebar tree selection) so
    /// detail mode can render without changing which tree row is
    /// highlighted.
    var selectedEntity: Reference? = nil

    /// Reference library category (= which category the sidebar
    /// pointed at, = 资料库 → 文学 / 哲学 etc.). Drives the
    /// `referenceScope(.some)` branch of PreviewPane.
    var selectedEntityCategory: EntityCategory? = nil

    /// Preview pane sort order (= applies to both entity-scope and
    /// book-scope card flows). Default = pinyin first letter
    /// (= boss 8/30 OOB '所有卡片默认排序是拼音首字母先后顺序').
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    init() {}
}