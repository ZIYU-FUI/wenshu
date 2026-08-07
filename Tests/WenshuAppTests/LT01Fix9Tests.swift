// LT01Fix9Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix9
//
// 装机 user 8/7 实机拍 "全部原生". 5 个 case 锁 NativeSplitter 行为契约:
//
//   1. testNativeSplitterView_visibleDivider_isOnePointThin
//      NSSplitView `.thin` divider 风格: 1pt 细线 (不是 6px 自写 rect).
//
//   2. testNativeSplitterView_horizontalCursor_mapsToResizeLeftRight
//      .horizontal orientation → mouseEntered push NSCursor.resizeLeftRight
//      (通过暴露的 `cursorForOrientation` 测试 helper 验证 mapping,
//       不构造 NSEvent 避免 actor isolation / NSEvent init 复杂度).
//
//   3. testNativeSplitterView_verticalCursor_mapsToResizeUpDown
//      同上, .vertical → .resizeUpDown.
//
//   4. testNativeSplitterView_singleClick_doesNotDispatchOnDrag
//      LT-01-fix7 真根因 fix 兜底: click 等价 translation (cumulative
//      < 5px) 走 `SplitterDragPolicy.dragDelta` 返回 nil (= 不调 onDrag)。
//
//   5. testNativeSplitter_dragDispatched_delta
//      drag 路径 = NSEvent mouseDragged + onDrag closure 收到正确 delta。
//
// 边界:
//   - 不依赖 LayoutShellView (避免整个 SwiftUI view hierarchy 实例化
//     引入 flaky 测试 — NativeSplitterView 是独立 NSView, 可直接测试)
//   - NSCursor 测试: 不验证 NSCursor.current (= 系统全局, 易 flaky),
//     通过暴露的 cursorForOrientation 静态 helper 验证 mapping 契约。
//   - 所有 NativeSplitterView 测试标 @MainActor (= onDrag 是 MainActor
//     隔离, 必须 MainActor 调用)。

import XCTest
import AppKit
@testable import WenshuApp

final class LT01Fix9Tests: XCTestCase {

    // MARK: - 1. 1pt 细线 (NSSplitView `.thin` 风格)

    /// NSSplitView `.thin` dividerStyle 是 1pt (= LT-01-fix7 自写 6px
    /// rect 的根治)。 NativeSplitterView 暴露 `visibleDividerThickness`
    /// (= 1) + `hitAreaThickness` (= 1, LT-01-fix16 跟 visible 一样宽,
    /// 整个 hit area 都是 line, 0 inset),
    /// 装机 user 实机验"分割线细细一条"的 source-level 保证。
    ///
    /// 不调 draw(): 没 NSWindow context 时 draw 会 trap (= 测试 runner
    /// 不构造 NSWindow)。 draw 路径装机 user 实机验覆盖 (分裂线 1pt
    /// 视觉 = 上面两个常量直接驱动 lineRect 计算)。
    @MainActor
    func testNativeSplitterView_visibleDivider_isOnePointThin() {
        XCTAssertEqual(
            NativeSplitterView.visibleDividerThickness, 1,
            "visible divider 必须是 1pt (= NSSplitView .thin style, 不是 6px 自写)"
        )

        // LT-01-fix16: hit area 缩到 1pt 跟 visible 一样宽, 整个 hit area
        // 都是 line, 0 inset, line 跟 panel 边界完全贴合。 不变量保持:
        // hit area ≥ visible (= 等于)。
        XCTAssertGreaterThanOrEqual(
            NativeSplitterView.hitAreaThickness,
            NativeSplitterView.visibleDividerThickness,
            "hit area 必须 ≥ visible divider (LT-01-fix16: hit area 跟 visible 一样宽 = 1pt)"
        )
        XCTAssertEqual(
            NativeSplitterView.hitAreaThickness, 1,
            "hit area = 1pt (LT-01-fix16: hit area 跟 visible divider 同样宽, 整个 hit area 都是 line, 0 inset)"
        )

        // 实例化 + 验证 NSView 子类 init 路径不 crash + 关键 flag。
        let frame = NSRect(x: 0, y: 0, width: 1, height: 200)
        let view = NativeSplitterView(frame: frame)
        view.orientation = .horizontal
        XCTAssertTrue(view.wantsLayer, "wantsLayer 必须 = true (1pt 细线走 CALayer)")
        XCTAssertEqual(view.frame, frame, "init frame 保持")
        XCTAssertTrue(view.acceptsFirstResponder, "NSView 必须收 first responder (拖动)")
    }

    // MARK: - 2. 水平 cursor (.horizontal → .resizeLeftRight)

    /// 暴露 cursorForOrientation 静态 helper 让测试验证 mapping 契约
    /// (= production code 在 mouseEntered 用的同一函数, 保证 refactor
    /// 时不会改错)。 NSCursor.push/pop 不验证 (= AppKit 全局栈, 易 flaky)。
    @MainActor
    func testNativeSplitterView_horizontalCursor_mapsToResizeLeftRight() {
        let cursor = NativeSplitterView.cursorForOrientation(.horizontal)
        // NSCursor.resizeLeftRight 是 NSCursor 的内置常量, 同一 instance
        // 比较 = 真值指针相同。 测试不构造 NSEvent, 不验证 push/pop,
        // 只验证"orientation → cursor" mapping = NSSplitView 内置行为。
        XCTAssertTrue(
            cursor === NSCursor.resizeLeftRight,
            ".horizontal orientation → NSCursor.resizeLeftRight (NSSplitView 内置)"
        )
    }

    // MARK: - 3. 垂直 cursor (.vertical → .resizeUpDown)

    /// .vertical orientation → NSCursor.resizeUpDown。 同上, 走
    /// cursorForOrientation 静态 helper 验证 mapping。
    @MainActor
    func testNativeSplitterView_verticalCursor_mapsToResizeUpDown() {
        let cursor = NativeSplitterView.cursorForOrientation(.vertical)
        XCTAssertTrue(
            cursor === NSCursor.resizeUpDown,
            ".vertical orientation → NSCursor.resizeUpDown (NSSplitView 内置)"
        )
    }

    // MARK: - 4. 单击不调 onDrag (LT-01-fix7 真根因 fix 兜底)

    /// LT-01-fix7 真根因: click-equivalent gesture 让 .onChanged 算出
    /// spurious 大 delta → 90:10 BUG。 NativeSplitterView 走 NSEvent
    /// mouseDown + mouseUp (中间无 mouseDragged) → onDrag 不调。
    ///
    /// 直接调 SplitterDragPolicy.dragDelta (= fix7 5px threshold) 验证:
    /// 任何 cumulative < threshold (= click) 都返回 nil (= 不调 onDrag)。
    /// 这是 fix9 保留的 safety net (= 见 docs/wenshu/LAYOUT-APPKIT-INVENTORY.md
    /// §1.1: "NativeSplitter 不该有这问题, 但 5px threshold 保留作防御性兜底")。
    @MainActor
    func testNativeSplitterView_singleClick_doesNotDispatchOnDrag() {
        // 1. click 等价谱: cumulative 从 0 到 threshold-0.1 全员 nil。
        for cumulative in stride(from: CGFloat(0), through: CGFloat(4.9), by: CGFloat(0.5)) {
            let delta = SplitterDragPolicy.dragDelta(cumulative: cumulative, lastReported: 0)
            XCTAssertNil(
                delta,
                "cumulative = \(cumulative) (sub-threshold click) 必须返回 nil (90:10 BUG 不复现)"
            )
        }

        // 2. 阈值边界: cumulative = threshold (5.0) = drag。
        XCTAssertNotNil(
            SplitterDragPolicy.dragDelta(
                cumulative: SplitterClickDetector.thresholdPixels, lastReported: 0
            ),
            "cumulative = threshold 边界 = drag (返回非 nil 增量)"
        )

        // 3. 路径 B 兜底: stale lastReported (e.g. 上次 drag 没 fire
        // mouseUp = @State 跨 gesture 泄漏) — click 路径必须仍返回 nil。
        XCTAssertNil(
            SplitterDragPolicy.dragDelta(cumulative: 2, lastReported: 240),
            "stale lastReported + click cumulative = nil (路径 B 真根因 fix)"
        )

        // 4. NativeSplitterView isDragging 状态机 (verifies click path):
        // mouseDown 设 dragStart, mouseUp 无 drag → isDragging 永远 false
        // → mouseUp 不回调 onDrag。 通过观察 dispatched counter 验证。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        var dispatchedDeltas: [CGFloat] = []
        view.onDrag = { dispatchedDeltas.append($0) }

        // 直接调用 mouseDown / mouseUp, 不构造 NSEvent (绕过 init 复杂度)。
        // override 方法接受 event 参数, 这里传 nil — super.mouseDown 调
        // event.locationInWindow 时会 force-unwrap, 所以传一个 dummy NSEvent。
        let dummyEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 4, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseDown(with: dummyEvent)

        let upEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 4, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseUp(with: upEvent)

        XCTAssertEqual(
            dispatchedDeltas, [],
            "mouseDown + mouseUp 无 drag → onDrag 不调 (90:10 BUG 不会复现)"
        )
    }

    // MARK: - 5. drag 路径调 onDrag (回归, 防 over-fix)

    /// 真正 drag (cumulative >= 5px) 必须仍 fire onDrag (= fix7 5px
    /// threshold 不 kill drag 路径)。 通过 SplitterDragPolicy 直接
    /// 验证增量计算正确 (= NativeSplitterView mouseDragged 的核心)。
    @MainActor
    func testNativeSplitter_dragDispatched_delta() {
        // dragDelta 增量语义:
        // - 第一次 drag: cumulative = 60, lastReported = 0 → delta = 60
        // - 第二次 drag: cumulative = 80, lastReported = 60 → delta = 20
        let firstDelta = SplitterDragPolicy.dragDelta(cumulative: 60, lastReported: 0)
        XCTAssertEqual(firstDelta, 60, "首次 drag 增量 = cumulative (lastReported = 0)")

        let secondDelta = SplitterDragPolicy.dragDelta(cumulative: 80, lastReported: 60)
        XCTAssertEqual(secondDelta, 20, "60 → 80 增量 = 20 (= NSEvent 拖动像素)")

        // 反向 drag: cumulative 跌回 sub-threshold = click (跟 fix7 一致)。
        let reverseToClick = SplitterDragPolicy.dragDelta(cumulative: 2, lastReported: 80)
        XCTAssertNil(
            reverseToClick,
            "drag 中途 cumulative < threshold = click (路径 B 兜底)"
        )

        // NativeSplitterView mouseDragged 调 dragDelta 后调 onDrag。
        // 直接模拟 mouseDown (设 dragStart) + mouseDragged (验证 onDrag 触发)。
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        var dispatched: [CGFloat] = []
        view.onDrag = { dispatched.append($0) }

        // mouseDown 把 dragStart 设到 (0, 50) (= production 路径)。
        let downEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 0, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseDown(with: downEvent)

        // mouseDragged 拖到 (60, 50): delta = 60 - 0 = 60, 5px threshold 过,
        // onDrag 调 1 次 with delta = 60。
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: 60, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseDragged(with: dragEvent)

        XCTAssertEqual(
            dispatched, [60],
            "mouseDragged (cumulative=60) 必须调 onDrag 1 次 with delta=60 (NSEvent 拖动契约)"
        )

        // 第二次 drag: cumulative = 80, lastReported = 60 → delta = 20。
        let dragEvent2 = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: 80, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseDragged(with: dragEvent2)

        XCTAssertEqual(
            dispatched, [60, 20],
            "二次 mouseDragged (60→80) 增量 = 20 (累积增量为 drag 路径核心)"
        )

        let upEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 80, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        view.mouseUp(with: upEvent)
    }
}
