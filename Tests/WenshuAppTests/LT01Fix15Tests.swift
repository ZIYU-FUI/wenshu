// LT01Fix15Tests.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix15
//
// 装机 user 8/7 实机拍 3 个二级问题 (拖完松手残留) + 1 个视觉优化:
//   1. 拖完松手 → 分割线 hover 高亮残留          (BUG1)
//   2. 拖完松手 → cursor 残留 resize 双箭头     (BUG2)
//   3. 1pt 细线在 hit area 内居中 → 看起来歪    (优化1)
//
// 3 个 case 锁真修:
//
//   1. testNativeSplitterDrag_mouseUp_clearsHover
//      mouseDown → mouseDragged → mouseUp (鼠标仍在 hit area 内)
//      → isHovered 必须 false (= mouseExited 不 fire, 必须显式清)。
//
//   2. testNativeSplitterDrag_mouseUp_resetsCursor
//      mouseEntered (push resize cursor)
//      → mouseDown → mouseDragged → mouseUp (鼠标仍在 hit area 内)
//      → cursorPushed 必须 false (= NSCursor.arrow.set() 兜底)。
//      测试不依赖 NSCursor.current (= 系统全局栈, 易 flaky),
//      改用 private(set) cursorPushed flag 验证 push/pop 配对。
//
//   3. testNativeSplitterDraw_noInsetPadding
//      走 `NativeSplitterView.lineRect(in:orientation:)` 静态 helper:
//      - .horizontal (vertical line) → x=0, width=1, height=bounds.height
//      - .vertical (horizontal line) → x=0, y=0, width=bounds.width, height=1
//      都不应有 inset/centering (= 1pt 线必须贴 hit area 边缘, 不浮在中间)。
//
// 边界:
//   - 只测 NativeSplitterView (= 独立 NSView, 不要 LayoutShellView 实例化,
//     避免 SwiftUI view hierarchy 拉一坨 sibling views 拖慢 XCTest / 引入 flaky)
//   - NSCursor 测试走 private(set) cursorPushed flag, 不读 NSCursor.current
//     (= NSCursor.current 是系统全局态, 跑 parallel tests 时会互相污染)
//   - redrawRequestCount 用同一处验收 (= 已有测试 LT01Fix10Tests 在用同款)。

import XCTest
import AppKit
@testable import WenshuApp

@MainActor
final class LT01Fix15Tests: XCTestCase {

    // MARK: - Helpers

    /// Construct a minimal `NSEvent` for mouseMoved / mouseDown /
    /// mouseDragged / mouseUp. 直接调 NSEvent.mouseEvent(...) ——
    /// `windowNumber: 0` (= 无 window context) 跟 LT01Fix14Tests /
    /// LT01Fix9Tests 同款约定, 测试 runner 没 NSWindow 时也能跑。
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

    // MARK: - 1. BUG1: mouseUp 清 hover

    /// 装机 user 8/7 实机拍 "抓住拖拽 → 释放鼠标 → 分割线还是高亮"。
    /// 真根因: 鼠标仍在 hit area 内 → mouseExited 不 fire → isHovered
    /// 残留。 fix15 修法: mouseUp 末尾显式 `isHovered = false` +
    /// `needsDisplay = true` (= 立即取消高亮, 双保险)。
    ///
    /// 模拟完整 drag 周期 (mouseEntered → mouseDown → mouseDragged
    /// → mouseUp), mouseUp 时 cursor 故意放在 hit area 中央 (= 不
    /// 触发 mouseExited 的场景), 验证 isHovered 被显式清。
    func testNativeSplitterDrag_mouseUp_clearsHover() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        let redrawsBeforeEnter = view.redrawRequestCount

        // 1. mouseEntered → isHovered 必须 = true (= 触发 hover 高亮).
        let enterEvent = Self.makeEvent(
            type: .mouseMoved,
            location: NSPoint(x: 4, y: 50),
            clickCount: 0,
            pressure: 0
        )
        view.mouseEntered(with: enterEvent)
        XCTAssertTrue(
            view.isHovered,
            "mouseEntered 必须设 isHovered = true (= hover 高亮启用)"
        )
        let redrawsAfterEnter = view.redrawRequestCount
        XCTAssertGreaterThan(
            redrawsAfterEnter, redrawsBeforeEnter,
            "mouseEntered 必须 schedule redraw (redrawRequestCount 递增)"
        )

        // 2. mouseDown → dragStart 设 (不要触发 isHovered 变化)。
        let downEvent = Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 4, y: 50)
        )
        view.mouseDown(with: downEvent)

        // 3. mouseDragged → cumulative 60 (> 5px threshold) → 调 onDrag 1 次,
        // isDragging = true。 dragStart = (4, 50), drag to (60, 50):
        //   axisDelta .horizontal: current.x - start.x = 60 - 4 = 56.
        let dragEvent = Self.makeEvent(
            type: .leftMouseDragged, location: NSPoint(x: 60, y: 50)
        )
        view.mouseDragged(with: dragEvent)

        // 4. mouseUp at (60, 50) — 鼠标仍在 hit area 内 (hit area = (0, 0, 8, 100),
        // x=60 是 bounds 外, 但 NSEvent 不验证 location 在 bounds 内)。
        // 装机 user 实际场景: "鼠标在 hit area 内按下 → 在 hit area 内松手",
        // 但为测试稳定性, mouseUp 位置可以随便, 关键是 fix15 mouseUp
        // 不依赖 mouseExited fire 就清 isHovered.
        let upEvent = Self.makeEvent(
            type: .leftMouseUp, location: NSPoint(x: 60, y: 50)
        )
        view.mouseUp(with: upEvent)

        // 5. **fix15 BUG1 真修**: mouseUp 必须立即清 isHovered
        // (= 装机 user 实机验 "抓住拖拽 → 释放鼠标 → 分割线立即不高亮")。
        XCTAssertFalse(
            view.isHovered,
            "mouseUp 必须清 isHovered (鼠标仍在 hit area 内 → mouseExited 不 fire → 必须显式清)"
        )

        // 6. needsDisplay 必须 schedule redraw (= 双保险)。
        let redrawsAfterUp = view.redrawRequestCount
        XCTAssertGreaterThan(
            redrawsAfterUp, redrawsAfterEnter,
            "mouseUp 清 isHovered 后必须 schedule redraw (redrawRequestCount 递增)"
        )
    }

    // MARK: - 2. BUG2: mouseUp reset cursor

    /// 装机 user 8/7 实机拍 "抓住拖拽 → 释放鼠标 → 鼠标变形没恢复
    /// (还是 resizeLeftRight / resizeUpDown 双箭头, 应恢复 .arrow)"。
    /// 真根因: 同 BUG1, 鼠标仍在 hit area 内 → mouseExited 不 fire →
    /// push 的 cursor 还在栈顶。 fix15 修法: mouseUp 末尾
    /// `if cursorPushed { NSCursor.pop(); cursorPushed = false }`
    /// (= 配对 pop) + `NSCursor.arrow.set()` (= 兜底)。
    ///
    /// 测试不依赖 `NSCursor.current` (= 系统全局栈, 跑 parallel tests 时
    /// 会互相污染, XCTest 默认串行但 CI 并行 stage 可能 flaky),
    /// 改用 `private(set) var cursorPushed: Bool` flag 验证 push/pop
    /// 配对 (= 跟 fix10 的 isHovered 验证同款 pattern)。
    func testNativeSplitterDrag_mouseUp_resetsCursor() {
        let view = NativeSplitterView(frame: NSRect(x: 0, y: 0, width: 8, height: 100))
        view.orientation = .horizontal

        // 1. 初始: cursorPushed = false (= 没 push 过 → 不要乱 pop).
        XCTAssertFalse(
            view.cursorPushed,
            "初始 cursorPushed 必须 = false (没 push 过任何 cursor)"
        )

        // 2. mouseEntered → push resizeLeftRight cursor, cursorPushed = true.
        let enterEvent = Self.makeEvent(
            type: .mouseMoved,
            location: NSPoint(x: 4, y: 50),
            clickCount: 0,
            pressure: 0
        )
        view.mouseEntered(with: enterEvent)
        XCTAssertTrue(
            view.cursorPushed,
            "mouseEntered 必须设 cursorPushed = true (= 我们 push 了 resizeLeftRight)"
        )

        // 3. mouseDown → mouseDragged → mouseUp (完整 drag 周期,
        // 鼠标仍在 hit area 内的真实场景)。
        let downEvent = Self.makeEvent(
            type: .leftMouseDown, location: NSPoint(x: 4, y: 50)
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

        // 4. **fix15 BUG2 真修**: mouseUp 必须 pop 我们 push 的 cursor,
        // 配对清 (cursorPushed = false)。 NSCursor.arrow.set() 是兜底,
        // 测不出来 (= AppKit 全局栈, 系统级副作用) 但 cursorPushed
        // flag 是 1:1 proxy (= 我们 push 了, 必须配对 pop)。
        XCTAssertFalse(
            view.cursorPushed,
            "mouseUp 必须 pop 我们 push 的 resizeLeftRight cursor (cursorPushed: true → false, 1:1 配对)"
        )
    }

    // MARK: - 3. 优化1: drawing 无 inset padding

    /// 装机 user 8/7 实机拍 "细线两边预留的一点点区块间距不需要 (细线
    /// 视觉上看起来歪)"。 真根因: NSRect lineRect 在 8pt hit area 内
    /// 居中 (`x = (bounds.width - 1) / 2 = 3.5`), 视觉"两边预留
    /// 3.5pt", 线看起来歪 (浮在中间, 不贴 panel 边界)。
    ///
    /// fix15 修法: lineRect 推到 hit area START edge (`.horizontal` →
    /// x=0, `.vertical` → y=0), edge-to-edge 贴 panel 边界。 测
    /// 试走静态 helper `NativeSplitterView.lineRect(in:orientation:)`:
    /// - .horizontal (vertical line) → x=0, y=0, width=1, height=bounds.height
    /// - .vertical (horizontal line) → x=0, y=0, width=bounds.width, height=1
    ///
    /// 测的是 input/output pure mapping, 不调 draw() (= 没 NSWindow
    /// context 时 draw 会 trap)。 production code 在 draw() 里调同一
    /// 个 helper, 所以"helper 通过" = "draw 视觉通过"。
    func testNativeSplitterDraw_noInsetPadding() {
        let bounds = NSRect(x: 0, y: 0, width: 8, height: 200)

        // ----- Case A: .horizontal splitter (vertical 1pt line) -----
        let verticalLine = NativeSplitterView.lineRect(in: bounds, orientation: .horizontal)

        XCTAssertEqual(
            verticalLine.origin.x, 0,
            "vertical line 必须贴 hit area 左边缘 (x=0, 不是居中 3.5), 真修 lineRect inset 移除"
        )
        XCTAssertEqual(
            verticalLine.origin.y, 0,
            "vertical line 必须贴 hit area 顶边缘 (y=0, edge-to-edge 不留 spacing)"
        )
        XCTAssertEqual(
            verticalLine.size.width, 1,
            "vertical line 1pt 细线 (visibleDividerThickness)"
        )
        XCTAssertEqual(
            verticalLine.size.height, bounds.height,
            "vertical line 沿 hit area 整高 edge-to-edge (height = bounds.height, 不留 inset)"
        )

        // ----- Case B: .vertical splitter (horizontal 1pt line) -----
        let horizontalLine = NativeSplitterView.lineRect(in: bounds, orientation: .vertical)

        XCTAssertEqual(
            horizontalLine.origin.x, 0,
            "horizontal line 必须贴 hit area 左边缘 (x=0, edge-to-edge)"
        )
        XCTAssertEqual(
            horizontalLine.origin.y, 0,
            "horizontal line 必须贴 hit area 顶边缘 (y=0, 不是居中 3.5), 真修 lineRect inset 移除"
        )
        XCTAssertEqual(
            horizontalLine.size.width, bounds.width,
            "horizontal line 沿 hit area 整宽 edge-to-edge (width = bounds.width, 不留 inset)"
        )
        XCTAssertEqual(
            horizontalLine.size.height, 1,
            "horizontal line 1pt 细线 (visibleDividerThickness)"
        )

        // ----- Case C: lineRect 必须跟 visibleDividerThickness 一致 -----
        // 防 production 把 visibleDividerThickness 改了 (= NSSplitView
        // `.thin` 1pt 标准) 但 lineRect helper 没同步改 = lineRect
        // 跟官方契约脱节。
        XCTAssertEqual(
            verticalLine.size.width, NativeSplitterView.visibleDividerThickness,
            "vertical line width 必须 = visibleDividerThickness (1pt NSSplitView .thin 标准)"
        )
        XCTAssertEqual(
            horizontalLine.size.height, NativeSplitterView.visibleDividerThickness,
            "horizontal line height 必须 = visibleDividerThickness (1pt NSSplitView .thin 标准)"
        )

        // ----- Case D: 不变量 — 1pt 细线必须 thin (不是 6px 自写 rect) -----
        // 守住 LT-01-fix7 → fix9 的"全部原生"路径, 防回退到 6px 自写 rect
        // (= AGENTS.md §13 基线拍板"全部原生 NSSplitView 风格")。
        XCTAssertEqual(
            NativeSplitterView.visibleDividerThickness, 1,
            "visibleDividerThickness 必须 = 1pt (NSSplitView `.thin` 标准, 不是 6px 自写 rect)"
        )
    }
}
