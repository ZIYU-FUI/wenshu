// LT01Fix14Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix14
//
// 装机 user 8/7 实机拍 3 症状的真根因 + 真修回归, 3 个 case:
//
//   1. testNativeSplitterDrag_incrementalDelta_followsMouse
//      多帧 mouseDragged → 增量之和精确 = 当前 cursor 位置
//     (= "拖动中线跟鼠标", 修前 fix9 lastReported 耦合 threshold 会丢帧)。
//
//   2. testNativeSplitterDrag_mouseUp_finalPositionMatchesCursor
//      mouseDown → N 帧 mouseDragged → mouseUp at 末位 cursor →
//      累积 onDrag 增量 = mouseUp 位置 (= "松开后线 = 鼠标位置", 修前
//      最后 mouseDragged 与 mouseUp 间丢最后一帧)。
//
//   3. testNativeSplitterDrag_incrementalResetAfterMouseUp
//      mouseUp 之后再来一轮 drag → 第二轮首帧 incremental 用新
//      dragStart 当 reference (= previousLocation = nil 兜底,
//      上一轮 previousLocation 不污染新周期)。
//
// 反向 (LT-01-fix11) 修对的部分不再单独测 — 走的就是 `axisDelta`
// 静态函数, 而 `axisDelta` 沿用 fix11 的 `start.y - current.y`
// (= AppKit 窗口坐标系 y 朝上 → 取反成向下为正), 反向验证已在
// LT-01-fix11 派单的单测里 PASS, fix14 不重测。

import XCTest
import AppKit
@testable import WenshuApp

@MainActor
final class LT01Fix14Tests: XCTestCase {

    // MARK: - Helpers

    /// Construct a minimal `NSEvent` for mouseDown / mouseDragged /
    /// mouseUp. We can't use `NSEvent.mouseEvent` with `.leftMouseDown`
    /// etc. without `windowNumber` set (which the test runner doesn't
    /// have); the same `NSEvent.mouseEvent(...)` factory is used by
    /// `LT01Fix9Tests`, so we mirror that pattern.
    private static func makeEvent(
        type: NSEvent.EventType,
        location: NSPoint
    ) -> NSEvent {
        return NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
    }

    // MARK: - 1. testNativeSplitterDrag_incrementalDelta_followsMouse

    /// 装机 user 8/7 实机拍 "拖动中线不在鼠标位置" (LT-01-fix14 真根因)。
    /// fix14 真修: NSEvent 标准增量算法, `previousLocation` 当 reference,
    /// 增量之和 = cursor 离 dragStart 的距离。
    ///
    /// 模拟多帧 mouseDragged (0,50)→(60,50)→(80,50)→(95,50):
    ///   frame 1: previousLocation = nil → ref = dragStart = (0,50)
    ///            incremental = 60 - 0 = 60
    ///   frame 2: previousLocation = (60,50) → incremental = 80 - 60 = 20
    ///   frame 3: previousLocation = (80,50) → incremental = 95 - 80 = 15
    /// 增量之和 (60 + 20 + 15 = 95) = (current.x - dragStart.x)
    /// → 线精确跟手。
    func testNativeSplitterDrag_incrementalDelta_followsMouse() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        var dispatched: [CGFloat] = []
        view.onDrag = { dispatched.append($0) }

        // mouseDown at (0, 50) — dragStart = (0, 50); previousLocation = nil.
        view.mouseDown(with: Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 0, y: 50)
        ))

        // mouseDragged at (60, 50) — frame 1, ref = dragStart.
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        ))

        // mouseDragged at (80, 50) — frame 2, ref = previousLocation = (60, 50).
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 80, y: 50)
        ))

        // mouseDragged at (95, 50) — frame 3, ref = previousLocation = (80, 50).
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 95, y: 50)
        ))

        XCTAssertEqual(
            dispatched, [60, 20, 15],
            "frame-by-frame 增量 = (current - previous), 各帧独立"
        )

        // 增量之和 = 实际 cursor x - dragStart x = 95 - 0 = 95
        // (= 装机 user 验"线精确在鼠标位置")。
        let sum = dispatched.reduce(0, +)
        XCTAssertEqual(
            sum, 95, accuracy: 0.0001,
            "增量之和 (60+20+15=95) = 当前 cursor (95) - dragStart (0) → 线跟手"
        )
    }

    // MARK: - 2. testNativeSplitterDrag_mouseUp_finalPositionMatchesCursor

    /// 装机 user 8/7 实机拍 "松开鼠标后线的落点 ≠ 最终鼠标位置"。
    /// fix14 真修: 最后一次 mouseDragged 已经把 (上一帧 → mouseUp 位置)
    /// 的增量发完, 累积增量精确 = (mouseUp 位置 - dragStart 位置)。
    ///
    /// 鼠标位置故意选非整数倍 (123 px) — 防止"测试恰好能过" (= 增量
    /// 累积可能掩盖部分 pixel 误差, 选非整数值显式锁精确)。
    func testNativeSplitterDrag_mouseUp_finalPositionMatchesCursor() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        var finalPosition: CGFloat = 0
        view.onDrag = { delta in finalPosition += delta }

        // mouseDown at (0, 50).
        view.mouseDown(with: Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 0, y: 50)
        ))

        // frame 1: drag to (60, 50).
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        ))

        // frame 2: drag to (123, 50) (mouseUp 同一位置).
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 123, y: 50)
        ))

        // mouseUp at (123, 50) — 跟最后一帧 mouseDragged 同一位置, 模拟
        // "鼠标停在该位置松手" (= 装机 user 实机验场景)。
        view.mouseUp(with: Self.makeEvent(
            type: .leftMouseUp, location: NSPoint(x: 123, y: 50)
        ))

        // finalPosition = 60 + (123 - 60) = 123 = mouseUp 时 cursor x.
        XCTAssertEqual(
            finalPosition, 123, accuracy: 0.0001,
            "mouseUp 时累积增量 = 123 (= mouseUp 位置), 装机 user 实机验第 3 项"
        )
    }

    // MARK: - 3. testNativeSplitterDrag_incrementalResetAfterMouseUp

    /// 装机 user 8/7 实机拍隐藏 BUG (fix14 真修连带覆盖): mouseUp 之后
    /// 再来一轮 drag → 第二轮首帧 reference 必须是新 dragStart, 不
    /// 能被上一轮的 previousLocation 污染 (= 否则第二轮首帧 incremental
    /// 跨两个 drag 周期, 出大值)。
    ///
    /// 上一轮 dragEnd: (0,50) → (60,50) → mouseUp at (60,50).
    /// 下一轮 dragStart: (30,50), drag 到 (90,50).
    /// 期望第二轮 incremental = 90 - 30 = 60 (跟上一轮的 60 数值一样,
    /// 但 reference 是新 dragStart 而非旧 previousLocation)。
    func testNativeSplitterDrag_incrementalResetAfterMouseUp() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        var dispatched: [CGFloat] = []
        view.onDrag = { dispatched.append($0) }

        // ----- 第一轮 drag 周期 -----
        // mouseDown at (0, 50) — dragStart = (0, 50); previousLocation = nil.
        view.mouseDown(with: Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 0, y: 50)
        ))

        // drag to (60, 50) — frame 1, ref = dragStart.
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        ))

        // mouseUp at (60, 50) — isDragging = false → 清 previousLocation.
        view.mouseUp(with: Self.makeEvent(
            type: .leftMouseUp, location: NSPoint(x: 60, y: 50)
        ))

        // ----- 第二轮 drag 周期 (新 dragStart) -----
        // mouseDown at (30, 50) — dragStart = (30, 50); previousLocation = nil.
        view.mouseDown(with: Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 30, y: 50)
        ))

        // drag to (90, 50) — frame 1, ref = dragStart = (30, 50), NOT 上一轮 previousLocation.
        view.mouseDragged(with: Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 90, y: 50)
        ))

        XCTAssertEqual(
            dispatched, [60, 60],
            "第二轮首帧 incremental = 90 - 30 = 60 (= 新 dragStart 当 reference, 上一轮 previousLocation 不污染)"
        )
    }
}
