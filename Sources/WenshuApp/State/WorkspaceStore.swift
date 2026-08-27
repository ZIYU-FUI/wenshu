// WorkspaceStore.swift · Wenshu (文枢) · v0.27 ticket 027-33
//
// Persistence + preset management for the user-customizable workspace
// (= .scratch/2026-08-27-xcode-paradigm-layout/spec.md).
//
// Atomic-coupling with WorkspaceState.swift (= ticket 027-32): the
// store reads / writes the WorkspaceState schema; = without one, the
// other has no purpose. Shipped together per boss 8/22 'atomic
// coupling' rule.
//
// Persistence model: UserDefaults JSON (= no FileManager /
// filesystem writes; = matches wenshu's 'preferences-only on User
/// Defaults' pattern established in v0.25 for zone visibility flags).

import Foundation
import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    /// UserDefaults keys (= centralized for grep-ability).
    private static let workspaceKey = "wenshu.workspace.json"
    private static let presetsKey = "wenshu.workspace.presets"
    private static let currentPresetIDKey = "wenshu.workspace.currentPresetID"

    /// Current workspace state (= ObservableObject for SwiftUI
    /// re-render; = mutations via `save()` write to UserDefaults).
    @Published var workspace: WorkspaceState

    /// Saved presets (= user can have several; = the built-in Default
    /// preset is always present).
    @Published var presets: [LayoutPreset]

    /// ID of the currently active preset (= nil = user is on an
    /// unsaved custom layout).
    @Published var currentPresetID: UUID?

    private let userDefaults: UserDefaults
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonDecoder = JSONDecoder()

        // Load persisted state (= falls back to the built-in Default
        // preset if UserDefaults is empty or corrupted).
        let builtin = Self.makeBuiltinWorkspace()
        let builtinPreset = LayoutPreset.builtinDefault(builtin)

        if let data = userDefaults.data(forKey: Self.workspaceKey),
           let decoded = try? jsonDecoder.decode(WorkspaceState.self, from: data),
           decoded.version == builtin.version {
            self.workspace = decoded
        } else {
            self.workspace = builtin
        }

        if let data = userDefaults.data(forKey: Self.presetsKey),
           let decoded = try? jsonDecoder.decode([LayoutPreset].self, from: data) {
            self.presets = decoded
        } else {
            self.presets = [builtinPreset]
        }

        if let uuidString = userDefaults.string(forKey: Self.currentPresetIDKey),
           let uuid = UUID(uuidString: uuidString) {
            self.currentPresetID = uuid
        } else {
            self.currentPresetID = builtinPreset.id
        }
    }

    /// Persist current workspace state to UserDefaults.
    func save() {
        if let data = try? jsonEncoder.encode(workspace) {
            userDefaults.set(data, forKey: Self.workspaceKey)
        }
    }

    /// Persist current presets list to UserDefaults.
    func savePresets() {
        if let data = try? jsonEncoder.encode(presets) {
            userDefaults.set(data, forKey: Self.presetsKey)
        }
        if let id = currentPresetID {
            userDefaults.set(id.uuidString, forKey: Self.currentPresetIDKey)
        }
    }

    /// Reset the current workspace to the built-in Default preset.
    func resetToDefault() {
        let builtin = Self.makeBuiltinWorkspace()
        self.workspace = builtin
        self.currentPresetID = presets.first(where: { $0.isBuiltIn })?.id
        save()
        savePresets()
    }

    /// Save the current workspace as a new named preset.
    @discardableResult
    func saveAsPreset(name: String) -> LayoutPreset {
        let preset = LayoutPreset(
            id: UUID(),
            name: name,
            workspace: workspace,
            isBuiltIn: false
        )
        presets.append(preset)
        currentPresetID = preset.id
        savePresets()
        return preset
    }

    /// Load a saved preset into the current workspace.
    func loadPreset(_ preset: LayoutPreset) {
        self.workspace = preset.workspace
        self.currentPresetID = preset.id
        save()
        savePresets()
    }

    /// Delete a non-built-in preset. Built-in presets cannot be deleted.
    func deletePreset(_ preset: LayoutPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll(where: { $0.id == preset.id })
        if currentPresetID == preset.id {
            currentPresetID = presets.first(where: { $0.isBuiltIn })?.id
        }
        savePresets()
    }

    /// Built-in default workspace (= the 6-zone LayoutShellView
    /// equivalent).
    ///
    /// Layout (= top to bottom):
    /// - Upper band: 4 panes horizontally
    ///   - projectSidebar (left)
    ///   - projectPreview (next)
    ///   - editor (center, larger flex)
    ///   - specializedTools (right)
    /// - Lower band: 2 panes horizontally
    ///   - aiChat (left)
    ///   - aiDynamic (right)
    ///
    /// The upper / lower bands are stacked vertically (= the root
    /// workspace's split direction). The 5 internal panes share the
    /// upper / lower band horizontal split direction.
    static func makeBuiltinWorkspace() -> WorkspaceState {
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let preview = TabSpec.make(kind: .projectPreview, title: "素材预览区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let tools = TabSpec.make(kind: .specializedTools, title: "工具区")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")
        let dynamic = TabSpec.make(kind: .aiDynamic, title: "动态区")

        let upperLeft = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id])
        let upperPreview = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 280, flex: 0.5), tabs: [preview.id])
        let upperEditor = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 300, idealWidth: 700, flex: 1.0), tabs: [editor.id])
        let upperTools = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 360, flex: 0.6), tabs: [tools.id])

        let lowerChat = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [chat.id])
        let lowerDynamic = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [dynamic.id])

        let panes = [upperLeft, upperPreview, upperEditor, upperTools, lowerChat, lowerDynamic]
        let tabs = [sidebar, preview, editor, tools, chat, dynamic]

        return WorkspaceState(
            panes: panes,
            activePaneID: upperEditor.id,
            activeTabIndexByPane: [:],
            tabs: tabs,
            version: 1
        )
    }
}