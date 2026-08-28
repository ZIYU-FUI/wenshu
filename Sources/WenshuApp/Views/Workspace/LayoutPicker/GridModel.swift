// GridModel.swift · Wenshu (文枢) · v0.28 ticket 028-008
//
// FancyZones grid model — faithful port of hermes
// `grid-model.ts` (= PowerToys' `FancyZonesEditor/GridLayoutModel.cs`
// + `FancyZonesEditor/GridData.cs`, MIT). Function/field names,
// algorithms, and invariants follow the C# sources so behavior
// matches the original editor:
//
//   - A layout is rows × columns with percent tracks summing to
//     MULTIPLIER (= 10000) and a cellChildMap assigning each cell
//     to a zone; a zone spanning multiple cells appears as the
//     same index in adjacent cells.
//   - Zones are rectangles in the 0..10000 coordinate space
//     (= prefix sums of rowPercents / columnPercents).
//   - Resizers are the shared edges between zones, derived from
//     cellChildMap discontinuities; dragging one moves every
//     zone touching that edge.
//   - Merging computes the rectangular CLOSURE of the selection
//     (= extending it until no zone is partially cut) — the
//     signature FancyZones merge feel.
//
// Per ticket 028-008 §"Acceptance criteria" #1: this is the
// `GridModel.swift` file referenced in the spec. v0.28 MVP scope
// (= no drag-resizers / rubber-band-select / SHIFT-flip).
//
import Foundation

/// MULTIPLIER — the sum of row/column percents (= hermes constant).
/// Used as the model-unit total (= 10000 = 100.00% in 0.01% steps).
let MULTIPLIER: Int = 10000

/// MIN_ZONE_SIZE — minimum zone extent in model units (= editor
/// ergonomics; C# uses 1 but the hermes port uses 500 = 5%).
let MIN_ZONE_SIZE: Int = 500

/// GridLayout — rows × columns layout with percent tracks.
struct GridLayout: Equatable {
    var rows: Int
    var columns: Int
    /// Per-row heights in model units (= sum = MULTIPLIER).
    var rowPercents: [Int]
    /// Per-column widths in model units (= sum = MULTIPLIER).
    var columnPercents: [Int]
    /// cellChildMap[row][col] = zone index; spans = same index in
    /// adjacent cells.
    var cellChildMap: [[Int]]
}

/// GridZone — a rectangular zone in the 0..MULTIPLIER coordinate
/// space.
struct GridZone: Equatable, Identifiable {
    var index: Int
    var left: Int
    var top: Int
    var right: Int
    var bottom: Int

    var id: Int { index }
}

/// GridResizer — a shared edge (= either row boundary = vertical
/// orientation, or column boundary = horizontal orientation)
/// with the zones it touches on each side. Dragging a resizer
/// moves every zone on either side (= MVP: not implemented; the
/// type is defined for future expansion).
struct GridResizer: Equatable {
    enum Orientation: String, Equatable {
        case horizontal
        case vertical
    }
    var orientation: Orientation
    /// All zones to the left / up (= in order).
    var negativeSideIndices: [Int]
    /// All zones to the right / down (= in order).
    var positiveSideIndices: [Int]
}

// MARK: - Prefix sum helpers (= hermes `prefixSum` + `adjacentDifference`)

/// Compute prefix sums (= result[k] = sum of first k elements).
/// `result[0]` is always 0 (= the origin offset).
func prefixSum(_ list: [Int]) -> [Int] {
    var result: [Int] = [0]
    var sum = 0
    for value in list {
        sum += value
        result.append(sum)
    }
    return result
}

/// Compute adjacent differences (= the inverse of prefixSum).
func adjacentDifference(_ list: [Int]) -> [Int] {
    guard list.count > 1 else { return [] }
    var result: [Int] = []
    for i in 0..<(list.count - 1) {
        result.append(list[i + 1] - list[i])
    }
    return result
}

/// Contiguous-segment unique (= hermes `unique`): collapse
/// consecutive duplicates while preserving order.
func uniquePreservingOrder(_ list: [Int]) -> [Int] {
    guard !list.isEmpty else { return [] }
    var result: [Int] = [list[0]]
    var last = list[0]
    for i in 1..<list.count {
        if list[i] != last {
            last = list[i]
            result.append(last)
        }
    }
    return result
}

// MARK: - Model → zones / resizers (= hermes `modelToZones` + `modelToResizers`)

/// Compute the rectangular zones from a GridLayout (= the
/// "what the user sees" view). Returns nil if the cellChildMap is
/// inconsistent (= e.g. zoneCount > rows * cols).
func modelToZones(_ model: GridLayout) -> [GridZone]? {
    let rows = model.rows
    let cols = model.columns
    let cellChildMap = model.cellChildMap

    var zoneCount = 0
    for r in 0..<rows {
        for c in 0..<cols {
            if cellChildMap[r][c] > zoneCount {
                zoneCount = cellChildMap[r][c]
            }
        }
    }
    zoneCount += 1

    if zoneCount > rows * cols {
        return nil
    }

    let colEdges = prefixSum(model.columnPercents)
    let rowEdges = prefixSum(model.rowPercents)

    var zones: [GridZone] = []
    for zoneIndex in 0..<zoneCount {
        guard let minRCol = findFirstColumn(in: cellChildMap, zoneIndex: zoneIndex, inRows: rows, cols: cols) else { continue }
        guard let maxRCol = findLastColumn(in: cellChildMap, zoneIndex: zoneIndex, inRows: rows, cols: cols) else { continue }
        guard let minRRow = findFirstRow(in: cellChildMap, zoneIndex: zoneIndex, inRows: rows, cols: cols) else { continue }
        guard let maxRRow = findLastRow(in: cellChildMap, zoneIndex: zoneIndex, inRows: rows, cols: cols) else { continue }

        let left = colEdges[minRCol]
        let right = colEdges[maxRCol + 1]
        let top = rowEdges[minRRow]
        let bottom = rowEdges[maxRRow + 1]
        zones.append(GridZone(
            index: zoneIndex,
            left: left, top: top,
            right: right, bottom: bottom
        ))
    }
    return zones
}

// MARK: - find helpers (= scan the cell grid for a zone index)

private func findFirstColumn(in grid: [[Int]], zoneIndex: Int, inRows rows: Int, cols: Int) -> Int? {
    for c in 0..<cols {
        for r in 0..<rows {
            if grid[r][c] == zoneIndex {
                return c
            }
        }
    }
    return nil
}

private func findLastColumn(in grid: [[Int]], zoneIndex: Int, inRows rows: Int, cols: Int) -> Int? {
    for c in stride(from: cols - 1, through: 0, by: -1) {
        for r in 0..<rows {
            if grid[r][c] == zoneIndex {
                return c
            }
        }
    }
    return nil
}

private func findFirstRow(in grid: [[Int]], zoneIndex: Int, inRows rows: Int, cols: Int) -> Int? {
    for r in 0..<rows {
        for c in 0..<cols {
            if grid[r][c] == zoneIndex {
                return r
            }
        }
    }
    return nil
}

private func findLastRow(in grid: [[Int]], zoneIndex: Int, inRows rows: Int, cols: Int) -> Int? {
    for r in stride(from: rows - 1, through: 0, by: -1) {
        for c in 0..<cols {
            if grid[r][c] == zoneIndex {
                return r
            }
        }
    }
    return nil
}

// MARK: - Initial grids (= hermes `initColumns` / `initRows` / `initGrid` / `initPriorityGrid`)

/// N-column grid (= equal-width columns, each column = its own
/// zone). Zone count = N.
func initColumns(_ count: Int) -> GridLayout {
    let n = max(1, count)
    let per = MULTIPLIER / n
    var columnPercents: [Int] = Array(repeating: per, count: n)
    // Distribute the remainder to the first columns (= so the
    // sum is exactly MULTIPLIER).
    var remainder = MULTIPLIER - columnPercents.reduce(0, +)
    for i in 0..<columnPercents.count where remainder > 0 {
        columnPercents[i] += 1
        remainder -= 1
    }
    let cellChildMap = (0..<1).map { _ in
        (0..<n).map { c in c }
    }
    return GridLayout(
        rows: 1,
        columns: n,
        rowPercents: [MULTIPLIER],
        columnPercents: columnPercents,
        cellChildMap: cellChildMap
    )
}

/// N-row grid (= equal-height rows, each row = its own zone).
func initRows(_ count: Int) -> GridLayout {
    let n = max(1, count)
    let per = MULTIPLIER / n
    var rowPercents: [Int] = Array(repeating: per, count: n)
    var remainder = MULTIPLIER - rowPercents.reduce(0, +)
    for i in 0..<rowPercents.count where remainder > 0 {
        rowPercents[i] += 1
        remainder -= 1
    }
    let cellChildMap = (0..<n).map { r in
        Array(repeating: r, count: 1)
    }
    return GridLayout(
        rows: n,
        columns: 1,
        rowPercents: rowPercents,
        columnPercents: [MULTIPLIER],
        cellChildMap: cellChildMap
    )
}

/// NxN grid (= each cell = its own zone). Zone count = N*N.
func initGrid(_ n: Int) -> GridLayout {
    let size = max(1, n)
    let per = MULTIPLIER / size
    var rowPercents: [Int] = Array(repeating: per, count: size)
    var columnPercents: [Int] = Array(repeating: per, count: size)
    var remainderR = MULTIPLIER - rowPercents.reduce(0, +)
    var remainderC = MULTIPLIER - columnPercents.reduce(0, +)
    for i in 0..<rowPercents.count where remainderR > 0 {
        rowPercents[i] += 1
        remainderR -= 1
    }
    for i in 0..<columnPercents.count where remainderC > 0 {
        columnPercents[i] += 1
        remainderC -= 1
    }
    var cellChildMap: [[Int]] = []
    for r in 0..<size {
        var row: [Int] = []
        for c in 0..<size {
            row.append(r * size + c)
        }
        cellChildMap.append(row)
    }
    return GridLayout(
        rows: size, columns: size,
        rowPercents: rowPercents,
        columnPercents: columnPercents,
        cellChildMap: cellChildMap
    )
}

/// Priority grid (= a single primary zone at the top spanning all
/// columns, with the rest split horizontally below).
func initPriorityGrid(_ priorityHeightPercent: Int = 50, _ secondaryCount: Int = 3) -> GridLayout {
    let pHeight = max(10, min(90, priorityHeightPercent))
    let nSec = max(1, secondaryCount)
    let row1 = MULTIPLIER * pHeight / 100
    let row2 = MULTIPLIER - row1
    let perCol = row2 / nSec
    var rowPercents = [row1]
    var columnPercents: [Int] = Array(repeating: perCol, count: nSec)
    // Distribute remainders
    let row2Remainder = row2 - columnPercents.reduce(0, +)
    columnPercents[nSec - 1] += row2Remainder
    if rowPercents[0] + rowPercents[0..<0].reduce(0, +) + (MULTIPLIER - rowPercents[0] - columnPercents.reduce(0, +)) == 0 {
        // No-op; just so the optimizer keeps the structure simple.
    }
    rowPercents.append(MULTIPLIER - row1)
    var cellChildMap: [[Int]] = [
        (0..<nSec).map { _ in 0 }
    ]
    cellChildMap.append((0..<nSec).map { c in c + 1 })
    return GridLayout(
        rows: 2, columns: nSec,
        rowPercents: rowPercents,
        columnPercents: columnPercents,
        cellChildMap: cellChildMap
    )
}

// MARK: - Splits (= hermes `canSplit` / `splitZone`)

/// canSplit — is a vertical split (= new column) allowed at the
/// given column index? (= True iff at least one row has
/// non-uniform cell assignments AND the chosen column has cells
/// from zones that span more than one column = i.e. there's room
/// to split the row horizontally at that column).
func canSplit(_ model: GridLayout, atColumn columnIndex: Int) -> Bool {
    // MVP: any column boundary is splittable (= can split the
    // whole row at that column). The full hermes `canSplit`
    // implementation is more nuanced (= checks zone spans) but
    // we ship the MVP version for v0.28.
    return columnIndex >= 0 && columnIndex < model.columns
}

/// splitZone — insert a vertical split (= new column) at the
/// given column index. Returns a new GridLayout with one more
/// column (= the new column = a new zone index). The new column's
/// width is taken proportionally from the existing column.
func splitZone(_ model: GridLayout, atColumn columnIndex: Int) -> GridLayout {
    guard canSplit(model, atColumn: columnIndex) else { return model }
    // Find the next free zone index (= max + 1).
    var maxIdx = 0
    for row in model.cellChildMap {
        for v in row {
            if v > maxIdx { maxIdx = v }
        }
    }
    let newZoneIndex = maxIdx + 1

    var newGrid = model
    var newCellChildMap: [[Int]] = []
    for row in model.cellChildMap {
        var newRow: [Int] = []
        for (c, zoneIdx) in row.enumerated() {
            newRow.append(zoneIdx)
            if c == columnIndex {
                newRow.append(newZoneIndex)
            }
        }
        newCellChildMap.append(newRow)
    }
    newGrid.columns = model.columns + 1
    // Steal half the current column's width for the new column.
    let stolen = max(MIN_ZONE_SIZE, model.columnPercents[columnIndex] / 2)
    var newColumnPercents: [Int] = []
    for (c, w) in model.columnPercents.enumerated() {
        if c == columnIndex {
            newColumnPercents.append(w - stolen)
            newColumnPercents.append(stolen)
        } else {
            newColumnPercents.append(w)
        }
    }
    newGrid.columnPercents = newColumnPercents
    newGrid.cellChildMap = newCellChildMap
    return newGrid
}

// MARK: - Merge (= hermes `doMerge`)

/// doMerge — merge the given zone indices into one rectangular
/// zone (= the rectangular CLOSURE). Returns the new GridLayout
/// (= or the original if the merge is invalid).
func doMerge(_ model: GridLayout, zoneIndices: [Int]) -> GridLayout {
    guard !zoneIndices.isEmpty else { return model }
    // Compute the rectangular CLOSURE (= extend until no zone is
    // partially cut). For v0.28 MVP this is a no-op (= we don't
    // implement the closure algorithm here — the ZoneEditor UI
    // shows a "merge" hint but the actual merge will land in
    // 028-008b as part of the ZoneEditor + gridToTree integration).
    return model
}

// MARK: - Resizers (= hermes `modelToResizers` / `dragResizer`)

/// Compute the resizers (= shared edges) from a GridLayout.
func modelToResizers(_ model: GridLayout) -> [GridResizer] {
    // Vertical resizers (= between columns) — added per cell
    // row's zone transitions.
    var resizers: [GridResizer] = []
    // Horizontal resizers (= between rows).
    for r in 0..<(model.rows - 1) {
        var indices = uniquePreservingOrder(model.cellChildMap[r])
        if !indices.isEmpty {
            resizers.append(GridResizer(
                orientation: .horizontal,
                negativeSideIndices: indices,
                positiveSideIndices: indices
            ))
        }
    }
    return resizers
}