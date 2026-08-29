// PaneLifecycle.swift · Wenshu (文枢) · v0.28 followup TKT-028-013
//
// Boss 2026-08-29 OOB '完整复刻 hermes app' = port the 3-state pane
// lifecycle cache from Hermes Desktop verbatim. The foreground pane
// is visible; the most recently visible inactive panes stay hot up
// to a small cap (= default 2); the rest park (= unmounted).
// Explicit keep-alive panes (terminal, logs) stay hot outside the cap
// so hiding UI never kills the stateful resource they host.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/pane-lifecycle.ts
// = PaneLifecycle = 'visible' | 'hot-hidden' | 'parked' +
// reconcilePaneLifecycle() pure function.

import Foundation

/// One pane's lifecycle state. The mount cost is `visible` > `hot-hidden`
/// > `parked`. `parked` panes are unmounted (= no DOM, no View).
public enum PaneLifecycle: String, Codable, Sendable {
    /// Foreground tab (= fully rendered, fully interactive).
    case visible
    /// Recently visible inactive tab (= mounted, but render budget
    /// reduced; e.g. live subscriptions gated off). Capped at
    /// `DEFAULT_HOT_HIDDEN_PANE_CAP` (= 2).
    case hotHidden
    /// Beyond cap (= unmounted; state lost on unmount).
    case parked
}

/// Default cap for inactive panes that stay mounted (= "hot-hidden").
/// Matches Hermes `DEFAULT_HOT_HIDDEN_PANE_CAP = 2`.
public let kDefaultHotHiddenPaneCap: Int = 2

/// One pane's lifecycle entry.
public struct PaneLifecycleEntry: Equatable, Sendable {
    public var lifecycle: PaneLifecycle
    public var lastVisible: Int

    public init(lifecycle: PaneLifecycle, lastVisible: Int) {
        self.lifecycle = lifecycle
        self.lastVisible = lastVisible
    }
}

/// Per-zone state (= the cache that tracks mount/unmount decisions).
public struct PaneLifecycleState: Equatable, Sendable {
    public var clock: Int
    public var entries: [String: PaneLifecycleEntry]

    public init(clock: Int = 0, entries: [String: PaneLifecycleEntry] = [:]) {
        self.clock = clock
        self.entries = entries
    }
}

/// Returns the empty (= initial) lifecycle state for one zone.
public func emptyPaneLifecycleState() -> PaneLifecycleState {
    PaneLifecycleState(clock: 0, entries: [:])
}

/// Options for one reconcile pass.
public struct ReconcilePaneLifecycleOptions {
    public var activeId: String
    public var hotHiddenCap: Int
    public var keepAlive: (String) -> Bool
    public var paneIds: [String]

    public init(
        activeId: String,
        hotHiddenCap: Int = kDefaultHotHiddenPaneCap,
        keepAlive: @escaping (String) -> Bool = { _ in false },
        paneIds: [String]
    ) {
        self.activeId = activeId
        self.hotHiddenCap = hotHiddenCap
        self.keepAlive = keepAlive
        self.paneIds = paneIds
    }
}

/// Reconcile one zone's mounted pane cache. Pure function: takes the
/// previous state + options, returns the new state.
///
/// Algorithm (= matches Hermes pane-lifecycle.ts verbatim):
/// 1. Any pane NOT in `paneIds` is dropped from entries.
/// 2. The active pane is marked `visible` (= bumps clock).
/// 3. Other panes (= inactive) are sorted by `lastVisible` descending.
/// 4. `keepAlive` panes are marked `hot-hidden` (always).
/// 5. The next `hotHiddenCap` panes (= sorted by lastVisible) are marked
///    `hot-hidden`.
/// 6. The rest are marked `parked`.
public func reconcilePaneLifecycle(
    previous: PaneLifecycleState,
    options: ReconcilePaneLifecycleOptions
) -> PaneLifecycleState {
    let present = Set(options.paneIds)
    var entries: [String: PaneLifecycleEntry] = [:]
    var clock = previous.clock

    // Step 1: prune panes no longer present.
    for id in options.paneIds {
        if let prior = previous.entries[id] {
            entries[id] = PaneLifecycleEntry(
                lifecycle: .parked,  // default; will override below
                lastVisible: prior.lastVisible
            )
        }
    }
    _ = present  // suppress unused warning; present is used implicitly via paneIds loop

    // Step 2: active pane is visible.
    if options.paneIds.contains(options.activeId) {
        let prior = previous.entries[options.activeId]
        if prior == nil || prior?.lifecycle != .visible {
            clock += 1
        }
        entries[options.activeId] = PaneLifecycleEntry(
            lifecycle: .visible,
            lastVisible: clock
        )
    }

    // Step 3: sort inactive panes by lastVisible desc.
    let inactive = options.paneIds
        .filter { $0 != options.activeId && entries[$0] != nil }
        .sorted { (a, b) -> Bool in
            let la = entries[a]?.lastVisible ?? 0
            let lb = entries[b]?.lastVisible ?? 0
            return la > lb
        }

    // Step 4: keepAlive panes are hot-hidden (always).
    for id in inactive.filter(options.keepAlive) {
        if var entry = entries[id] {
            entry.lifecycle = .hotHidden
            entries[id] = entry
        }
    }

    // Step 5: next hotHiddenCap panes (= sorted by lastVisible) are hot-hidden.
    let cap = max(0, options.hotHiddenCap)
    let candidates = inactive.filter { !options.keepAlive($0) }
    for id in candidates.prefix(cap) {
        if var entry = entries[id] {
            entry.lifecycle = .hotHidden
            entries[id] = entry
        }
    }

    // Step 6: rest are parked (= already parked from step 1; no-op).

    return PaneLifecycleState(clock: clock, entries: entries)
}