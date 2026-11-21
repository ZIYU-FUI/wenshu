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
//  NSToolbar defaults). The icon font is the semantic body font
//  (the literal 14 PT this file once carried was superseded by the
//  ruling of (see OOB.md #2026-11-22)).
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
/// CURRENTLY ORPHANED. It has no production caller at this tip
/// (`git grep "WindowOpenButton("` hits only this declaration and
/// `ComponentIndex.md`): the eleven window buttons left the main
/// title bar on 2026-10-21, and the repo already records the fact
/// in `docs/agents/2026-10-30-trailing-column-and-the-mac-companion.md`
/// ("no production caller left") and the 2026-11-16 session close
/// (`verify-dead.py --ui-components` names this file as the single
/// repo-wide candidate). Its removal is a separate dead-code ticket
/// (tracked as row 20 of `docs/agents/2026-11-12-the-macos27-ui-defaults-todo-list.md`).
///
/// The format consolidation this view was created for (see OOB.md #2026-10-16)
/// is why the icon font and ink live in exactly one place here; the
/// toolbar-icon ruling of (see OOB.md #2026-11-22) moved that font from
/// a literal 14 PT to the semantic body font.
///
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
            // The icon rides the semantic body font so Dynamic Type
            // controls size AND weight (= craft audit T1 closed with
            // the ruling of (see OOB.md #2026-11-22), which supersedes
            // the literal 14 PT of the 2026-10-16 row; the .secondary
            // ink from that row stays).
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .help(title)
        .disabled(!isEnabled)
    }
}
