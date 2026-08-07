// LT01Fix16Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix16
//
// 装机 user 8/7 实机验 fix15 后拍 1 个残留视觉问题:
//   优化1 (细线 1-2px 间距) ❌ 没修 — fix15 把 lineRect 从居中 3.5pt
//   推到 hit area x=0, 但 hit area 仍 = 8pt, line 后还有 7pt 空白。
//
// 4 个 case 锁真修 (hit area 缩到 1pt, 整个 hit area 都是 line):
//
//   1. testNativeSplitterHitArea_width1pt
//      `NativeSplitterView.hitAreaThickness` 必须 = 1pt (= LT-01-fix16
//      真修, 从 8pt 缩到 1pt)。 source-level 锁真修。
//
//   2. testNativeSplitterDraw_noPadding
//      走 `NativeSplitterView.lineRect(in:orientation:)` 静态 helper:
//      hit area 现在 = 1pt 宽, lineRect 跟 hit area 完全重叠 (0 inset),
//      visual edge 直接贴 panel 边界。
//
//   3. testNativeSplitterDrag_afterShrinkHitArea_stillWorks
//      hit area 从 8pt 缩到 1pt 后, 拖动逻辑不变。 验证 onDrag 仍 callback。
//
//   4. testNativeSplitterCursor_afterShrinkHitArea_stillResets
//      hit area 从 8pt 缩到 1pt 后, mouseEntered/mouseExited 仍 fire,
//      cursor push/pop 配对仍正确。

import XCTest
import AppKit
@testable import WenshuApp

@MainActor
final class LT01Fix16Tests: XCTestCase {

    // MARK: - Helpers

    /// Construct a minimal `NSEvent` for mouseMoved / mouseDown /
    /// mouseDragged / mouseUp. `windowNumber: 0` (= 无 window context)
    /// 跟 LT01Fix14Tests / LT01Fix9Tests / LT01Fix15Tests 同款约定,
    /// 测试 runner 没 NSWindow 时也能跑。
    private static func makeEvent(
        type: NSEvent.EventType,
        location: NSPoint,
        clickCount: Int = 1,
        pressure: Float = 1.0
    ) -> NSEvent {
        return NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: pressure
        )!
    }

    // MARK: - 1. hit area 宽度 = 1pt

    /// 装机 user 8/7 实机验 fix15 后拍"细线两边还有 1-2px 间隙, 不贴
    /// panel 边界"。真根因 (PM-direct 自纠 #4): hit area 8pt 太宽,
    /// 1pt line 画在 hit area x=0 后还有 7pt 空白 (= 8-1), 视觉上 line
    /// 跟 panel 边界之间有 7pt 空隙。
    ///
    /// fix16 修法: hit area 从 8pt 缩到 1pt (= visibleDividerThickness
    /// 同样宽), 整个 hit area 都是 line, 0 inset, line 跟 panel 边界
    /// 完全贴合。
    ///
    /// 这个 test 锁 source-level 真修: `hitAreaThickness == 1` (= 不是
    /// 8, 不是 4 macOS HIG min, 不是 6 折中)。 装机 user 实机拍板接受
    /// 比 HIG min 小的 hit area (= 鼠标必须精准点击 line 才能拖, 但
    /// "细线就是唯一的区块分割, 不要任何边距" 优先级更高)。
    func testNativeSplitterHitArea_width1pt() {
        XCTAssertEqual(
            NativeSplitterView.hitAreaThickness, 1,
            "hit area 必须 = 1pt (LT-01-fix16 真修: hit area 跟 visible divider 同样宽, 整个 hit area 都是 line, 0 inset, line 贴 panel 边界)"
        )

        // 不变量: hit area 跟 visible divider 一样 (= LT-01-fix16 的核心
        // 不变量, 整个 hit area 都是 line, 没有 "line + 空白" 二段式)。
        XCTAssertEqual(
            NativeSplitterView.hitAreaThickness,
            NativeSplitterView.visibleDividerThickness,
            "hit area 必须 = visible divider (= 1pt, 整个 hit area 都是 line, fix16 核心不变量)"
        )

        // 反例锁: hit area 不能 ≥ 2 (= 不能回退到 8pt 老设计)。
        XCTAssertLessThan(
            NativeSplitterView.hitAreaThickness, 2,
            "hit area 不能 ≥ 2pt (防止回退到 8pt 老设计, 8-1=7pt 空白会回来)"
        )
    }

    // MARK: - 2. 1pt line visual edge 贴 panel 边界 (0 inset)

    /// 走 `NativeSplitterView.lineRect(in:orientation:)` 静态 helper 验证
    /// "line 视觉贴 panel 边界 (0 inset)"。
    ///
    /// LT-01-fix15 (优化1 第一阶段): lineRect 从居中 3.5pt 推到 hit area
    /// START edge (x=0), 但 hit area 还是 8pt 宽, lineRect = (0, 0, 1, h)
    /// (= line 1pt 宽, hit area 8pt 宽 → line 后还有 7pt 空白)。
    ///
    /// LT-01-fix16 (优化1 第二阶段): hit area 缩到 1pt 宽, bounds 现在
    /// = 1pt 宽, lineRect 跟 hit area 完全重叠 (整个 hit area 都是 line,
    /// 0 inset)。
    ///
    /// 测的是 input/output pure mapping, 不调 draw() (= 没 NSWindow
    /// context 时 draw 会 trap)。 production code 在 draw() 里调同一
    /// 个 helper, 所以"helper 通过" = "draw 视觉通过"。
    func testNativeSplitterDraw_noPadding() {
        // bounds = 1pt 宽 = fix16 后的 hit area 实际宽度
        let bounds = NSRect(x: 0, y: 0, width: 1, height: 200)

        // ----- Case A: .horizontal splitter (vertical 1pt line, 1pt 宽 hit area) -----
        let verticalLine = NativeSplitterView.lineRect(in: bounds, orientation: .horizontal)

        XCTAssertEqual(
            verticalLine.origin.x, 0,
            "vertical line 必须贴 hit area 左边缘 (x=0, 沿用 fix15 修法)"
        )
        XCTAssertEqual(
            verticalLine.origin.y, 0,
            "vertical line 必须贴 hit area 顶边缘 (y=0)"
        )
        XCTAssertEqual(
            verticalLine.size.width, 1,
            "vertical line 1pt 细线 (= bounds.width, hit area 缩到 1pt 后 line 跟 hit area 完全重叠)"
        )
        XCTAssertEqual(
            verticalLine.size.height, bounds.height,
            "vertical line 沿 hit area 整高 edge-to-edge"
        )

        // ----- Case B: .vertical splitter (horizontal 1pt line, 1pt 高 hit area) -----
        let horizontalLine = NativeSplitterView.lineRect(in: bounds, orientation: .vertical)

        XCTAssertEqual(
            horizontalLine.origin.x, 0,
            "horizontal line 必须贴 hit area 左边缘 (x=0)"
        )
        XCTAssertEqual(
            horizontalLine.origin.y, 0,
            "horizontal line 必须贴 hit area 顶边缘 (y=0, 沿用 fix15 修法)"
        )
        XCTAssertEqual(
            horizontalLine.size.width, bounds.width,
            "horizontal line 沿 hit area 整宽 edge-to-edge"
        )
        XCTAssertEqual(
            horizontalLine.size.height, 1,
            "horizontal line 1pt 细线 (= bounds.height, hit area 缩到 1pt 后 line 跟 hit area 完全重叠)"
        )

        // ----- Case C: lineRect 必须 == bounds (hit area 缩到 1pt 后核心不变量) -----
        // 整个 hit area 都是 line, lineRect == bounds (0 inset, 无空白)。
        // 这是 fix16 的视觉不变量 (= line 跟 hit area 完全重叠)。
        XCTAssertEqual(
            verticalLine, bounds,
            "horizontal orientation: vertical line 1pt 宽 hit area 后, lineRect == bounds (0 inset, 整个 hit area 都是 line)"
        )

        // ----- Case D: 不变量 — 1pt 细线必须 thin (不是 6px 自写 rect) -----
        XCTAssertEqual(
            NativeSplitterView.visibleDividerThickness, 1,
            "visibleDividerThickness 必须 = 1pt (NSSplitView `.thin` 标准, 不是 6px 自写 rect)"
        )

        // ----- Case E: layout math 联动 (splitterPixels 同步) -----
        // hit area 缩到 1pt 后, LayoutState.swift 的 splitterPixels 必须
        // 同步从 8 改 1, 否则 layout math 预留 8pt × splitter_count 给
        // splitters, 但 SwiftUI 实际只给 1pt × splitter_count, trailing
        // 出现 14pt 空白 (= 装机 user "不要任何边距" 验不过)。
        XCTAssertEqual(
            LayoutSnapshot.splitterPixels, 1,
            "LayoutSnapshot.splitterPixels 必须 = 1 (跟 hitAreaThickness 同步, 否则 panel sized-for totalWidth - 16 但实际 splitter 占 1pt, trailing 14pt 空白)"
        )
    }

    // MARK: - 3. hit area 缩 1pt 后拖动仍跟手

    /// hit area 从 8pt 缩到 1pt 后, 拖动逻辑不变。 NSView 的 mouseDown/
    /// Down/Dragged 接收跟 bounds 大小无关 (= 只跟 bounds 内是否命中)。
    /// hit area 缩小 = 鼠标必须更精准, 但 drag 行为本身不变。
    ///
    /// 模拟完整 drag 周期 (mouseDown → mouseDragged → mouseUp) 在 1pt 宽
    /// 的 NativeSplitterView 上, 验证 onDrag 仍 callback (装机 user 拖动
    /// 仍跟手)。
    func testNativeSplitterDrag_afterShrinkHitArea_stillWorks() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 1, height: 100))
        view.orientation = .horizontal

        // onDrag callback 计数 (LT01Fix14Tests 同款 pattern, 验证回调触发)。
        var dragCount = 0
        var lastDelta: CGFloat = 0
        view.onDrag = { delta in
            dragCount += 1
            lastDelta = delta
        }

        // 1. mouseDown at center of 1pt hit area (x=0.5, y=50)。
        let downEvent = Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 0.5, y: 50)
        )
        view.mouseDown(with: downEvent)

        // 2. mouseDragged with cumulative 60 (> 5px threshold) → onDrag fires。
        //    dragStart = (0.5, 50), drag to (60, 50):
        //      axisDelta .horizontal: current.x - start.x = 60 - 0.5 = 59.5.
        let dragEvent = Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        )
        view.mouseDragged(with: dragEvent)

        XCTAssertGreaterThan(
            dragCount, 0,
            "hit area 缩到 1pt 后, mouseDragged 仍必须触发 onDrag (装机 user 拖动仍跟手, drag 行为不变)"
        )
        XCTAssertEqual(
            lastDelta, 59.5, accuracy: 0.001,
            "onDrag 收到的 incremental delta 必须 = 鼠标实际位移 (LT-01-fix14 增量算法, hit area 大小不影响增量算法)"
        )

        // 3. mouseUp → drag state 清 (= isDragging = false)。
        let upEvent = Self.makeEvent(
            type: .leftMouseUp, location: NSPoint(x: 60, y: 50)
        )
        view.mouseUp(with: upEvent)
    }

    // MARK: - 4. hit area 缩 1pt 后 cursor push/pop 配对仍正确

    /// hit area 从 8pt 缩到 1pt 后, mouseEntered/mouseExited 仍 fire
    /// (trackingArea 仍注册, 只是 rect = bounds = 1pt)。 装机 user "修
    /// cursor 用 1pt 单独 track" 拍板, 验证 cursor push/pop 配对不受
    /// hit area 缩窄影响。
    ///
    /// 测试不依赖 `NSCursor.current` (= 系统全局栈, 易 flaky), 改用
    /// `private(set) var cursorPushed: Bool` flag 验证 push/pop 配对。
    func testNativeSplitterCursor_afterShrinkHitArea_stillResets() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 1, height: 100))
        view.orientation = .horizontal

        // 1. 初始: cursorPushed = false (= 没 push 过 → 不要乱 pop)。
        XCTAssertFalse(
            view.cursorPushed,
            "初始 cursorPushed 必须 = false (没 push 过任何 cursor)"
        )

        // 2. mouseEntered → push resizeLeftRight cursor, cursorPushed = true。
        let enterEvent = Self.makeEvent(
            type: .mouseMoved,
            location: NSPoint(x: 0.5, y: 50),
            clickCount: 0,
            pressure: 0
        )
        view.mouseEntered(with: enterEvent)
        XCTAssertTrue(
            view.cursorPushed,
            "hit area 缩到 1pt 后 mouseEntered 仍必须设 cursorPushed = true (trackingArea rect = bounds = 1pt, 仍 fire)"
        )

        // 3. mouseExited → cursorPushed = false (配对 pop, LT-01-fix15 修)。
        let exitEvent = Self.makeEvent(
            type: .mouseMoved,
            location: NSPoint(x: 50, y: 50),
            clickCount: 0,
            pressure: 0
        )
        view.mouseExited(with: exitEvent)
        XCTAssertFalse(
            view.cursorPushed,
            "hit area 缩到 1pt 后 mouseExited 仍必须设 cursorPushed = false (配对 pop, hit area 大小不影响 push/pop 配对)"
        )

        // 4. 再 enter → push 1 次 → mouseUp (drag path) → cursorPushed = false。
        view.mouseEntered(with: enterEvent)
        XCTAssertTrue(view.cursorPushed, "re-enter 后 cursorPushed 必须 = true")

        let downEvent = Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 0.5, y: 50)
        )
        view.mouseDown(with: downEvent)

        let dragEvent = Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        )
        view.mouseDragged(with: dragEvent)

        let upEvent = Self.makeEvent(
            type: .leftMouseUp, location: NSPoint(x: 60, y: 50)
        )
        view.mouseUp(with: upEvent)

        XCTAssertFalse(
            view.cursorPushed,
            "hit area 缩到 1pt 后完整 drag 周期 (enter → down → drag → up) 后 cursorPushed 必须 = false (LT-01-fix15 BUG2 修法沿用)"
        )
    }
}
