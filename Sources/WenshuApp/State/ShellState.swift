//
//  ShellState.swift · Wenshu
//
//  Per-window observable for the 4 shell-chrome fields
//  (= sidebarSelection + inspectorVisible + chatVisible +
//  inspectorPage) and their persistence helpers.
//  Why bundle these 4 (= not 4 separate classes):
//  - All are "shell chrome" (= sidebar + inspector + chat zone
//    + inspector page).
//  - They co-vary in Apple HIG (= NavigationSplitView's
//    columnVisibility + inspector(isPresented:) + inspectorPane
//    + inspectorColumnWidth).
//  - InspectorPage is structurally pinned to inspectorVisible
//    (= if inspector is hidden, page is irrelevant; = state-of-
//    shell).
//
//  Persistence:
//  - sidebarSelection → UserDefaults "wenshu.sidebarSelection"
//    (JSON via Codable).
//  - inspectorVisible / chatVisible / inspectorPage: in-memory
//    only (= column-local; = matches pre-existing AppState
//    semantics; = resets to default on relaunch).
//
//  Environment injection: ShellState is injected once at the
//  AppRootScene root (= same .environment(...) chain as
//  AppState); = descendants read via
//  @Environment(ShellState.self).
//
//  Mirrors the BookStore+SidebarInline pattern (= v0.72 P2-06
//  split; = see commit f37b578f9 for the precedent). Per-v0.85
//  P2-06 split (= the AppState half of the audit), ShellState
//  is one of 4 new state classes added this arc
//  (= ShellState / WorkspaceUIState / SheetRequestState /
//  EditorCounters).
//

import Foundation

/// Per-window observable for shell chrome (= sidebar selection +
/// inspector visibility + chat-zone visibility + inspector page).
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(shell)` on WiredShell.
/// Descendants read it with
/// `@Environment(ShellState.self) private var shell`.
///
/// All shell-chrome state lives here. Persistence is handled
/// internally (= didSet → UserDefaults write) for the 1 field
/// that survives relaunch.
@MainActor
@Observable
final class ShellState {

    /// Sidebar tree selection (= 5 cases: .book(UUID) / .folder /
    /// .shelf / .referenceCategory / .referenceLibraryRoot,
    /// nil = nothing selected). Drives Preview pane scope
    /// (= see WorkspaceView.previewScope).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape via Codable; = set by didSet = write back on
    /// every change; = read by ShellState.init() at launch).
    ///
    /// Persisted to `wenshu.sidebarSelection` UserDefaults key
    /// (= JSON shape via Codable; = set by didSet = write back on
    /// every change; = read by ShellState.init() at launch).
    /// The previous AppState comment here previously claimed
    /// 'Persisted to wenshu.sidebarSelection' but the actual
    /// write / read code was missing (= only `llmModel` and
    /// `openTabs` had real persistence in init + didSet;
    /// = `sidebarSelection` was an in-memory @Observable property
    /// that reset to `nil` on every launch). This property
    /// restores the documented behavior.
    var sidebarSelection: SidebarItem? = nil {
        didSet {
            // didSet is NOT called during init (= Swift property
            // wrapper semantics), so this does NOT trigger a
            // write back to UserDefaults on launch (= pure read-
            // side migration). Encoded as JSON via the existing
            // Codable conformance (= SidebarItem: Hashable,
            // Codable, declared in its own file
            // `SidebarItem.swift` post-v1.69c split).
            //
            // Duplicate-write guard (= same pattern as
            // `activeTabId.didSet` and `llmModel.didSet`) so a
            // burst of clicks (= N identical sets) only writes
            // once. UserDefaults.standard.set is in-memory fast
            // (= does not sync to disk synchronously per the Apple
            // HIG UserDefaults queue contract); = the guard still
            // helps avoid N redundant write calls during rapid
            // interaction (= e.g. keyboard nav spam).
            guard oldValue != sidebarSelection else { return }
            if let item = sidebarSelection,
               let data = try? JSONEncoder().encode(item) {
                UserDefaultsStore.shared.setData(data, forKey: .sidebarSelection)
            } else {
                UserDefaultsStore.shared.remove(.sidebarSelection)
            }
        }
    }

    /// UserDefaults key for sidebar selection persistence
    /// (= JSON). Moved from AppState.sidebarSelectionKey (= the
    /// pre-P2-06 location).
    static let sidebarSelectionKey = "wenshu.sidebarSelection"

    /// The user can drag the right-column divider to close the
    /// inspector, and clicking the right content toggle in the
    /// top-right toolbar reopens the inspector AND restores the
    /// previous content. This is the canonical Apple HIG behavior
    /// for `.inspector(isPresented:)` per Apple's WWDC23-10161
    /// documentation: 'Inspectors can collapse by default, but
    /// they aren't resizable by default. We can change it with
    /// .inspectorColumnWidth. We can also add a toolbar button
    /// to toggle the presented property.'
    ///
    /// The toolbar toggle button is the Keynote/Pages/Numbers
    /// pattern for the "presenter notes" / inspector reopen
    /// action; = per WWDC23.
    var inspectorVisible: Bool = true

    /// The chat zone (= the bottom half of the detail column =
    /// hosted by an `NSSplitViewItem` inside
    /// `EditorChatNSController`) has a Show/Hide toggle that lives
    /// in the macOS menu bar (= Apple HIG canonical pattern for
    /// View > Show/Hide {Pane Name} menu items; = NO toolbar
    /// button today).
    ///
    /// When `chatVisible = true`, the chat zone NSSplitViewItem is
    /// visible (= editor + chat zone = 50/50 detail column).
    /// When `chatVisible = false`, the NSSplitViewItem.isCollapsed
    /// = true (= the editor fills the full detail column;
    /// = matches Keynote's 'presenter notes' Show/Hide behavior).
    var chatVisible: Bool = true

    /// Lives here (= not as `@State private var` inside
    /// `ShellDetailColumn`) because it co-varies with
    /// `inspectorVisible` (= an inspector page is meaningless
    /// when the inspector is hidden).
    ///
    /// NOT persisted to UserDefaults (= column-local state is
    /// ephemeral; = matches the boss's 'should disappear on
    /// restart' expectation).
    var inspectorPage: InspectorPage = .authoringFiction

    init() {
        // Restore the sidebar selection from UserDefaults
        // (= JSON-encoded via Codable; = same pattern as openTabs).
        // Without this read, the sidebar selection resets to nil
        // on every launch.
        //
        // Assignment via `self.sidebarSelection = ...` does NOT
        // trigger the didSet write-back (= Swift property
        // wrapper semantics; = didSet is suppressed during init).
        // So this read is purely load-side (= no UserDefaults
        // write during launch = no extra disk churn).
        if let data = UserDefaults.standard.data(forKey: Self.sidebarSelectionKey),
           let decoded = try? JSONDecoder().decode(SidebarItem.self, from: data) {
            self.sidebarSelection = decoded
        }
    }
}