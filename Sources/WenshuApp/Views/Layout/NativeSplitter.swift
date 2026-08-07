// NativeSplitter.swift · 文枢 (Wenshu) · v0.02.0 LT-01-fix14
//
// 装机 user 8/7 实机拍板"全部原生" (LT-01-fix9) + 增量 delta 算法真修
// (LT-01-fix14):
//
//   - 分割线粗 (自写 SwiftUI 6px rect)        → NSSplitView `.thin` style 1pt
//   - 拖动闪动 + 不顺滑                       → NSView NSEvent drag (AppKit 优化)
//   - 光标不变                                → mouseEntered 自动设 NSCursor
//
// LT-01-fix14 真根因 (装机 user 实机拍 3 症状):
//   1. 反向没真修 — fix11 `axisDelta` 翻号逻辑 (`start.y - current.y`)
//      是对的 (AppKit 窗口坐标系 y 朝上), 但实际现场仍未正向
//   2. 拖动中线不在鼠标位置 — 旧算法用 `lastReported` (上次报 cumulative)
//      当 reference, 等价于 `current - lastReported` (incremental), 但
//      `lastReported` 的更新时机跟 threshold 守卫耦合: 一旦某帧
//      cumulative < threshold (= click path, `lastReported = 0` 重置),
//      下一帧的 incremental = `cumulative - 0` = 全累积, 鼠标快移
//      时会"丢几帧然后一次补回来" → 线不跟手
//   3. 松开后线的落点 ≠ 最终鼠标位置 — 同 2, 最后一次 mouseDragged
//      报完 incremental 后 mouseUp 没再 dispatch, 但因为 reference
//      错位, 总 cumulative 也对不上最终 cursor
//
// fix14 算法: **NSEvent 标准增量算法** — `previousLocation` (上一帧
// 真实位置) 当 reference, 每次 mouseDragged 发 `current - previous`。
// 不再依赖 `lastReported` 缓存, 不再受 threshold 守卫耦合干扰:
//
//   mouseDown:   previousLocation = nil
//   mouseDragged:
//     ref = previousLocation ?? dragStart       // 首帧用 dragStart
//     incremental = axisDelta(orientation, from: ref, to: current)
//     cumulative  = axisDelta(orientation, from: dragStart, to: current)
//     guard abs(cumulative) >= 5 else { return }   // 5px click defense
//     previousLocation = current
//     onDrag(incremental)
//   mouseUp:     previousLocation = nil
//
// 效果:
//   - 拖动中线跟手 — 每帧 incremental = 鼠标实际位移
//   - 松开后线 = 真实鼠标位置 — 最后 mouseDragged 已经把上一帧到
//     当前 cursor 的全部增量发完了, 累积值精确 = cursor - dragStart
//   - 反向修对 — `axisDelta` 沿用 fix11 (AppKit y 翻号), 只是改用
//     `previous` 当 start, 符号依然 down/right 为正
//
// 5px click threshold 保留 (装机 user 8/7 拍板, fix5 阈值): 任何
// `|cumulative| < 5px` 的 mouseDragged 都视为 click, 不调 onDrag,
// `previousLocation` 也不更新 (= 防止 micro-movement 污染 reference)。
//
// LayoutShellView 调用接口与原 PanelSplitter 一致 (drop-in 替换):
//   PanelSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//   →  NativeSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//
// 不动:
//   - LayoutShellViewModel 的 adjustXxx API (delta 还是 pixel-level)
//   - SplitterDragPolicy / SplitterClickDetector (LT-01-fix7 路径 B
//     兜底 + 旧 fix7/fix9 测试用, 仍留在 PanelSplitter.swift)
//   - LayoutShellView 的 VStack/HStack 几何结构

import SwiftUI
import AppKit

// MARK: - NativeSplitterView (NSView subclass)

/// NSSplitView divider 风格的 NSView: 1pt 细线 + NSCursor 自动设 + 原生
/// mouseDragged。 Hit area 8pt (= NSSplitView 实际 divider hit width),
/// 比 1pt 视觉宽, 鼠标好抓。
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

    /// Pixel delta since drag start (positive = drag direction).
    /// 装机 user 拖动时实时回调。
    /// `@MainActor` 因为 NSView 整体在 main thread 用, callback 也会在 main thread 触发。
    @MainActor var onDrag: ((CGFloat) -> Void)?

    // MARK: - Drag state (private)

    /// Drag start 时 mouse 的起点 (window coords)。
    /// LT-01-fix14: 首帧 mouseDragged 的 reference (= previousLocation 还没
    /// 设过 → fallback 到 dragStart), 之后每次 mouseDragged 都用
    /// previousLocation 当 reference。 保留 dragStart 是为了首帧 + 5px
    /// cumulative threshold 兜底 (=|axisDelta(dragStart, current)|)。
    private var dragStart: NSPoint = .zero

    /// 是否在 drag 中 (= mouseDown 已 fire, mouseUp 还没 fire)。
    private var isDragging: Bool = false

    /// LT-01-fix14: 上一帧 mouseDragged 的 locationInWindow (= NSEvent
    /// 标准增量算法的 reference point)。 mouseDown 时 = nil, 每次
    /// mouseDragged 末尾更新为 current, mouseUp / mouseExited 时清 nil。
    ///
    /// 为什么替换掉 fix9 的 `lastReported: CGFloat` (上次报 cumulative
    /// 缓存): fix9 算法等价 `current - lastReported`, 但 lastReported
    /// 是 cumulative 缓存, 跟 5px threshold 守卫耦合 (`else` 分支重置
    /// 为 0), 鼠标快移时会出现 reference 错位, 导致"丢帧 + 一次补回来"
    /// (= 装机 user 实机拍"线不跟手")。 直接存 previousLocation 是
    /// NSEvent 标准做法, 不依赖累计缓存, 永远跟实际 cursor 对齐。
    private var previousLocation: NSPoint? = nil

    /// Visible divider thickness (= NSSplitView `.thin` style).
    /// LT-01-fix7 用 6px 自写 rect; fix9 改 1pt 系统标准。
    static let visibleDividerThickness: CGFloat = 1

    /// Hit area (拖动手柄可点击范围)。 比 visible divider 宽
    /// (= NSSplitView 实际行为: divider 是 1pt 细线, 但 hit area 是
    /// 8pt, 方便鼠标精准抓住)。 macOS HIG 最小 hit target 4pt, 8pt
    /// 是 NSSplitView 默认值。
    static let hitAreaThickness: CGFloat = 8

    /// 当前鼠标是否位于整个 divider hit area 内。
    /// 用于 hover 高亮, 并在 mouseExited 时清除残留视觉状态。
    private(set) var isHovered = false

    /// Redraw request counter (用于测试验证 needsDisplay 被触发)。
    /// production code 设 `needsDisplay = true` 的同一处递增。
    /// 测试不能用 needsDisplay 直读 (= AppKit 在 runloop 中会重置,
    /// 没有 NSWindow 时无法稳定观察)。
    private(set) var redrawRequestCount: Int = 0

    /// LT-01-fix7 兜底阈值: drag 累积 < 5px 视为 click, 不调 onDrag。
    /// 来自 `SplitterClickDetector.thresholdPixels` (= 装机 user 拍板)。
    /// LT-01-fix14: 在 mouseDragged 里直接对照 `axisDelta(dragStart, current)`
    /// 的绝对值, 不再走 `SplitterDragPolicy.dragDelta(...)` (= 该函数
    /// 是 fix7 fix9 的中间层, fix14 不再需要)。
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

    /// 轴向 delta 计算 (LT-01-fix14 保留 fix11 的符号契约, 改增量算法)。
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
    /// LT01Fix11Tests.axisDelta_signContract), fix14 不重测。
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
        let lineThickness = Self.visibleDividerThickness
        let lineRect: NSRect
        if orientation == .horizontal {
            // 垂直分割线 (拖 left/right) → 竖直 1pt 线, 居中于 hit area。
            let x = (bounds.width - lineThickness) / 2
            lineRect = NSRect(x: x, y: 0, width: lineThickness, height: bounds.height)
        } else {
            // 水平分割线 (拖 up/down) → 水平 1pt 线, 居中于 hit area。
            let y = (bounds.height - lineThickness) / 2
            lineRect = NSRect(x: 0, y: y, width: bounds.width, height: lineThickness)
        }
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
        redrawRequestCount += 1
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        // Pair this with mouseEntered's push so the previous cursor is restored
        // as soon as the pointer leaves the complete divider hit area.
        NSCursor.pop()
        redrawRequestCount += 1
        needsDisplay = true
        // 鼠标拖到窗口外再回来, drag 状态不应残留 (= LT-01-fix7 路径 B
        // 兜底, fix14 改为清 `previousLocation` — 旧 `lastReported = 0`
        // 同步替换为 nil, reference 必须 nil 才能避免下一帧 reference
        // 错位)。
        if !isDragging {
            previousLocation = nil
        }
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
        dragStart = event.locationInWindow
        // LT-01-fix14: 用 `previousLocation = nil` 替代 fix9 的
        // `lastReported = 0` (= 删除字段)。 首帧 mouseDragged 的
        // reference fallback 用 dragStart (= `previousLocation ?? dragStart`)。
        previousLocation = nil
        // 注意: isDragging 暂不设 true — 等 mouseDragged 第一次 fire
        // 且累计 > threshold 才视为 drag (= LT-01-fix7 真根因 click
        // 路径防御)。 mouseUp 时如果从没进 drag, 就当 click 不回调。
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        let current = event.locationInWindow

        // LT-01-fix14: 标准 NSEvent 增量算法 — 用"上一帧 mouseDragged
        // 的 locationInWindow" (or dragStart 首帧 fallback) 当 reference。
        // 跟 fix9 的 `current - lastReported` (= 用"上次报 cumulative"
        // 缓存当 reference) 等价数值, 但 fix9 的 lastReported 缓存跟
        // 5px threshold 守卫耦合 (`else` 分支会重置 lastReported = 0),
        // 鼠标快移时 reference 错位 → 丢帧 / 一次补回来 (= 装机 user
        // 8/7 实机拍"线不跟手")。 直接存 previousLocation 不依赖缓存
        // 清理逻辑, 永远跟实际 cursor 对齐。
        let ref = previousLocation ?? dragStart
        let incremental = Self.axisDelta(
            orientation: orientation,
            from: ref,
            to: current
        )

        // 5px click threshold 兜底 (LT-01-fix5/fix7 装机 user 拍板):
        // 按 cumulative (从 dragStart 到 current) 绝对值判定, 不是
        // incremental (避免 incremental 偏小绕过 threshold)。
        // cumulative < threshold → click, 不调 onDrag, previousLocation
        // 也不更新 (= 防止 micro-movement 污染 reference, 下次 mouseDragged
        // 仍然 fallback 到 dragStart)。
        let cumulative = Self.axisDelta(
            orientation: orientation,
            from: dragStart,
            to: current
        )
        guard abs(cumulative) >= clickThreshold else {
            return
        }
        isDragging = true
        previousLocation = current
        onDrag?(incremental)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // Click 路径双保险 (LT-01-fix7 .onEnded 防御性兜底):
        // 如果 mouseDragged 从没 fire (纯 click), 不回调任何 handler。
        // LT-01-fix14: 同步清 `previousLocation` (= 替代 fix9 的
        // `lastReported = 0`)。 isDragging = false 后, 下次 mouseDragged
        // 仍会以 dragStart 当首帧 reference (= previousLocation nil 兜底)。
        if !isDragging {
            previousLocation = nil
            return
        }
        isDragging = false
        previousLocation = nil
    }

    /// 接受 first responder, 才能接 mouseDragged (默认 NSView 不收)。
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - NativeSplitter (NSViewRepresentable wrapper)

/// SwiftUI 包装。 Drop-in 替代 `PanelSplitter`: 同 orientation +
/// 同 onDrag 回调接口, LayoutShellView 调用点零改动。
struct NativeSplitter: NSViewRepresentable {
    let orientation: SplitterOrientation
    /// Pixel delta since drag start (positive = drag direction).
    let onDrag: (CGFloat) -> Void

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

    /// Hit area frame (8pt) + 实际 frame 由 SwiftUI 父容器定 (HStack/
    /// VStack spacing: 0)。 这里给的是 preferred size hint — SwiftUI
    /// 父容器用这个做 layout pass 的 intrinsic content size。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NativeSplitterView, context: Context) -> CGSize? {
        let thickness = NativeSplitterView.hitAreaThickness
        if orientation == .horizontal {
            // 垂直分割线 → 宽 = 8pt, 高 = 父容器给的 max height。
            return CGSize(width: thickness, height: proposal.height ?? 0)
        } else {
            // 水平分割线 → 高 = 8pt, 宽 = 父容器给的 max width。
            return CGSize(width: proposal.width ?? 0, height: thickness)
        }
    }
}
