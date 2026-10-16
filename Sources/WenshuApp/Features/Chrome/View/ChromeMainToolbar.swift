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
//  + `SFIcon(...)` pattern (= the same shape as the prior
//  memoryHistory button that was the only one wired before A92).
//  Buttons for windows without a usable surface today use a
//  SFIcon + `.disabled` (= boss "大部分没开发完" = "most not yet
//  developed"; = the button is registered + visible so the user
//  sees the feature exists, but the action is disabled until the
//  feature lands).
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
                Button {
                    openWindow(id: WindowID.memoryHistory)
                } label: {
                    SFIcon("brain", style: .small, color: .accent)
                }
                .help(String(localized: "window.memoryHistory.title"))

                // 2-11. The 10 other independent-window buttons
                // (= boss 2026-10-16 OOB '大部分现在没有开发完').
                // Each is registered (= visible in toolbar) but
                // disabled until the underlying feature lands.
                // The placeholders establish the toolbar layout
                // (= 11 buttons at .primaryAction placement) so
                // the user sees the full feature surface.
                ForEach(WindowID.placeholderButtons, id: \.id) { button in
                    Button {
                        openWindow(id: button.id)
                    } label: {
                        SFIcon(button.icon, style: .small)
                    }
                    .help(button.title)
                    .disabled(!button.isEnabled)
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
    /// Metadata for the 10 placeholder toolbar buttons (= boss
    /// 2026-10-16 OOB: 大部分现在没有开发完 = "most not yet
    /// developed"). Each entry is `enabled: false` until the
    /// underlying feature lands (= see feature roadmap).
    struct PlaceholderButton: Identifiable {
        let id: String
        let icon: String
        let title: String
        let isEnabled: Bool
    }

    /// The 10 placeholder buttons (= one per unregistered feature
    /// window). The memoryHistory button above is the only one
    /// that's enabled (= the prior 1 wired button).
    static let placeholderButtons: [PlaceholderButton] = [
        PlaceholderButton(id: WindowID.kanban, icon: "rectangle.split.3x1", title: "看板", isEnabled: true),
        PlaceholderButton(id: WindowID.todo, icon: "checklist", title: "待办", isEnabled: true),
        PlaceholderButton(id: WindowID.canvas, icon: "rectangle.on.rectangle.angled", title: "Canvas", isEnabled: false),
        PlaceholderButton(id: WindowID.composer, icon: "square.and.pencil", title: "Composer", isEnabled: false),
        PlaceholderButton(id: WindowID.foreshadowingGraph, icon: "point.3.connected.trianglepath.dotted", title: "Foreshadowing Graph", isEnabled: false),
        PlaceholderButton(id: WindowID.cron, icon: "clock.arrow.circlepath", title: "Cron", isEnabled: false),
        PlaceholderButton(id: WindowID.attachments, icon: "paperclip", title: "Attachments", isEnabled: false),
        PlaceholderButton(id: WindowID.manifest, icon: "list.bullet.rectangle", title: "Manifest", isEnabled: false),
        PlaceholderButton(id: WindowID.summaries, icon: "doc.text", title: "Summaries", isEnabled: false),
        PlaceholderButton(id: WindowID.libraryMigration, icon: "arrow.triangle.2.circlepath", title: "Library Migration", isEnabled: false)
    ]
}
