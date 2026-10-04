// AppNotifications.swift · WenshuApp · v2.6
//
// Single source of truth for `Notification.Name` raw values. Unified
// on Apple's reverse-DNS naming convention (= "com.wenshu.X"; see
// developer.apple.com/documentation/foundation/nsnotificationname +
// Apple Notification Programming Topics).
//
// Grouped into 3 semantic enums (= backward-compat accessors exposed
// as `static let`s on `Notification.Name` so existing callers
// compile unchanged):
//   - `AppCommands`:    toolbar / menu-driven commands
//   - `AppStateEvents`: lifecycle events posted by core systems
//   - `LayoutEvents`:   layout / edit-mode state changes

import Foundation

// MARK: - AppCommands
//
// Toolbar / menu-driven commands. Posted from .commands { Button } and
// other AppKit menu item surfaces. Listened by views that don't share
// a direct @Environment / @Binding with the menu source.
enum AppCommands: String, CaseIterable {
    /// Toggle one of the 6 zones (= sidebar / preview / editor / tools /
    /// chat / dynamic). Object payload: TabKind.
    case toggleZone = "com.wenshu.toggleZone"

    /// Request to create a new book. Posted by the zone-header new-icon
    /// button (= AppleSidebarView bottom slot via AppleSidebarBottomNewButton). Consumed by
    /// AppleSidebarView body (= real view hierarchy; = .sheet(item:) renders the actual sheets).
    case newBookRequested = "com.wenshu.newBookRequested"

    /// Request to create a new shelf (= see newBookRequest).
    case newShelfRequested = "com.wenshu.newShelfRequested"

    /// Request to import a .md / .zip / .ws bundle via NSOpenPanel.
    case importRequested = "com.wenshu.importRequested"

    /// Request to present the NewChoiceSheet (= new project / new book /
    /// new shelf picker). Posted by zone-header buttons, consumed by
    /// AppleSidebarView body.
    case choiceRequested = "com.wenshu.choiceRequested"

    /// Request to export (= zip current .ws bundle).
    case exportRequested = "com.wenshu.exportRequested"
}

// MARK: - AppStateEvents
//
// Lifecycle events posted by core systems. Listened by views that need
// to react when state changes happen elsewhere.
enum AppStateEvents: String, CaseIterable {
    /// ProviderKeychain changed (= Settings save / delete a provider key).
    /// Posted after UserDefaults writes for wenshu.llm.provider /
    /// wenshu.llm.model. Listened by chat-zone LLM model picker etc.
    case providerKeychainChanged = "com.wenshu.providerKeychainChanged"

    /// Defocus chat input when user clicks outside (= so keyboard focus
    /// returns to the work area, not stuck in the chat input field).
    case defocusChatInput = "com.wenshu.defocusChatInput"

    /// RuntimeCWD override changed (= user picked a new override folder).
    /// Posted by RuntimeCWD.setCWD(_:) after the UserDefaults write.
    /// Listened by RuntimeCWDDisplayChip (= editor zone toolbar chip).
    case runtimeCWDDidChange = "com.wenshu.runtimeCWD.didChange"
}

// MARK: - LayoutEvents
//
// Layout / edit-mode state changes. Cross-instance signaling for layout
// intents that can't share @State directly (= ( menu vs windowed view vs
// nested view hierarchies).
enum LayoutEvents: String, CaseIterable {
    /// Reset layout to default (= NSWindow standard ⌘0-style). Posted by
    /// View menu "Reset Layout" entry. Listened by WorkspaceView +
    /// LayoutTreeStore.
    case resetLayout = "com.wenshu.resetLayout"

    /// Toggle layout edit mode (= View menu "Layout edit mode" entry,
    /// ⌘⇧\ hotkey). Listened by WorkspaceView's LayoutEditMode singleton.
    case toggleEditMode = "com.wenshu.toggleEditMode"

    /// Editor expand/shrink toggle (= editor top-bar right-side expand icon).
    /// Object payload: Bool (= true = expand, false = shrink). Posted by
    /// EditorExpandShrinkTrailingButton when @AppStorage("wenshu.editorMaximized")
    /// changes. Previously consumed by `PaneNSController` (= the
    /// wenshu-summary NSSplitView abstraction; = deleted after the
    /// Phase 1-6 NavigationSplitView replacement made it unreachable).
    /// The notification is still posted (= the @AppStorage key is still
    /// observed by EditorExpandShrinkTrailingButton) but is no longer
    /// consumed by any production subscriber.
    case editorMaximizedChanged = "com.wenshu.editorMaximizedChanged"
}

// MARK: - Backward-compat accessors
//
// Existing callers reference these notifications as `.wenshuXxx`
// (= the legacy `static let`s on `Notification.Name` defined here).
// To preserve all 17 call sites without renaming them, expose
// `static let`s on `Notification.Name` that map to the enum cases.
//
// New code SHOULD reference the enum case directly (= cleaner intent)
// but the legacy path remains functional.
extension Notification.Name {
    // AppCommands
    // (wenshuToggleZone / wenshuNewBookRequested / wenshuNewShelfRequested /
    //  wenshuChoiceRequested / wenshuExportRequested removed 2026-10 in
    //  q99-spec-p0-batch2 — verify-dead.py confirmed 0 external callers;
    //  = the corresponding AppCommands enum cases (= toggleZone /
    //  newBookRequested / newShelfRequested / choiceRequested /
    //  exportRequested) are the canonical notification surface now;
    //  = callers should reference `Notification.Name.<AppCommand>.rawValue`
    //  or the enum cases directly. The wenshuImportRequested +
    //  wenshuProviderKeychainChanged + wenshuDefocusChatInput entries
    //  below are still wired (= retained as the active legacy surface).
    //  See wenshu-pocock-workflow references/v3.0-design-system-rule.md
    //  + wenshu-dead-code-cleanup SKILL.md.)
    static let wenshuImportRequested = Notification.Name(AppCommands.importRequested.rawValue)

    // AppStateEvents
    static let wenshuProviderKeychainChanged = Notification.Name(AppStateEvents.providerKeychainChanged.rawValue)
    static let wenshuDefocusChatInput = Notification.Name(AppStateEvents.defocusChatInput.rawValue)

    /// Local symbol for `runtimeCWDDidChange` (no `wenshu` prefix to
    /// match the existing call sites in RuntimeCWDDisplayChip + tests).
    static let runtimeCWDDidChange = Notification.Name(AppStateEvents.runtimeCWDDidChange.rawValue)

    // LayoutEvents
    static let wenshuResetLayout = Notification.Name(LayoutEvents.resetLayout.rawValue)
    static let wenshuToggleEditMode = Notification.Name(LayoutEvents.toggleEditMode.rawValue)
    static let wenshuEditorMaximizedChanged = Notification.Name(LayoutEvents.editorMaximizedChanged.rawValue)
}

// MARK: - Convenience factory
//
// Prefer these factories (= enum-driven + discovery-friendly) in NEW code.
// Existing callers keep using .wenshuXxx until the migration window closes.
extension Notification {
    /// Build a Notification.Name for the given AppCommands case.
    static func name(_ command: AppCommands) -> Notification.Name {
        Notification.Name(command.rawValue)
    }

    /// Build a Notification.Name for the given AppStateEvents case.
    static func name(_ event: AppStateEvents) -> Notification.Name {
        Notification.Name(event.rawValue)
    }

    /// Build a Notification.Name for the given LayoutEvents case.
    static func name(_ event: LayoutEvents) -> Notification.Name {
        Notification.Name(event.rawValue)
    }
}
