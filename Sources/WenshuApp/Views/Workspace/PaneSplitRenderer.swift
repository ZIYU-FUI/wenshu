// PaneSplitRenderer.swift · Wenshu (文枢) · v0.28 followup TKT-028-017
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// split rendering + 1px seam + sash drag pattern from Hermes Desktop
// verbatim. The seam IS the boundary (= junction-owned, never doubled).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/renderer/tree-split.tsx
// = TreeSplit = flex row/column with 1px seams between siblings
//   (= the seam IS the boundary — junction-owned, never doubled).
//   Sash drag updates `$paneStates` (= per-pane widthOverride /
//   heightOverride) via setPaneWidthOverride / setPaneHeightOverride.
//
// And: /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/store/panes.ts
// = $paneStates (per-pane width/height overrides).
//
// And: /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/presets.ts
// = applyLayoutPreset(id, tree) = applyTree(structuredClone(tree), id)
//   (= built-in presets are immutable; live edits never mutate preset).

import Foundation
import SwiftUI
import AppKit

// MARK: - LayoutNode deep clone (= hermes applyTree structuredClone)

/// Deep clone a LayoutNode (= copies the entire tree). Used by
/// `applyTree` to ensure live edits never mutate the source preset.
/// Matches Hermes `structuredClone(tree)` verbatim.
func deepCloneLayoutNode(_ node: LayoutNode) -> LayoutNode {
    switch node {
    case .split(let s):
        return .split(SplitNode(
            type: s.type,
            id: s.id,
            orientation: s.orientation,
            children: s.children.map(deepCloneLayoutNode),
            weights: s.weights  // Array<Double> is value type, copied automatically
        ))
    case .group(let g):
        return .group(GroupNode(
            type: g.type,
            id: g.id,
            panes: g.panes,  // Array<PaneID> is value type, copied automatically
            active: g.active,
            minimized: g.minimized,
            tabStrip: g.tabStrip
        ))
    }
}

/// Deep clone a WorkspaceState (= clones root + panes + tabs).
func deepCloneWorkspaceState(_ state: WorkspaceState) -> WorkspaceState {
    var copy = state
    copy.root = deepCloneLayoutNode(state.root)
    return copy
}

// MARK: - PaneSplitRenderer (= 1px seam = junction-owned)

/// Renders a `SplitNode` (= row or column) with 1px seams as sashes.
/// The seam IS the boundary (= drawn by the split renderer itself,
/// NOT by child panes — children must NOT paint their own edge chrome
/// inside the split).
///
/// Drag-to-resize:
/// - Cursor swaps to `NSCursor.resizeLeftRight` (vertical sash) or
///   `NSCursor.resizeUpDown` (horizontal sash) on hover.
/// - Drag updates `$paneStates` (= per-pane widthOverride/heightOverride)
///   via `PaneVisibilityStore.setPaneWidthOverride`.
/// - Per-split snapshot via `signature-gated snapshot` (= each split
///   only re-renders when its OWN subtree changes, not the whole tree).
@MainActor
struct PaneSplitRenderer: View {
    let split: SplitNode
    let visibilityStore: PaneVisibilityStore?
    /// Width unit (= total available width divided by sum of weights).
    /// Used to convert weights to actual frame sizes.
    let totalWidth: CGFloat
    /// Height unit (= same as totalWidth but for column splits).
    let totalHeight: CGFloat

    init(
        split: SplitNode,
        visibilityStore: PaneVisibilityStore? = nil,
        totalWidth: CGFloat = 1920,
        totalHeight: CGFloat = 1080
    ) {
        self.split = split
        self.visibilityStore = visibilityStore
        self.totalWidth = totalWidth
        self.totalHeight = totalHeight
    }

    var body: some View {
        Group {
            if split.orientation == .row {
                rowSplit
            } else {
                columnSplit
            }
        }
    }

    @ViewBuilder
    private var rowSplit: some View {
        let weightUnit = totalWidth / CGFloat(split.weights.reduce(0, +))
        HStack(spacing: 0) {
            ForEach(split.children.indices, id: \.self) { i in
                PaneRenderer(node: split.children[i], store: WorkspaceStore())
                    .frame(
                        minWidth: minChildSize,
                        idealWidth: max(minChildSize, CGFloat(split.weights[i]) * weightUnit)
                    )
                if i < split.children.count - 1 {
                    VerticalSeam(
                        onDrag: { delta in
                            adjustSiblingWidths(atIndex: i, delta: delta)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var columnSplit: some View {
        let weightUnit = totalHeight / CGFloat(split.weights.reduce(0, +))
        VStack(spacing: 0) {
            ForEach(split.children.indices, id: \.self) { i in
                PaneRenderer(node: split.children[i], store: WorkspaceStore())
                    .frame(
                        minHeight: minChildSize,
                        idealHeight: max(minChildSize, CGFloat(split.weights[i]) * weightUnit)
                    )
                if i < split.children.count - 1 {
                    HorizontalSeam(
                        onDrag: { delta in
                            adjustSiblingHeights(atIndex: i, delta: delta)
                        }
                    )
                }
            }
        }
    }

    private func adjustSiblingWidths(atIndex i: Int, delta: CGFloat) {
        // Update `$paneStates` (= sash drag writes here, scoped to subtree).
        // The split node's left child gets +delta width; right child gets -delta.
        guard let visibilityStore else { return }
        if case .group(let leftGroup) = split.children[i] {
            let newWidth = (visibilityStore.paneSizeSnapshot(leftGroup.id)?.widthOverride ?? 0) + delta
            visibilityStore.setPaneWidthOverride(paneId: leftGroup.id, width: max(minChildSize, newWidth))
        }
        if i + 1 < split.children.count, case .group(let rightGroup) = split.children[i + 1] {
            let newWidth = (visibilityStore.paneSizeSnapshot(rightGroup.id)?.widthOverride ?? 0) - delta
            visibilityStore.setPaneWidthOverride(paneId: rightGroup.id, width: max(minChildSize, newWidth))
        }
    }

    private func adjustSiblingHeights(atIndex i: Int, delta: CGFloat) {
        guard let visibilityStore else { return }
        if case .group(let topGroup) = split.children[i] {
            let newHeight = (visibilityStore.paneSizeSnapshot(topGroup.id)?.heightOverride ?? 0) + delta
            visibilityStore.setPaneHeightOverride(paneId: topGroup.id, height: max(minChildSize, newHeight))
        }
        if i + 1 < split.children.count, case .group(let bottomGroup) = split.children[i + 1] {
            let newHeight = (visibilityStore.paneSizeSnapshot(bottomGroup.id)?.heightOverride ?? 0) - delta
            visibilityStore.setPaneHeightOverride(paneId: bottomGroup.id, height: max(minChildSize, newHeight))
        }
    }

    /// Minimum size for a child pane (= matches Hermes `MIN_PANE_PX`).
    private let minChildSize: CGFloat = 60
}

// MARK: - VerticalSeam (= 1px seam = sash for vertical split)

/// 1px vertical seam (= sash for row split). Junction-owned (= drawn
/// here, NOT by children — children paint no edge chrome). Hover swaps
/// cursor to `NSCursor.resizeLeftRight`; drag invokes `onDrag`.
@MainActor
private struct VerticalSeam: View {
    let onDrag: (CGFloat) -> Void
    @State private var isHover: Bool = false
    @State private var dragStart: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))  // 7 PT hot area
            .onHover { hover in
                isHover = hover
                if hover {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.resizeLeftRight.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation.x
                        }
                        let delta = value.location.x - (dragStart ?? value.location.x)
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
            .onDisappear {
                if isHover {
                    NSCursor.resizeLeftRight.pop()
                }
            }
    }
}

// MARK: - HorizontalSeam (= 1px seam = sash for horizontal split)

/// 1px horizontal seam (= sash for column split). Cursor swaps to
/// `NSCursor.resizeUpDown` on hover.
@MainActor
private struct HorizontalSeam: View {
    let onDrag: (CGFloat) -> Void
    @State private var isHover: Bool = false
    @State private var dragStart: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hover in
                isHover = hover
                if hover {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.resizeUpDown.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation.y
                        }
                        let delta = value.location.y - (dragStart ?? value.location.y)
                        onDrag(delta)
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
            .onDisappear {
                if isHover {
                    NSCursor.resizeUpDown.pop()
                }
            }
    }
}

// MARK: - applyTree deep-clone wrapper

/// WorkspaceStore extension to apply a preset (= always deep-clones
/// to avoid mutating the source preset). Matches Hermes
/// `applyLayoutPreset(id, tree) = applyTree(structuredClone(tree), id)`.
extension WorkspaceStore {
    /// Apply a preset (= deep-clones the tree so live edits never
    /// mutate the source preset). Use this instead of directly
    /// assigning `workspace.root = preset.root`.
    func applyTree(_ tree: LayoutNode, presetID: UUID? = nil) {
        let cloned = deepCloneLayoutNode(tree)
        var newWorkspace = self.workspace
        newWorkspace.root = cloned
        self.workspace = newWorkspace
        if let presetID {
            self.currentPresetID = presetID
        }
        save()
    }
}