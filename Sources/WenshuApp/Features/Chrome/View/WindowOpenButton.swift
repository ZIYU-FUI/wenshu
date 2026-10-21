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
//  format (= Image(systemName:) + .help + openWindow action) was
//  duplicated 3x (= ChromeMainToolbar in the main window title bar
//  + the secondary toolbar + WenshuAppDelegateSwiftData
//  Migration in the app startup bridge). This file consolidates
//  that shape into 1 reusable view = 1 source of truth for the
//  format = changing the icon font weight / .help tooltip pattern
//  now happens in 1 place.
//
//  Per boss 2026-10-16 OOB 'SF 符号，apple 没有库引入吗，我怎么
//  感觉我们现在没有直接用，而是绕远了一下': this view uses the
//  Apple-canonical `Image(systemName:)` directly (= SwiftUI's
//  SF Symbols 6 built-in; = no import needed) instead of routing
//  through the project's `SFIcon` factory (= which is a design
//  system factory for **list / sidebar / table** icons that need
//  enforced size / weight / color / rendering mode consistency;
//  = overkill for a toolbar button where the icon style is
//  already pinned by the toolbar's ControlSize + Apple's
//  NSToolbar defaults). The toolbar's icon font size follows
//  the unified macOS toolbar's default 14 PT .regular (= matches
//  Apple HIG `NSToolbar > Default icon size`).
//
//  Why a single file (= and not a ViewModel / Store entry): the
//  button format is a pure visual concern (= the Image +
//  openWindow composition has no business logic; = the openWindow
//  action is bound at the call site). Per the §6.2 4-slot spec,
//  this belongs in View/ (= the only slot that fits a pure
//  visual subcomponent).
//

import SwiftUI

/// Reusable button for opening an independent macOS window.
///
/// Used by:
/// - `Features/Chrome/View/ChromeMainToolbar.swift` (= the main
///   window's title bar; = 11 window buttons at .primaryAction =
///   the canonical full set).
/// - the editor's secondary toolbar (the
///   own inspector-specific controls, NOT the 9 duplicate window
///   buttons that lived there pre-A96).
/// - `Sources/WenshuApp/App/WenshuAppDelegateSwiftDataMigration.swift`
///   (the app startup bridge for the libraryMigration window).
///
/// All call sites use the same `Image(systemName:) + .help +
/// openWindow` shape via this view.
struct WindowOpenButton: View {
    /// The window's stable identifier (= used for openWindow(id:) and
    /// the `.help(...)` tooltip lookup). See `WindowID` in
    /// `AppRootScene.swift` for the canonical 11 IDs.
    let id: String
    /// The SF Symbols 6 icon for the button (= e.g. 'rectangle.split.3x1'
    /// for kanban, 'checklist' for todo, 'brain' for memoryHistory).
    /// The string is passed directly to `Image(systemName:)` =
    /// SwiftUI's built-in SF Symbols 6 renderer; = no import,
    /// no custom wrapper, no library.
    let icon: String
    /// The button's label (= "看板" / "待办" / "记忆历史" etc.).
    /// Used as the .help tooltip (= the visible button is just
    /// an icon per Apple HIG toolbar conventions; = the title
    /// appears in the tooltip on hover).
    let title: String
    /// The openWindow environment action (= injected at the call site
    /// so the button has access to the same scope as the owning view).
    let openWindow: OpenWindowAction
    /// Whether the button is enabled (= defaults to `true`; = the
    /// 11 windows all have actual panels per boss 2026-10-16 OOB
    /// "不是未开发，是没开发完，之前是有面板的").
    var isEnabled: Bool = true

    var body: some View {
        Button {
            openWindow(id: id)
        } label: {
            // Apple-canonical SF Symbols 6 path. The toolbar's
            // NSToolbar default font size (14 PT, .regular) and
            // foregroundStyle (.secondary = matches Apple's
            // macOS 27 unified toolbar convention) are applied
            // here in 1 place (= 1 source of truth for the
            // toolbar button icon font + color per the v3.0
            // design system hard rule).
            Image(systemName: icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .help(title)
        .disabled(!isEnabled)
    }
}
