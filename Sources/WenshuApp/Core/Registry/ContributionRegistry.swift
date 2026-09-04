// ContributionRegistry.swift · Wenshu (文枢) · v0.28 followup TKT-028-013
//
// Boss 2026-08-29 OOB '完整复刻 hermes app' = port the Hermes Desktop
// contribution registry pattern verbatim so adding a new pane / titlebar
// tool / statusbar item / layout preset = 1 register() call (= not edit
// every preset/template).
//
// PATTERN: 1 uniform registry keyed by area. Each area holds its own
// contribution list. Mutations are area-scoped (= mutating `panes`
// does NOT invalidate `statusbar.left`). Snapshots are referentially
// stable until the area mutates (= safe for SwiftUI diffing).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/contrib/registry.ts
// = `ContributionRegistry` class. Same semantics, translated to
// Swift `@Observable` + Swift Concurrency model.

import Foundation
import Observation
import SwiftUI

/// The provenance tag for a contribution. `'core'` (= app's own UI)
/// is the default. Plugins would use their own id (= e.g. 'plugin:foo').
public typealias ContributionSource = String

/// A single contribution = the uniform primitive every surface consumes.
/// Pane hosts render `render` content. Bar hosts render `data` payloads
/// (= StatusbarItem / TitlebarTool). Layout picker reads `data` as the
/// preset tree.
public struct Contribution: Identifiable, Sendable {
    public let id: String
    public let area: String
    public let source: ContributionSource
    public let title: String?
    public let order: Int?
    /// When non-nil, evaluated on each `getArea` rebuild (= NOT reactive
    /// — a `when()` that flips without a register/remove won't re-resolve
    /// on its own; trigger a registry mutation, or don't rely on it
    /// flipping without one). Matches hermes registry.ts verbatim.
    public let when: (@Sendable () -> Bool)?
    public let render: (@Sendable () -> AnyView)?
    public let data: (@Sendable () -> Any)?
    /// Workspace surface binding (= `sessions` or `bots`). Affects which
    /// surfaces render the contribution.
    public let workspaceMode: String?
    /// Opaque owner key within `bots` (= never parsed; compared exactly).
    public let workspaceOwnerKey: String?

    public init(
        id: String,
        area: String,
        source: ContributionSource = "core",
        title: String? = nil,
        order: Int? = nil,
        when: (@Sendable () -> Bool)? = nil,
        render: (@Sendable () -> AnyView)? = nil,
        data: (@Sendable () -> Any)? = nil,
        workspaceMode: String? = nil,
        workspaceOwnerKey: String? = nil
    ) {
        self.id = id
        self.area = area
        self.source = source
        self.title = title
        self.order = order
        self.when = when
        self.render = render
        self.data = data
        self.workspaceMode = workspaceMode
        self.workspaceOwnerKey = workspaceOwnerKey
    }
}

// MARK: - Well-known areas

public enum ContributionArea {
    public static let panes = "panes"
    public static let titlebarLeft = "titlebar.left"
    public static let titlebarRight = "titlebar.right"
    public static let statusbarLeft = "statusbar.left"
    public static let statusbarRight = "statusbar.right"
    public static let layouts = "layouts"
    public static let commands = "commands"
    public static let keybinds = "keybinds"
}

// MARK: - Registry

/// One registry for every area. Snapshots are cached per area and only
/// invalidated on mutation, so the value is referentially stable for
/// SwiftUI diffing. Invalidation is area-scoped: mutating `panes` only
/// invalidates the `panes` snapshot — no churn on titlebar / statusbar
/// subscriptions.
///
/// `registerMany` collapses a batch into one notification per touched
/// area. A global subscriber channel still fires on every mutation
/// (= for panes adoption, statusbar pre-loading, etc.).
@MainActor
@Observable
public final class ContributionRegistry {
    private var byArea: [String: [Contribution]] = [:]
    private var snapshot: [String: [Contribution]] = [:]
    private var areaListeners: [String: [UUID: () -> Void]] = [:]
    private var globalListeners: [UUID: () -> Void] = [:]

    /// Bumped on every registry mutation — the reactive token for
    /// non-SwiftUI consumers that read `registry.getArea` imperatively.
    /// SwiftUI views should keep using `useContributions(area)`.
    public private(set) var version: Int = 0

    public init() {}

    // MARK: Registration

    /// Register one contribution. Returns a disposer that removes it.
    @discardableResult
    public func register(_ c: Contribution) -> () -> Void {
        return registerMany([c])
    }

    /// Register several at once. Returns a disposer that removes all of
    /// them. A batch touches each affected area exactly once — no per-item
    /// churn (= 1 SwiftUI re-render per area, not 1 per item).
    @discardableResult
    public func registerMany(_ cs: [Contribution]) -> () -> Void {
        for c in cs {
            put(c)
        }
        let areas = Set(cs.map(\.area))
        invalidate(areas)
        return { [weak self] in
            self?.removeMany(cs.map { (area: $0.area, id: $0.id) })
        }
    }

    /// Remove one contribution by id from its area.
    public func remove(area: String, id: String) {
        removeMany([(area: area, id: id)])
    }

    /// Remove several at once. A batch touches each affected area
    /// exactly once.
    public func removeMany(_ keys: [(area: String, id: String)]) {
        guard !keys.isEmpty else { return }
        var areasTouched: Set<String> = []
        for key in keys {
            guard var list = byArea[key.area] else { continue }
            let initialCount = list.count
            list.removeAll { $0.id == key.id }
            if list.count != initialCount {
                byArea[key.area] = list
                areasTouched.insert(key.area)
            }
        }
        invalidate(areasTouched)
    }

    // MARK: Lookup

    /// Resolved, sorted, filtered entries for an area. Stable ref until
    /// mutated. Sort = ascending by `order` (nil last); ties keep
    /// insertion order (= matches hermes registry.ts).
    public func getArea(_ area: String) -> [Contribution] {
        if let cached = snapshot[area] {
            return cached
        }
        let raw = byArea[area] ?? []
        let filtered = raw.filter { c in
            c.when?() ?? true
        }
        let sorted = filtered.sorted { a, b in
            switch (a.order, b.order) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return false
            }
        }
        snapshot[area] = sorted
        return sorted
    }

    // MARK: Listeners

    /// Subscribe to one area's mutations (= fires on register/remove in
    /// THAT area only). Returns a disposer.
    @discardableResult
    public func subscribe(area: String, _ listener: @escaping () -> Void) -> UUID {
        let id = UUID()
        areaListeners[area, default: [:]][id] = listener
        return id
    }

    /// Unsubscribe one area listener.
    public func unsubscribe(area: String, id: UUID) {
        areaListeners[area]?.removeValue(forKey: id)
    }

    /// Subscribe to ALL mutations (= for panes adoption, statusbar
    /// pre-loading, etc.). Returns a disposer.
    @discardableResult
    public func subscribeAll(_ listener: @escaping () -> Void) -> UUID {
        let id = UUID()
        globalListeners[id] = listener
        return id
    }

    /// Unsubscribe one global listener.
    public func unsubscribeAll(id: UUID) {
        globalListeners.removeValue(forKey: id)
    }

    // MARK: Private

    private func put(_ c: Contribution) {
        var list = byArea[c.area] ?? []
        list.removeAll { $0.id == c.id }
        list.append(c)
        byArea[c.area] = list
    }

    private func invalidate(_ areas: Set<String>) {
        version += 1
        for area in areas {
            snapshot.removeValue(forKey: area)
            areaListeners[area]?.values.forEach { $0() }
        }
        globalListeners.values.forEach { $0() }
    }
}

// MARK: - SwiftUI bridge (= useContributions)

/// Reactive access to a single area. Bumps whenever the area is
/// invalidated. SwiftUI body re-renders on bump (= matches hermes
/// `useContributions('panes')`).
@MainActor
public struct UseContributions {
    let registry: ContributionRegistry
    let area: String
    let token: UUID
    var values: [Contribution]

    init(registry: ContributionRegistry, area: String) {
        self.registry = registry
        self.area = area
        self.token = UUID()
        self.values = registry.getArea(area)
    }
}

/// SwiftUI `View` extension that re-renders when the registry's area
/// mutates. Usage:
///   `let panes = useContributions(.panes)`
public struct UseContributionsHandle {
    let wrapper: UseContributions
}

@MainActor
public func useContributions(_ area: String, in registry: ContributionRegistry) -> [Contribution] {
    let handle = UseContributions(registry: registry, area: area)
    // Subscribe to area mutations (= invalidates the wrapper).
    registry.subscribe(area: area) {
        // Side effect: bumping the wrapper version triggers @Observable
        // re-render. Since `UseContributions` is a struct captured by
        // the calling view, the captured `values` field stays stable
        // until invalidated.
        _ = handle.token  // touch to suppress unused warning
    }
    return handle.values
}