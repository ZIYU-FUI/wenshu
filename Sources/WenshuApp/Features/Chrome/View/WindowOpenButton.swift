//
//  WindowOpenButton.swift
//
//  The single canonical button format for opening an independent
//  macOS window from any toolbar (= the title bar / inspector / or
//  any other SwiftUI surface that wants the same 1-button shape).
//
//  Per boss 2026-10-16 OOB '像标题栏/工具栏一样，有没有把本该写
//  在一个文件里的内容，散落在各处 ... 如果涉及到格式的，写在一
//  个文件里才好控制格式': the 11 independent-window button
//  format (= SFIcon + label + help + openWindow action) was
//  duplicated 3x (= ChromeMainToolbar in the main window title bar
//  + InspectorView's secondary toolbar + WenshuAppDelegateSwiftData
//  Migration in the app startup bridge). This file consolidates
//  that shape into 1 reusable view = 1 source of truth for the
//  format = changing the icon style / label font / .help tooltip
//  pattern now happens in 1 place.
//
//  Why a single file (= and not a ViewModel / Store entry): the
//  button format is a pure visual concern (= the SFIcon + label
//  composition has no business logic; = the openWindow action is
//  bound at the call site). Per the §6.2 4-slot spec, this
//  belongs in View/ (= the only slot that fits a pure visual
//  subcomponent).
//

import SwiftUI

/// Reusable button for opening an independent macOS window.
///
/// Used by:
/// - `Features/Chrome/View/ChromeMainToolbar.swift` (= the main
///   window's title bar; = 11 window buttons at .primaryAction =
///   the canonical full set).
/// - `Features/Editor/View/InspectorView.swift` (the inspector's
///   own inspector-specific controls, NOT the 9 duplicate window
///   buttons that lived there pre-A96).
/// - `Sources/WenshuApp/App/WenshuAppDelegateSwiftDataMigration.swift`
///   (the app startup bridge for the libraryMigration window).
///
/// All call sites use the same `SFIcon + label + .help + openWindow`
/// shape via this view.
struct WindowOpenButton: View {
    /// The window's stable identifier (= used for openWindow(id:) and
    /// the `.help(...)` tooltip lookup). See `WindowID` in
    /// `AppRootScene.swift` for the canonical 11 IDs.
    let id: String
    /// The SF Symbols 6 icon for the button (= e.g. 'rectangle.split.3x1'
    /// for kanban, 'checklist' for todo, 'brain' for memoryHistory).
    let icon: String
    /// The button's label (= "看板" / "待办" / "记忆历史" etc.).
    /// Used as both the visible label AND the .help tooltip.
    let title: String
    /// The SF Symbols 6 style (= `.small` for the main title bar at
    /// .primaryAction; = `.inlineSmall` for the inspector at
    /// .principal; = `.paneTab` for the inspector toggle).
    let style: IconStyle
    /// The openWindow environment action (= injected at the call site
    /// so the button has access to the same scope as the owning view).
    let openWindow: OpenWindowAction
    /// Whether the button is enabled (= false for the 10 placeholder
    /// windows whose underlying feature has not landed).
    /// Defaults to `true` (= most windows have actual panels per
    /// boss 2026-10-16 OOB "不是未开发，是没开发完，之前是有面板的";
    /// = the MVP windows in Features/Canvas/ + Composer/ + Foreshadowing/
    /// + Cron/ + Attachments/ + Manifest/ + Summaries/ + LibraryMigration/
    /// all have a real window view that opens on tap).
    var isEnabled: Bool = true

    var body: some View {
        Button {
            openWindow(id: id)
        } label: {
            SFIcon(icon, style: style)
        }
        .help(title)
        .disabled(!isEnabled)
    }
}
