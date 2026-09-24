//
//  SheetRequestState.swift · Wenshu · P2-06 (audit 2026-09-24)
//
//  P2-06 (audit 2026-09-24): extracted from `AppState.swift`.
//  AppState was 644 LOC; this new class absorbs the 3 sheet-request
//  trigger counters (= newBook / newShelf / choice). Net effect:
//  AppState drops further in the rest of the P2-06 arc.
//
//  Why bundle these 3 counters (= not 3 separate classes):
//  - All 3 follow the same fire-and-forget counter pattern
//    (= bump the int = sidebar body observes via .onChange and
//    flips its local @State showXSheet).
//  - All 3 are mutated by toolbar Menu / sidebar buttons → read
//    by AppRootScene / AppleSidebarView. Same callers.
//  - All 3 reset to 0 implicitly (no boundary; = survives relaunch
//    at default 0 because no counter is ever persisted).
//
//  Why a dedicated @Observable (= not just 3 Ints on AppState):
//  - Sheet-request is a cross-zone concern (toolbar Menu in
//    AppRootScene triggers a sheet in the sidebar body; = not
//    a single-view concern).
//  - Future expansion: e.g. import-request, sync-request can
//    follow the same pattern (= this class becomes the canonical
//    home for fire-and-forget cross-zone UI triggers).
//
//  Persistence: none. Counters reset to 0 on relaunch (= fire-
//  and-forget trigger; = no user state).
//
//  Environment injection: SheetRequestState is injected once at
//  the AppRootScene root (= same .environment(...) chain as
//  ShellState + WorkspaceUIState); = descendants read via
//  @Environment(SheetRequestState.self).
//
//  Per-v0.85 P2-06 split (= the AppState half of the audit),
//  SheetRequestState is one of 4 new state classes added this arc
//  (= ShellState / WorkspaceUIState / SheetRequestState /
//  EditorCounters).
//

import Foundation

/// Per-window observable for sheet-request trigger counters
/// (= newBook / newShelf / choice).
///
/// Owned by `WenshuApp` (= the App struct, = per-window via
/// `@State`), injected via `.environment(sheetRequests)` on
/// WiredShell. Descendants read it with
/// `@Environment(SheetRequestState.self) private var sheetRequests`.
///
/// All 3 counters are in-memory only (= no UserDefaults
/// persistence); = fire-and-forget triggers; = reset to 0 on
/// relaunch by default.
@MainActor
@Observable
final class SheetRequestState {

    // v1.0.0-m1-shell boss 2026-09-10 OOB 'the sidebar tree syntax does not match
    // Apple API': 3 sheet-request triggers moved from
    // NotificationCenter (.wenshuNewBookRequested /
    // .wenshuNewShelfRequested / .wenshuChoiceRequested) into
    // @Observable shared state. The toolbar Menu in AppRootScene
    // (.keyboardShortcut("n", modifiers: .command)) and the
    // sidebar's own New buttons (zoneHeaderButtons +
    // sidebarBottomNewButton) all need to flip the same `showNewX
    // Sheet` @State on the sidebar body. Cross-component writes
    // belong in shared @Observable state, not in a Notification
    // channel (= NotificationCenter is fire-and-forget, no observed
    // binding, requires manual @State copy on receiver side, =
    // fragile data flow). The pattern: the toolbar Menu or
    // sidebar button mutates sheetRequests.newBook += 1;
    // the sidebar body observes via .onChange(of: sheetRequests.
    // newBook) and flips its local showNewBookSheet.
    // Same approach for newShelf + choice.
    var newBook: Int = 0
    var newShelf: Int = 0
    var choice: Int = 0

    init() {
        // In-memory only (= no UserDefaults read).
    }
}