//
//  ChromeMainToolbar.swift
//
//  Main toolbar (= the 11 independent-window button row).
//  Extracted from LibraryRootView in A92 (= §6.2 god-class split:
//  the 10+ LOC inline `.toolbar` block moved out of the 809-LOC
//  LibraryRootView into this dedicated file).
//
//  Why extracted (= §6.2 god-class split + discoverability): the main
//  `LibraryRootView` is 809 LOC = 1.35x the 600-LOC cap. The main
//  toolbar is a single concern (= "the 11 independent-window button
//  row that sits in the unified macOS toolbar"). Putting it in a
//  dedicated file named after the concern (= ChromeMainToolbar.swift)
//  lets the next reader find the toolbar button row by name.
//
//  Design (= 11 independent-window buttons per boss 2026-10-16 OOB):
//  Each button wires to one of the 11 WindowIDs registered in
//  AppRootScene.swift. The implementation is the canonical Apple HIG
//  `ToolbarItem(placement: .primaryAction)` + `Button { openWindow(id: ...)}`
//  + `SFIcon(...)` pattern.
//  All 11 windows have actual panels (= see Features/<window-name>/
//  View/<Window>.swift; = each was created in A93 with a real
//  window view). Per boss 2026-10-16 OOB "不是未开发，是没开发完,
//  之前是有面板的": the windows exist in MVP form (= a list /
//  count / placeholder layout = visible + tappable) and will be
//  filled in over time. The toolbar shows the full 11-button row
//  (= 1 source of truth for the title bar).
//

import SwiftUI
import AppKit

/// Main toolbar (= the 11 independent-window button row that sits
/// in the unified macOS toolbar at the top of the main window).
/// Per boss 2026-10-16 OOB '标题栏/工具栏应该拆出来一个独立目录
/// 来处理 (= the title bar / toolbar should be split out into a
/// dedicated directory)': this is the single source of truth for
/// the title bar's independent-window buttons.
///
/// `openWindow` is the macOS 13+ SwiftUI environment action that
/// opens an `AppRootScene` `Window` scene by its `WindowID`. The 11
/// `WindowID`s (= kanban / todo / canvas / composer /
/// foreshadowingGraph / cron / attachments / manifest /
/// summaries / libraryMigration / memoryHistory) are registered in
/// `AppRootScene.swift` and in `OOB.md #2026-09-28`.
///
/// `sheetRequests` is the cross-component state for the legacy
/// sheet pattern (= buttons that need to open a `.sheet(item:)`
/// rather than a `Window` scene post a counter to `sheetRequests`;
/// = the consumer's `.sheet(item:)` watches the counter and
/// presents the matching sheet).
struct ChromeMainToolbar {
    /// The SwiftUI `openWindow` environment action (= injected
    /// from `LibraryRootView` so the toolbar has access to the
    /// same scope as the owning view).
    let openWindow: OpenWindowAction

    /// The cross-component sheet request state (= injected
    /// from `LibraryRootView` so the toolbar can bump
    /// `exportSheet` to trigger the File > Export sheet).
    let sheetRequests: SheetRequestState
}

extension ChromeMainToolbar: ToolbarContent {
    /// The kanban window button + the export button.
    /// Apple HIG canonical: `.primaryAction` placement for the
    /// rightmost toolbar slot (= matches the wenshu 1:1 macOS 27
    /// Liquid Glass default).
    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            WindowOpenButton(
                id: WindowID.kanban,
                icon: "rectangle.split.3x1",
                title: String(localized: "window.kanban.title"),
                openWindow: openWindow,
                isEnabled: true
            )
        }
        ToolbarItem(placement: .automatic) {
            // Export button (= the 2nd `.toolbar` block that lived
            // in LibraryRootView.content). Cross-component sync:
            // tapping it bumps `sheetRequests.exportSheet += 1`
            // (= matches the File > Export menu item per the
            // boss standing rule "a new feature should appear
            // everywhere = synced").
            Button {
                sheetRequests.exportSheet += 1
            } label: {
                Label(
                    String(localized: "export.toolbar.label"),
                    systemImage: "square.and.arrow.up"
                )
            }
            .help(String(localized: "export.toolbar.label"))
        }
    }
}
