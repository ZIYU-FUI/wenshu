// UI/EnvironmentKeys.swift · WenshuApp
// Cross-view shared context keys (= the canonical way to pass state across >2 layers
// without drilling it through every child View.init). Apple HIG macOS 14+ canonical
// = custom EnvironmentKey + @Environment(\.key) reader.

import SwiftUI

// MARK: - Chat session context

/// Shared context for `ChatZoneView` + its `ChatMessageView` + 5 `Chat*PartView` tree.
// RATIONALE: replaces the 6-field manual init-param drilling observed 2026-10-15
// (= session + message-id + viewmodel + streaming-state + theme + insert-pos).
// SAFETY: @unchecked Sendable — `viewModelRef` is a non-Sendable ViewModel reference;
// callers must only mutate via @MainActor paths (Phase A skeleton; refined by A2/A4).
struct ChatSessionContext: @unchecked Sendable {
    let sessionID: String
    let viewModelRef: AnyObject  // safe reference box; non-Sendable ViewModel lives behind it
    let streamingMessageID: String?
}

private struct ChatSessionContextKey: EnvironmentKey {
    static let defaultValue: ChatSessionContext? = nil
}

extension EnvironmentValues {
    var chatSessionContext: ChatSessionContext? {
        get { self[ChatSessionContextKey.self] }
        set { self[ChatSessionContextKey.self] = newValue }
    }
}

// MARK: - Editor services

/// Shared service bundle for `EditorView` + `WenshuMarkdownEditor` + sub-tools.
// RATIONALE: the editor tree currently drills 4 service refs (storage + outline +
// file-watcher + impl-factory); EnvironmentValue removes the manual pass-down.
// SAFETY: @unchecked Sendable — handle refs are opaque non-Sendable; refined by A2 typed ID + A3 DIP.
struct EditorServices: @unchecked Sendable {
    let storageHandle: AnyObject
    let outlineHandle: AnyObject
    let watcherHandle: AnyObject
}

private struct EditorServicesKey: EnvironmentKey {
    static let defaultValue: EditorServices? = nil
}

extension EnvironmentValues {
    var editorServices: EditorServices? {
        get { self[EditorServicesKey.self] }
        set { self[EditorServicesKey.self] = newValue }
    }
}

// MARK: - Sidebar context

/// Shared context for `AppleSidebarView` + `SidebarRowView` + `SidebarZoneHeaderButtons`
/// + `SidebarSheets` (= the library tree).
// RATIONALE: replaces the store + selection + service 3-field manual drilling observed 2026-10-15.
// SAFETY: @unchecked Sendable — library handle is opaque non-Sendable; refined by A2 + A3 DIP.
struct SidebarContext: @unchecked Sendable {
    let libraryHandle: AnyObject
    let selectionPath: AnyObject  // NS-managed navigation path; opaque across layers
}

private struct SidebarContextKey: EnvironmentKey {
    static let defaultValue: SidebarContext? = nil
}

extension EnvironmentValues {
    var sidebarContext: SidebarContext? {
        get { self[SidebarContextKey.self] }
        set { self[SidebarContextKey.self] = newValue }
    }
}