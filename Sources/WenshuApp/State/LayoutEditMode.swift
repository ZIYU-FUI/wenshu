// LayoutEditMode.swift · Wenshu (文枢) · v0.28 ticket 028-006
//
// Layout edit mode singleton (= hermes `$layoutEditMode` atom port).
//
// The boolean is owned by a single @Observable (= Apple Observation
// framework, Swift 6) so any SwiftUI view can read it via
// @Bindable without manual subscriptions. When edit mode is on,
// the user can drag splitters / drag tabs between panes / drop
// panes into new zones (= the full drag UX surface, gated by
// 028-006 + 028-007 + 028-008). When edit mode is off (= default),
// the drag gestures are inert (= the workspace behaves like the
// v0.27 LayoutShellView with no editing surface).
//
// Persistence: `wenshu.workspace.editMode` UserDefaults Bool. Set
// once at init (= so the value persists across app launches per
// the spec §"Acceptance criteria" #8 = 'Edit mode persistence
// survives app restart'). The `toggle()` method is the single
// mutator and is the only place that writes back to UserDefaults.
//
//
import Foundation
import Observation

/// LayoutEditMode — observable boolean controlling the layout
/// edit mode of the wenshu workspace.
///
/// Usage:
/// ```swift
/// @State private var editMode = LayoutEditMode()
/// ...
/// .layoutEditHotkey(editMode)   // attaches Cmd+Shift+\ toggle
/// ```
@Observable
@MainActor
final class LayoutEditMode {
    /// The current edit mode state (= true = layout can be edited
    /// via drag gestures; false = static).
    var isEnabled: Bool

    /// UserDefaults key (= mirrors WorkspaceStore's pattern of
    /// centralizing keys for grep-ability).
    private static let editModeKey = "wenshu.workspace.editMode"

    /// Schema version (= bumped on breaking changes; v0.28.028-006
    /// ships v1 = simple Bool).
    private static let currentSchemaVersion = 1

    init(userDefaults: UserDefaults = .standard) {
        // Read persisted state (= defaults to false on first
        // launch or if the stored value is corrupted).
        let stored = userDefaults.object(forKey: Self.editModeKey) as? Bool
        self.isEnabled = stored ?? false
    }

    /// Toggle the edit mode state + persist to UserDefaults.
    func toggle() {
        isEnabled.toggle()
        save()
    }

    /// Explicit set (= used by Escape-exit per the spec
    /// §"Acceptance criteria" #7).
    func set(_ value: Bool) {
        guard isEnabled != value else { return }
        isEnabled = value
        save()
    }

    /// Persist current state to UserDefaults.
    private func save(userDefaults: UserDefaults = .standard) {
        userDefaults.set(isEnabled, forKey: Self.editModeKey)
    }
}