//
//  ZoneLayout.swift · Wenshu (文枢) · B-07 ticket 028-003
//
//  Single source of truth for which `TabKind` (= which functional
//  module / pane) ships into which `ZoneSlot` (= which of the six
//  zones in wenshu's default 6-zone layout).
//
//  Replaces the implicit, hard-coded mapping that lived inside
//  `WorkspaceStore.builtinDefaultPreset()` (= the FCP-Browser /
//  6-zone preset shipped in v0.30) with an explicit, testable
//  data structure. Future 028-005 followup will have the preset
//  read `PaneZoneLayout.default.mapping` instead of re-stating the
//  same wiring inline.
//
//  Two surfaces are deliberately OUTSIDE the 6-zone grid:
//
//    - Reference library (= `library-public` Wiki) = global,
//      opens as a separate window via Sidebar.
//    - Settings = macOS standard `Settings` scene, separate window.
//
//  Both are covered by tests #3 and #4.
//
//  Per ADR-0008: zero new dependencies; pure-Swift data layer.
//

import Foundation

// MARK: - ZoneSlot canonical ordering

extension ZoneSlot {
    /// Canonical ordering of the six zones (= projectSidebar first,
    /// aiDynamic last). The order matches the visual layout's
    /// upper-band-then-lower-band enumeration so the picker UI can
    /// iterate deterministically.
    ///
    /// `ZoneSlot` is a plain Swift enum (= no raw type) so it does
    /// not auto-synthesize `allCases`. We expose the canonical list
    /// here as a static let.
    static let allCases: [ZoneSlot] = [
        .projectSidebar,
        .projectPreview,
        .editor,
        .specializedTools,
        .aiChat,
        .aiDynamic,
    ]

    /// Stable identifier string (= used by UserDefaults keys + tests).
    /// Matches the `TabKind` raw values for 1:1 lookup symmetry.
    var identifier: String {
        switch self {
        case .projectSidebar:   return "projectSidebar"
        case .projectPreview:   return "projectPreview"
        case .editor:           return "editor"
        case .specializedTools: return "specializedTools"
        case .aiChat:           return "aiChat"
        case .aiDynamic:        return "aiDynamic"
        }
    }
}

// MARK: - PaneZoneLayout

/// `PaneZoneLayout` — the module-to-zone assignment for wenshu's
/// default 6-zone layout (= 1:1 with `ZoneSlot.allCases`).
///
/// The struct is intentionally minimal: a `ZoneSlot -> TabKind`
/// dictionary plus lookup + swap primitives. The renderer
/// (`builtinDefaultPreset()`) does not read from this struct yet
/// (= that wiring is a separate 028-005 followup); for v0.30 this
/// is the document, not the runtime source.
struct PaneZoneLayout: Equatable {

    /// The current zone -> module assignment. Mutable so the user
    /// (= via the layout picker, future ticket) can swap zones
    /// freely. Always covers all six `ZoneSlot` cases in the
    /// `default` instance.
    var mapping: [ZoneSlot: TabKind]

    /// The recommended starting point (= matches `ZoneSlot` 1:1
    /// with its homonymous `TabKind`):
    ///
    /// | Zone             | Module                |
    /// |------------------|----------------------|
    /// | projectSidebar   | .projectSidebar      |
    /// | projectPreview   | .projectPreview      |
    /// | editor           | .editor              |
    /// | specializedTools | .specializedTools    |
    /// | aiChat           | .aiChat              |
    /// | aiDynamic        | .aiDynamic           |
    ///
    /// Matches the v0.30 boss 8/31 OOB ratio table
    /// (`15/20/50/15` upper + `70/30` lower; see
    /// `.scratch/v0.30-pane-routing-splitter-fix/spec.md`).
    static let `default`: PaneZoneLayout = PaneZoneLayout(mapping: [
        .projectSidebar:   .projectSidebar,
        .projectPreview:   .projectPreview,
        .editor:           .editor,
        .specializedTools: .specializedTools,
        .aiChat:           .aiChat,
        .aiDynamic:        .aiDynamic,
    ])

    // MARK: Lookup helpers

    /// The module (= `TabKind`) assigned to the given zone.
    /// Returns `nil` only if the zone is unmapped (= a malformed
    /// layout; `default` always covers all six).
    func module(for zone: ZoneSlot) -> TabKind? {
        mapping[zone]
    }

    /// The zone that hosts the given module. Inverse of
    /// `module(for:)`. Returns `nil` if the module is not present
    /// in the mapping (= e.g. Reference Library or Settings; see
    /// the global-modules docs in the ticket spec).
    func zone(for module: TabKind) -> ZoneSlot? {
        for (zone, kind) in mapping where kind == module {
            return zone
        }
        return nil
    }

    // MARK: Free-layout primitives

    /// Return a new layout where `a` and `b` exchange modules.
    /// Pure (= the receiver is unchanged). If either zone is
    /// unmapped in the receiver, the missing side stays nil
    /// (= symmetric swap, not crash).
    func swapping(_ a: ZoneSlot, _ b: ZoneSlot) -> PaneZoneLayout {
        var copy = self
        let aModule = copy.mapping[a]
        let bModule = copy.mapping[b]
        copy.mapping[a] = bModule
        copy.mapping[b] = aModule
        return copy
    }

    /// In-place swap (= sugar over `swapping(_:_:)` for callers
    /// that already hold a mutable layout).
    mutating func swap(_ a: ZoneSlot, _ b: ZoneSlot) {
        self = swapping(a, b)
    }

    // MARK: Global module inventory

    /// All `TabKind`s the receiver maps into the 6-zone layout.
    /// Equal to the set of `TabKind` values that have a zone.
    var zonedModules: Set<TabKind> {
        Set(mapping.values)
    }

    /// All zones (= convenience for picker UIs and tests).
    var zones: [ZoneSlot] {
        ZoneSlot.allCases.filter { mapping[$0] != nil }
    }
}

// MARK: - Global module catalog (= the modules that are NOT in any zone)

extension PaneZoneLayout {

    /// The set of `TabKind`s that live OUTSIDE the 6-zone grid.
    /// Today this set is empty (= all six `TabKind`s map to a
    /// zone); reference library + settings are documented
    /// separately (= they are not `TabKind`s; they are separate
    /// surfaces with their own windows). See tests #3 and #4.
    static let globalModules: Set<TabKind> = []

    /// Reference library (= `library-public` Wiki) = opens as a
    /// separate window via Sidebar. NOT a `TabKind`; documented
    /// here as the canonical name so tests can assert that no
    /// zone is allowed to host it.
    static let referenceLibraryName: String = "ReferenceLibrary"

    /// Settings = macOS standard `Settings` scene. NOT a `TabKind`;
    /// documented here for the same reason.
    static let settingsName: String = "Settings"
}