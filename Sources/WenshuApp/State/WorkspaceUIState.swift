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
/// sort order + layout edit mode + active tag filter + chat-zone
/// visibility + inspector page).
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
///
/// Phase 1b/1c note (= 2026-10-03 overabstraction cleanup):
/// chatVisible + inspectorPage were previously on `ShellState`
/// (= a separate 4-property @Observable class). Apple HIG
/// treats all 5 fields here as the same shape (= view-local UI
/// state shared across column descendants; = the Pages /
/// Numbers / Keynote pattern is to keep them in one
/// environment-injected class, not split across multiple
/// sibling classes). Single source of truth = easier to delete
/// `ShellState` (= the now-redundant 1-property shell
/// selection class that holds only `sidebarSelection`).
@MainActor
@Observable
final class WorkspaceUIState {

    /// Preview card-grid sort order (= shared across
    /// PreviewPane's cards / unwrap sort menu in the preview
    /// pane's tab bar trailing slot + WorkspaceView's
    /// previewScope). Default = .pinyinFirstLetter (= boss
    /// spec).
    ///
    /// Removed the 3 independent `@State` copies (= previously
    /// in ShellMiddleColumn + WorkspaceView + PreviewPane =
    /// drifted). Lives on WorkspaceUIState (= single source of
    /// truth; = batch 3 = WorkspaceUIState split from
    /// AppState).
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    /// Layout edit mode state (= `⌘⇧\` toggle / `Escape` exit).
    /// Hoisted to `appState.editMode` so all workspace
    /// descendants share one instance (= per-window via
    /// WenshuApp's `@State`). Hotkey binding lives in
    /// `EditModeHotkey.swift`.
    var editMode = LayoutEditMode()

    /// Active tag filter (= the user clicked a `.tag(String)`
    /// sidebar item; = the preview pane renders only references
    /// whose `tags` set contains this string). `nil` means
    /// "no tag filter" (= show all references).
    /// Lives on WorkspaceUIState (= the §11.13 P2-06 split
    /// pattern; = per-window via @State in WenshuApp).
    var activeTag: String?

    /// Chat zone visibility (= the bottom half of the detail
    /// column = an `NSSplitViewItem` inside
    /// `EditorChatNSController`). The macOS menu bar View >
    /// Show/Hide Chat Zone toggle (= `⌥⌘K`) writes here.
    ///
    /// When `chatVisible = true`, the chat zone NSSplitViewItem
    /// is visible (= editor + chat = 50/50 detail column).
    /// When `chatVisible = false`, the NSSplitViewItem
    /// `.isCollapsed` (= editor fills the full detail column;
    /// = matches Keynote's 'presenter notes' Show/Hide
    /// behavior).
    ///
    /// Co-varies with `inspectorPage` (= both are shell chrome
    /// toggled via macOS menu items; = both are cross-view
    /// column-local state; = single source of truth lives here).
    var chatVisible: Bool = true

    /// Inspector tab selection (= `Authoring / Style /
    /// Characters / Project Management` = 4 pages). When the
    /// inspector column is hidden (= `inspectorVisible` in
    /// NavigationSplitShell `@State`), this page is still
    /// remembered so reopening restores the last selection
    /// (= Apple Keynote/Pages inspector reopen behavior).
    ///
    /// Lives here (= not as `@State` inside `ShellDetailColumn`)
    /// because the toolbar Picker in ShellDetailColumn binds to
    /// `$workspaceUI.inspectorPage` (= cross-view state).
    var inspectorPage: InspectorPage = .authoringFiction

    init() {
        // In-memory only (= no UserDefaults read).
    }
}