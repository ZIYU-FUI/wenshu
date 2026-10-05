//
//  State/LayoutTreeRepository.swift
//
//  SwiftData-backed persistence for the workspace layout tree (= replaces
//  the JSON-in-UserDefaults persistence that LayoutTreeStore.swift was
//  using).
//
//  Per boss 2026-10-05 OOB '做 8 和 9' (= complete the SwiftData migration
//  for LayoutTree + FileSystem stores). This is commit 2 of the #9
//  LayoutTreeState/Store → SwiftData migration.
//
//  LayoutTreeStore keeps its existing public API (= `workspace`,
//  `presets`, `currentPresetID`, `save()`, `replaceAll(...)`, etc.);
//  this repository sits underneath and translates every Codable struct
//  the store mutates into the SwiftData @Model row updates (=
//  Persistence/WSLayoutTreeState.swift).
//
//  Apple HIG canonical: SwiftData replaces the hand-rolled
//  Codable + UserDefaults combination (= Apple HIG §6 persistence =
//  prefer SwiftData / Core Data / FileManager for structured state).
//  The repository pattern keeps the old public API stable so the 15
//  caller files don't need to change in this commit.

import Foundation
import SwiftData

/// Repository (= thin facade over SwiftData ModelContext) for the
/// workspace layout tree. Hides the @Model details from
/// `LayoutTreeStore`, which keeps operating on Codable structs.
@MainActor
struct LayoutTreeRepository {
    /// The ModelContext (= the SwiftData CRUD surface).
    let context: ModelContext
    /// The workspace identifier (= one repo per workspace).
    let workspaceID: UUID

    /// One-shot migration from the v1/v2 UserDefaults JSON blob into
    /// the SwiftData @Model tables. After this returns, the
    /// UserDefaults keys are deleted (= the new canonical home is
    /// SwiftData).
    ///
    /// Returns the migrated workspace state (= the v2 Codable tree,
    /// loaded from SwiftData after the JSON has been imported).
    /// If neither JSON nor SwiftData has any data, returns nil.
    @discardableResult
    func migrateFromUserDefaultsIfNeeded() -> LayoutTreeState? {
        let workspaceKey = "wenshu.workspace.json"

        guard let data = UserDefaults.standard.data(forKey: workspaceKey),
              let decoded = try? JSONDecoder().decode(LayoutTreeState.self, from: data) else {
            // No JSON blob (= either SwiftData already has the data,
            // or this is a first launch). Try SwiftData; return nil
            // if empty (= caller will seed from the built-in Default).
            return loadWorkspace()
        }

        // Found a JSON blob: convert each LayoutTreeState field into
        // SwiftData @Model rows. We mirror the v2 tree shape (= panes
        // + tab specs + recursive layout nodes) into the four @Model
        // classes.
        let state = WSLayoutTreeState(id: workspaceID, updatedAt: Date())
        context.insert(state)

        // Mirror the in-memory Codable tree into SwiftData.
        for pane in decoded.panes {
            let paneModel = WSPaneNode(
                id: pane.id.raw,
                split: pane.split.rawValue,
                minWidth: Double(pane.frame.minWidth),
                idealWidth: Double(pane.frame.idealWidth),
                flex: Double(pane.frame.flex)
            )
            context.insert(paneModel)
            // Mirror the pane's tabs (= ordered TabSpec list).
            for tabID in pane.tabIDs {
                guard let tabSpec = decoded.tabs.first(where: { $0.id == tabID }) else { continue }
                let tabModel = WSTabSpec(
                    id: tabSpec.id.raw,
                    kind: tabSpec.kind.rawValue,
                    title: tabSpec.title,
                    contextBookID: tabSpec.contextBookID
                )
                context.insert(tabModel)
                paneModel.tabs.append(tabModel)
            }
            state.panes.append(paneModel)
        }

        // Mirror the recursive layout node (= workspace has a single
        // root; = mirror that one root into the SwiftData state via
        // parentState).
        mirrorLayoutNode(decoded.root, into: state)

        try? context.save()
        // JSON has been imported; delete the legacy key so subsequent
        // launches go straight to SwiftData.
        UserDefaults.standard.removeObject(forKey: workspaceKey)
        return decoded
    }

    /// Persist the in-memory Codable tree (= LayoutTreeState) into
    /// the SwiftData @Model tables. Called from LayoutTreeStore.save().
    ///
    /// Per Apple HIG observable model, this is the only writer
    /// (= the Codable structs stay in memory; = SwiftData is the
    /// disk source of truth). Implementation: clear the existing
    /// SwiftData rows for this workspace, then re-insert from the
    /// in-memory state.
    func saveWorkspace(_ workspace: LayoutTreeState) {
        // Clear existing rows for this workspace.
        let existingStates = (try? context.fetch(
            FetchDescriptor<WSLayoutTreeState>(predicate: #Predicate { $0.id == workspaceID })
        )) ?? []
        for s in existingStates { context.delete(s) }

        let state = WSLayoutTreeState(id: workspaceID, updatedAt: Date())
        context.insert(state)

        // Mirror panes + tabs.
        for pane in workspace.panes {
            let paneModel = WSPaneNode(
                id: pane.id.raw,
                split: pane.split.rawValue,
                minWidth: Double(pane.frame.minWidth),
                idealWidth: Double(pane.frame.idealWidth),
                flex: Double(pane.frame.flex)
            )
            context.insert(paneModel)
            for tabID in pane.tabIDs {
                guard let tabSpec = workspace.tabs.first(where: { $0.id == tabID }) else { continue }
                let tabModel = WSTabSpec(
                    id: tabSpec.id.raw,
                    kind: tabSpec.kind.rawValue,
                    title: tabSpec.title,
                    contextBookID: tabSpec.contextBookID
                )
                context.insert(tabModel)
                paneModel.tabs.append(tabModel)
            }
            state.panes.append(paneModel)
        }

        // Mirror the recursive layout node.
        mirrorLayoutNode(workspace.root, into: state)

        try? context.save()
    }

    /// Load the workspace (= Codable struct) from SwiftData. Returns
    /// nil if the workspace has no rows (= first launch / no
    /// migration done yet).
    func loadWorkspace() -> LayoutTreeState? {
        guard let state = try? context.fetch(
            FetchDescriptor<WSLayoutTreeState>(predicate: #Predicate { $0.id == workspaceID })
        ).first else {
            return nil
        }
        return reconstructWorkspace(from: state)
    }

    // MARK: - Internal helpers

    /// Mirror a single Codable LayoutNode into SwiftData WSLayoutNode
    /// rows. Handles the recursive split|group sum type by checking
    /// the case at each step.
    private func mirrorLayoutNode(_ node: LayoutNode, into state: WSLayoutTreeState) {
        let model = WSLayoutNode(id: UUID(uuidString: node.id) ?? UUID(), kind: "")
        switch node {
        case .split(let split):
            model.kind = "split"
            model.orientation = split.orientation.rawValue
            // Encode the weights as JSON Data (= SwiftData doesn't
            // store [Double] natively).
            if let weightsData = try? JSONEncoder().encode(split.weights) {
                model.childrenWeightsData = weightsData
            }
            context.insert(model)
            model.parentState = state
            // Recurse into children.
            for child in split.children {
                let childModel = WSLayoutNode(id: UUID(uuidString: child.id) ?? UUID(), kind: "split")
            context.insert(childModel)
                childModel.parentSplit = model
                model.splitChildren.append(childModel)
                mirrorLayoutNode(child, into: state)
            }
        case .group(let group):
            model.kind = "group"
            model.minimized = group.minimized ?? false
            model.tabStrip = group.tabStrip?.rawValue ?? ""
            context.insert(model)
            model.parentState = state
            // Mirror the group's stacked panes.
            for paneID in group.panes {
                guard let paneModel = state.panes.first(where: { $0.id == paneID.raw }) else { continue }
                paneModel.parentGroup = model
                model.panes.append(paneModel)
            }
            // Active pane.
            if let activePane = state.panes.first(where: { $0.id == group.active.raw }) {
                model.activePane = activePane
            }
        }
    }

    /// Reconstruct a Codable LayoutTreeState (= the in-memory pure
    /// type) from the SwiftData @Model rows. Inverse of `saveWorkspace`.
    private func reconstructWorkspace(from state: WSLayoutTreeState) -> LayoutTreeState? {
        // Build the panes array.
        var panes: [PaneNode] = []
        var tabs: [TabSpec] = []
        for paneModel in state.panes {
            var tabIDs: [TabID] = []
            for tabModel in paneModel.tabs {
                let tabID = TabID(tabModel.id)
                tabIDs.append(tabID)
                tabs.append(TabSpec(
                    id: tabID,
                    kind: TabKind(rawValue: tabModel.kind) ?? .editor,
                    title: tabModel.title,
                    contextBookID: tabModel.contextBookID
                ))
            }
            let split = SplitDirection(rawValue: paneModel.split) ?? .horizontal
            let frame = PaneFrame(
                minWidth: CGFloat(paneModel.minWidth),
                idealWidth: CGFloat(paneModel.idealWidth),
                flex: CGFloat(paneModel.flex)
            )
            panes.append(PaneNode(id: PaneID(paneModel.id), split: split, frame: frame, tabIDs: tabIDs))
        }

        // Build the recursive root.
        let rootModel = state.rootNodes.first(where: { $0.parentSplit == nil }) ?? state.rootNodes.first
        guard let rootModel = rootModel, let rootNode = reconstructLayoutNode(rootModel) else {
            return nil
        }

        return LayoutTreeState(
            root: rootNode,
            panes: panes,
            tabs: tabs,
            version: 2,  // v2 schema (LayoutTreeState doesn't expose currentSchemaVersion; = hardcode 2 here),
            useThreeColumnSplit: nil
        )
    }

    /// Inverse of `mirrorLayoutNode`: walk the SwiftData tree and
    /// rebuild the Codable LayoutNode tree.
    private func reconstructLayoutNode(_ model: WSLayoutNode) -> LayoutNode? {
        switch model.kind {
        case "split":
            guard let orientation = Orientation(rawValue: model.orientation) else { return nil }
            var children: [LayoutNode] = []
            for childModel in model.splitChildren {
                if let child = reconstructLayoutNode(childModel) {
                    children.append(child)
                }
            }
            // Decode the weights (= JSON Data → [Double]).
            let weights: [Double] = (try? JSONDecoder().decode(
                [Double].self, from: model.childrenWeightsData
            )) ?? Array(repeating: 1.0, count: children.count)
            let split = SplitNode(
                type: "split",
                id: model.id.uuidString,
                orientation: orientation,
                children: children,
                weights: weights
            )
            return .split(split)
        case "group":
            let paneIDs = model.panes.map { PaneID($0.id) }
            let activePaneID: PaneID = model.activePane.map { PaneID($0.id) }
                ?? paneIDs.first
                ?? PaneID()
            let minimized = model.minimized ? true : nil
            let tabStrip = TabStripMode(rawValue: model.tabStrip)
            let group = GroupNode(
                type: "group",
                id: model.id.uuidString,
                panes: paneIDs,
                active: activePaneID,
                minimized: minimized,
                tabStrip: tabStrip
            )
            return .group(group)
        default:
            return nil
        }
    }
}
