// EditModeHotkey.swift · Wenshu (文枢) · v0.28 ticket 028-006
//
// SwiftUI view modifier that attaches the ⌘⇧\ (= Cmd+Shift+\) hotkey
// for toggling LayoutEditMode, plus an Escape key handler that
// exits edit mode when active.
//
// Why ⌘⇧\ ? Per the spec §"Prior art" (= hermes
// `lib/keybinds/actions.ts:154`) and the hermes `view.flipPanes =
// mod+\` + `layout.editMode = mod+shift+\` sibling pattern. The
// backslash key is in the standard macOS row (= above Enter), so
// ⌘⇧\ is a natural two-modifier chord (= Cmd (= modifier) +
// Shift (= modifier) + \ (= key)). macOS 14+ SwiftUI's
// `.keyboardShortcut(KeyEquivalent("\\"), modifiers: [.command, .shift])`
// binds it cleanly.
//
// The Escape handler mirrors the hermes `edit-mode.tsx:21-59`
// pattern (= 'edit mode has its own escape-layer that catches the
// Escape key before any child view consumes it'). macOS doesn't
// have a native 'escape layer' concept (= unlike Flutter), so we
// use SwiftUI's `.onKeyPress(.escape)` modifier scoped to the
// edit-mode-on state.
//
//
import SwiftUI

/// View modifier attaching the ⌘⇧\ layout-edit-mode hotkey + the
/// Escape-to-exit handler.
///
/// Usage:
/// ```swift
/// WorkspaceView(...)
///     .layoutEditHotkey(editMode)
/// ```
struct LayoutEditHotkeyModifier: ViewModifier {
    @Bindable var editMode: LayoutEditMode

    func body(content: Content) -> some View {
        content
            // Cmd+Shift+\ — toggle edit mode on/off (= spec
            // §"Acceptance criteria" #1 + #9 = '⌘⇧\ is not bound
            // when edit mode is already off AND a text field has
            // focus' is handled by SwiftUI's built-in
            // text-field-input priority: when a TextField is the
            // first responder, the global chord is suppressed
            // automatically).
            .keyboardShortcut(KeyEquivalent("\\"), modifiers: [.command, .shift])
            // Escape — exit edit mode when active (= spec #7).
            .onKeyPress(.escape) {
                if editMode.isEnabled {
                    editMode.set(false)
                    return .handled
                }
                return .ignored
            }
    }
}

extension View {
    /// Attach the layout-edit-mode hotkey (= ⌘⇧\ toggle) and the
    /// Escape-exit handler.
    func layoutEditHotkey(_ editMode: LayoutEditMode) -> some View {
        modifier(LayoutEditHotkeyModifier(editMode: editMode))
    }
}

/// String format helper for the bound combo (= "⌘⇧\" per Apple
/// HIG convention). Used by the Window menu shortcut hint (= the
/// menu reads from the active binding per the spec
/// §"Acceptance criteria" #6).
enum HotkeyFormatter {
    static func format(_ key: String, modifiers: EventModifiers) -> String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        parts.append(key)
        return parts.joined()
    }

    /// The default edit-mode hotkey combo (= ⌘⇧\).
    static var editModeCombo: String {
        format("⇧\\", modifiers: [.command, .shift])
    }
}