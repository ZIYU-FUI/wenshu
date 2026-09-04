// TreeHistory.swift · Wenshu (文枢) · v0.28 followup TKT-028-025
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// undo/redo pattern (= pure tree operations, each destructive op
// pushes the previous tree to history) from Hermes Desktop verbatim.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/store.ts
// = Each destructive op (= removePane / setSplitWeights /
//   setActivePane / setGroupMinimized / dismissTreePane) is a pure
//   function on the tree. The tree state IS the history (= no separate
//   history stack needed). Hermes implements undo via 'applyTree(prevTree)'
//   which restores the entire tree state (= not per-op undo).

import Foundation

/// Bounded ring buffer for tree history. Cap = 50 entries (= matches
/// hermes `undoStack` cap). When full, oldest entry is dropped.
public final class TreeHistory: @unchecked Sendable {
    public static let defaultCap: Int = 50

    private let cap: Int
    private var entries: [LayoutNode] = []
    private var redoEntries: [LayoutNode] = []
    private let lock = NSLock()

    public init(cap: Int = TreeHistory.defaultCap) {
        self.cap = cap
    }

    /// Number of undo entries.
    public var undoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    /// Number of redo entries.
    public var redoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return redoEntries.count
    }

    /// Record a destructive operation (= push the BEFORE tree to history).
    /// Clears the redo stack (= standard undo/redo behavior).
    func record(before: LayoutNode) {
        lock.lock()
        entries.append(before)
        if entries.count > cap {
            entries.removeFirst(entries.count - cap)
        }
        // Clear redo stack on new action.
        redoEntries.removeAll()
        lock.unlock()
    }

    /// Undo: pop the most recent tree (= BEFORE state) and push the
    /// current tree to redo stack. Returns nil if no history.
    func undo(currentTree: LayoutNode) -> LayoutNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let lastEntry = entries.popLast() else { return nil }
        redoEntries.append(currentTree)
        if redoEntries.count > cap {
            redoEntries.removeFirst(redoEntries.count - cap)
        }
        return lastEntry
    }

    /// Redo: pop the most recent redo entry (= AFTER state) and push
    /// the current tree to undo stack. Returns nil if no redo.
    func redo(currentTree: LayoutNode) -> LayoutNode? {
        lock.lock()
        defer { lock.unlock() }
        guard let nextRedo = redoEntries.popLast() else { return nil }
        entries.append(currentTree)
        if entries.count > cap {
            entries.removeFirst(entries.count - cap)
        }
        return nextRedo
    }

    /// Clear all history (= e.g. after applying a preset).
    public func clear() {
        lock.lock()
        entries.removeAll()
        redoEntries.removeAll()
        lock.unlock()
    }

    /// Most recent undo entry (= shown as hint in statusbar).
    var lastUndoEntry: LayoutNode? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last
    }
}

// MARK: - WorkspaceStore extension for undo/redo

extension WorkspaceStore {
    /// Undo the most recent tree change (= applies the BEFORE tree).
    /// Pushes the current tree to redo stack.
    func undoTreeChange() -> Bool {
        guard let history = self.treeHistory else { return false }
        guard let beforeTree = history.undo(currentTree: self.workspace.root) else { return false }
        self.workspace.root = beforeTree
        save()
        return true
    }

    /// Redo the most recently undone tree change.
    func redoTreeChange() -> Bool {
        guard let history = self.treeHistory else { return false }
        guard let afterTree = history.redo(currentTree: self.workspace.root) else { return false }
        self.workspace.root = afterTree
        save()
        return true
    }
}

// MARK: - WorkspaceStore treeHistory (= bound to workspace state)

private nonisolated(unsafe) var _treeHistoryKey: UInt8 = 0

extension WorkspaceStore {
    /// History bound to this store (= lives for the store's lifetime).
    /// Set up automatically via `prepareUndoRedo` (= one-time setup
    /// on store init).
    var treeHistory: TreeHistory? {
        get {
            return objc_getAssociatedObject(self, &_treeHistoryKey) as? TreeHistory
        }
        set {
            objc_setAssociatedObject(self, &_treeHistoryKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}