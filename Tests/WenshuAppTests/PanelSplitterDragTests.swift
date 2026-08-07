// PanelSplitterDragTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix4
//
// LT-01-fix4 BUG1 coverage. 装机 user 8/7 实机验 reported the horizontal
// splitter in the lower band (聊天 ↔ 状态) couldn't be dragged.
//
// Root cause was a `@Published` nested-mutation gotcha — the drag
// handlers were doing `snapshot.ratios = ratios` instead of reassigning
// the whole `snapshot`. SwiftUI never saw a `willSet` fire so the body
// never re-evaluated. Persistence still ran (scheduleSave writes the
// mutated array), which is why a cold-launch restore would show the
// ratios had moved even though the live window didn't repaint.
//
// These tests pin the *behavioural contract*: each adjustXxx method
// must (1) actually change the ratios in memory, (2) keep them in the
// declared [5%, 95%] clamp band, and (3) preserve the sum invariant for
// paired columns (upper-row splitters only).

import XCTest
@testable import WenshuApp

final class PanelSplitterDragTests: XCTestCase {

    // MARK: - Lower-band horizontal splitter (下左 ↔ 下右, ratios[4])

    /// Drag the bottom-row horizontal splitter (between 聊天 and 状态) by
    /// 50px to the right → bottomLeft ratio must increase. Pre-fix4 the
    /// test would have passed on cold launch (because the array was
    /// mutated and persisted) but the *live* window never repainted;
    /// from the VM's perspective, however, the in-memory ratios array
    /// did change, so this assertion has always held at the model layer.
    /// The companion fix is in `LayoutShellViewModel.adjustLowerColumn`,
    /// which now reassigns `snapshot` (not just `snapshot.ratios`) so
    /// SwiftUI's `@Published` actually emits `objectWillChange`.
    @MainActor
    func testHorizontalSplitterDrag_changesBottomRatio() {
        let vm = LayoutShellViewModel()
        let initial = vm.snapshot.ratios[4]      // default = 0.7 (70:30)
        XCTAssertEqual(initial, 0.7, accuracy: 0.0001)

        // Drag right by 50px on a 1000pt-wide lower band.
        vm.adjustLowerColumn(delta: 50, totalWidth: 1000)

        XCTAssertNotEqual(
            vm.snapshot.ratios[4], initial,
            "50px drag must change bottomLeftRatio (装机 user BUG1)"
        )
        XCTAssertGreaterThan(
            vm.snapshot.ratios[4], initial,
            "Dragging right must widen bottomLeft (≥ initial)"
        )
        // Clamp guard: ratios[4] stays inside [0.05, 0.95].
        XCTAssertGreaterThanOrEqual(vm.snapshot.ratios[4], 0.05)
        XCTAssertLessThanOrEqual(vm.snapshot.ratios[4], 0.95)

        // Drag left back past the starting point — must also move.
        vm.adjustLowerColumn(delta: -200, totalWidth: 1000)
        XCTAssertLessThan(vm.snapshot.ratios[4], initial)
    }

    // MARK: - Upper-band vertical splitter (topLeft ↔ topCenter, ratios[1])

    /// Drag the upper-band vertical splitter (between 项目管理 and 文档) by
    /// 50px to the right → topCenter ratio must change (it gets narrower
    /// because the drag pulls the splitter rightward into topCenter).
    /// Same `@Published` gotcha applies — verify the in-memory mutation
    /// occurs so the live UI follows.
    @MainActor
    func testVerticalSplitterDrag_changesColumnRatio() {
        let vm = LayoutShellViewModel()
        let initialTopCenter = vm.snapshot.ratios[1]   // default = 0.6

        // Drag right by 50px on a 1200pt-wide upper row.
        vm.adjustUpperColumn(splitterIndex: 0, delta: 50, totalWidth: 1200)

        XCTAssertNotEqual(
            vm.snapshot.ratios[1], initialTopCenter,
            "50px drag must change topCenterRatio"
        )
        XCTAssertLessThan(
            vm.snapshot.ratios[1], initialTopCenter,
            "Dragging right widens topLeft, narrows topCenter"
        )
        // Sum invariant: topLeft + topCenter stays constant under a
        // single-splitter drag (so topRight = 0.2 is untouched).
        let sum = vm.snapshot.ratios[0] + vm.snapshot.ratios[1]
        XCTAssertEqual(sum, 0.8, accuracy: 0.0001,
                       "Splitter drag must preserve column pair sum")
        XCTAssertEqual(vm.snapshot.ratios[2], 0.2, accuracy: 0.0001,
                       "Unrelated column must not move")
    }
}
