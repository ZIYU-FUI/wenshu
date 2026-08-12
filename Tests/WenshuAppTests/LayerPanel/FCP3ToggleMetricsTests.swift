// FCP3ToggleMetricsTests.swift · 文枢 (Wenshu) · v0.04.0 t_bfa84198
//
// Geometry correctness for the FCP 3 toggle fold buttons (designer
// wenshu-fcp-fold-3buttons-2026-08-12 §3.1 + §2.1 真值表). 沿
// PanelVisibilityTests 风格用纯 `LayoutMetrics` (无需 @MainActor), 验证
// 8 组合下 upperWidths + lowerBandHeight 的几何正确性:
//
//   1. 全显       → 3 上 + 2 下 都按默认 ratios 分配
//   2. 按钮1 only  → topCenter=0, topLeft/topRight 按 ratio 分满
//   3. 按钮3 only  → topRight=0, topLeft/topCenter 按 ratio 分满
//   4. 按钮2 only  → lowerBandHeight=0 (下半整体消失)
//   5. 按钮1+3     → topCenter=0 + topRight=0, topLeft 占满
//   6. 按钮2+3     → lowerBandHeight=0 + topRight=0
//   7. 按钮1+2     → topCenter=0 + lowerBandHeight=0
//   8. 3 toggle 全隐 → upperBand 占满 (topLeft=totalWidth, 余=0,
//                          lowerBandHeight=0)
//
// `.topLeft` 永远不折叠 — 见 test 1 + 5 验证 topLeft 在任何组合下都可见。

import XCTest
@testable import WenshuApp

final class FCP3ToggleMetricsTests: XCTestCase {

    private let totalWidth: CGFloat = 1000
    private let totalHeight: CGFloat = 800
    private let ratios = LayoutSnapshot.default.ratios   // [0.2, 0.6, 0.2, 0.5, 0.8]
    private let splitter = CGFloat(LayoutSnapshot.splitterPixels)

    // MARK: - 8 组合几何

    /// 1. 全显基线: 3 上 (20/60/20) + 下半 50% 高
    func test_fullVisible_geometry() {
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState()
        )
        let allAvailable = totalWidth - 2 * splitter
        XCTAssertEqual(upper.0, allAvailable * 0.2, accuracy: 0.01, "topLeft = 20%")
        XCTAssertEqual(upper.1, allAvailable * 0.6, accuracy: 0.01, "topCenter = 60%")
        XCTAssertEqual(upper.2, allAvailable * 0.2, accuracy: 0.01, "topRight = 20%")

        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: PanelVisibilityState()
            ),
            totalHeight * 0.5,
            accuracy: 0.01,
            "下半默认 = 50% 高"
        )
    }

    /// 2. 按钮 1 only → topCenter=0, topLeft + topRight 按 ratio 分满
    func test_button1Only_geometry() {
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(topCenter: false)
        )
        XCTAssertEqual(upper.1, 0, "topCenter 隐藏 → 0pt")
        // topLeft + topRight 按 0.2 : 0.2 = 50:50 (1 个 splitter, totalWidth - splitter)
        let hiddenAvailable = totalWidth - splitter
        XCTAssertEqual(upper.0, hiddenAvailable * 0.5, accuracy: 0.01)
        XCTAssertEqual(upper.2, hiddenAvailable * 0.5, accuracy: 0.01)
        XCTAssertEqual(upper.0 + upper.2, hiddenAvailable, accuracy: 0.01)

        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: PanelVisibilityState(topCenter: false)
            ),
            totalHeight * 0.5,
            accuracy: 0.01,
            "下半不变 (按钮 1 不动下半)"
        )
    }

    /// 3. 按钮 3 only → topRight=0
    func test_button3Only_geometry() {
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(topRight: false)
        )
        XCTAssertEqual(upper.2, 0)
        let hiddenAvailable = totalWidth - splitter
        XCTAssertEqual(upper.0, hiddenAvailable * 0.25, accuracy: 0.01, "topLeft: 0.2/(0.2+0.6) = 25%")
        XCTAssertEqual(upper.1, hiddenAvailable * 0.75, accuracy: 0.01, "topCenter: 0.6/(0.2+0.6) = 75%")
    }

    /// 4. 按钮 2 only → lowerBandHeight=0 (下半整体消失, upper 占满)
    func test_button2Only_geometry() {
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: PanelVisibilityState(bottomLeft: false, bottomRight: false)
            ),
            0,
            "下半整体隐 → 高 = 0"
        )

        // 上半不受影响, 仍按 20/60/20 分配
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(bottomLeft: false, bottomRight: false)
        )
        let allAvailable = totalWidth - 2 * splitter
        XCTAssertEqual(upper.0, allAvailable * 0.2, accuracy: 0.01)
        XCTAssertEqual(upper.1, allAvailable * 0.6, accuracy: 0.01)
        XCTAssertEqual(upper.2, allAvailable * 0.2, accuracy: 0.01)
    }

    /// 5. 按钮 1 + 按钮 3 → topCenter=0 + topRight=0, topLeft 占满
    func test_button1And3_geometry() {
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(topCenter: false, topRight: false)
        )
        XCTAssertEqual(upper.1, 0, "topCenter 隐 → 0")
        XCTAssertEqual(upper.2, 0, "topRight 隐 → 0")
        // 仅 topLeft 可见, 无 splitter
        XCTAssertEqual(upper.0, totalWidth, accuracy: 0.01, "topLeft 占满全宽")
    }

    /// 6. 按钮 2 + 按钮 3 → 下半 0 + topRight 0
    func test_button2And3_geometry() {
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: PanelVisibilityState(
                    topRight: false, bottomLeft: false, bottomRight: false
                )
            ),
            0,
            "下半整体隐 → 0"
        )

        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(
                topRight: false, bottomLeft: false, bottomRight: false
            )
        )
        XCTAssertEqual(upper.2, 0)
        // topLeft + topCenter 按 0.2 : 0.6 分
        let hiddenAvailable = totalWidth - splitter
        XCTAssertEqual(upper.0, hiddenAvailable * 0.25, accuracy: 0.01)
        XCTAssertEqual(upper.1, hiddenAvailable * 0.75, accuracy: 0.01)
    }

    /// 7. 按钮 1 + 按钮 2 → topCenter=0 + 下半 0
    func test_button1And2_geometry() {
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: PanelVisibilityState(
                    topCenter: false, bottomLeft: false, bottomRight: false
                )
            ),
            0
        )

        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: PanelVisibilityState(
                topCenter: false, bottomLeft: false, bottomRight: false
            )
        )
        XCTAssertEqual(upper.1, 0)
        // topLeft + topRight 按 0.2 : 0.2 = 50:50
        let hiddenAvailable = totalWidth - splitter
        XCTAssertEqual(upper.0, hiddenAvailable * 0.5, accuracy: 0.01)
        XCTAssertEqual(upper.2, hiddenAvailable * 0.5, accuracy: 0.01)
    }

    /// 8. 3 toggle 全隐 → upper 占满, lower = 0, 仅 topLeft 可见
    func test_all3Hidden_geometry() {
        let vis = PanelVisibilityState(
            topCenter: false, topRight: false,
            bottomLeft: false, bottomRight: false
        )

        // 下半 0 (上半仍有可见 panel, 不走 fallback 50:50 路径)
        XCTAssertEqual(
            LayoutMetrics.lowerBandHeight(
                totalHeight: totalHeight,
                ratios: ratios,
                visibility: vis
            ),
            0
        )

        // 上半仅 topLeft 可见, 占满全宽
        let upper = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: ratios,
            collapsed: PanelCollapsedState(),
            visibility: vis
        )
        XCTAssertEqual(upper.0, totalWidth, accuracy: 0.01, "topLeft 占满")
        XCTAssertEqual(upper.1, 0)
        XCTAssertEqual(upper.2, 0)
    }

    /// 边界: topLeft 永远不折叠 — 任何组合下都可见且有宽度
    func test_topLeft_alwaysVisible() {
        let combos: [PanelVisibilityState] = [
            PanelVisibilityState(),                                          // 全显
            PanelVisibilityState(topCenter: false),                          // btn1
            PanelVisibilityState(topRight: false),                           // btn3
            PanelVisibilityState(bottomLeft: false, bottomRight: false),     // btn2
            PanelVisibilityState(topCenter: false, topRight: false),         // btn1+3
            PanelVisibilityState(topCenter: false, topRight: false,
                                 bottomLeft: false, bottomRight: false),     // 全隐
        ]
        for (idx, vis) in combos.enumerated() {
            let upper = LayoutMetrics.upperWidths(
                totalWidth: totalWidth,
                ratios: ratios,
                collapsed: PanelCollapsedState(),
                visibility: vis
            )
            XCTAssertGreaterThan(upper.0, 0, "组合 \(idx): topLeft 永远有宽度")
        }
    }
}
