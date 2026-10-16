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
    /// The 11 independent-window buttons + the export button.
    /// Apple HIG canonical: `.primaryAction` placement for the
    /// rightmost toolbar slot (= matches the wenshu 1:1 macOS 27
    /// Liquid Glass default).
    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DesignTokens.spacingTight) {
                // 1. Memory history (= the only previously-wired
                // button). Active.
                WindowOpenButton(
                    id: WindowID.memoryHistory,
                    icon: "brain",
                    title: String(localized: "window.memoryHistory.title"),
                    openWindow: openWindow,
                    isEnabled: true
                )

                // 2-11. The 10 additional independent-window buttons.
                // All 11 windows have actual panels (= see
                // Features/<window-name>/View/<Window>.swift; = each
                // window was created with a real UI in A93). All
                // buttons are tappable.
                ForEach(WindowID.toolbarButtons, id: \.id) { button in
                    WindowOpenButton(
                        id: button.id,
                        icon: button.icon,
                        title: String(localized: String.LocalizationValue(button.title)),
                        openWindow: openWindow
                    )
                }
            }
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

extension WindowID {
    /// Metadata for the 11 independent-window toolbar buttons.
    /// Per boss 2026-10-16 OOB "不是未开发，是没开发完，之前是有面板的":
    /// all 11 windows have actual panels (= created in A93 = one
    /// Feature per window, each with a real window view; = see
    /// Features/Canvas/ + Composer/ + Foreshadowing/ + Cron/ +
    /// Attachments/ + Manifest/ + Summaries/ + LibraryMigration/).
    /// The "MVP" stage means the panel exists but its content is
    /// light (= a list / count / placeholder layout) = visible and
    /// tappable = enabled.
    struct ToolbarButton: Identifiable {
        let id: String
        let icon: String
        let title: String
    }

    /// The 10 additional independent-window buttons (=
    /// the 11 total minus the 1 memoryHistory button that has its own
    /// dedicated Button block above for documentation clarity).
    static let toolbarButtons: [ToolbarButton] = [
        ToolbarButton(id: WindowID.kanban, icon: "rectangle.split.3x1", title: "看板"),
        ToolbarButton(id: WindowID.todo, icon: "checklist", title: "待办"),
        ToolbarButton(id: WindowID.canvas, icon: "rectangle.on.rectangle.angled", title: "Canvas"),
        ToolbarButton(id: WindowID.composer, icon: "square.and.pencil", title: "Composer"),
        ToolbarButton(id: WindowID.foreshadowingGraph, icon: "point.3.connected.trianglepath.dotted", title: "Foreshadowing Graph"),
        ToolbarButton(id: WindowID.cron, icon: "clock.arrow.circlepath", title: "Cron"),
        ToolbarButton(id: WindowID.attachments, icon: "paperclip", title: "Attachments"),
        ToolbarButton(id: WindowID.manifest, icon: "list.bullet.rectangle", title: "Manifest"),
        ToolbarButton(id: WindowID.summaries, icon: "doc.text", title: "Summaries"),
        ToolbarButton(id: WindowID.libraryMigration, icon: "arrow.triangle.2.circlepath", title: "Library Migration")
    ]
}
