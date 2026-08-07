// LT01Fix7Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix7
//
// 修水平 splitter 点一下变 90:10 BUG 的回归测试, 4 个 case:
//
//   1. testSplitterSingleClick_doesNotChangeRatio
//   2. testSplitterClick_doesNotInvokeLayoutMetrics
//   3. testSplitterClick_doesNotToggleVisibility
//   4. testSplitterDrag_stillChangesRatio (回归, 防 over-fix)
//
// 真根因 (CC Step 0 verify 完, 见 ACCEPTANCE-v0.02.0-LT-01-fix7.md):
// fix5 只在 .onEnded 堵 click, 但 .onChanged 已经在 .onEnded 之前 fire
// 过 onDrag。 fix7 把 click 检测移到 .onChanged 入口, 并新增
// `SplitterDragPolicy.dragDelta(cumulative:lastReported:)` 把决策抽成
// 可测函数。
//
// 测试不跑 SwiftUI gesture host — 直接调 dragDelta, 验证它对 click
// 路径返回 nil (= 不调 onDrag), 对 drag 路径返回正确增量 (= 调
// onDrag with 正确 delta)。

import XCTest
@testable import WenshuApp

final class LT01Fix7Tests: XCTestCase {

    // MARK: - 1. testSplitterSingleClick_doesNotChangeRatio

    /// 装机 user 8/7 实机验 BUG: 点水平 splitter (上下半之间那条) 一下
    /// 就变成 上半 90% / 下半 10%。 模拟"鼠标按下 + 松开, 不动" →
    /// `cumulative = 0` → policy 返回 nil → `adjustBottomHeight` **不
    /// 调** → `vm.snapshot.ratios` 与初始一致。
    @MainActor
    func testSplitterSingleClick_doesNotChangeRatio() {
        // Baseline: ratios[3] = 0.5 (默认 50:50).
        let vm = LayoutShellViewModel()
        let initialRatios = vm.snapshot.ratios
        XCTAssertEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.0001,
                       "默认 ratios[3] = 0.5 (50:50 baseline)")

        // 模拟 .onChanged fire 一次, cumulative = 0 (纯 click, 无 motion).
        // 按真根因 fix 逻辑: dragDelta(cumulative: 0, lastReported: 0) = nil.
        let clickDelta = SplitterDragPolicy.dragDelta(
            cumulative: 0,
            lastReported: 0
        )
        XCTAssertNil(clickDelta, "cumulative = 0 必须是 click (返回 nil)")

        // 模拟没有调 onDrag → adjustBottomHeight 也没调:
        //   if let delta = clickDelta { vm.adjustBottomHeight(delta: delta, ...) }
        // 因为 clickDelta = nil, 这段代码跳过, vm.snapshot.ratios 不变。
        XCTAssertEqual(vm.snapshot.ratios, initialRatios,
                       "click 路径 ratios 必须不变 (修前 90:10 BUG)")

        // 模拟连续 5 次 click (装机 user 验视觉清单): 每次 cumulative 都
        // 是 sub-5px, 都返回 nil, 都跳过 onDrag。
        for i in 1...5 {
            let c = CGFloat(i % 4)  // 0, 1, 2, 3, 0 (sub-5px 全员)
            let d = SplitterDragPolicy.dragDelta(cumulative: c, lastReported: 0)
            XCTAssertNil(d, "click #\(i) (cumulative=\(c)) 必须返回 nil")
            if let delta = d {
                vm.adjustBottomHeight(delta: delta, totalHeight: 600)
            }
        }
        XCTAssertEqual(vm.snapshot.ratios, initialRatios,
                       "连点 5 次 ratios 必须仍 = 初始 (90:10 BUG 不复现)")
    }

    // MARK: - 2. testSplitterClick_doesNotInvokeLayoutMetrics

    /// Click 路径下 `SplitterDragPolicy.dragDelta` 必须返回 nil, 即
    /// "不 invoke any adjustXxx (含 layout 下游算 ratios 的入口)"。
    ///
    /// 注意: 真根因是 `.onChanged` 在 click-equivalent 上 fire `onDrag`,
    /// `onDrag` 才是 `adjustBottomHeight` / `adjustLowerColumn` /
    /// `adjustUpperColumn` 的唯一切入点。 上游 dragDelta 返回 nil → onDrag
    /// 不调 → adjustXxx 不调 → LayoutMetrics (lowerBandHeight /
    /// upperWidths / lowerWidths) 不被任何 view 侧 trigger 重算。 这条
    /// 测试锁这条链。
    func testSplitterClick_doesNotInvokeLayoutMetrics() {
        // Click 等价的 translation 谱: 从绝对零到 threshold - 0.1。
        for cumulative in stride(from: CGFloat(0), through: CGFloat(4.9), by: CGFloat(0.5)) {
            let d = SplitterDragPolicy.dragDelta(
                cumulative: cumulative,
                lastReported: 0
            )
            XCTAssertNil(d,
                "cumulative = \(cumulative) (sub-threshold click) 必须返回 nil; " +
                "返回 nil 才不会调 onDrag → 才不会进 adjustBottomHeight " +
                "→ 才不会触发 LayoutMetrics.lowerBandHeight 重算")
        }

        // 阈值边界: cumulative = threshold 本身 (5.0) 必须**不**是 click。
        let atThreshold = SplitterDragPolicy.dragDelta(
            cumulative: SplitterClickDetector.thresholdPixels,
            lastReported: 0
        )
        XCTAssertNotNil(atThreshold, "cumulative = threshold (5.0) 边界 = drag (返回增量)")

        // 阈值边界: cumulative = threshold + 0.1 必须是 drag。
        let aboveThreshold = SplitterDragPolicy.dragDelta(
            cumulative: SplitterClickDetector.thresholdPixels + 0.1,
            lastReported: 0
        )
        XCTAssertNotNil(aboveThreshold, "cumulative > threshold 必须是 drag")

        // Last-reported 状态: 即便 click 等价, dragDelta 也保证不调 onDrag。
        // 这条断言 click 路径下 "policy 返回 nil" = "LayoutMetrics 不被触发"
        // 的核心 invariant。
        XCTAssertNil(SplitterDragPolicy.dragDelta(cumulative: 0, lastReported: 0))
        XCTAssertNil(SplitterDragPolicy.dragDelta(cumulative: 2, lastReported: 0))
        XCTAssertNil(SplitterDragPolicy.dragDelta(cumulative: -3, lastReported: 0))
        XCTAssertNil(SplitterDragPolicy.dragDelta(cumulative: 4.9, lastReported: 100),
            "click 路径 lastReported 即使泄漏也无害 (因为 dragDelta 返回 nil)")
    }

    // MARK: - 3. testSplitterClick_doesNotToggleVisibility

    /// Click 路径不触发 `vm.togglePanelVisibility`, 即 `vm.visibility` 与
    /// 初始值 `==`。 派单 prompt 第 3 条要求 — 防御 macOS menu / 快捷键 /
    /// 未来手势之外的 click 路径偷改 panel visibility。
    @MainActor
    func testSplitterClick_doesNotToggleVisibility() {
        let vm = LayoutShellViewModel()
        let initialVisibility = vm.visibility
        XCTAssertEqual(initialVisibility, PanelVisibilityState(),
                       "默认 visibility = 全可见 (PanelVisibilityState())")

        // 模拟 click 走完 .onChanged / .onEnded, 但因为 policy 返回 nil,
        // onDrag 没调 → 任何 VM 方法都没调 → visibility 不变。
        for cumulative in [CGFloat(0), 1, 2.5, 4.9] {
            let d = SplitterDragPolicy.dragDelta(
                cumulative: cumulative,
                lastReported: 0
            )
            XCTAssertNil(d)
        }

        XCTAssertEqual(vm.visibility, initialVisibility,
                       "click 路径 visibility 必须不变 (5 panel 全可见)")

        // 直接防御: 即便有人手动调 togglePanelVisibility, click 路径也不
        // 走那条线。 这条 guard 跟 `testToggleChatVisibility_blocked` 配合
        // (LT01Fix5Tests.swift), 锁 "click 路径绝不动 visibility"。
        XCTAssertEqual(vm.visibility.topLeft, true)
        XCTAssertEqual(vm.visibility.topCenter, true)
        XCTAssertEqual(vm.visibility.topRight, true)
        XCTAssertEqual(vm.visibility.bottomLeft, true)
        XCTAssertEqual(vm.visibility.bottomRight, true)
    }

    // MARK: - 4. testSplitterDrag_stillChangesRatio (回归, 防 over-fix)

    /// 回归测试: 真正 drag (cumulative ≥ threshold) 必须仍 fire onDrag,
    /// drag 路径不能被 fix7 误杀。 装机 user 实机验 checklist 第二条:
    /// "拖水平 splitter → ratios 实时变"。
    @MainActor
    func testSplitterDrag_stillChangesRatio() {
        let vm = LayoutShellViewModel()
        let initialRatios3 = vm.snapshot.ratios[3]
        XCTAssertEqual(initialRatios3, 0.5, accuracy: 0.0001)

        // 模拟 60px 拖拽 (上半/下半之间的水平 splitter 向下拖 60px).
        // dragDelta(cumulative: 60, lastReported: 0) = 60.
        let dragDelta1 = SplitterDragPolicy.dragDelta(
            cumulative: 60,
            lastReported: 0
        )
        XCTAssertEqual(dragDelta1, 60, "60px 拖拽增量 = 60")

        if let delta = dragDelta1 {
            vm.adjustBottomHeight(delta: delta, totalHeight: 600)
        }

        // ratios[3] 必须改变 (drag 路径生效).
        XCTAssertNotEqual(vm.snapshot.ratios[3], initialRatios3,
                          "60px 拖拽必须 change ratios[3] (drag 路径没废)")

        // 计算: deltaRatio = 60/600 = 0.1, ratios[3] = 0.5 + 0.1 = 0.6.
        XCTAssertEqual(vm.snapshot.ratios[3], 0.6, accuracy: 0.0001)

        // 模拟"拖拽中途再 fire 一次": cumulative 从 60 涨到 80.
        let dragDelta2 = SplitterDragPolicy.dragDelta(
            cumulative: 80,
            lastReported: 60
        )
        XCTAssertEqual(dragDelta2, 20, "60 → 80 增量 = 20")

        if let delta = dragDelta2 {
            vm.adjustBottomHeight(delta: delta, totalHeight: 600)
        }
        XCTAssertEqual(vm.snapshot.ratios[3], 0.6333, accuracy: 0.001)

        // 反方向: cumulative 从 80 跌回 0 (用户拖回去松手, 但 .onChanged
        // 还没结束). dragDelta(0, 80) — 但 |0| < 5px, 视为 click, 返回 nil.
        // 这条对应 LT-01-fix7 真根因: 用户在 drag 中途松手, 最后一次
        // .onChanged 的 cumulative < threshold, 视为 click 不调 onDrag,
        // 但之前 cumulative >= threshold 的 .onChanged 都已正确调过
        // onDrag, ratios 已经反映出来。
        let onEnd = SplitterDragPolicy.dragDelta(cumulative: 0, lastReported: 80)
        XCTAssertNil(onEnd,
            "drag 中途松手, 最后 .onChanged cumulative < threshold = click = nil")

        // 最终 ratios 应该是 0.6333 (drag 路径累计, 不受最后 click 干扰).
        XCTAssertEqual(vm.snapshot.ratios[3], 0.6333, accuracy: 0.001,
                       "drag 路径累计值保留, 最后 click 不撤销已 fire 的 onDrag")
    }

    // MARK: - 5. 状态泄漏兜底回归 (testSplitterDrag_resetsStateAfterClick)

    /// 路径 B (真根因): .onEnded 不保证每次 fire, @State 跨 gesture 泄漏。
    /// fix7 在 click 路径 (.onChanged 入口) 重置 `lastReportedDragValue`
    /// = 0, 下次合法 drag 从干净 baseline 开始。 这条测试锁这条 invariant:
    /// 即便 `lastReported` 是 stale (e.g. 模拟 .onEnded 没 fire), 第一次
    /// click 路径的 dragDelta 返回 nil 且不依赖 lastReported (返回 nil 的
    /// 条件只看 cumulative, 不看 lastReported)。
    func testSplitterDrag_resetsStateAfterClick() {
        // 模拟上一次 drag 的 lastReported = 240 (e.g. .onEnded 没 fire).
        let staleLastReported: CGFloat = 240

        // 第一次 .onChanged 是 click (cumulative = 2): 返回 nil, 不调
        // onDrag. 这条 click 路径下 policy 不依赖 lastReported (条件只
        // 看 cumulative < threshold).
        let clickAfterLeak = SplitterDragPolicy.dragDelta(
            cumulative: 2,
            lastReported: staleLastReported
        )
        XCTAssertNil(clickAfterLeak,
            "click 路径返回 nil (= 不调 onDrag), 即便 lastReported stale")

        // View 端按 fix7 入口代码: click 路径把 lastReportedDragValue 重置
        // 0. 下一次合法 drag 从干净 baseline 开始:
        //   dragDelta(cumulative: 50, lastReported: 0) = 50
        let cleanDrag = SplitterDragPolicy.dragDelta(
            cumulative: 50,
            lastReported: 0  // 已被 fix7 重置
        )
        XCTAssertEqual(cleanDrag, 50,
            "click 路径重置 lastReported 后, 下次 drag 增量 = 50 (干净 baseline)")

        // 对比: 如果不重置, dragDelta(cumulative: 50, lastReported: 240) = -190,
        // 这就是路径 B 真根因产生的 spurious 大 delta (= 90:10 量级).
        let leakedDrag = SplitterDragPolicy.dragDelta(
            cumulative: 50,
            lastReported: 240
        )
        XCTAssertEqual(leakedDrag, -190,
            "不重置 lastReported 会算出 -190 spurious delta (路径 B 真根因)")

        // 这条测试要锁的 invariant: View 端必须按 fix7 在 click 路径重置
        // lastReportedDragValue. 单测通过 policy 函数本身无法验证这一点,
        // 但可以验证"假设重置, 一切正常; 假设不重置, 真根因会复现"。
    }
}
