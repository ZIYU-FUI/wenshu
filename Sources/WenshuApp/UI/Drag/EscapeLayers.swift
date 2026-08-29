// EscapeLayers.swift · Wenshu (文枢) · v0.28 followup TKT-028-024
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// escape layer priority queue + narrow viewport + floating panes from
// Hermes Desktop verbatim.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/lib/escape-layers.ts
// = ESCAPE_PRIORITY enum (editMode > narrowOverlay > dialog > contextMenu)
//   + pushEscapeLayer(priority) → disposer
//   + isTopEscapeLayer(priority) → bool
//
// And: hermes pane-shell/tree/renderer/narrow-overlays.tsx
// = \$narrowViewport atom (= reactive narrow state, auto-collapse sidebar
//   below SIDEBAR_COLLAPSE_MEDIA_QUERY)
// + NarrowOverlays (= hover-strip reveal + pinned reveal via ⌘B / ⌘G)
//
// And: hermes pane-shell/tree/renderer/floating-panes.tsx
// = placement: 'floating' (= opt-out of layout tree)
//   + drag by header + persisted position per pane id

import Foundation
import SwiftUI
import AppKit

// MARK: - Escape priority (= matches hermes ESCAPE_PRIORITY enum)

/// Escape priority level. Higher priority escapes first; the top-most
/// (= highest priority) layer handles Escape (= its layer is dismissed).
/// Matches Hermes `ESCAPE_PRIORITY` enum verbatim (= editMode >
/// narrowOverlay > dialog > contextMenu).
public enum EscapePriority: Int, Comparable, Sendable {
    case contextMenu = 0
    case dialog = 10
    case narrowOverlay = 20
    case layoutEdit = 30

    public static func < (lhs: EscapePriority, rhs: EscapePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Escape layer (= an active escape handler). Holds the priority +
/// an identifier so we can dismiss layers in LIFO order.
public final class EscapeLayer: @unchecked Sendable {
    public let id: UUID
    public let priority: EscapePriority
    public init(priority: EscapePriority) {
        self.id = UUID()
        self.priority = priority
    }
}

/// Escape layer manager (= one per app, shared across all dismissable
/// overlays). Layers are pushed in LIFO order; isTopEscapeLayer checks
/// if the given priority is the current top.
@MainActor
public final class EscapeLayerManager {
    private var layers: [EscapeLayer] = []

    public init() {}

    /// Current top layer (= highest priority) or nil if none.
    public var topLayer: EscapeLayer? {
        layers.max(by: { $0.priority < $1.priority })
    }

    /// Push a new layer; returns the layer (= caller can dismiss it).
    public func push(_ priority: EscapePriority) -> EscapeLayer {
        let layer = EscapeLayer(priority: priority)
        layers.append(layer)
        return layer
    }

    /// Dismiss (= remove) a layer by id (= disposer from push()).
    public func dismiss(_ layer: EscapeLayer) {
        layers.removeAll { $0.id == layer.id }
    }

    /// True iff the given priority is the top-most (= owns Escape).
    public func isTop(_ priority: EscapePriority) -> Bool {
        guard let top = topLayer else { return false }
        return top.priority == priority
    }
}

// MARK: - Narrow viewport state (= matches hermes \$narrowViewport)

/// Sidebar collapse breakpoint (= below this width, sidebar auto-collapses
/// to hover strip + reveals via NarrowOverlays). Matches Hermes
/// `SIDEBAR_COLLAPSE_MEDIA_QUERY` (typically `(max-width: 1023px)`).
public let kSidebarCollapseBreakpoint: CGFloat = 1024

/// Reactive narrow viewport state (= sidebar should auto-collapse).
@MainActor
@Observable
public final class NarrowViewportState {
    public var isNarrow: Bool = false

    public init() {}

    /// Update narrow state (= called from a GeometryReader's onChange).
    public func update(width: CGFloat) {
        isNarrow = width < kSidebarCollapseBreakpoint
    }
}

// MARK: - Floating pane registry (= non-tiling placement)

/// A pane that opts OUT of the layout tree (= rendered as a floating
/// card above the tree). Persists position per pane id. Matches
/// Hermes `placement: 'floating'` (= opt-out of layout tree).
public struct FloatingPanePlacement: Codable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var collapsed: Bool

    public init(x: CGFloat, y: CGFloat, collapsed: Bool = false) {
        self.x = x
        self.y = y
        self.collapsed = collapsed
    }
}

/// Registry for floating pane positions (= persisted across launches).
/// Stored at `wenshu.workspace.floating.v1` (= matches Hermes
/// `hermes.desktop.floatingPanes.v1` key pattern).
@MainActor
@Observable
public final class FloatingPaneRegistry {
    public private(set) var positions: [String: FloatingPanePlacement] = [:]

    public init() {}

    public func setPosition(_ paneId: String, _ placement: FloatingPanePlacement) {
        positions[paneId] = placement
    }

    public func getPosition(_ paneId: String) -> FloatingPanePlacement? {
        positions[paneId]
    }

    public func remove(_ paneId: String) {
        positions.removeValue(forKey: paneId)
    }

    public func toggleCollapsed(_ paneId: String) {
        guard var pos = positions[paneId] else { return }
        pos.collapsed.toggle()
        positions[paneId] = pos
    }

    // MARK: - Codable persistence (= matches hermes floatingPanes storage)

    /// JSON-encoded representation for UserDefaults.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(positions)
    }

    /// Restore from JSON (= empty if format mismatch).
    public func restore(from data: Data) {
        guard let decoded = try? JSONDecoder().decode([String: FloatingPanePlacement].self, from: data) else {
            return
        }
        positions = decoded
    }
}

// MARK: - Escape layer ViewModifier

/// SwiftUI View modifier that pushes an Escape layer when the view
/// appears + dismisses when it disappears. Caller owns the priority
/// (= matches the layer's semantic role).
public struct EscapeLayerView: ViewModifier {
    let priority: EscapePriority
    @Environment(\.escapeLayerManagerBox) private var managerBox
    @State private var layer: EscapeLayer?

    public func body(content: Content) -> some View {
        content
            .onAppear {
                layer = managerBox.manager.push(priority)
            }
            .onDisappear {
                if let layer {
                    managerBox.manager.dismiss(layer)
                }
            }
    }
}

extension View {
    /// Register an Escape layer (= caller-managed priority). Use
    /// `.escapeLayer(.dialog)` etc. The View's onAppear pushes; onDisappear
    /// pops. Only the top-most layer handles Escape (= see `EscapeLayerManager`).
    public func escapeLayer(_ priority: EscapePriority) -> some View {
        modifier(EscapeLayerView(priority: priority))
    }
}

// MARK: - EscapeLayerManager environment (= SwiftUI bridge)

/// Box wrapper for `EscapeLayerManager` (= environment values require
/// reference types).
public final class EscapeLayerManagerBox: @unchecked Sendable {
    public let manager: EscapeLayerManager
    public init() {
        // EscapeLayerManager is @MainActor; we initialize it lazily.
        // The manager is created on first access via MainActor.run.
        self.manager = MainActor.assumeIsolated { EscapeLayerManager() }
    }
}

private struct EscapeLayerManagerBoxEnvironmentKey: EnvironmentKey, @unchecked Sendable {
    static var defaultValue: EscapeLayerManagerBox { EscapeLayerManagerBox() }
}

extension EnvironmentValues {
    public var escapeLayerManagerBox: EscapeLayerManagerBox {
        get { self[EscapeLayerManagerBoxEnvironmentKey.self] }
        set { self[EscapeLayerManagerBoxEnvironmentKey.self] = newValue }
    }
}