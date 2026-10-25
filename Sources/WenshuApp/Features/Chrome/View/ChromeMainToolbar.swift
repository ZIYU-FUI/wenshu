//
//  ChromeMainToolbar.swift
//
//  Main toolbar (= the window button row).
//  Extracted from LibraryRootView in A92 (= §6.2 god-class split:
//  the 10+ LOC inline `.toolbar` block moved out of the 809-LOC
//  LibraryRootView into this dedicated file).
//
//  Why extracted (= §6.2 god-class split + discoverability): the main
//  `LibraryRootView` is now 434 LOC = under the 600-LOC cap. The main
//  toolbar is a single concern (= "the button row that sits in the
//  unified macOS toolbar"). Putting it in a dedicated file named after
//  the concern (= ChromeMainToolbar.swift) lets the next reader find
//  the toolbar button row by name.
//
//  Design (per boss 2026-10-16 OOB):
//  The row carries the kanban window button and export. The window
//  button wires to a `WindowID` registered in AppRootScene.swift. The
//  implementation is the canonical Apple HIG
//  `ToolbarItem(placement: .primaryAction)` + `Button { openWindow(id: ...)}`
//  + `SFIcon(...)` pattern.
//  The other secondary windows were removed on 2026-10-21 (= the
//  top-window cleanup; = the kanban window and the export stayed, and
//  the library-migration window stays as the recovery path out of a
//  failed library upgrade, with no toolbar button). The toolbar is the
//  single source of truth for the title bar.
//

import SwiftUI
import AppKit

/// Main toolbar (= the button row that sits in the unified macOS
/// toolbar at the top of the main window).
/// Per boss 2026-10-16 OOB '标题栏/工具栏应该拆出来一个独立目录
/// 来处理 (= the title bar / toolbar should be split out into a
/// dedicated directory)': this is the single source of truth for
/// the title bar's buttons.
///
/// `openWindow` is the macOS 13+ SwiftUI environment action that
/// opens an `AppRootScene` `Window` scene by its `WindowID`. The
/// `WindowID`s (= kanban / libraryMigration) are registered in
/// `AppRootScene.swift`; the library-migration window has no toolbar
/// button (= it is opened by the migration pipeline itself, and it is
/// the way out of a failed upgrade).
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
