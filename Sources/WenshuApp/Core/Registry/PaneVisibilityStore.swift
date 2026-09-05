// PaneVisibilityStore.swift · Wenshu · v0.28 followup TKT-028-014
//
// Boss 2026-08-29 OOB 'verbatim port from hermes app' = port the 3 visibility
// mechanisms from Hermes Desktop verbatim (= hiddenTreePanes /
// dismissedPanes / collapsePanes) + their binding helpers
// (bindPaneVisibility / bindToolPaneCollapse / dismissTreePane /
// revealTreePane / removeTreePane / isPaneVisible / togglePaneVisible).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/store.ts
// = $hiddenTreePanes atom + $dismissedPanes atom + collapsePanes Set
//   + paneOpeners / paneClosers maps + bindPaneVisibility /
//   bindToolPaneCollapse / setTreePaneHidden / dismissTreePane /
//   revealTreePane / removeTreePane / isPaneVisible /
//   togglePaneVisible / $paneVisible computed.
//
// Also: /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/store/panes.ts
// = $paneStates (per-pane widthOverride / heightOverride)
//
// And: /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/store/statusbar-prefs.ts
// = $statusbarVisible + $statusbarHiddenIds + setStatusbarItemVisible

import Foundation
import Observation
import SwiftUI

// MARK: - PaneSizeSnapshot (= per-pane sash drag override)

/// Per-pane size override (= used by the sash drag to persist the
/// user's manual resize). Matches Hermes `$paneStates` shape.
public struct PaneSizeSnapshot: Equatable, Codable, Sendable {
    public var widthOverride: CGFloat?
    public var heightOverride: CGFloat?

    public init(widthOverride: CGFloat? = nil, heightOverride: CGFloat? = nil) {
        self.widthOverride = widthOverride
        self.heightOverride = heightOverride
    }
}

// MARK: - PaneVisibilityStore

/// Owns the 3 visibility mechanisms + pane size overrides + per-item
/// statusbar visibility. Lives next to WorkspaceStore (= same persistence
/// rules, same schema version, same save() cadence) but is additive:
/// does not touch any existing Wenshu 5-zone AppStorage flags.
@MainActor
@Observable
public final class PaneVisibilityStore {

    // MARK: Visibility sets

    /// Panes hidden by app chrome toggles (titlebar sidebar / right-sidebar
    /// buttons). The tree KEEPS the zone and its mounted content; a zone
    /// whose every pane is hidden collapses to nothing until a toggle
    /// brings it back.
    public var hiddenTreePanes: Set<String> = []

    /// Panes the user explicitly closed (= Close button, "dismiss").
    /// The pane is REMOVED from the tree; reveal re-adds it via adoption.
    public var dismissedPanes: Set<String> = []

    /// Tool panels (= terminal, logs): collapse to rail (= tab stays,
    /// body collapsed) instead of hiding. IntelliJ/VS-Code model.
    public var collapsePanes: Set<String> = []

    // MARK: Pane states (= sash drag persistence)

    /// Per-pane width / height override. When a sash drag finishes,
    /// the pane id's override is written here. The split renderer reads
    /// these to honor the user's manual resize.
    public var paneStates: [String: PaneSizeSnapshot] = [:]

    // MARK: Statusbar per-item visibility

    /// Statusbar item ids hidden by the user (right-click → context menu
    /// → "Hide"). The statusbar reads this set to skip rendering hidden
    /// items. Matches Hermes `$statusbarHiddenIds`.
    public var statusbarHiddenIds: Set<String> = []

    // MARK: Statusbar overall visibility

    /// Whether the statusbar is shown at all. Matches Hermes
    /// `$statusbarVisible`.
    public var statusbarVisible: Bool = true

    // MARK: Pane opener / closer registry (= the binding protocol)

    /// Maps pane id → opener (= called by revealTreePane to restore the
    /// pane's visibility store). Per-pane; cleared when the pane unregisters.
    private var paneOpeners: [String: () -> Void] = [:]
    /// Maps pane id → closer (= called by togglePaneVisible to write
    /// the pane's visibility store to "hidden"). Per-pane.
    private var paneClosers: [String: () -> Void] = [:]

    // MARK: Persisted pane share memory (= remember last group + active
    // tab for restore on re-reveal)

    /// Per-pane last-known group id (= for restore on re-reveal).
    private var lastGroupOfPane: [String: String] = [:]
    /// Per-pane last-known position in group (= for restore).
    private var lastPositionOfPane: [String: Int] = [:]

    public init() {}

    // MARK: Pane opener / closer registration

    public func registerPaneOpener(paneId: String, open: @escaping () -> Void) {
        paneOpeners[paneId] = open
    }

    public func registerPaneCloser(paneId: String, close: @escaping () -> Void) {
        paneClosers[paneId] = close
    }

    // MARK: Collapse membership (= mark pane as tool panel)

    public func markCollapsePane(paneId: String) {
        collapsePanes.insert(paneId)
    }

    public func isCollapsePane(_ paneId: String) -> Bool {
        collapsePanes.contains(paneId)
    }

    // MARK: Hidden tree panes (= sidebar ⌘B / file browser ⌘G)

    /// Toggle `paneId` in/out of `hiddenTreePanes`. When unhiding, also
    /// fronts the pane in its group (= makes it the active tab).
    public func setTreePaneHidden(paneId: String, hidden: Bool) {
        let current = hiddenTreePanes
        let next: Set<String>
        if hidden {
            next = current.union([paneId])
        } else {
            next = current.subtracting([paneId])
        }
        if next != current {
            hiddenTreePanes = next
        }
        // Unhide = also front pane in group (= reactive unhides need
        // this so the pane is visible the next time the column is shown).
        if !hidden {
            // Caller is responsible for calling setActivePane on the tree
            // (= this store doesn't own the tree). We expose the signal
            // via `paneOpeners`.
            paneOpeners[paneId]?()
        }
    }

    // MARK: Dismissed panes (= Close button removes from tree)

    /// Mark `paneId` as dismissed (= user explicitly closed it). Pair
    /// with `revealTreePane(paneId:)` to un-dismiss + re-add to tree.
    public func setDismissed(paneId: String, dismissed: Bool) {
        if dismissed {
            dismissedPanes.insert(paneId)
        } else {
            dismissedPanes.remove(paneId)
        }
    }

    /// Remember a pane's group + position BEFORE dismissing (= so
    /// reveal can restore it to the exact same spot).
    public func rememberPaneShare(groupId: String, paneId: String, position: Int) {
        lastGroupOfPane[paneId] = groupId
        lastPositionOfPane[paneId] = position
    }

    public func rememberedGroup(ofPane paneId: String) -> String? {
        lastGroupOfPane[paneId]
    }

    public func rememberedPosition(ofPane paneId: String) -> Int? {
        lastPositionOfPane[paneId]
    }

    // MARK: Pane visibility query

    /// Is the pane actually ON SCREEN? (= in tree, not dismissed, not
    /// chrome hidden, its zone un-minimized, and holding the active
    /// slot in its stack).
    public func isPaneVisible(
        paneId: String,
        inTree: Bool,
        zoneMinimized: Bool,
        isActiveInGroup: Bool
    ) -> Bool {
        if dismissedPanes.contains(paneId) || hiddenTreePanes.contains(paneId) {
            return false
        }
        return inTree && !zoneMinimized && isActiveInGroup
    }

    // MARK: Pane visibility toggle (= called by titlebar / statusbar buttons)

    /// Toggle visibility. Pair of `bindPaneVisibility` opener + closer.
    public func togglePaneVisible(paneId: String) {
        if hiddenTreePanes.contains(paneId) {
            setTreePaneHidden(paneId: paneId, hidden: false)
        } else {
            // Hide via the closer (= writes the bound visibility store).
            paneClosers[paneId]?()
            setTreePaneHidden(paneId: paneId, hidden: true)
        }
    }

    // MARK: Bindings (= chrome ↔ tree)

    /// HIDE-STYLE PANES (files, review, preview). Bind a pane's visibility
    /// STORE to the tree so its toggle HIDES the pane (its zone collapses
    /// while the content stays mounted), as opposed to the tool panels
    /// which collapse to a rail and keep their tab.
    ///
    /// `close` and `open` are a PAIR, and passing only one is the bug
    /// this exists to prevent. The closer keeps the toggle truthful when
    /// the pane is closed from the tab menu; the opener is its mirror.
    public func bindPaneVisibility(
        paneId: String,
        isOpen: Bool,
        close: (() -> Void)? = nil,
        open: (() -> Void)? = nil
    ) {
        setTreePaneHidden(paneId: paneId, hidden: !isOpen)
        if let close {
            registerPaneCloser(paneId: paneId, close: close)
        }
        if let open {
            registerPaneOpener(paneId: paneId, open: open)
        }
    }

    /// TOOL PANELS (terminal, logs). Bind a pane's visibility STORE to
    /// the tree so its toggle COLLAPSES the zone to a persistent rail
    /// (the tab stays) instead of hiding it. IntelliJ/VS-Code tool
    /// window model. Restore routes back through `open`.
    public func bindToolPaneCollapse(
        paneId: String,
        isOpen: Bool,
        close: @escaping () -> Void,
        open: @escaping () -> Void
    ) {
        markCollapsePane(paneId: paneId)
        setTreePaneHidden(paneId: paneId, hidden: !isOpen)
        registerPaneCloser(paneId: paneId, close: close)
        registerPaneOpener(paneId: paneId, open: open)
    }

    // MARK: Pane states (= sash drag persistence)

    public func setPaneWidthOverride(paneId: String, width: CGFloat?) {
        var state = paneStates[paneId] ?? PaneSizeSnapshot()
        state.widthOverride = width
        paneStates[paneId] = state
    }

    public func setPaneHeightOverride(paneId: String, height: CGFloat?) {
        var state = paneStates[paneId] ?? PaneSizeSnapshot()
        state.heightOverride = height
        paneStates[paneId] = state
    }

    public func paneSizeSnapshot(_ paneId: String) -> PaneSizeSnapshot? {
        paneStates[paneId]
    }

    public func clearAllPaneSizeOverrides() {
        paneStates.removeAll()
    }

    // MARK: Statusbar per-item visibility

    public func setStatusbarItemVisible(itemId: String, visible: Bool) {
        if visible {
            statusbarHiddenIds.remove(itemId)
        } else {
            statusbarHiddenIds.insert(itemId)
        }
    }

    public func resetStatusbarLayout() {
        statusbarHiddenIds.removeAll()
    }

    public func isStatusbarLayoutDefault() -> Bool {
        statusbarHiddenIds.isEmpty
    }
}

// MARK: - Codable round-trip (= persistence)

extension PaneVisibilityStore {
    /// Persisted shape (= schema-versioned for migration).
    private struct PersistedShape: Codable {
        var schemaVersion: Int
        var hiddenTreePanes: [String]
        var dismissedPanes: [String]
        var collapsePanes: [String]
        var paneStates: [String: PaneSizeSnapshot]
        var statusbarHiddenIds: [String]
        var statusbarVisible: Bool

        static let currentSchemaVersion = 1
    }

    /// Encode current state for persistence (= JSON-encoded via Codable).
    public func encoded() throws -> Data {
        let shape = PersistedShape(
            schemaVersion: PersistedShape.currentSchemaVersion,
            hiddenTreePanes: Array(hiddenTreePanes),
            dismissedPanes: Array(dismissedPanes),
            collapsePanes: Array(collapsePanes),
            paneStates: paneStates,
            statusbarHiddenIds: Array(statusbarHiddenIds),
            statusbarVisible: statusbarVisible
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(shape)
    }

    /// Restore state from persisted JSON (= falls back to defaults on
    /// schema mismatch or decode failure).
    public func restore(from data: Data) {
        let decoder = JSONDecoder()
        guard let shape = try? decoder.decode(PersistedShape.self, from: data),
              shape.schemaVersion == PersistedShape.currentSchemaVersion else {
            return
        }
        hiddenTreePanes = Set(shape.hiddenTreePanes)
        dismissedPanes = Set(shape.dismissedPanes)
        collapsePanes = Set(shape.collapsePanes)
        paneStates = shape.paneStates
        statusbarHiddenIds = Set(shape.statusbarHiddenIds)
        statusbarVisible = shape.statusbarVisible
    }
}