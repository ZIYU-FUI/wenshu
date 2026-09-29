//
//  WorkspaceUIState.swift · Wenshu
//
//  Per-window observable for the 2 column-local UI state fields
//  (= previewSortOrder + editMode) that survive shell lifecycle
//  changes (= different scope than shell chrome).
//
//  Why bundle previewSortOrder + editMode (= not 2 separate classes):
//  - Both are column-local UI state (= shared across WorkspaceView
//    descendants).
//  - Both reset together on shell collapse-expand (= co-vary).
//  - Both are read by WorkspaceView.body (= the same call sites;
//    = splitting creates 2 callers per split = more cost than
//    benefit).
//
//  Persistence: in-memory only (= column-local; = matches the
//  pre-existing AppState semantics for these fields; = resets
//  to default on relaunch per the boss's 'should disappear on
//  restart' expectation for column-local UI).
//
//  Environment injection: WorkspaceUIState is injected once at
//  the AppRootScene root (= same .environment(...) chain as
//  ShellState); = descendants read via
//  @Environment(WorkspaceUIState.self).
//
//  WorkspaceUIState is one of 4 new state classes added this arc
//  (= ShellState / WorkspaceUIState / SheetRequestState /
//  EditorCounters).
//

import Foundation

/// Per-window observable for column-local UI state (= preview
/// sort order + layout edit mode + active tag filter).
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(workspaceUI)` on
/// WiredShell. Descendants read it with
/// `@Environment(WorkspaceUIState.self) private var workspaceUI`.
///
/// All fields are in-memory only (= no UserDefaults
/// persistence); = column-local; = matches the boss's
/// 'should disappear on restart' expectation for ephemeral UI
/// state.
@MainActor
@Observable
final class WorkspaceUIState {

    /// Preview card-grid sort order (= shared across
    /// PreviewPane's cards + the sort menu in the preview pane's
    /// tab bar trailing slot + WorkspaceView's previewScope).
    /// Default = .pinyinFirstLetter (= boss spec).
    ///
    /// Removed the
    /// 3 independent `@State` copies (= previously in
    /// ShellMiddleColumn + WorkspaceView + PreviewPane = drifted).
    /// Lives on AppState (= single source of truth; = batch 3 =
    /// WorkspaceUIState split from AppState).
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    /// Layout edit mode state (= `⌘⇧\` toggle / `Escape` exit).
    /// Hoisted to `appState.editMode` so all workspace descendants
    /// share one instance (= per-window via WenshuApp's `@State`).
    /// Hotkey binding lives in `EditModeHotkey.swift`.
    var editMode = LayoutEditMode()

    /// Active tag filter (= the user clicked a `.tag(String)`
    /// sidebar item; = the preview pane renders only references
    /// whose `tags` set contains this string). `nil` means
    /// "no tag filter" (= show all references).
    /// Lives on WorkspaceUIState (= the §11.13 P2-06 split
    /// pattern; = per-window via @State in WenshuApp).
    var activeTag: String?

    init() {
        // In-memory only (= no UserDefaults read).
    }
}