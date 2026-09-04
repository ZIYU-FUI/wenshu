// GridToTree.swift · Wenshu (文枢) · v0.28 ticket 028-008
//
// Grid → tree bridge. A FancyZones grid whose zones can be
// produced by recursive guillotine cuts (= every FancyZones
// template + almost every practical layout) converts exactly to
// our runtime `LayoutNode` tree: full-length cut lines become
// splits with weights from the cut positions. Non-guillotine
// arrangements (= interlocking pinwheels) return nil and the
// editor disables Save with an explanation.
//
// Per ticket 028-008 §"Acceptance criteria" #2: this is the
// `GridToTree.swift` file referenced in the spec (= 1:1 port of
// hermes `grid-to-tree.ts`).
//
import Foundation

/// PanePlacementHint — where a pane wants to land in the grid
/// (= from the user's drag-position in the editor; per the hermes
/// `assignZones` semantics).
enum PanePlacementHint: String {
    case main
    case left
    case right
    case top
    case bottom
}

/// PlacedPane — a pane the user is placing into the grid editor
/// (= id + optional placement hint).
struct PlacedPane {
    let id: PaneID
    let placement: PanePlacementHint?
}

// MARK: - Cut algorithm (= hermes `cut` + `cutCandidates` + `isValidCut`)

private func cutCandidates(zones: [GridZone], axis: Axis) -> [Int] {
    let coords: Set<Int> = Set(zones.flatMap { zone -> [Int] in
        switch axis {
        case .x: return [zone.left, zone.right]
        case .y: return [zone.top, zone.bottom]
        }
    })
    // Interior lines only (= drop the first and last edges).
    return coords.sorted().dropFirst().dropLast().map { $0 }
}

private enum Axis { case x, y }

private func isValidCut(zones: [GridZone], axis: Axis, at: Int) -> Bool {
    return zones.allSatisfy { zone in
        switch axis {
        case .x: return zone.right <= at || zone.left >= at
        case .y: return zone.bottom <= at || zone.top >= at
        }
    }
}

/// Recursively cut the zone set. Collects ALL valid cuts on the
/// chosen axis at once so "three columns" becomes one flat 3-child
/// split (= not nested pairs).
///
/// `assignPane` maps each zone index to a list of PaneIDs (= used
/// when the cut bottoms out to a single zone).
private func cut(
    zones: [GridZone],
    assignPane: (Int) -> [PaneID]
) -> LayoutNode? {
    if zones.count == 1 {
        // Single zone → leaf group (= empty if no panes were
        // assigned = editor drop target that lives until the first
        // structural op prunes it via normalize).
        return makeGroup(panes: assignPane(zones[0].index))
    }

    for axis in [Axis.x, Axis.y] {
        let cuts = cutCandidates(zones: zones, axis: axis).filter { isValidCut(zones: zones, axis: axis, at: $0) }
        if cuts.isEmpty { continue }

        let start = zones.map { zone in
            switch axis {
            case .x: return zone.left
            case .y: return zone.top
            }
        }.min() ?? 0
        let end = zones.map { zone in
            switch axis {
            case .x: return zone.right
            case .y: return zone.bottom
            }
        }.max() ?? MULTIPLIER
        let lines = [start] + cuts + [end]

        var children: [LayoutNode] = []
        var weights: [Double] = []

        for i in 0..<(lines.count - 1) {
            let lo = lines[i]
            let hi = lines[i + 1]

            let slice = zones.filter { zone in
                switch axis {
                case .x: return zone.left >= lo && zone.right <= hi
                case .y: return zone.top >= lo && zone.bottom <= hi
                }
            }
            if slice.isEmpty { continue }

            if let child = cut(zones: slice, assignPane: assignPane) {
                children.append(child)
                weights.append(Double(hi - lo))
            }
        }

        if children.isEmpty { return nil }
        if children.count == 1 { return children[0] }
        return makeSplit(
            orientation: axis == .x ? .row : .column,
            children: children,
            weights: weights
        )
    }

    // No full-length cut exists on either axis: non-guillotine
    // (= pinwheel). Return nil to signal "Save disabled".
    return nil
}

// MARK: - Zone assignment (= hermes `assignZones` + `claim`)

private let CENTER: Int = MULTIPLIER / 2

private struct ZoneGeo {
    let index: Int
    let area: Int
    let cx: Int
    let cy: Int
}

/// Compute which panes go into which zones (= semantic role-based
/// assignment: `main` takes the largest zone; `left`/`right`/
/// `top`/`bottom` take zones whose centroid sits on that side).
/// Returns a map: zoneIndex → [PaneID].
private func assignZones(zones: [GridZone], panes: [PlacedPane]) -> [Int: [PaneID]] {
    let geo: [ZoneGeo] = zones.map { z in
        ZoneGeo(
            index: z.index,
            area: (z.right - z.left) * (z.bottom - z.top),
            cx: (z.left + z.right) / 2,
            cy: (z.top + z.bottom) / 2
        )
    }
    var remaining: [Int: ZoneGeo] = Dictionary(uniqueKeysWithValues: geo.map { ($0.index, $0) })
    var assignments: [Int: [PaneID]] = [:]
    var zoneForRole: [String: Int] = [:]

    let mainSpec = (accept: { (_: ZoneGeo) -> Bool in true },
                    score: { (g: ZoneGeo) -> Int in g.area })
    let leftSpec = (accept: { (g: ZoneGeo) -> Bool in g.cx < CENTER },
                   score: { (g: ZoneGeo) -> Int in CENTER - g.cx + g.area / 100_000_000 })
    let rightSpec = (accept: { (g: ZoneGeo) -> Bool in g.cx > CENTER },
                    score: { (g: ZoneGeo) -> Int in g.cx - CENTER + g.area / 100_000_000 })
    let topSpec = (accept: { (g: ZoneGeo) -> Bool in g.cy < CENTER },
                  score: { (g: ZoneGeo) -> Int in CENTER - g.cy + g.area / 100_000_000 })
    let bottomSpec = (accept: { (g: ZoneGeo) -> Bool in g.cy > CENTER },
                     score: { (g: ZoneGeo) -> Int in g.cy - CENTER + g.area / 100_000_000 })

    let specs: [String: (accept: (ZoneGeo) -> Bool, score: (ZoneGeo) -> Int)] = [
        "main": mainSpec, "left": leftSpec, "right": rightSpec,
        "top": topSpec, "bottom": bottomSpec
    ]

    // Capture for nested closure.
    func claim(_ pane: PlacedPane, role: String) {
        let spec = specs[role] ?? mainSpec
        var best: ZoneGeo? = nil
        for (_, g) in remaining {
            if spec.accept(g) && (best == nil || spec.score(g) > spec.score(best!)) {
                best = g
            }
        }
        if let chosen = best {
            remaining.removeValue(forKey: chosen.index)
            assignments[chosen.index] = [pane.id]
            zoneForRole[role] = chosen.index
            if role == "main" || zoneForRole["main"] == nil {
                zoneForRole["main"] = zoneForRole["main"] ?? chosen.index
            }
            return
        }
        // No acceptable zone left: stack with role-mates, else
        // with main, else last.
        let home = zoneForRole[role] ?? zoneForRole["main"] ?? assignments.keys.sorted().last
        if let h = home {
            assignments[h, default: []].append(pane.id)
        }
    }

    let rank: (PlacedPane) -> Int = { p in
        p.placement == .main ? 0 : (p.placement == nil ? 2 : 1)
    }
    let sortedPanes = panes.sorted { rank($0) < rank($1) }
    for pane in sortedPanes {
        let role = pane.placement?.rawValue ?? "_"
        claim(pane, role: role == "_" ? "main" : role)
    }

    return assignments
}

// MARK: - Public API (= hermes `gridToTree` + `gridIsTreeExpressible`)

/// Convert a grid to a tree. Returns nil if the grid is non-
/// guillotine (= pinwheel).
func gridToTree(gridModel: GridLayout, panes: [PlacedPane]) -> LayoutNode? {
    guard let zones = modelToZones(gridModel),
          !zones.isEmpty,
          !panes.isEmpty else {
        return nil
    }
    let assignments = assignZones(zones: zones, panes: panes)
    let raw = cut(zones: zones) { zoneIndex in
        assignments[zoneIndex] ?? []
    }
    if let raw = raw {
        return normalize(raw)
    }
    return nil
}

/// True when the grid is expressible as a tree (= guillotine-
/// cuttable). Used by the ZoneEditor Save button to enable /
/// disable (= per spec §"Acceptance criteria" #11 = 'Save button:
/// enabled iff gridIsTreeExpressible(model), disabled otherwise with
/// explanatory tooltip').
func gridIsTreeExpressible(gridModel: GridLayout) -> Bool {
    guard let zones = modelToZones(gridModel), !zones.isEmpty else {
        return false
    }
    let probe = cut(zones: zones) { _ in [] }
    return probe != nil
}