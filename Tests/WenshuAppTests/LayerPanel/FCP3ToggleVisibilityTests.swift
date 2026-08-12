// FCP3ToggleVisibilityTests.swift · 文枢 (Wenshu) · v0.04.0 t_bfa84198
//
// Covers the FCP Viewer-style 3 toggle fold buttons (designer
// wenshu-fcp-fold-3buttons-2026-08-12 §3.1):
//   按钮 1 ↔ .topCenter (中上 viewer)
//   按钮 2 ↔ .bottomLeft + .bottomRight (整条下半栏)
//   按钮 3 ↔ .topRight (检视)
//   .topLeft 永远不折叠
//   组合式 visibility (3 toggle × 8 组合, OR 关系, 非 XOR)
//
// 8 组合真值表 (沿 designer §2.1, 截图基线 10-48-23 / 10-48-36 /
// 10-48-45 / 10-48-55 + §2.3 未验证状态升级):
//   1. 全显       (initial)
//   2. 按钮1 only  (viewer 隐)
//   3. 按钮3 only  (inspector 隐)
//   4. 按钮2 only  (下半 隐)
//   5. 按钮1+3     (viewer + inspector 隐)
//   6. 按钮2+3     (下半 + inspector 隐)
//   7. 按钮1+2     (viewer + 下半 隐)
//   8. 全隐 (3 toggle)  — §2.3 未验证状态
//   + 双向 toggle 回显

import XCTest
@testable import WenshuApp

@MainActor
final class FCP3ToggleVisibilityTests: XCTestCase {

    // MARK: - 8 组合真值表

    /// 1. 全显基线 (10-48-23 = 5 截图基线)
    func test_initialState_allVisible() {
        let vm = LayoutShellViewModel()
        XCTAssertTrue(vm.isVisible(.topCenter), "按钮 1 控制 .topCenter 默认显")
        XCTAssertTrue(vm.isBottomBandVisible(), "按钮 2 控制下半 默认显")
        XCTAssertTrue(vm.isVisible(.topRight), "按钮 3 控制 .topRight 默认显")
        XCTAssertTrue(vm.isVisible(.topLeft), ".topLeft 永远显")
    }

    /// 2. 按钮 1 only → 中上隐
    func test_button1Only_viewerHidden() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topCenter)
        XCTAssertFalse(vm.isVisible(.topCenter))
        XCTAssertTrue(vm.isBottomBandVisible(), "按钮 2 不动")
        XCTAssertTrue(vm.isVisible(.topRight), "按钮 3 不动")
        XCTAssertTrue(vm.isVisible(.topLeft), ".topLeft 不动")
    }

    /// 3. 按钮 1 + 按钮 3 → 中上 + 右侧隐 (10-48-45 截图基线)
    func test_button1And3_viewerAndInspectorHidden() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topCenter)
        vm.togglePanelVisibility(.topRight)
        XCTAssertFalse(vm.isVisible(.topCenter))
        XCTAssertTrue(vm.isBottomBandVisible())
        XCTAssertFalse(vm.isVisible(.topRight))
        XCTAssertTrue(vm.isVisible(.topLeft))
    }

    /// 4. 按钮 2 only → 下半隐 (10-48-55 截图基线)
    func test_button2Only_bottomBandHidden() {
        let vm = LayoutShellViewModel()
        vm.toggleBottomBand()
        XCTAssertTrue(vm.isVisible(.topCenter))
        XCTAssertFalse(vm.isBottomBandVisible())
        XCTAssertTrue(vm.isVisible(.topRight))
        // 按钮 2 同时 toggle 两个, 验证 OR 真值:
        XCTAssertFalse(vm.isVisible(.bottomLeft))
        XCTAssertFalse(vm.isVisible(.bottomRight))
    }

    /// 5. 按钮 2 + 按钮 3 → 下半 + inspector 隐
    func test_button2And3_bottomAndInspectorHidden() {
        let vm = LayoutShellViewModel()
        vm.toggleBottomBand()
        vm.togglePanelVisibility(.topRight)
        XCTAssertTrue(vm.isVisible(.topCenter))
        XCTAssertFalse(vm.isBottomBandVisible())
        XCTAssertFalse(vm.isVisible(.topRight))
    }

    /// 6. 按钮 1 + 按钮 2 → 中上 + 下半隐
    func test_button1And2_viewerAndBottomHidden() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topCenter)
        vm.toggleBottomBand()
        XCTAssertFalse(vm.isVisible(.topCenter))
        XCTAssertFalse(vm.isBottomBandVisible())
        XCTAssertTrue(vm.isVisible(.topRight))
    }

    /// 7. 3 toggle 全隐 (designer §2.3 未验证状态升级 — 本卡覆盖, 验证 OR 真值)
    func test_all3Hidden() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topCenter)
        vm.toggleBottomBand()
        vm.togglePanelVisibility(.topRight)
        XCTAssertFalse(vm.isVisible(.topCenter))
        XCTAssertFalse(vm.isBottomBandVisible())
        XCTAssertFalse(vm.isVisible(.topRight))
        // 永远不折叠:
        XCTAssertTrue(vm.isVisible(.topLeft))
    }

    /// 8. 双向 toggle 回显 (designer §2.3 "从 2 隐切回 1 隐" 验证)
    func test_toggleBackFromHidden() {
        let vm = LayoutShellViewModel()

        vm.togglePanelVisibility(.topCenter)
        vm.togglePanelVisibility(.topCenter)
        XCTAssertTrue(vm.isVisible(.topCenter), "按钮 1 双向 toggle 回显")

        vm.toggleBottomBand()
        vm.toggleBottomBand()
        XCTAssertTrue(vm.isBottomBandVisible(), "按钮 2 双向 toggle 回显")

        vm.togglePanelVisibility(.topRight)
        vm.togglePanelVisibility(.topRight)
        XCTAssertTrue(vm.isVisible(.topRight), "按钮 3 双向 toggle 回显")
    }

    // MARK: - isDismissible 拍板

    /// FCP 范式 = 全 toggle, v0.04.0 起 5 区全 dismissible
    func test_isDismissible_all5True() {
        for panel in PanelID.allCases {
            XCTAssertTrue(panel.isDismissible, "\(panel.title) v0.04.0 起 dismissible")
        }
    }

    // MARK: - .ws JSON round-trip

    /// visibility 状态走 PanelStatesEnvelope encode/decode 不丢数据
    func test_visibilityRoundTrip() {
        let vm = LayoutShellViewModel()
        vm.togglePanelVisibility(.topCenter)
        vm.toggleBottomBand()
        let json = PanelStatesEnvelope.encode(
            collapsed: vm.snapshot.collapsed,
            visible: vm.visibility
        )
        let decoded = PanelStatesEnvelope.decode(json)
        XCTAssertEqual(decoded.visible, vm.visibility)
        XCTAssertFalse(decoded.visible.topCenter)
        XCTAssertFalse(decoded.visible.bottomLeft)
        XCTAssertFalse(decoded.visible.bottomRight)
        XCTAssertTrue(decoded.visible.topLeft)
        XCTAssertTrue(decoded.visible.topRight)
    }
}
