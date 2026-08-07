// PanelVisibilityTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix3
//
// Covers the macOS-menu-bar-driven panel show/hide added in LT-01-fix3:
//   1. defaults (every panel visible on a fresh / pre-fix3 .ws)
//   2. toggling one panel flips exactly that panel
//   3. hiding a panel redistributes its width to the survivors
//
// `LayoutMetrics` is pure arithmetic so (3) needs no SwiftUI. The
// ViewModel cases run on @MainActor and use a fresh instance rather than
// `.shared` so they don't touch the real .ws store.

import XCTest
@testable import WenshuApp

final class PanelVisibilityTests: XCTestCase {

    // MARK: - 1. Defaults

    @MainActor
    func testAllPanelsVisibleByDefault() {
        let vm = LayoutShellViewModel()
        for panel in PanelID.allCases {
            XCTAssertTrue(vm.isVisible(panel), "\(panel.title) 默认必须可见")
        }
        XCTAssertEqual(vm.visibility, PanelVisibilityState())

        // Pre-LT-01-fix3 .ws rows hold the legacy flat collapsed JSON with
        // no visibility key at all — they must degrade to all-visible, not
        // to an all-hidden window.
        let legacy = LayoutSnapshot.encodeCollapsed(
            PanelCollapsedState(topLeft: true)
        )
        let decoded = PanelStatesEnvelope.decode(legacy)
        XCTAssertTrue(decoded.collapsed.topLeft, "旧 .ws 的折叠状态必须保留")
        XCTAssertEqual(decoded.visible, PanelVisibilityState(), "旧 .ws fallback = 全可见")
    }

    // MARK: - 2. Toggle

    @MainActor
    func testTogglePanelVisibility_changesState() {
        let vm = LayoutShellViewModel()

        vm.togglePanelVisibility(.topRight)
        XCTAssertFalse(vm.isVisible(.topRight), "toggle 一次 → 隐藏")
        // Only that panel moved.
        for panel in PanelID.allCases where panel != .topRight {
            XCTAssertTrue(vm.isVisible(panel), "\(panel.title) 不该被连带隐藏")
        }

        vm.togglePanelVisibility(.topRight)
        XCTAssertTrue(vm.isVisible(.topRight), "再 toggle 一次 → 恢复")

        // 全显示 (Cmd+Shift+1) clears every hide at once.
        vm.togglePanelVisibility(.bottomRight)
        vm.togglePanelVisibility(.topLeft)
        vm.showAllPanels()
        XCTAssertEqual(vm.visibility, PanelVisibilityState(), "全显示后 5 panel 全可见")

        // Round-trips through the .ws panel_states column.
        vm.togglePanelVisibility(.bottomLeft)
        let json = PanelStatesEnvelope.encode(
            collapsed: vm.snapshot.collapsed,
            visible: vm.visibility
        )
        XCTAssertEqual(PanelStatesEnvelope.decode(json).visible, vm.visibility)
    }

    // MARK: - 3. Hidden panel redistributes width

    func testHiddenPanelRecomputesRatios() {
        let ratios = LayoutSnapshot.default.ratios   // 20 / 60 / 20 upper
        let total: CGFloat = 1000
        let splitter = CGFloat(LayoutSnapshot.splitterPixels)

        // Baseline: all 3 upper panels visible, 2 splitters between them.
        let all = LayoutMetrics.upperWidths(
            totalWidth: total,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState()
        )
        let allAvailable = total - 2 * splitter
        XCTAssertEqual(all.0, allAvailable * 0.2, accuracy: 0.01)
        XCTAssertEqual(all.1, allAvailable * 0.6, accuracy: 0.01)
        XCTAssertEqual(all.2, allAvailable * 0.2, accuracy: 0.01)

        // Hide 检视 (topRight): it takes 0pt, only 1 splitter is drawn, and
        // the freed 20% is split between 项目管理 / 文档 in proportion to
        // their own ratios (0.2 : 0.6 → 25% : 75%).
        let hidden = LayoutMetrics.upperWidths(
            totalWidth: total,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(topRight: false)
        )
        let hiddenAvailable = total - splitter
        XCTAssertEqual(hidden.2, 0, "隐藏的 panel 不占宽度")
        XCTAssertEqual(hidden.0, hiddenAvailable * 0.25, accuracy: 0.01)
        XCTAssertEqual(hidden.1, hiddenAvailable * 0.75, accuracy: 0.01)
        XCTAssertEqual(hidden.0 + hidden.1, hiddenAvailable, accuracy: 0.01,
                       "剩余 panel 必须分满 100%")
        XCTAssertGreaterThan(hidden.1, all.1, "文档 panel 变宽 (吃掉被隐藏的份额)")

        // Lower band: hiding 状态 gives 聊天 the whole width, no splitter.
        let lower = LayoutMetrics.lowerWidths(
            totalWidth: total,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(bottomRight: false)
        )
        XCTAssertEqual(lower.1, 0)
        XCTAssertEqual(lower.0, total, accuracy: 0.01)

        // Hiding both lower panels collapses the band's height to 0 so the
        // upper band owns the window (and vice-versa).
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: 800,
                ratios: ratios,
                visibility: PanelVisibilityState(bottomLeft: false, bottomRight: false)
            ),
            0
        )
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: 800,
                ratios: ratios,
                visibility: PanelVisibilityState(
                    topLeft: false, topCenter: false, topRight: false
                )
            ),
            800
        )
    }
}
