// NativeSplitter.swift · 文枢 (Wenshu) · v0.02.0 LT-01-fix17
//
// 装机 user 8/7 实机拍板"全部原生" (LT-01-fix9) + 增量 delta 算法真修
// (LT-01-fix14) + 松手残留高亮/cursor/inset 三合一清理 (LT-01-fix15)
// + hit area 缩到 1pt 真修细线 panel 边界 0 间距 (LT-01-fix16)
// + cumulative 算法替换增量算法 真修 clamp 边界 state leak (LT-01-fix17):
//
//   - 分割线粗 (自写 SwiftUI 6px rect)        → NSSplitView `.thin` style 1pt
//   - 拖动闪动 + 不顺滑                       → NSView NSEvent drag (AppKit 优化)
//   - 光标不变                                → mouseEntered 自动设 NSCursor
//
// LT-01-fix17 真根因 (LT01Fix13Tests 4 case FAIL, 装机 user 拍回归):
//   fix14 用 incremental 算法 (= `current - previous`), VM 用 cumulative
//   语义处理 (= `proposed = ratios[3] - delta/totalHeight` 当 delta 是
//   cumulative 才是对的, 当 delta 是 incremental 就会少算一截)。 加上
//   clamp false 时的 `previousLocation = nil` reset 不彻底 — 下次 drag
//   从 dragStart fallback 算 cumulative, 但 dragStart 还是老位置, 等
//   于 reference 回到原点后 incremental 又从原点重新累, 跟 VM 期望的
//   "cumulative 减去 reset 后的 baseline" 错位。
//
// fix17 算法: **cumulative + dragStart reset** — `previousLocation` 字段
// 删除, 每次 mouseDragged 直接发 `cumulative = axisDelta(dragStart → current)`。
// VM clamp false 时 (`applied == false`) reset `dragStart = current` (= 干净
// baseline, 类似 `lastReported = 0` reset), 下次 drag 的 cumulative 从新
// 位置算起, 数值 + 符号都跟 VM 一致:
//
//   mouseDown:   dragStart = event.locationInWindow
//   mouseDragged:
//     cumulative = axisDelta(orientation, from: dragStart, to: current)
//     guard abs(cumulative) >= 5 else { return }   // 5px click defense
//     let applied = onDrag?(cumulative) ?? true
//     if !applied { dragStart = current }            // clamp 边界 reset
//   mouseUp:     (dragStart 不清 — 下次 mouseDown 重设)
//
// 效果:
//   - VM 收到 cumulative, 数值 + 符号 = 真实鼠标位移 (跟 fix6/fix11 契约
//     一致: 向下拖 = axisDelta 正 = ratios[3] 调小)
//   - clamp 边界 reset = 干净 baseline, 跟 LT-01-fix13 的 `false = state
//     leak 兜底` 契约一致, 4 个 LT01Fix13Tests 失效 case 全修
//
// LT-01-fix15 (装机 user 8/7 实机拍 3 个二级问题):
//   BUG1: 抓住拖拽 → 释放鼠标 → 分割线 hover 高亮残留 (应松手立即取消)
//   BUG2: 抓住拖拽 → 释放鼠标 → cursor 残留 (.resizeLeftRight / .resizeUpDown
//         仍是双箭头, 应恢复 .arrow)
//   优化1: 分割线 1pt 细线在 8pt hit area 内居中, 细线"两边预留 3.5pt"
//          看起来歪 (不贴 panel 边界) → lineRect 推到 hit area START 边
//
// fix15 修法 (鼠标仍在 hit area 内, mouseExited 不会 fire → 必须显式清):
//   mouseUp:
//     isDragging = false
//     if isHovered { isHovered = false; needsDisplay = true }   // BUG1
//     if cursorPushed { NSCursor.pop(); cursorPushed = false } // BUG2 pair
//     NSCursor.arrow.set()                                       // BUG2 兜底
//   draw: lineRect 从居中改为 hit area START edge (x=0 / y=0)   // 优化1
//
// LT-01-fix16 (装机 user 8/7 实机验 fix15 后拍"细线两边还有 1-2px 间隙"):
//   优化1 fix15 没真修 — fix15 把 lineRect 从"居中 3.5pt"推到 hit area
//   START edge (x=0), 但 hit area 还是 8pt 宽, line 后还有 7pt 空白
//   (= 8-1)。 装机 user 截图主观感知成 "1-2px gap" (= retina DPI 下
//   7pt ≈ 14-21px, 视觉上"很小")。
//
//   真根因 (PM-direct 自纠 #4): hit area 宽度 = 8pt 太宽, line 跟 panel
//   边界之间永远有 7pt 空白 (= hit area 8pt - line 1pt = 7pt)。
//   修法: hit area 缩到 1pt (= visibleDividerThickness 同样宽), 整个
//   hit area 都是 line, 0 inset。
//
// fix16 修法:
//   hitAreaThickness = 1  (从 8)
//   lineRect helper 不变 (仍然 x=0 / y=0 贴 START edge), 但 bounds 现在
//   = 1pt 宽, 所以 lineRect 跟 hit area 完全重叠, 整个 hit area 都是 line
//
// 副作用:
//   - hit area 比 macOS HIG 推荐 4pt 小, 鼠标必须精准点击 line 才能拖
//     (装机 user 8/7 拍板接受, "细线就是唯一的区块分割")
//   - LayoutState.swift 的 `splitterPixels` 必须同步从 8 改 1, 否则
//     layout math 仍预留 8pt × splitter_count 给 splitters, 但 SwiftUI
//     实际只给 1pt × splitter_count, trailing 出现 14pt 空白 (= 装机
//     user "不要任何边距" 验不过)。 fix16 必须联动改 `splitterPixels`。
//
// 5px click threshold 保留 (装机 user 8/7 拍板, fix5 阈值): 任何
// `|cumulative| < 5px` 的 mouseDragged 都视为 click, 不调 onDrag,
// `dragStart` 也不重设 (= 防止 micro-movement 污染 reference)。
//
// LayoutShellView 调用接口与原 PanelSplitter 一致 (drop-in 替换):
//   PanelSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//   →  NativeSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//
// 不动:
//   - LayoutShellViewModel 的 adjustXxx API (delta 还是 pixel-level,
//     内部用 `ratios[3] - delta/totalHeight` 公式 — 现在 VM 收到
//     cumulative = 真实位移, 公式正确)
//   - SplitterDragPolicy / SplitterClickDetector (LT-01-fix7 路径 B
//     兜底 + 旧 fix7/fix9 测试用, 仍留在 PanelSplitter.swift)
//   - LayoutShellView 的 VStack/HStack 几何结构

import SwiftUI
import AppKit

// MARK: - NativeSplitterView (NSView subclass)

/// NSSplitView divider 风格的 NSView: 1pt 细线 + NSCursor 自动设 + 原生
/// mouseDragged。 Hit area 1pt (= 跟 visible divider 一样宽, 整个 hit area
/// 都是 line, 0 inset, line 跟 panel 边界完全贴合 — LT-01-fix16)。
///
/// 为什么不直接用 NSSplitView 包整个 row?
/// - 见 docs/wenshu/LAYOUT-APPKIT-INVENTORY.md §1.2:
///   NSSplitViewController 重写 LayoutShellView 是 LT-01-fix10+ 大重构,
///   fix9 不在范围。
/// - 这块"thin drag handle"是 NSSplitView divider 行为的最小化重现,
///   保留 LayoutShellView 现有 VStack/HStack 结构 + ViewModel 单一信源。
final class NativeSplitterView: NSView {

    /// `.horizontal` = drag left/right (resizes columns)
    /// `.vertical`   = drag up/down (resizes bands)
    var orientation: SplitterOrientation = .horizontal

    /// Cumulative pixel delta from dragStart (positive = drag direction).
    /// 装机 user 拖动时实时回调。
    /// `@MainActor` 因为 NSView 整体在 main thread 用, callback 也会在 main thread 触发。
    ///
    /// 返回 Bool (= "applied" = ratios 真变). 返回 false 表示 VM 已
    /// clamp 到边界, ratios 没动 — drag handler 必须 reset dragStart 到
    /// current (= 干净 baseline, 类似 LT-01-fix7 的 `lastReported = 0`
    /// 重置), 避免下次 mouseDragged 算出 spurious 大反向 delta。
    /// LT-01-fix13 拍板真值 = main 之前 merge 时丢了 fix13 签名, 修复
    /// 回 (CGFloat) -> Bool。 LT-01-fix17 = 改 cumulative 算法后, 这个
    /// Bool 契约不变。
    @MainActor var onDrag: ((CGFloat) -> Bool)?

    // MARK: - Drag state (private)

    /// Drag start 时 mouse 的起点 (window coords)。
    /// LT-01-fix17: dragStart 是 cumulative 算法的 reference (= 每次
    /// mouseDragged 都从这里算到 current 的 axisDelta)。 mouseDown
    /// 时设, clamp false 时重设 = current (干净 baseline), mouseUp
    /// 不重设 (下次 mouseDown 覆盖)。
    private var dragStart: NSPoint = .zero

    /// 是否在 drag 中 (= mouseDown 已 fire, mouseUp 还没 fire)。
    private var isDragging: Bool = false

    /// Visible divider thickness (= NSSplitView `.thin` style).
    /// LT-01-fix7 用 6px 自写 rect; fix9 改 1pt 系统标准。
    static let visibleDividerThickness: CGFloat = 1

    /// Hit area (拖动手柄可点击范围) = 1pt (跟 visible divider 一样)。
    /// LT-01-fix16 (装机 user 8/7 实机验 fix15 后拍"细线两边还有 1-2px
    /// 间隙, 不贴 panel 边界") 真根因 = hit area 8pt 太宽, 1pt line 画在
    /// hit area x=0 后还有 7pt 空白 (8-1), 视觉上 line 跟 panel 边界之间
    /// 有 7pt 空隙 (装机 user 截图误读成 "1-2px gap", retina DPI 下主观)。
    ///
    /// 修法: hit area 缩到 1pt (= line 宽), 整个 hit area 就是 line,
    /// 0 inset, line 跟 panel 边界完全贴合。 副作用 = hit area 比 macOS
    /// HIG 推荐 4pt 小, 鼠标必须精准点击 line 才能抓住 (装机 user 拍板
    /// 接受, "细线就是唯一的区块分割")。 Cursor / hover / drag 行为不
    /// 变 (= mouseEntered/mouseExited 仍 fire, drag 仍跟手)。
    ///
    /// **layout math 联动**: `LayoutSnapshot.splitterPixels` (= 8pt) 必
    /// 须同步改成 1pt, 否则 panel sized-for totalWidth - 16 但实际
    /// splitter 占 1pt, total occupied < totalWidth → trailing 14pt 空
    /// (= 装机 user "不要任何边距" 验不过)。
    static let hitAreaThickness: CGFloat = 1

    /// 当前鼠标是否位于整个 divider hit area 内。
    /// 用于 hover 高亮, 并在 mouseExited 时清除残留视觉状态。
    private(set) var isHovered = false

    /// LT-01-fix15 (BUG2 真根因追踪): 跟踪 mouseEntered push 的
    /// resize cursor 是否仍在栈顶。 `private(set)` 让单测能直接验证
    /// push/pop 配对 (= 测试不依赖 `NSCursor.current` 全局态, 稳定)。
    ///
    /// 历史 pop 行为 (`mouseExited` 无条件 `NSCursor.pop()`) 有 bug:
    /// mouseEntered 没 fire 但 mouseExited 却 fire (罕见但可能, e.g.
    /// tracking area 注册晚于第一次跨边界) → pop 错栈 → 系统 cursor
    /// 乱。 fix15 改成 `cursorPushed == true` 才 pop, mouseUp 同样守
    /// 这个 flag (鼠标在 hit area 内拖完松手, mouseExited 不 fire →
    /// mouseUp 显式清)。
    private(set) var cursorPushed: Bool = false

    /// Redraw request counter (用于测试验证 needsDisplay 被触发)。
    /// production code 设 `needsDisplay = true` 的同一处递增。
    /// 测试不能用 needsDisplay 直读 (= AppKit 在 runloop 中会重置,
    /// 没有 NSWindow 时无法稳定观察)。
    private(set) var redrawRequestCount: Int = 0

    /// LT-01-fix7 兜底阈值: drag 累积 < 5px 视为 click, 不调 onDrag。
    /// 来自 `SplitterClickDetector.thresholdPixels` (= 装机 user 拍板)。
    /// LT-01-fix17: 在 mouseDragged 里直接对照 `cumulative` (= axisDelta
    /// from dragStart to current) 的绝对值。 旧 `SplitterDragPolicy.dragDelta(...)`
    /// 是 fix7 fix9 的中间层, fix17 不再需要。
    private let clickThreshold: CGFloat = SplitterClickDetector.thresholdPixels

    /// Static cursor mapping (暴露给单测验证 NSSplitView 内置行为契约)。
    /// production code 在 mouseEntered 调这个函数决定 push 哪个 NSCursor。
    /// 不暴露 NSCursor.current (= 系统全局栈, 易 flaky), 改暴露 input
    /// → output 的 pure mapping。
    ///
    /// 测试用例:
    /// - testNativeSplitterView_horizontalCursor_mapsToResizeLeftRight
    /// - testNativeSplitterView_verticalCursor_mapsToResizeUpDown
    static func cursorForOrientation(_ o: SplitterOrientation) -> NSCursor {
        return (o == .horizontal) ? .resizeLeftRight : .resizeUpDown
    }

    /// LT-01-fix15 (优化1) — 抽出 lineRect 计算成 pure helper, 让单测
    /// 直接验证"分割线 edge-to-edge 贴 panel 边界, 无 inset/padding"。
    ///
    /// 修复前: lineRect 在 8pt hit area 内居中
    /// (`x = (bounds.width - 1) / 2 = 3.5`), 视觉"两边预留 3.5pt",
    /// 看起来歪 (line 在 gap 中浮着, 不贴 panel 边界)。
    ///
    /// LT-01-fix15 修复: lineRect 直接放在 hit area 的 START 边缘
    /// (= 左/上 panel 边界):
    /// - .horizontal (vertical line) → `x = 0`, 贴左 panel 右边界
    /// - .vertical (horizontal line) → `y = 0`, 贴上 panel 下边界
    ///
    /// LT-01-fix16 进一步修复 (装机 user 8/7 实机验 fix15 后拍"细线两边
    /// 还有 1-2px 间隙"): hit area 从 8pt 缩到 1pt (= visibleDividerThickness
    /// 同样宽), 整个 hit area 都是 line, lineRect 跟 hit area 完全重叠,
    /// 0 inset (line 既是 hit area, 整个贴 panel 边界)。 lineRect helper
    /// 不变 (仍然 `x = 0 / y = 0` 贴 START edge), 只是 bounds 现在 = 1pt
    /// 宽 (= 整个 hit area), 所以视觉上 line 跟 panel 边界 0 间距。
    ///
    /// 整条线沿绘制方向 edge-to-edge (= `width = bounds.width` 或
    /// `height = bounds.height`), 垂直于绘制方向仍 = `visibleDividerThickness` (1pt)。
    static func lineRect(in bounds: NSRect, orientation: SplitterOrientation) -> NSRect {
        let thickness = visibleDividerThickness
        if orientation == .horizontal {
            // Vertical 1pt line at LEFT edge of hit area (= 右 panel 右边界).
            // bounds.width 现在 = 1pt (hit area 缩窄), 所以 lineRect 跟
            // hit area 完全重叠, 整个 hit area 都是 line, 0 inset。
            return NSRect(x: 0, y: 0, width: thickness, height: bounds.height)
        } else {
            // Horizontal 1pt line at TOP edge of hit area (= 下 panel 边界).
            // bounds.height 现在 = 1pt (hit area 缩窄), 同上 0 inset。
            return NSRect(x: 0, y: 0, width: bounds.width, height: thickness)
        }
    }

    /// 轴向 delta 计算 (LT-01-fix17 沿用 fix11 的符号契约, 改用 dragStart)。
    ///
    /// **AppKit 窗口坐标系 y 轴朝上**, 而 `LayoutShellViewModel` 的
    /// delta 契约是 **y 轴朝下** (= SwiftUI `DragGesture.translation.height`
    /// 的约定, LT-01-fix6 就是按这个约定把 `adjustBottomHeight` 修成
    /// `ratios[3] - deltaRatio` 的)。 `.horizontal` (x 轴) 不翻转 ——
    /// 向右拖 → delta > 0 → `adjustUpperColumn` 把左侧 ratios 调大。
    /// `.vertical` (y 轴) 翻转 ——
    /// 向下拖 → `start.y - current.y > 0` → `adjustBottomHeight` 把
    /// `ratios[3]` (下半占比) 调小 → 上半变大 ✅。
    ///
    /// 抽成 static pure function 是为了单测能直接验证符号契约, 不必
    /// 构造带 NSWindow 的 event 环境。 fix11 验证过 (= 见
    /// LT01Fix11Tests.axisDelta_signContract), fix17 不重测。
    static func axisDelta(
        orientation: SplitterOrientation,
        from start: NSPoint,
        to current: NSPoint
    ) -> CGFloat {
        if orientation == .horizontal {
            // 向右拖为正 (window coords x 与屏幕方向一致)。
            return current.x - start.x
        } else {
            // 向下拖为正 (window coords y 向上 → 取反)。
            return start.y - current.y
        }
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // 让 NSView 接收 mouseMoved/mouseEntered 等事件 (默认 NSView
        // 不收, 需要 NSTrackingArea 显式注册, 见下文 updateTrackingAreas)。
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // MARK: - Layout / Drawing

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        // CALayer 跟 frame 同步 — layer-backed NSView 必须显式 sync,
        // 否则 resize 时 layer 不重画 (= 1pt 线段消失)。
        layer?.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 1pt 细线, 跟 NSSplitView `.thin` dividerStyle 视觉对齐。
        // 颜色取 NSColor.separatorColor (= macOS 标准分割线颜色,
        // Light/Dark mode 自动适配 — 不写死 Color.gray)。
        //
        // LT-01-fix15 (优化1): lineRect 走 `Self.lineRect(in:orientation:)`
        // 静态 helper (= 上面), 取代居中算法:
        // - 修前: `x = (bounds.width - 1) / 2` → 1pt 线在 8pt hit area
        //   中央, 视觉"两边预留 3.5pt", 线看起来歪 (浮在中间,
        //   不贴 panel 边界)
        // - 修后: `x = 0` (or `y = 0`) → 1pt 线贴 hit area START 边
        //   (= 左/上 panel 边界), edge-to-edge 不再歪
        let lineRect = Self.lineRect(in: bounds, orientation: orientation)
        let dividerColor = isHovered
            ? NSColor.controlAccentColor
            : NSColor.separatorColor
        dividerColor.setFill()
        lineRect.fill()
    }

    // MARK: - Cursor (NSSplitView 内置行为 — AppKit 推荐路径)

    /// 注册 NSTrackingArea, 让 mouseEntered / mouseExited / mouseMoved
    /// 主动 fire (= NSSplitView divider 的内置行为)。
    /// 不注册的话 NSView 不收 mouseEntered, NSCursor 永远设不上。
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // 清理旧 tracking areas, 避免每次 layout 都累积。
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow
        ]
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        Self.cursorForOrientation(orientation).push()
        // LT-01-fix15 (BUG2 修复 part 1): 标记栈顶 cursor 是我们 push
        // 的 resize cursor。 配对 pop 必须在 mouseExited 或 mouseUp
        // 看到 `cursorPushed == true` 才发生 (= 防 pop 错栈:
        // mouseEntered 没 fire 但 mouseExited 却 fire 时不乱栈)。
        cursorPushed = true
        redrawRequestCount += 1
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        // Pair this with mouseEntered's push so the previous cursor is
        // restored as soon as the pointer leaves the complete divider hit
        // area. LT-01-fix15 (BUG2 修复 part 1): 仅当 cursorPushed
        // (= mouseEntered 真的 push 了我们自己的 cursor) 时才 pop。
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        redrawRequestCount += 1
        needsDisplay = true
    }

    // MARK: - Drag (NSEvent, not SwiftUI Gesture)

    /// NSEvent-based drag (= AppKit 优化路径, 不走 SwiftUI gesture host)。
    /// 装机 user 8/7 实机验"拖动闪动 + 不顺滑"的根因 = SwiftUI
    /// DragGesture 每 fire 都让 LayoutShellView 重 render (= 重算
    /// LayoutMetrics.upperWidths / lowerWidths / lowerBandHeight)。
    /// NSEvent drag 不走 SwiftUI render pipeline, 拖动时只更新
    /// divider 视觉, sibling view 不重 render。
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
        // LT-01-fix17: dragStart 每次 mouseDown 重设 (= cumulative 算法的
        // reference point)。 旧 fix14 用 `previousLocation = nil` + dragStart
        // 双字段, fix17 合并成单字段 dragStart。
        dragStart = event.locationInWindow
        // 注意: isDragging 暂不设 true — 等 mouseDragged 第一次 fire
        // 且累计 > threshold 才视为 drag (= LT-01-fix7 真根因 click
        // 路径防御)。 mouseUp 时如果从没进 drag, 就当 click 不回调。
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        let current = event.locationInWindow

        // LT-01-fix17: cumulative 算法 — 每次 mouseDragged 直接发
        // `cumulative = axisDelta(dragStart, current)`, 跟 VM
        // `proposed = ratios[3] - delta/totalHeight` 的 cumulative 语义
        // 对齐。 旧 fix14 用 incremental (= `current - previousLocation`)
        // + `previousLocation = current` 缓存, 跟 VM 错位, 还会被 5px
        // threshold 守卫耦合污染 (`else` 分支不更新 previousLocation → 下
        // 一帧 reference 错位 = 装机 user 8/7 实机拍"线不跟手")。
        // fix17 删 previousLocation 字段, 不依赖任何缓存, 永远从 dragStart
        // 算到 current, 数值 + 符号都对。
        let cumulative = Self.axisDelta(
            orientation: orientation,
            from: dragStart,
            to: current
        )

        // 5px click threshold 兜底 (LT-01-fix5/fix7 装机 user 拍板):
        // 按 cumulative (从 dragStart 到 current) 绝对值判定, dragStart
        // 不重设 (= 防止 micro-movement 污染 reference, 下次 mouseDragged
        // 仍然 fallback 到 dragStart)。
        guard abs(cumulative) >= clickThreshold else {
            return
        }
        isDragging = true
        // LT-01-fix13: VM 返回 Bool = "applied". false = 已 clamp 到边界,
        // ratios 没动 — drag handler 必须 reset dragStart = current (= 干净
        // baseline), 避免下次 mouseDragged 算出 spurious 大反向 delta。
        // LT-01-fix17: 旧 fix14 用 `previousLocation = nil` 不彻底, 因为
        // 下次 mouseDragged ref = dragStart (没更新), incremental =
        // `current - dragStart` = 全累积, 不是 reset 后的 baseline。
        // fix17 把 reset 直接改 dragStart = current, 跟 VM cumulative 语义
        // 真正对齐。 main 之前 merge 时丢了 fix13 签名 + reset 逻辑,
        // 本修复 restore 回 LT-01-fix13 + LT-01-fix17 拍板真值。
        let applied = onDrag?(cumulative) ?? true
        if !applied {
            dragStart = current
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // LT-01-fix17: dragStart 不清 — 下次 mouseDown 覆盖 (= cumulative
        // 算法的 reference 每次 gesture 重设, mouseUp 时 dragStart 保留
        // 当前 cursor 位置也无所谓, mouseDown 会重写)。
        isDragging = false

        // ===== LT-01-fix15 (BUG1 + BUG2 合一清理) =====
        //
        // 装机 user 8/7 实机拍板 (2 个二级残留问题):
        //   BUG1: 抓住拖拽 → 释放鼠标 → 分割线 hover 高亮残留
        //         (鼠标仍在 hit area 内 → mouseExited 不 fire)
        //   BUG2: 抓住拖拽 → 释放鼠标 → cursor 残留 resize 双箭头
        //         (同上理由, mouseExited 不 fire → push 还在栈顶)
        //
        // 为什么 mouseUp 必须显式清? mouseExited 只在鼠标"离开" hit area
        // 时 fire。 拖拽场景: 用户在 hit area 内按下 → 在 hit area 内拖
        // → 在 hit area 内松手 → mouseExited 从不 fire → isHovered /
        // cursor 都残留 (= 装机 user 实机拍"分割线还是高亮" + "鼠标变形
        // 没恢复")。
        //
        // 不管刚才是不是 drag 都清 (= 纯 click 也清, 因为 hover + cursor
        // 都是 mouseEntered 时设的, 与 drag 无关)。

        // BUG1: 显式清 hover 高亮 (= mouseExited 不 fire 的兜底)。
        if isHovered {
            isHovered = false
            redrawRequestCount += 1
            needsDisplay = true
        }
        // BUG2 part 1: 配对 pop。 仅在 cursorPushed 时才 pop, 防
        // mouseEntered 没 fire 但 mouseExited 却 fire (= push 没发生
        // 但 pop 已经发生) 时乱栈。
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        // BUG2 part 2 兜底: 强制设 NSCursor.arrow。 即便 push/pop
        // 配对在某种边界条件下错乱, 也能保证 cursor 落回 .arrow (= 装
        // 机 user 实机拍"鼠标变形没恢复"的最后防线)。
        NSCursor.arrow.set()
    }

    /// 接受 first responder, 才能接 mouseDragged (默认 NSView 不收)。
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - NativeSplitter (NSViewRepresentable wrapper)

/// SwiftUI 包装。 Drop-in 替代 `PanelSplitter`: 同 orientation +
/// 同 onDrag 回调接口, LayoutShellView 调用点零改动。
struct NativeSplitter: NSViewRepresentable {
    let orientation: SplitterOrientation
    /// Cumulative pixel delta from dragStart (positive = drag direction).
    /// 返回 Bool = "applied" (= ratios 真变). main 之前 merge 时丢了
    /// LT-01-fix13 的 Bool 签名修复, 本修复 restore 回 `Bool`。
    let onDrag: (CGFloat) -> Bool

    func makeNSView(context: Context) -> NativeSplitterView {
        let view = NativeSplitterView()
        view.orientation = orientation
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: NativeSplitterView, context: Context) {
        // onDrag 每次 SwiftUI 重 render 都更新 closure, 保证最新的
        // LayoutShellViewModel 被 capture (= 不会 capture stale VM)。
        nsView.orientation = orientation
        nsView.onDrag = onDrag
    }

    /// Hit area frame (1pt after LT-01-fix16) + 实际 frame 由 SwiftUI
    /// 父容器定 (HStack/VStack spacing: 0)。 这里给的是 preferred size
    /// hint — SwiftUI 父容器用这个做 layout pass 的 intrinsic content size。
    ///
    /// **LT-01-fix16**: hit area 从 8pt 缩到 1pt (= visibleDividerThickness
    /// 同样宽), 所以 SwiftUI 给 NSView 的 preferred size = 1pt, NSView
    /// frame = 1pt, lineRect 跟 frame 完全重叠 (= 整个 frame 都是 line),
    /// 0 inset, 装机 user "不要任何边距, 细线就是唯一的区块分割" 验证通过。
    ///
    /// 副作用: hit area 比 macOS HIG 推荐 4pt 小, 鼠标必须精准点击 line
    /// 才能拖动 (装机 user 8/7 拍板接受, 修 cursor 用 1pt 单独 track —
    /// trackingArea 仍 = bounds = 1pt, mouseEntered/Exited 仍 fire)。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NativeSplitterView, context: Context) -> CGSize? {
        let thickness = NativeSplitterView.hitAreaThickness
        if orientation == .horizontal {
            // 垂直分割线 → 宽 = 1pt, 高 = 父容器给的 max height。
            return CGSize(width: thickness, height: proposal.height ?? 0)
        } else {
            // 水平分割线 → 高 = 1pt, 宽 = 父容器给的 max width。
            return CGSize(width: proposal.width ?? 0, height: thickness)
        }
    }
}
