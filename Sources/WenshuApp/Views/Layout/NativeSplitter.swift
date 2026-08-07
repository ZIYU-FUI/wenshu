// NativeSplitter.swift · 文枢 (Wenshu) · v0.02.0 LT-01-fix9
//
// 装机 user 8/7 实机拍 "全部原生". 替换 LT-01-fix7 的自写 SwiftUI
// `PanelSplitter` (6px rect + DragGesture + 自写 NSCursor 全缺):
//
//   - 分割线粗 (自写 SwiftUI 6px rect)        → NSSplitView `.thin` style 1pt
//   - 拖动闪动 + 不顺滑                       → NSView NSEvent drag (AppKit 优化)
//   - 光标不变                                → mouseEntered 自动设 NSCursor
//
// 真根因 fix7 留下的 `SplitterDragPolicy` / `SplitterClickDetector` 5px
// threshold 全是绕路 (见 docs/wenshu/LAYOUT-APPKIT-INVENTORY.md §1.1).
// NativeSplitter 直接用 NSSplitView 风格的内置行为, click 不动, 拖动
// 才动 — 90:10 BUG 不会出现。
//
// 但 5px threshold **保留作防御性兜底** (= fix9 留 safety net, 不破坏
// fix7 测试 contract):
//   - delta < 5px → 不调 onDrag (clicks 不算 drag)
//   - 此举同时兼容 LT-01-fix7 真根因路径 B (.onEnded 不保证每次 fire
//     导致 @State 跨 gesture 泄漏): 即便 NSEvent 路径有等价 race,
//     我们在累积 delta < 5px 时直接 return, 不依赖状态清理。
//
// LayoutShellView 调用接口与原 PanelSplitter 一致 (drop-in 替换):
//   PanelSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//   →  NativeSplitter(orientation: .horizontal) { delta in vm.adjustXxx(...) }
//
// 不动:
//   - LayoutShellViewModel 的 adjustXxx API (delta 还是 pixel-level)
//   - SplitterDragPolicy / SplitterClickDetector (兜底 + 测试用)
//   - LayoutShellView 的 VStack/HStack 几何结构 (不动, 见 inventory §1.2)

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

    /// Drag start 时 mouse 的起点 (window coords).
    private var dragStart: NSPoint = .zero
    /// 是否在 drag 中 (= mouseDown 已 fire, mouseUp 还没 fire).
    private var isDragging: Bool = false
    /// 上一次 drag 累计值 (= fix7 `lastReportedDragValue` 等价)。
    /// 用于计算增量 delta (= dragDelta 逻辑的兜底)。
    private var lastReported: CGFloat = 0

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
        // 鼠标拖到窗口外再回来, drag 状态不应残留 (= fix7 路径 B 兜底)。
        if !isDragging {
            lastReported = 0
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
        lastReported = 0
        // 注意: isDragging 暂不设 true — 等 mouseDragged 第一次 fire
        // 且累计 > threshold 才视为 drag (= LT-01-fix7 真根因 click
        // 路径防御)。 mouseUp 时如果从没进 drag, 就当 click 不回调。
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        let current = event.locationInWindow
        let deltaInWindow = (orientation == .horizontal)
            ? (current.x - dragStart.x)
            : (current.y - dragStart.y)

        // 5px threshold 兜底 (LT-01-fix7 真根因 fix):
        // - cumulative < threshold → click, 不调 onDrag
        // - 重置 lastReported (兜底路径 B 的 @State 跨 gesture 泄漏)
        guard let incremental = SplitterDragPolicy.dragDelta(
            cumulative: deltaInWindow,
            lastReported: lastReported
        ) else {
            lastReported = 0
            return
        }
        isDragging = true
        lastReported = deltaInWindow
        onDrag?(incremental)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // Click 路径双保险 (LT-01-fix7 .onEnded 防御性兜底):
        // 如果 mouseDragged 从没 fire (纯 click), 不回调任何 handler。
        if !isDragging {
            lastReported = 0
            return
        }
        isDragging = false
        lastReported = 0
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
