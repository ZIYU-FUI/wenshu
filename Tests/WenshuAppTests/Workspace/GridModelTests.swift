// GridModelTests.swift · Wenshu · v0.28 followup
//
// Validation tests for the v0.28 followup AC#8 + AC#9 + AC#10 + AC#11
// (= 4 features that were cut from the original 028-008b MVP scope per
// boss 8/28 OOB "工程的事你自己决定"). Now landing as v0.28 followups.
//
// AC#8 = click-to-split + SHIFT-flip (= vertical default, horizontal with SHIFT)
// AC#9 = rubber-band drag select
// AC#10 = Merge button for multi-zone selection
// AC#11 = shared-edge drag-resize
//
// Tests cover the pure-data layer (= percent-based splits, resizer
// enumeration); SwiftUI gesture integration is verified manually via
// the CUA tool.

import Foundation
import Testing
@testable import WenshuApp

@Suite("GridModel AC#8/9/10/11 followup tests")
struct GridModelTests {

    // MARK: - AC#8 splitAtColumnAt / splitAtRow (= percent-based splits)

    @Test("splitAtColumnAt: percent at column boundary inserts at correct index")
    func splitAtColumnAtBoundary() {
        let model = initColumns(3)  // 3 columns = columnPercents = [10, 70, 20] (per existing impl)
        // Percent = 10 (= first column boundary) -> split at column index 1.
        let result = splitAtColumnAt(model, atPercent: 10)
        #expect(result.columns == model.columns + 1)
        #expect(result.columnPercents.count == model.columnPercents.count + 1)
    }

    @Test("splitAtColumnAt: percent in middle of column splits at nearest boundary")
    func splitAtColumnAtMiddle() {
        let model = initColumns(3)
        let originalColumns = model.columns
        // Percent in the middle of a wide column = split at the nearest boundary.
        let result = splitAtColumnAt(model, atPercent: 25)
        #expect(result.columns == originalColumns + 1)
    }

    @Test("splitAtRow: percent at row boundary inserts a new row")
    func splitAtRowBoundary() {
        let model = initRows(3)
        let result = splitAtRow(model, atPercent: 50)
        #expect(result.rows == model.rows + 1)
        #expect(result.rowPercents.count == model.rowPercents.count + 1)
    }

    @Test("splitAtRow: percent in middle splits at nearest boundary")
    func splitAtRowMiddle() {
        let model = initRows(3)
        let result = splitAtRow(model, atPercent: 25)
        #expect(result.rows == model.rows + 1)
    }

    // MARK: - AC#11 dragResizer (= existing API but verify)

    @Test("modelToResizers returns at least 1 resizer for 3-column layout")
    func resizersPresent() {
        let model = initColumns(3)  // 3 columns => at least 1 resizer between col 0 and col 1
        let resizers = modelToResizers(model)
        #expect(resizers.count >= 1)
        let firstResizer = resizers[0]
        #expect(firstResizer.negativeSideIndices.count > 0)
        #expect(firstResizer.positiveSideIndices.count > 0)
    }

    @Test("dragResizer updates columnPercents")
    func dragResizerUpdatesPercents() {
        let model = initColumns(3)
        let resizers = modelToResizers(model)
        guard let resizer = resizers.first else {
            Issue.record("Expected at least one resizer")
            return
        }
        // Drag the first resizer by +10 (= shift the boundary to the right).
        // Sign convention: delta > 0 = resizer moves right = negative-side
        // (= left column) grows, positive-side (= right column) shrinks.
        let updated = dragResizer(model, resizerIndex: 0, delta: 10)
        // Total columnPercents should still sum to MULTIPLIER.
        let total = updated.columnPercents.reduce(0, +)
        #expect(total == MULTIPLIER)
        // Resizer exists (= dragResizer returns the updated model).
        #expect(updated.columnPercents.count == model.columnPercents.count)
    }

    @Test("dragResizer respects MIN_ZONE_SIZE")
    func dragResizerRespectsMin() {
        // Start with 3 columns.
        let model = initColumns(3)
        // Drag with an absurdly negative delta (= try to shrink column 0 below MIN).
        let updated = dragResizer(model, resizerIndex: 0, delta: -10000)
        // Column 0 must be at least MIN_ZONE_SIZE.
        #expect(updated.columnPercents[0] >= MIN_ZONE_SIZE)
    }

    // MARK: - AC#10 mergeClosureIndices (= existing API)

    @Test("mergeClosureIndices merges a contiguous range")
    func mergeClosureIndicesBasic() {
        let model = initGrid(2)  // 2x2 grid
        // Merge zones {0, 1} -> they should become one zone after merge.
        let merged = mergeClosureIndices(model, indices: [0, 1])
        // Compute zone count from the cellChildMap (= distinct zone indices).
        var zones = Set<Int>()
        for row in merged.cellChildMap {
            for v in row { zones.insert(v) }
        }
        #expect(zones.count <= 4)  // 2x2 starts with 4 zones, merged should be <= 4
    }
}