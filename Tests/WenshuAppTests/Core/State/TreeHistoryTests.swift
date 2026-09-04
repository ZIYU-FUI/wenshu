// TreeHistoryTests.swift · Wenshu (文枢) · v0.28 followup TKT-028-025
//
// Tests for the bounded undo/redo ring buffer. Boss 2026-08-29 OOB.

import XCTest
@testable import WenshuApp

final class TreeHistoryTests: XCTestCase {

    func testEmptyHistoryHasZeroCounts() {
        let h = TreeHistory()
        XCTAssertEqual(h.undoCount, 0)
        XCTAssertEqual(h.redoCount, 0)
        XCTAssertNil(h.lastUndoEntry)
    }

    func testRecordIncreasesUndoCount() {
        let h = TreeHistory()
        let tree = makeGroup(panes: [PaneID()])
        h.record(before: tree)
        XCTAssertEqual(h.undoCount, 1)
    }

    func testUndoReturnsBeforeTree() {
        let h = TreeHistory()
        let before = makeGroup(panes: [PaneID()])
        let current = makeSplit(
            orientation: .row,
            children: [makeGroup(panes: [PaneID()])],
            weights: [1.0]
        )
        h.record(before: before)
        let undone = h.undo(currentTree: current)
        XCTAssertNotNil(undone)
        XCTAssertEqual(h.undoCount, 0)
        XCTAssertEqual(h.redoCount, 1)
    }

    func testUndoEmptyReturnsNil() {
        let h = TreeHistory()
        let current = makeGroup(panes: [PaneID()])
        XCTAssertNil(h.undo(currentTree: current))
    }

    func testRedoReturnsAfterTree() {
        let h = TreeHistory()
        let before = makeGroup(panes: [PaneID()])
        let current = makeSplit(
            orientation: .row,
            children: [makeGroup(panes: [PaneID()])],
            weights: [1.0]
        )
        h.record(before: before)
        let undone = h.undo(currentTree: current)
        XCTAssertNotNil(undone)
        let redone = h.redo(currentTree: undone!)
        XCTAssertNotNil(redone)
    }

    func testRedoEmptyReturnsNil() {
        let h = TreeHistory()
        let current = makeGroup(panes: [PaneID()])
        XCTAssertNil(h.redo(currentTree: current))
    }

    func testNewActionClearsRedoStack() {
        let h = TreeHistory()
        let tree1 = makeGroup(panes: [PaneID()])
        let tree2 = makeGroup(panes: [PaneID(), PaneID()])
        h.record(before: tree1)
        _ = h.undo(currentTree: tree2)
        XCTAssertEqual(h.redoCount, 1)
        h.record(before: tree2)
        XCTAssertEqual(h.redoCount, 0)  // cleared by new record
    }

    func testCapEnforced() {
        let h = TreeHistory(cap: 3)
        for _ in 0..<10 {
            h.record(before: makeGroup(panes: [PaneID()]))
        }
        XCTAssertEqual(h.undoCount, 3)  // cap = 3, oldest 7 dropped
    }

    func testClear() {
        let h = TreeHistory()
        h.record(before: makeGroup(panes: [PaneID()]))
        _ = h.undo(currentTree: makeGroup(panes: [PaneID()]))
        h.clear()
        XCTAssertEqual(h.undoCount, 0)
        XCTAssertEqual(h.redoCount, 0)
    }

    func testLastUndoEntry() {
        let h = TreeHistory()
        let tree1 = makeGroup(panes: [PaneID()])
        let tree2 = makeGroup(panes: [PaneID(), PaneID()])
        h.record(before: tree1)
        XCTAssertNotNil(h.lastUndoEntry)
        h.record(before: tree2)
        XCTAssertNotNil(h.lastUndoEntry)
    }

    func testDefaultCap() {
        XCTAssertEqual(TreeHistory.defaultCap, 50)
    }
}