// AppNotifications.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB (B-04 backlog entry): Notification.Name
// naming convention scattered (= 6 wenshu.X + 5 com.wenshu.X across
// 2 extension blocks in App.swift). Moved to this single source of
// truth + unified to Apple's reverse-DNS naming convention (=
// "com.wenshu.X" for Notification.Name raw values per
// developer.apple.com/documentation/foundation/nsnotificationname
// + Apple Notification Programming Topics).
//
// Grouped into 3 semantic enums (= backward-compat accessors exposed
// as static lets on each enum case so existing callers compile
// unchanged):
//   - AppCommands:    toolbar / menu-driven commands (= actions from user)
//   - AppStateEvents: lifecycle events posted by core systems
//                     (= chat store ready, provider keychain change)
//   - LayoutEvents:   layout / edit-mode state changes
//
// Single file location for ALL Notification.Name values makes the
// surface area discoverable (= `grep AppNotifications.swift Sources/`
// enumerates the complete cross-instance signaling contract in one shot).

import Foundation

// MARK: - AppCommands
//
// Toolbar / menu-driven commands. Posted from .commands { Button } and
// other AppKit menu item surfaces. Listened by views that don't share
// a direct @Environment / @Binding with the menu source.
//
// Boss 2026-08-19 OOB §Commands: 老板 rejected @FocusedValue as a
// substitute for these specific notifications (= .commands Button -> View
// is the reverse direction from @FocusedValue's View -> commands
// capability; v0.34 commit 85f87a68f Apple-API-first #6 documented this).
enum AppCommands: String, CaseIterable {
    /// Toggle one of the 6 zones (= sidebar / preview / editor / tools /
    /// chat / dynamic). Object payload: ZoneSlot.
    case toggleZone = "com.wenshu.toggleZone"

    /// Request to create a new book. Posted by the zone-header new-icon
    /// button (= NewLibraryOutlineView trailing slot). Consumed by
    /// NewLibraryOutlineView body (= real view hierarchy).
    case newBookRequested = "com.wenshu.newBookRequested"

    /// Request to create a new shelf (= see newBookRequest).
    case newShelfRequested = "com.wenshu.newShelfRequested"

    /// Request to import a .md / .zip / .ws bundle via NSOpenPanel.
    case importRequested = "com.wenshu.importRequested"

    /// Request to present the NewChoiceSheet (= new project / new book /
    /// new shelf picker). Posted by zone-header buttons, consumed by
    /// NewLibraryOutlineView body. v0.30 boss 8/31 OOB #2 '弹出菜单没有恢复'
    /// tracks this notification's lifecycle.
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

    /// ChatSessionStore is ready (= post applicationDidFinishLaunching).
    /// Posted once after ChatSessionStore creation. ChatView listens and
    /// reloads history when received (= retry load on cold-launch race
    /// with the store init).
    case chatStoreReady = "com.wenshu.chatStoreReady"

    /// Defocus chat input when user clicks outside (= so keyboard focus
    /// returns to the work area, not stuck in the chat input field).
    case defocusChatInput = "com.wenshu.defocusChatInput"
}

// MARK: - LayoutEvents
//
// Layout / edit-mode state changes. Cross-instance signaling for layout
// intents that can't share @State directly (= ( menu vs windowed view vs
// nested view hierarchies).
enum LayoutEvents: String, CaseIterable {
    /// Reset layout to default (= NSWindow standard ⌘0-style). Posted by
    /// View menu "Reset Layout" entry. Listened by WorkspaceView +
    /// WorkspaceStore.
    case resetLayout = "com.wenshu.resetLayout"

    /// Toggle layout edit mode (= View menu "Layout edit mode" entry,
    /// ⌘⇧\ hotkey). Listened by WorkspaceView's LayoutEditMode singleton.
    /// v0.28 ticket 028-006.
    case toggleEditMode = "com.wenshu.toggleEditMode"
}

// MARK: - Backward-compat accessors
//
// Existing callers reference these notifications as
// `.wenshuToggleZone` (= the legacy static lets on Notification.Name
// defined in App.swift L40-69). To preserve all 17 call sites without
// renaming them, expose static accessors on each enum case that map
// to the legacy `Notification.Name.wenshuXxx` keys.
//
// New code SHOULD reference the enum case directly (= cleaner intent)
// but the legacy path remains functional for the migration window.
// Future PR (= v0.35+): rename callers to use the enum cases, then
// delete these static accessors.
extension Notification.Name {
    // AppCommands
    static let wenshuToggleZone = Notification.Name(AppCommands.toggleZone.rawValue)
    static let wenshuNewBookRequested = Notification.Name(AppCommands.newBookRequested.rawValue)
    static let wenshuNewShelfRequested = Notification.Name(AppCommands.newShelfRequested.rawValue)
    static let wenshuImportRequested = Notification.Name(AppCommands.importRequested.rawValue)
    static let wenshuChoiceRequested = Notification.Name(AppCommands.choiceRequested.rawValue)
    static let wenshuExportRequested = Notification.Name(AppCommands.exportRequested.rawValue)

    // AppStateEvents
    static let wenshuProviderKeychainChanged = Notification.Name(AppStateEvents.providerKeychainChanged.rawValue)
    static let wenshuChatStoreReady = Notification.Name(AppStateEvents.chatStoreReady.rawValue)
    static let wenshuDefocusChatInput = Notification.Name(AppStateEvents.defocusChatInput.rawValue)

    // LayoutEvents
    static let wenshuResetLayout = Notification.Name(LayoutEvents.resetLayout.rawValue)
    static let wenshuToggleEditMode = Notification.Name(LayoutEvents.toggleEditMode.rawValue)
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