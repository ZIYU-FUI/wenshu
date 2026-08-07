// LT01Fix6SplitTests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix6
//
// 装机 user 8/7 二次实机验: "中间的上下分割线还是有 BUG, 是不是定位
// 错误". 真根因 = `adjustBottomHeight` 的**符号反了** — `ratios[3]`
// 存的是**下半**的高度占比, 而向下拖 (delta > 0) 应该让上半变大 /
// 下半变小, 所以要减不是加. 加号让分割线朝鼠标的反方向跑, 而且跑偏
// 的比例被 scheduleSave 落盘到 .ws, 冷启动后停在一个跟中点无关的
// 位置.
//
// 这里 pin 3 条契约:
//   1. 默认 (未拖过) = 上半 50% / 下半 50%
//   2. 向下拖 → 下半变小 (符号正确) 且实时反映到 LayoutMetrics
//   3. fallback (dismissible panel 全隐藏) 仍然强制 50:50, 不受
//      拖出来的 ratios[3] 影响

import XCTest
@testable import WenshuApp

final class LT01Fix6SplitTests: XCTestCase {

    /// 默认 5 区 layout → 上半 50% 总高, 下半 50% 总高.
    @MainActor
    func testDefaultSplit_50_50() {
        let vm = LayoutShellViewModel()
        let total: CGFloat = 900

        XCTAssertEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.0001,
                       "默认 ratios[3] (下半占比) 必须是 0.5 = 50:50")

        let lower = LayoutMetrics.lowerBandHeight(
            totalHeight: total,
            ratios: vm.snapshot.ratios,
            visibility: vm.visibility
        )
        XCTAssertEqual(lower, total * 0.5, accuracy: 0.5,
                       "默认下半 = 总高 50%")
        XCTAssertEqual(total - lower, total * 0.5, accuracy: 0.5,
                       "默认上半 = 总高 50% (分割线在中点)")
    }

    /// 向下拖 100px → 下半缩 100px, 上半涨 100px. 符号搞反的话这条
    /// 会反向失败.
    @MainActor
    func testDragDown_shrinksLowerBand() {
        let vm = LayoutShellViewModel()
        let total: CGFloat = 900

        vm.adjustBottomHeight(delta: 100, totalHeight: total)

        let lower = LayoutMetrics.lowerBandHeight(
            totalHeight: total,
            ratios: vm.snapshot.ratios,
            visibility: vm.visibility
        )
        XCTAssertEqual(lower, total * 0.5 - 100, accuracy: 0.5,
                       "向下拖 100px → 下半少 100px (分割线跟着鼠标走)")

        // 反向拖回去 → 回到中点.
        vm.adjustBottomHeight(delta: -100, totalHeight: total)
        XCTAssertEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.0001,
                       "拖回来必须回到 50:50")
    }

    /// fallback (项目管理 + 检视 + 状态 全隐藏, 只剩 文档 + 聊天) →
    /// 强制 50:50, 忽略用户拖出来的 ratios[3].
    @MainActor
    func testFallbackSplit_forces50_50() {
        let vm = LayoutShellViewModel()
        let total: CGFloat = 900

        // 先把 ratios[3] 拖到一个明显不是 0.5 的值.
        vm.adjustBottomHeight(delta: 200, totalHeight: total)
        XCTAssertNotEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.01)

        var visibility = PanelVisibilityState()
        visibility.topLeft = false
        visibility.topRight = false
        visibility.bottomRight = false
        XCTAssertTrue(LayoutMetrics.isFallbackLayout(visibility: visibility))

        let lower = LayoutMetrics.lowerBandHeight(
            totalHeight: total,
            ratios: vm.snapshot.ratios,
            visibility: visibility
        )
        XCTAssertEqual(lower, total * 0.5, accuracy: 0.5,
                       "fallback 强制 50:50, 不读拖出来的 ratios[3]")

        // 持久化的 ratios[3] 不能被 fallback 改写 (un-hide 后要还原).
        XCTAssertNotEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.01,
                          "fallback 只影响计算, 不改写持久化 ratios[3]")
    }
}
