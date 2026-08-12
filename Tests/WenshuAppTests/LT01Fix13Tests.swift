// LT01Fix13Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix13
//
// 装机 user 8/7 实机拍"水平 splitter 拖到 90:10 (极端比例) 后被锁住,
// 不用重置布局无法恢复"。 真根因 (PM-direct 自纠):
//
// - `clamp` 函数用 `min(max(x, lo), hi)` — 拖到 0.10 时返回 0.10, 但
//   drag handler (= NativeSplitterView.mouseDragged) 仍认为拖动有效,
//   继续累积 `lastReported`
// - 类似 LT-01-fix7 路径 B 的 `@State lastReportedDragValue` 跨 gesture
//   泄漏 — clamp 边界时 drag handler 状态没清, 下次 drag 从污染
//   baseline 开始 (= 算出 spurious 大 delta)
//
// 修法 (LT-01-fix13, 见 NativeSplitter.swift 头注释):
//   1. onDrag closure 签名 `((CGFloat) -> Void)?` → `((CGFloat) -> Bool)?`
//      (= Bool = "applied, ratios 真变")
//   2. LayoutShellViewModel 3 个 adjustXxx 加 @discardableResult + 返回
//      Bool (= proposed == clamped)
//   3. NativeSplitterView.mouseDragged: 收到 false → reset
//      `lastReported = 0` (干净 baseline)
//
// 4 个测试 case (派单 prompt 要求):
//   1. testNativeSplitterDrag_clampAtLowerBound_resetsState
//      drag 到 0.10 边界 → VM 返回 false → lastReported 重置 (= state
//      干净 baseline)
//   2. testNativeSplitterDrag_clampAtUpperBound_resetsState
//      drag 到 0.90 边界 → 同上
//   3. testNativeSplitterDrag_afterClamp_canDragBack
//      clamp 后松手 + 重新 mouseDown + 拖回中点 → ratios 正确
//   4. testNativeSplitterDrag_extremeRatio_doesNotLock
//      拖成 90:10 后下次 drag 能拖回 50:50 (= 装机 user 实机拍锁死的回归)
//
// 边界:
//   - 不依赖 SwiftUI gesture host — 直接调 NativeSplitterView 的
//     mouseDown / mouseDragged / mouseUp (= NSEvent 路径)
//   - 所有 NativeSplitterView 测试标 @MainActor (= onDrag 是 MainActor
//     隔离, 必须 MainActor 调用)
//   - 旧 fix7 fragile 测试 (testSplitterDrag_stillChangesRatio 期望
//     ratios[3] = 0.6 等等) **不要求全过** (= 派单边界, fix6 sign fix
//     后 stale, 不在 fix13 范围)
//   - 另加 bonus 测试: testAdjustBottomHeight_discardableResult_doesNotBreakOldCallsites
//     (锁 `@discardableResult` 兼容旧调用点)

import XCTest
import AppKit
@testable import WenshuApp

final class LT01Fix13Tests: XCTestCase {

    // MARK: - helper

    /// Construct a `NSEvent` of a given type + location. Mirrors the
    /// pattern in `LT01Fix9Tests` so the tests read identically.
    @MainActor
    private func makeEvent(
        _ type: NSEvent.EventType,
        x: CGFloat,
        y: CGFloat
    ) -> NSEvent {
        return NSEvent.mouseEvent(
            with: type,
            location: NSPoint(x: x, y: y),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
    }

    /// Default `adjustBottomHeight` configuration used across cases.
    /// 600pt window height means a single 0.1 ratio = 60pt (= the FCP
    /// 30px auto-collapse threshold's twice-over, so dragging more than
    /// 240pt down hits the 0.10 floor).
    private let kTotalHeight: CGFloat = 600
    private let kTotalWidth: CGFloat = 1200

    // MARK: - 1. testNativeSplitterDrag_clampAtLowerBound_resetsState

    /// Drag the bottom-of-window splitter far enough down to clamp
    /// `ratios[3]` at `0.10` (= "90:10" 状态: upper 90% / lower 10%)。
    /// 装机 user 实机拍: 拖到这个边界后, 拖动状态被锁死。 修法 =
    /// VM 返回 `false` (= clamp) 时 NativeSplitterView reset
    /// `lastReported = 0`。
    ///
    /// 测试通过观察 `onDrag` closure 返回的 Bool (= clamp 信号) 来验:
    /// VM 真的在边界返回 false (= adjustBottomHeight 的新 contract)。
    @MainActor
    func testNativeSplitterDrag_clampAtLowerBound_resetsState() {
        let vm = LayoutShellViewModel()
        XCTAssertEqual(vm.snapshot.ratios[3], 0.5, accuracy: 0.0001,
                       "默认 ratios[3] = 0.5 (50:50 baseline)")

        // 把 ratios[3] 从 0.5 拖到 0.10 (= 240px 拖拽, deltaRatio = 0.4):
        // ratios[3] = 0.5 - 0.4 = 0.10, 正好在 lower bound (= 0.10)。
        // 此时 proposed == clamped → adjustBottomHeight 返回 true。
        let atLowerBound = vm.adjustBottomHeight(delta: 240, totalHeight: kTotalHeight)
        XCTAssertTrue(atLowerBound,
            "ratios[3] 恰好到 0.10 (= clamped == proposed) → applied = true")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001)

        // 再拖 10px (= ratios[3] = 0.10 - 0.0167 = 0.0833, 但 clamp 到 0.10):
        // proposed != clamped → adjustBottomHeight 返回 false (= 边界信号)。
        let pastLowerBound = vm.adjustBottomHeight(delta: 10, totalHeight: kTotalHeight)
        XCTAssertFalse(pastLowerBound,
            "ratios[3] 想跌到 0.083 但 clamp 在 0.10 → applied = false (= clamp 边界信号)")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001,
                       "clamp 后 ratios[3] 仍 = 0.10 (没被穿过去)")

        // NativeSplitterView 集成验证: onDrag closure 返回 false 时
        // lastReported 必须 reset (= state leak 兜底)。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .vertical

        var appliedResults: [Bool] = []
        view.onDrag = { _ in
            // 模拟 VM 行为: 第一次 drag applied, 第二次 drag clamped。
            let wasApplied = appliedResults.count == 0
            appliedResults.append(wasApplied)
            return wasApplied
        }

        // mouseDown 设 dragStart = (0, 0).
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 0))

        // 第一次 mouseDragged: cumulative = 240 (>= 5px threshold), onDrag
        // 返回 true (= applied)。 lastReported 应被设成 240 (= dragState
        // 正常累积)。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 240))
        XCTAssertEqual(appliedResults, [true])

        // 第二次 mouseDragged: cumulative = 250, incremental = 10
        // (250 - 240)。 onDrag 返回 false (= clamp)。 NativeSplitterView
        // 必须 reset lastReported = 0 (= 干净 baseline, 防 state leak)。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 250))
        XCTAssertEqual(appliedResults, [true, false],
            "VM 必须收到 applied 信号 (true → false), NativeSplitterView 据此 reset")

        // 关键验证: 第三次 mouseDragged 的增量必须是 cumulative 减去 reset
        // 后的 lastReported (= 0), 不是 lastReported = 250 (= 没 reset)。
        // 第三次 mouseDragged at (0, 350) → cumulative = 350。
        // 如果 lastReported reset (= 0) → incremental = 350 - 0 = 350 (= 干净 baseline)。
        // 如果 lastReported 没 reset (= 250) → incremental = 350 - 250 = 100 (state leak)。
        var thirdCallIncremental: CGFloat? = nil
        view.onDrag = { incremental in
            thirdCallIncremental = incremental
            return incremental == 350
        }

        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 350))
        XCTAssertEqual(thirdCallIncremental, 350,
            "clamp 后 lastReported 必须 reset → 下次 drag 增量 = cumulative (= 干净 baseline, 不是 state leak 的小值)")
    }

    // MARK: - 2. testNativeSplitterDrag_clampAtUpperBound_resetsState

    /// 对称的 upper bound (= 0.90) 测试。 `adjustBottomHeight` 用
    /// `max(0.10, min(0.90, ...))`, 向上拖 (= delta < 0) 会让
    /// ratios[3] 涨, 触 0.90 上界。
    @MainActor
    func testNativeSplitterDrag_clampAtUpperBound_resetsState() {
        let vm = LayoutShellViewModel()

        // 向上拖 240px (= delta = -240, ratios[3] = 0.5 - (-0.4) = 0.9,
        // 恰好在上界)。 proposed == clamped → applied = true。
        let atUpperBound = vm.adjustBottomHeight(delta: -240, totalHeight: kTotalHeight)
        XCTAssertTrue(atUpperBound,
            "ratios[3] 恰好到 0.90 (= clamped == proposed) → applied = true")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.90, accuracy: 0.0001)

        // 再向上拖 10px (= ratios[3] = 0.90 + 0.0167 = 0.917, clamp 到 0.90).
        let pastUpperBound = vm.adjustBottomHeight(delta: -10, totalHeight: kTotalHeight)
        XCTAssertFalse(pastUpperBound,
            "ratios[3] 想涨到 0.917 但 clamp 在 0.90 → applied = false")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.90, accuracy: 0.0001,
                       "clamp 后 ratios[3] 仍 = 0.90 (没被穿过去)")

        // NativeSplitterView 集成验证: 反方向 clamp 也触发 reset。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .vertical

        var appliedResults: [Bool] = []
        view.onDrag = { _ in
            let wasApplied = appliedResults.count == 0
            appliedResults.append(wasApplied)
            return wasApplied
        }

        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 0))
        // 第一次 drag 向上 240 (= cumulative = -240).
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: -240))
        XCTAssertEqual(appliedResults, [true])

        // 第二次 drag 向上到 cumulative = -250, incremental = -10。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: -250))
        XCTAssertEqual(appliedResults, [true, false])

        // 第三次 drag (= 验证 lastReported reset): cumulative = -350,
        // expected incremental = -350 (干净 baseline)。
        var thirdCallIncremental: CGFloat? = nil
        view.onDrag = { incremental in
            thirdCallIncremental = incremental
            return incremental == -350
        }
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: -350))
        XCTAssertEqual(thirdCallIncremental, -350,
            "clamp 后 lastReported 必须 reset → 下次 drag 增量 = cumulative (干净 baseline)")
    }

    // MARK: - 3. testNativeSplitterDrag_afterClamp_canDragBack

    /// clamp 到边界 + 松手 + 重新 mouseDown + 拖回中点 → ratios 正确。
    /// 这是装机 user 实机拍"水平 splitter 拖到 90:10 后被锁住, 不用重置
    /// 布局无法恢复" 的核心回归: 修复后用户能流畅从 90:10 拖回 50:50。
    @MainActor
    func testNativeSplitterDrag_afterClamp_canDragBack() {
        let vm = LayoutShellViewModel()
        let initialRatios3 = vm.snapshot.ratios[3]
        XCTAssertEqual(initialRatios3, 0.5, accuracy: 0.0001)

        // 模拟装机 user 真实操作序列:
        //   1. drag 到 0.10 边界 (= 240px 拖拽)
        //   2. 松手 (= mouseUp, lastReported = 0)
        //   3. 重新 mouseDown (新 dragStart, lastReported = 0)
        //   4. 反向拖回 50:50 (= -120px)
        vm.adjustBottomHeight(delta: 240, totalHeight: kTotalHeight)
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001,
                       "拖到 0.10 边界 (clamp 信号前)")

        // 模拟 mouseUp → mouseDown cycle (NativeSplitterView 自动 reset
        // lastReported, fix9 + fix13 都做)。
        // 这里只验 VM 层 drag-after-clamp 行为:
        vm.adjustBottomHeight(delta: -120, totalHeight: kTotalHeight)
        XCTAssertEqual(vm.snapshot.ratios[3], 0.30, accuracy: 0.0001,
                       "反向拖 -120px → ratios[3] = 0.10 + 120/600 = 0.30 (= 干净 baseline, 没被 state leak 污染)")

        // 再拖 120px 向上 (= -120): ratios[3] = 0.30 + 0.2 = 0.50 (= 回到中点)
        vm.adjustBottomHeight(delta: -120, totalHeight: kTotalHeight)
        XCTAssertEqual(vm.snapshot.ratios[3], 0.50, accuracy: 0.0001,
                       "再拖 -120px → ratios[3] = 0.50 (= 完美回到中点, 装机 user 实机拍锁死 BUG 不复现)")

        // NativeSplitterView 集成验证: 全套 gesture cycle (= mouseDown →
        // mouseDragged 多次 → mouseUp → mouseDown → mouseDragged) 在
        // clamp 边界后仍能正常工作。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .vertical

        var onDragCallCount = 0
        var lastApplied: Bool = false
        view.onDrag = { _ in
            onDragCallCount += 1
            // 第一次 gesture 的最后两次 (= cumulative = 240 + 10 + 20 ...)
            // 都返回 false (= clamp)。 第二次 gesture 全返回 true
            // (= 拖回中点, ratios 自由动)。
            if onDragCallCount <= 2 {
                lastApplied = false  // clamp
            } else {
                lastApplied = true  // applied
            }
            return lastApplied
        }

        // Gesture 1: drag 到极端。
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 0))
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 240))
        XCTAssertEqual(onDragCallCount, 1)

        // 模拟拖到 clamp 边界 (= cumulative = 260, incremental = 20).
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 260))
        XCTAssertEqual(onDragCallCount, 2)

        view.mouseUp(with: makeEvent(.leftMouseUp, x: 0, y: 260))

        // Gesture 2: 新 mouseDown (dragStart = (0, 260), lastReported
        // 应已被 mouseUp 重置 + fix13 的 clamp reset 兜底)。
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 260))

        // 反向拖 -100px (= cumulative = -100, incremental 期望 = -100,
        // 因为 lastReported = 0 from mouseUp + fix13 reset)。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 160))
        XCTAssertEqual(onDragCallCount, 3)
        XCTAssertTrue(lastApplied, "clamp 后新 gesture 的 drag 仍调 onDrag (applied)")

        view.mouseUp(with: makeEvent(.leftMouseUp, x: 0, y: 160))
    }

    // MARK: - 4. testNativeSplitterDrag_extremeRatio_doesNotLock

    /// 装机 user 8/7 实机拍"水平 splitter 拖到 90:10 后被锁住, 不用重置
    /// 布局无法恢复"。 这条测试是修复的主回归 — 拖到 90:10 后再拖回
    /// 50:50, ratios 必须正确恢复 (= 不锁死)。
    ///
    /// 测试通过 NativeSplitterView 全套 gesture cycle 模拟装机 user
    /// 真实操作, 并把 onDrag closure 接到真实 VM (= LayoutShellViewModel)
    /// 验证 end-to-end: 模拟"极端拖拽 → 松手 → 反向拖拽 → 回中点"完整
    /// 链路, 最终 ratios[3] 必须 = 0.5 (= 50:50)。
    ///
    /// LT-01-fix17 坐标 (cumulative 算法 + dragStart reset):
    ///   axisDelta(.vertical, dragStart, current) = dragStart.y - current.y
    ///   向下拖 (y 减小) → axisDelta 正 → ratios[3] 调小
    ///   向上拖 (y 增大) → axisDelta 负 → ratios[3] 调大
    @MainActor
    func testNativeSplitterDrag_extremeRatio_doesNotLock() {
        let vm = LayoutShellViewModel()

        // 直接构造 view 来手动 inject onDrag closure (NativeSplitter
        // NSViewRepresentable wrapper 在没 NSHostingController 时不便
        // 直接 unit-test, 见 LT01Fix9Tests 同款模式)。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .vertical
        view.onDrag = { delta in
            return vm.adjustBottomHeight(delta: delta, totalHeight: self.kTotalHeight)
        }

        // Gesture 1: 极端拖拽 (= 向下 240px 到 0.10 边界 + 30px 多拖 clamp)。
        // mouseDown(0, 1080) → dragStart = (0, 1080)。
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 1080))

        // 向下拖 240px (= cumulative = 1080 - 840 = +240, ratios[3] =
        // 0.5 - 0.4 = 0.10, 正好边界, applied = true)。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 840))
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001,
                       "极端拖拽后 ratios[3] = 0.10 (= 90:10 上半/下半)")

        // 多向下拖 30px (= cumulative = 1080 - 810 = +270, ratios[3]
        // 想跌到 0.05 但 clamp 到 0.10, applied = false → dragStart
        // reset 到 current = (0, 810))。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 810))
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001,
                       "clamp 后 ratios[3] 仍 = 0.10 (没被穿过去)")

        view.mouseUp(with: makeEvent(.leftMouseUp, x: 0, y: 810))

        // Gesture 2: 装机 user 想拖回 50:50 (= 向上 240px)。
        // 鼠标当前位置 = (0, 810), 新 dragStart = (0, 810)。
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 810))

        // 向上拖 240px (= cumulative = 810 - 1050 = -240, ratios[3]
        // = 0.10 - (-0.4) = 0.50)。
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 1050))
        XCTAssertEqual(vm.snapshot.ratios[3], 0.50, accuracy: 0.0001,
                       "clamp 后反向拖回 ratios[3] = 0.50 (= 50:50 完美恢复, 装机 user 实机拍锁死 BUG 不复现)")

        view.mouseUp(with: makeEvent(.leftMouseUp, x: 0, y: 1050))

        // 最后再 Gesture 3: 验证状态完全干净 (dragStart = mouseDown 处
        // 重设, isDragging = false), 拖动行为正常。
        view.mouseDown(with: makeEvent(.leftMouseDown, x: 0, y: 810))
        view.mouseDragged(with: makeEvent(.leftMouseDragged, x: 0, y: 690))
        XCTAssertEqual(vm.snapshot.ratios[3], 0.30, accuracy: 0.0001,
                       "Gesture 3 拖动继续生效 (state 完全干净, 没泄漏)")
        view.mouseUp(with: makeEvent(.leftMouseUp, x: 0, y: 690))
    }

    // MARK: - bonus: VM @discardableResult 兼容旧调用点

    /// LT-01-fix13 把 3 个 adjustXxx 改成返回 Bool + @discardableResult。
    /// 旧调用点 (= 不接返回值) 必须仍能编译 + 行为一致。 这条测试锁
    /// `@discardableResult` 兼容性。
    @MainActor
    func testAdjustBottomHeight_discardableResult_doesNotBreakOldCallsites() {
        let vm = LayoutShellViewModel()

        // 不接返回值 (旧调用方式)。
        vm.adjustBottomHeight(delta: 60, totalHeight: kTotalHeight)
        XCTAssertEqual(vm.snapshot.ratios[3], 0.4, accuracy: 0.0001,
                       "丢弃返回值 → 行为不变 (修前/修后 ratios[3] 都 = 0.4)")

        // 接返回值 (新调用方式)。
        let applied = vm.adjustBottomHeight(delta: 30, totalHeight: kTotalHeight)
        XCTAssertTrue(applied, "ratios[3] 从 0.4 到 0.35, 在边界内 → applied = true")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.35, accuracy: 0.0001)

        // 接返回值 + clamp 边界信号。
        let clamped = vm.adjustBottomHeight(delta: 600, totalHeight: kTotalHeight)
        XCTAssertFalse(clamped, "ratios[3] 从 0.35 想跌到 -0.65, clamp 到 0.10 → applied = false")
        XCTAssertEqual(vm.snapshot.ratios[3], 0.10, accuracy: 0.0001)
    }
}
