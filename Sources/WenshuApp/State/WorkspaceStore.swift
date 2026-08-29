// WorkspaceStore.swift · Wenshu (文枢) · v0.28 ticket 028-003
//
// Persistence + preset management for the user-customizable workspace
// (= .scratch/2026-08-28-v0-28-free-layout/spec.md).
//
// Atomic-coupling with WorkspaceState.swift (= ticket 028-003, same
// commit): the store reads / writes the WorkspaceState schema; without
// one, the other has no purpose. Shipped together per boss 8/22
// 'atomic coupling' rule. This commit ALSO bumps the built-in default
// preset (= makeBuiltinWorkspace) to the FCP Browser 3-pane paradigm
// per boss拍 2026-08-27 (= b/II = WorkspaceView ON default, FCP
// Browser paradigm). 028-005 ticket will register the preset officially;
// this commit sets the seed so the FCP Browser shape is in place from
// day one of v2.
//
// Persistence model: UserDefaults JSON (= no FileManager / filesystem
// writes; matches wenshu's 'preferences-only on UserDefaults' pattern
// established in v0.25 for zone visibility flags).
//
// v2 migration (= ticket 028-003 acceptance criterion): the store
// reads / writes the v2 tree schema (= WorkspaceState.root backed by
// a LayoutNode tree). On detecting a v1 (= flat array) JSON blob in
// UserDefaults, the store RETIRES it (= drops the v1 keys wholesale,
// starts fresh) per the hermes "retire v1 wholesale" pattern. This
// matches the v0.28 development-phase rationale (= no external users,
// the only "returning user" is the boss, who is fine with a fresh
// tree for v2).

import Foundation
import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    /// UserDefaults keys (= centralized for grep-ability).
    private static let workspaceKey = "wenshu.workspace.json"
    private static let presetsKey = "wenshu.workspace.presets"
    private static let currentPresetIDKey = "wenshu.workspace.currentPresetID"

    /// Schema versions (= on breaking schema changes, bump
    /// `currentSchemaVersion` and migrate in `migrateState`).
    /// - 1: flat pane array (= v0.27 ticket 027-32)
    /// - 2: recursive split tree (= v0.28 ticket 028-003, this commit)
    private static let currentSchemaVersion = 2

    /// Current workspace state (= ObservableObject for SwiftUI
    /// re-render; mutations via `save()` write to UserDefaults).
    @Published var workspace: WorkspaceState

    /// Saved presets (= user can have several; the built-in Default
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
        let builtinPresets = Self.makeBuiltinPresets()
        let builtinDefault = builtinPresets.first { $0.isBuiltIn && $0.name == "默认" }!

        // v0.28 Boss UX round 17 (Boss 2026-08-29 OOB '其他模版切换一下,
        // 然后每个都截个图, 我看适配情况'): honor currentPresetID on
        // FIRST launch too (= not just when the persisted workspace is
        // present). Without this, switching preset via
        // `defaults write wenshu.workspace.currentPresetID` only works
        // when the persisted workspace is also overwritten (= the
        // current code only sets currentPresetID, but then init reads
        // workspace JSON which has the OLD layout = preset display is
        // correct but the actual layout is from the old preset).
        //
        // Now: if currentPresetID points to a valid builtin preset,
        // use that preset's workspace as the seed (= before the
        // persisted JSON fallback).
        var forcedPreset: LayoutPreset? = nil
        if let uuidString = userDefaults.string(forKey: Self.currentPresetIDKey),
           let uuid = UUID(uuidString: uuidString),
           let matched = builtinPresets.first(where: { $0.id == uuid }) {
            forcedPreset = matched
        }

        if let data = userDefaults.data(forKey: Self.workspaceKey),
           let decoded = try? jsonDecoder.decode(WorkspaceState.self, from: data) {
            // Schema version check: if the persisted JSON is on a
            // different schema version (= e.g. v1 = flat array from
            // v0.27), migrate it (= for v2 from v1: retire v1
            // wholesale, start fresh — see `migrateState`).
            if decoded.version == Self.currentSchemaVersion {
                self.workspace = decoded
            } else {
                let migrated = Self.migrateState(decoded)
                self.workspace = migrated
                userDefaults.removeObject(forKey: Self.workspaceKey)
            }
        } else if let preset = forcedPreset {
            // No persisted workspace, but user selected a non-default
            // preset via currentPresetID = use that preset's tree.
            self.workspace = preset.workspace
        } else {
            // First launch / no persisted JSON + no forced preset:
            // start fresh from the built-in Default.
            self.workspace = builtinDefault.workspace
        }

        if let data = userDefaults.data(forKey: Self.presetsKey),
           let decoded = try? jsonDecoder.decode([LayoutPreset].self, from: data) {
            self.presets = decoded
            // If the persisted presets contain a v1 workspace, retire
            // them too (= same wholesale-retire logic).
            if decoded.contains(where: { $0.workspace.version != Self.currentSchemaVersion }) {
                self.presets = builtinPresets
                userDefaults.removeObject(forKey: Self.presetsKey)
            }
        } else {
            // First launch (= no persisted presets): seed with the
            // 4 builtin presets per 028-005.
            self.presets = builtinPresets
        }

        if let uuidString = userDefaults.string(forKey: Self.currentPresetIDKey),
           let uuid = UUID(uuidString: uuidString),
           self.presets.contains(where: { $0.id == uuid }) {
            self.currentPresetID = uuid
        } else {
            self.currentPresetID = builtinDefault.id
        }
    }

    /// Migrate a persisted state from an older schema version to the
    /// current one.
    ///
    /// v1 → v2 (= ticket 028-003): retire v1 wholesale (= drop the v1
    /// keys on detection, start fresh). This matches the hermes
    /// "retire v1 wholesale" pattern documented in
    /// `hermes-agent/apps/desktop/src/components/pane-shell/tree/
    /// model.ts` §"Validation" — analogous to the `headerHidden`
    /// retirement. The v0.28 development-phase rationale is: no
    /// external users; the only "returning user" is the boss, who
    /// can re-seed the workspace manually (= or via a future
    /// import-from-v1-JSON feature ticket if needed).
    private static func migrateState(_ old: WorkspaceState) -> WorkspaceState {
        switch old.version {
        case 1:
            return makeBuiltinWorkspace()
        default:
            // Unknown version: also retire wholesale (= future
            // versions can override this switch with their own
            // forward-migration logic).
            return makeBuiltinWorkspace()
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

    /// Adjust a split's weights by the given delta applied to a
    /// specific child (= the drag-resize gesture's per-step delta).
    ///
    /// `childIndex` is the index of the LEFT/TOP sibling (= the
    /// splitter sits between `childIndex` and `childIndex + 1`).
    /// Positive `delta` (= drag right / down) grows the LEFT/TOP
    /// sibling (= standard macOS split convention).
    ///
    /// Implementation: finds the split by id, scales its weights
    /// array proportionally (= weight[i] += delta,
    /// weight[i+1] -= delta, clamped at minWeight = 0.05 so a pane
    /// never fully collapses under drag).
    func adjustSplitWeights(splitID: String, childIndex: Int, delta: Double) {
        let minWeight = 0.05
        let newRoot = mapSplitWeights(splitID: splitID) { weights in
            guard weights.count > childIndex + 1 else { return weights }
            var w = weights
            let left = w[childIndex]
            let right = w[childIndex + 1]
            // Apply the delta proportionally (= delta is in PT
            // units; convert to weight by dividing by the total).
            let total = left + right
            let dW = delta / total
            var newLeft = max(minWeight, min(1 - minWeight, left + dW))
            let newRight = max(minWeight, total - newLeft)
            newLeft = total - newRight
            w[childIndex] = newLeft
            w[childIndex + 1] = newRight
            return w
        }
        if let newRoot {
            workspace.root = newRoot
            save()
        }
    }

    /// Set the active pane in a group (= dispatches into the tree
    /// pure function so callers can read the new tree without
    /// manually walking it).
    func setActivePaneInGroup(groupID: String, paneID: PaneID) {
        let newRoot = setActivePane(workspace.root, groupId: groupID, paneId: paneID)
        workspace.root = newRoot
        save()
    }

    /// Move a pane from one group to another (= the tab-drag UX
    /// drop handler). The pane is removed from its source group and
    /// joined as a tab in the target group (= center position).
    ///
    /// If the source group is reduced to zero panes by the removal,
    /// the tree's `normalize` (= called by removePane) prunes the
    /// empty group per the VS Code semantics.
    func movePaneWithinGroup(groupID: String, paneID: PaneID, targetPaneID: PaneID) {
        // Find the target group id by walking the tree from the
        // target pane.
        guard let targetGroup = findGroupOfPane(workspace.root, paneId: targetPaneID) else {
            return
        }
        // Move via the file-scope pure function (= removes from
        // source group + inserts as tab in target group with pos=.center).
        let newRoot = movePane(
            workspace.root,
            paneId: paneID,
            target: (groupId: targetGroup.id, pos: .center, before: nil)
        )
        workspace.root = newRoot
        save()
        _ = groupID // suppress unused warning (= groupID is for future
                    // direct-group addressing; current implementation
                    // uses targetPaneID to locate the target group).
    }

    /// Remove a pane from whatever group contains it (= the tab-close
    /// UX per ticket 028-004b3). If the source group is reduced to
    /// zero panes by the removal, the tree's `normalize` (= called
    /// by removePane) prunes the empty group per the VS Code
    /// semantics. If the entire tree is emptied (= the user closed
    /// the last pane), the root becomes nil (= UI shows the empty-
    /// pane fallback in PaneRenderer).
    func removePaneFromGroup(paneID: PaneID) {
        guard let newRoot = removePane(workspace.root, paneId: paneID) else {
            // Tree emptied (= the user closed the last pane).
            // We keep the workspace as-is (= root becomes nil but
            // the panes/tabs metadata persists; the renderer
            // shows the empty-pane fallback). Saving is a no-op
            // for the tree but still useful for the JSON
            // round-trip guarantee.
            workspace = WorkspaceState(
                root: makeGroup(panes: []),
                panes: workspace.panes,
                tabs: workspace.tabs,
                version: 2
            )
            save()
            return
        }
        workspace.root = newRoot
        save()
    }

    /// Private helper: walk the tree to find the split with `id` and
    /// update its weights; return the new tree (or nil if the split
    /// was not found).
    private func mapSplitWeights(splitID: String, _ transform: ([Double]) -> [Double]) -> LayoutNode? {
        func walk(_ node: LayoutNode) -> LayoutNode? {
            if case .split(let s) = node {
                if s.id == splitID {
                    let newWeights = transform(s.weights)
                    return .split(SplitNode(
                        id: s.id, orientation: s.orientation,
                        children: s.children, weights: newWeights
                    ))
                }
                var updated: [LayoutNode] = []
                for child in s.children {
                    if let walked = walk(child) {
                        updated.append(walked)
                    } else {
                        updated.append(child)
                    }
                }
                return .split(SplitNode(
                    id: s.id, orientation: s.orientation,
                    children: updated, weights: s.weights
                ))
            }
            return nil
        }
        return walk(workspace.root)
    }

    /// Built-in presets (= the 4 wenshu ships by default per ticket
    /// 028-005; literal port from hermes
    /// `controller.tsx:392-440`). Names per spec.md i18n table:
    /// "默认" / "Focus" / "Terminal deck" / "Quad".
    ///
    /// Built-in shapes (= per ticket 028-005 §"Built-in shapes"):
    /// - builtinDefault = 6-zone shape (= upper 4 horizontal + lower 2
    ///   horizontal; same as v0.27 makeBuiltinWorkspace before the
    ///   028-002 FCP Browser retarget — preserved for users who want
    ///   the legacy layout via the picker).
    /// - builtinFocus = 2-pane sidebar + everything-else-as-tabs
    ///   (= single-stage editor for distraction-free writing).
    /// - builtinTerminalDeck = 3-pane top row + chat bottom (= the
    ///   debug-band pattern).
    /// - builtinQuad = 2x2 grid (= sidebar + editor on top; chat +
    ///   dynamic on bottom).
    static func makeBuiltinPresets() -> [LayoutPreset] {
        return [
            builtinDefaultPreset(),
            builtinFocusPreset(),
            builtinTerminalDeckPreset(),
            builtinQuadPreset()
        ]
    }

    private static func builtinDefaultPreset() -> LayoutPreset {
        // Same as v0.27's 6-zone LayoutShellView shape (= upper 4 +
        // lower 2 horizontal). Kept here for the 028-005 picker
        // (= users who want the legacy 6-zone layout via the picker
        // even after the FCP Browser 3-pane becomes default).
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let preview = TabSpec.make(kind: .projectPreview, title: "素材预览区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let tools = TabSpec.make(kind: .specializedTools, title: "工具区")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")
        let dynamic = TabSpec.make(kind: .aiDynamic, title: "动态区")

        let sidebarPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id])
        let previewPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 280, flex: 0.5), tabs: [preview.id])
        let editorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 300, idealWidth: 700, flex: 1.0), tabs: [editor.id])
        let toolsPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 360, flex: 0.6), tabs: [tools.id])
        let chatPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [chat.id])
        let dynamicPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [dynamic.id])

        let panes = [sidebarPane, previewPane, editorPane, toolsPane, chatPane, dynamicPane]
        let tabs = [sidebar, preview, editor, tools, chat, dynamic]

        // Tree shape: outer column split (upper band + lower band)
        // with each band being a horizontal row split.
        let upperBand = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebarPane.id]),
                makeGroup(panes: [previewPane.id]),
                makeGroup(panes: [editorPane.id]),
                makeGroup(panes: [toolsPane.id])
            ],
            weights: [1, 1, 3.4, 1.25]
        )
        let lowerBand = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [chatPane.id]),
                makeGroup(panes: [dynamicPane.id])
            ],
            weights: [1, 1]
        )
        let root = makeSplit(
            orientation: .column,
            children: [upperBand, lowerBand],
            weights: [3, 1]
        )

        return LayoutPreset(
            id: LayoutPreset.builtinDefaultID,
            name: "默认",
            workspace: WorkspaceState(
                root: root,
                panes: panes,
                tabs: tabs,
                version: 2
            ),
            isBuiltIn: true
        )
    }

    private static func builtinFocusPreset() -> LayoutPreset {
        // 2-pane sidebar + everything-else-as-tabs (= single-stage
        // editor with sidebar). Designed for distraction-free
        // writing.
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let preview = TabSpec.make(kind: .projectPreview, title: "素材预览区")
        let tools = TabSpec.make(kind: .specializedTools, title: "工具区")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")
        let dynamic = TabSpec.make(kind: .aiDynamic, title: "动态区")

        let sidebarPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id])
        let editorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 400, idealWidth: 900, flex: 1.0), tabs: [editor.id])

        let panes = [sidebarPane, editorPane]
        let tabs = [sidebar, editor, preview, tools, chat, dynamic]

        // Tree: row split with sidebar on the left and editor on
        // the right; editor is a group with multiple tabs (= the
        // "all 5 as tabs in editor" pattern from the spec).
        let root = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebarPane.id]),
                makeGroup(panes: [editorPane.id, PaneID(), PaneID(), PaneID(), PaneID()])
            ],
            weights: [1, 4.6]
        )

        return LayoutPreset(
            id: LayoutPreset.builtinFocusID,
            name: "Focus",
            workspace: WorkspaceState(
                root: root,
                panes: panes,
                tabs: tabs,
                version: 2
            ),
            isBuiltIn: true
        )
    }

    private static func builtinTerminalDeckPreset() -> LayoutPreset {
        // 4-pane top row + chat bottom (= the debug-band pattern).
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let preview = TabSpec.make(kind: .projectPreview, title: "素材预览区")
        let tools = TabSpec.make(kind: .specializedTools, title: "工具区")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")

        let sidebarPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id])
        let editorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 300, idealWidth: 700, flex: 1.0), tabs: [editor.id])
        let inspectorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 360, flex: 0.6), tabs: [preview.id, tools.id])
        let chatPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 800, flex: 1.0), tabs: [chat.id])

        let panes = [sidebarPane, editorPane, inspectorPane, chatPane]
        let tabs = [sidebar, editor, preview, tools, chat]

        let topRow = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebarPane.id]),
                makeGroup(panes: [editorPane.id]),
                makeGroup(panes: [inspectorPane.id])
            ],
            weights: [1, 3.2, 1.2]
        )
        let root = makeSplit(
            orientation: .column,
            children: [topRow, makeGroup(panes: [chatPane.id])],
            weights: [3, 1]
        )

        return LayoutPreset(
            id: LayoutPreset.builtinTerminalDeckID,
            name: "Terminal deck",
            workspace: WorkspaceState(
                root: root,
                panes: panes,
                tabs: tabs,
                version: 2
            ),
            isBuiltIn: true
        )
    }

    private static func builtinQuadPreset() -> LayoutPreset {
        // 2x2 grid (= sidebar + editor on top; chat + dynamic on
        // bottom).
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let preview = TabSpec.make(kind: .projectPreview, title: "素材预览区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")
        let dynamic = TabSpec.make(kind: .aiDynamic, title: "动态区")

        let sidebarPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id, preview.id])
        let editorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 300, idealWidth: 800, flex: 1.0), tabs: [editor.id])
        let chatPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [chat.id])
        let dynamicPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 360, flex: 0.8), tabs: [dynamic.id])

        let panes = [sidebarPane, editorPane, chatPane, dynamicPane]
        let tabs = [sidebar, preview, editor, chat, dynamic]

        let topRow = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebarPane.id]),
                makeGroup(panes: [editorPane.id])
            ],
            weights: [1, 3]
        )
        let bottomRow = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [chatPane.id]),
                makeGroup(panes: [dynamicPane.id])
            ],
            weights: [1.4, 1]
        )
        let root = makeSplit(
            orientation: .column,
            children: [topRow, bottomRow],
            weights: [3, 1]
        )

        return LayoutPreset(
            id: LayoutPreset.builtinQuadID,
            name: "Quad",
            workspace: WorkspaceState(
                root: root,
                panes: panes,
                tabs: tabs,
                version: 2
            ),
            isBuiltIn: true
        )
    }

    /// Built-in default workspace (= the FCP Browser 3-pane paradigm
    /// per boss拍 2026-08-27, ticket 028-002 = b/II).
    ///
    /// Layout (= left to right, three panes separated by two
    /// draggable splitters):
    /// - Left pane: projectSidebar (= project management)
    /// - Center pane: editor (= chapter / draft Markdown editor)
    /// - Right pane: aiChat + aiDynamic as inspector tabs (= chat /
    ///   dynamic zone contents in a single tabbed pane; matches the
    ///   hermes inspector-tab pattern that boss拍 2026-08-27 cited as
    ///   surface-area reuse).
    ///
    /// Tree shape (= recursive per v2 schema):
    ///   split(row, [group(sidebar), group(editor), split(column,
    ///             [group(chat), group(dynamic)])], [1, 1, 1])
    static func makeBuiltinWorkspace() -> WorkspaceState {
        let sidebar = TabSpec.make(kind: .projectSidebar, title: "项目管理区")
        let editor = TabSpec.make(kind: .editor, title: "编辑器")
        let chat = TabSpec.make(kind: .aiChat, title: "聊天区")
        let dynamic = TabSpec.make(kind: .aiDynamic, title: "动态区")

        let sidebarPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 240, flex: 0.4), tabs: [sidebar.id])
        let editorPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 300, idealWidth: 700, flex: 1.0), tabs: [editor.id])
        let chatPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [chat.id])
        let dynamicPane = PaneNode.make(split: .horizontal, frame: PaneFrame(minWidth: 200, idealWidth: 400, flex: 1.0), tabs: [dynamic.id])

        let panes = [sidebarPane, editorPane, chatPane, dynamicPane]
        let tabs = [sidebar, editor, chat, dynamic]

        // Inspector pane = chat + dynamic tabs in one group (= FCP
        // Browser paradigm).
        let inspectorGroup = makeGroup(panes: [chatPane.id, dynamicPane.id], active: chatPane.id)
        // Top row = sidebar + editor + inspector, horizontally split.
        let root = makeSplit(
            orientation: .row,
            children: [
                makeGroup(panes: [sidebarPane.id], active: sidebarPane.id),
                makeGroup(panes: [editorPane.id], active: editorPane.id),
                inspectorGroup
            ],
            weights: [1, 2, 1]
        )

        return WorkspaceState(
            root: root,
            panes: panes,
            tabs: tabs,
            version: currentSchemaVersion
        )
    }
}