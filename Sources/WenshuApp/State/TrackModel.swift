// TrackModel.swift · Wenshu (文枢) · v0.28 followup TKT-028-033
//
// Boss 2026-08-29 OOB '100% 复刻, 做到极致' = port the
// `track-model.ts` verbatim (= MIN_PANE_PX, COLLAPSED_ZONE_PX,
// MINIMIZED_TRACK, PaneSizing, fixed/flex/uncapped resolution).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/tree/renderer/track-model.ts
// = 1. MIN_PANE_PX = 80 (floor for non-tool panes)
//   2. COLLAPSED_ZONE_PX = 28 (floor for tool panels like terminal/logs
//      that collapse to a rail)
//   3. MINIMIZED_TRACK = '1.75rem' (= 28 PT, collapsed zone rail)
//   4. PaneSizing (= width/height/minWidth/maxWidth/minHeight/maxHeight)
//   5. TrackKind enum (= .fixed | .flex | .uncapped)
//   6. cssMax() pure function (= max() of CSS strings)
//   7. PaneSizeContribution (= the pane-level sizing contribution)
//   8. Fixed track resolution (= fixed if all children declare size,
//      flex otherwise)
//
// This file = SwiftUI port:
// - kMinPanePX = 80 (= matches Hermes MIN_PANE_PX)
// - kCollapsedZonePX = 28 (= matches Hermes COLLAPSED_ZONE_PX)
// - kMinimizedTrack: CGFloat = 28 (= matches Hermes MINIMIZED_TRACK = 1.75rem @ 16 PT base)
// - TrackKind enum (= .fixed | .flex | .uncapped)
// - PaneSizeContribution (= width/height/min/max in PT)
// - cssMaxPx(_:) pure function
// - PaneSizeMode for PaneFrame (= replaces PaneFrame.flex with explicit mode)

import SwiftUI

// MARK: - Track model constants (= hermes verbatim)

/// Floor for a non-tool pane (= the sash lets it shrink down to this
/// before it collapses). Matches Hermes `MIN_PANE_PX = 80`.
public let kMinPanePX: CGFloat = 80

/// Floor for a tool panel zone (= terminal / logs). A tool panel is
/// meant to be draggable down to nothing (= the minimized rail is the
/// smallest meaningful form, so the sash lets it shrink to exactly
/// that and then collapses the zone rather than jamming against an
/// 80px floor with a sliver of unusable content still showing).
/// Matches Hermes `COLLAPSED_ZONE_PX = 28`.
public let kCollapsedZonePX: CGFloat = 28

/// A minimized zone IS its strip (= vertical rail row / header column)
/// — both 28 PT thick. Matches Hermes `MINIMIZED_TRACK = '1.75rem'`
/// (= 1.75 * 16 = 28 PT).
public let kMinimizedTrack: CGFloat = 28

// MARK: - Track kind

/// Whether a pane's size along a split axis is:
/// - `.fixed` = pane declares a width/height (= sidebars keep their size,
///   weighted zones absorb the rest)
/// - `.flex` = pane has no declared width/height (= weight-shared leftover)
/// - `.uncapped` = like `.flex` but with no maxWidth/maxHeight clamp
///   (= the last child in an all-fixed split absorbs leftover space)
public enum TrackKind: String, Codable, Sendable, Equatable {
    case fixed
    case flex
    case uncapped
}

// MARK: - Pane size contribution (= pane's declared sizing)

/// Pane sizing contribution. Matches Hermes `PaneSizing` interface
/// (= width/height/min/max along both axes). All values are in PT
/// (= points, the macOS-native unit). `nil` (= no declaration; the
/// pane is flex-at-heart).
public struct PaneSizeContribution: Equatable, Codable, Sendable {
    public var width: CGFloat?
    public var height: CGFloat?
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var minHeight: CGFloat?
    public var maxHeight: CGFloat?

    public init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil
    ) {
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    public var isEmpty: Bool {
        width == nil && height == nil && minWidth == nil && maxWidth == nil
            && minHeight == nil && maxHeight == nil
    }
}

// MARK: - Pure helper: cssMax

/// max() of the defined values. Matches Hermes `cssMax()` (= dedupes
/// + returns `max(a, b, ...)` when more than one value, or the single
/// value when only one). `nil` when no values.
public func cssMaxPx(_ values: [CGFloat?]) -> CGFloat? {
    let defined = values.compactMap { $0 }
    let unique = Array(Set(defined))
    if unique.isEmpty { return nil }
    return unique.max()
}

// MARK: - Track kind resolver

/// Determine the track kind for a group (= `.fixed` if it declares a
/// width/height along the axis, `.flex` otherwise). Matches Hermes
/// `fixedTrackSize()` semantics (= a MAIN-bearing zone is flex-at-heart).
///
/// - Parameters:
///   - panes: The group's panes (= their size contributions).
///   - axis: The split axis (= `.row` = horizontal, `.column` = vertical).
///   - hasMainPane: True if any pane in the group is a `placement: 'main'`
///     pane (= workspace/tile). Main-bearing zones are flex-at-heart
///     regardless of size declarations (= matching Hermes).
public func resolveTrackKind(
    panes: [PaneSizeContribution],
    axis: SplitAxis,
    hasMainPane: Bool = false
) -> TrackKind {
    // Main-bearing zones are flex-at-heart (= matches Hermes
    // `if (sizes.length !== declaredSizes.length && ids.some(id =>
    // paneChrome(ctx.paneFor(id)).placement === 'main')) return null`).
    let sizes = panes.map { axis == .row ? $0.width : $0.height }
    let declaredSizes = sizes.compactMap { $0 }
    if declaredSizes.count < sizes.count && hasMainPane {
        return .flex
    }
    if declaredSizes.isEmpty {
        return .flex
    }
    // Has declared size along axis → fixed track.
    return .fixed
}

// MARK: - Axis (= row vs column)

/// Split axis (= row = horizontal, column = vertical). Matches Hermes
/// track-model.ts `axis: 'row' | 'column'`. Named `SplitAxis` to avoid
/// collision with SwiftUI's `Axis` (= same enum values).
public enum SplitAxis: String, Codable, Sendable, Equatable {
    case row
    case column
}

// MARK: - PaneFrame mode (= extended for fixed/flex/uncapped)

/// Extended PaneFrame (= existing Wenshu `PaneFrame` has `flex` only;
/// this addition adds explicit mode + min/max clamps). Wenshu
/// `PaneFrame` is the per-pane sizing contribution; this struct
/// enriches it with TrackKind + optional size contribution.
///
/// For backward compatibility (= existing call sites use
/// `PaneFrame.minWidth/idealWidth/flex`), we provide convenience
/// initializers:
/// - `PaneFrame.minWidth(_:)` = flex pane with minWidth floor
/// - `PaneFrame.fixed(_:)` = fixed pane with exact width
/// - `PaneFrame.flex(_:)` = flex pane with weight
public struct PaneFrameMode: Equatable, Codable, Sendable {
    public var mode: TrackKind
    public var size: CGFloat?           // width (row axis) or height (column axis)
    public var minWidth: CGFloat?       // min along primary axis (= row)
    public var idealWidth: CGFloat?     // ideal (= unused in pure track model, kept for compat)
    public var flex: CGFloat            // weight (= 1.0 default)
    public var maxWidth: CGFloat?       // max along primary axis (= row)

    public init(
        mode: TrackKind = .flex,
        size: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        flex: CGFloat = 1.0,
        maxWidth: CGFloat? = nil
    ) {
        self.mode = mode
        self.size = size
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.flex = flex
        self.maxWidth = maxWidth
    }
}

// MARK: - All-fixed absorber (= the last uncapped track absorbs leftover)

/// Returns the child index to absorb leftover space, or `-1` when
/// every fixed track is capped (= leave dead space; better than a
/// ballooned sidebar). Matches Hermes `allFixedAbsorberIndex()`.
///
/// In an all-fixed split, the last uncapped track may absorb leftover
/// space (= terminal/logs stacked at 38vh with nothing else to fill
/// the column). A CAPPED track must never be the absorber: review/files
/// declare maxWidth 20rem, and promoting them to grow-1 + dropping
/// the clamp made ⌘G / ⌘J open a half-window rail and ignore
/// sash-remembered sizes (= flex-basis alone can't hold against grow).
public func allFixedAbsorberIndex(
    growable: [Int],
    maxAlongAxis: (Int) -> CGFloat?
) -> Int {
    if growable.isEmpty { return -1 }
    for i in growable.reversed() {
        if maxAlongAxis(i) == nil {
            return i
        }
    }
    return -1
}