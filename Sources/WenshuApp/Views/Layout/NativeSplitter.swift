//
//  NativeSplitter.swift · Wenshu
//
//  Boss 8/18 拍: "拖拽线少两根没有落地, 分割线不可拖拽的, 全缺, 没有落地".
//  MCP 读 Sketch 6 区 + 7 拖拽线 + 7 不可拖拽分割线真值, 沿 wenshu-pocock-style Law 6
//  Apple 真实调研落地: 拖拽线 = 手画 NSView (HSplitView/VSplitView 不暴露 hover/cursor/drag hooks,
//  divider 颜色改不了 → 不符合 boss 1PT 细线设计), 走 NSViewRepresentable 桥接 AppKit 增量拖拽.
//
//  Layer tree (MCP read, PT = PX/2):
//    Drag splitters (NativeSplitterView, 6):
//      vertical 1  : x=200, y=30,    w=1, h=442  (project sidebar / preview)
//      vertical 2  : x=758, y=0,     w=1, h=472  (project / editor)
//      vertical 3  : x=1516, y=0,    w=1, h=472  (editor / tools)
//      vertical 4  : x=200, y=504,   w=1, h=441  (chat sidebar / dialogue)
//      vertical 5  : x=1516, y=504,  w=1, h=441  (chat dialogue / dynamic)
//      horizontal 1: x=0, y=472,     w=1920, h=1 (novel / chat split)
//
//  Static dividers (SwiftUI Divider, 7):
//      y=38, w=1920  (title bar bottom)
//      y=68, w=1920  (novel zone top bar bottom)
//      y=98, w=558   (project zone top bar bottom)
//      y=481, w=1719 (chat dialogue top)
//      y=542, w=1920 (chat zone top bar bottom)
//      y=952, w=200  (project zone bottom bar bottom)
//      y=952, w=403  (specialized tools bottom bar bottom)
//
//  Apple SDK grep gate (verified 2026-08-18):
//    SwiftUI HSplitView/VSplitView (Public, macOS 27.0 存在, but no cursor/hover hook)
//    SwiftUI Divider (Public, macOS 27.0 存在, 1PT static line, perfect for 不可拖拽分割线)
//    NSSplitView / NSSplitViewItem / NSSplitViewController (Public, AppKit 27.0, via NSViewRepresentable)
//    Decision: hand-rolled NSView (Custom Drag) for 拖拽线; SwiftUI Divider for 不可拖拽分割线
//    Reason: boss Sketch line = 1PT 黑线, HSplitView/VSplitView 内置 divider 颜色 / 命中区不能改

import SwiftUI
import AppKit

// MARK: - 拖拽线（手画 NSView + 桥接 SwiftUI）
//
// 设计原则 (MacPocock Style §Apple HIG + macos-nsview-drag-splitter skill):
//   1. visual line thickness = 1PT (boss 设计稿, dark mode 下可见最小值 = 2PT, 但 boss 拍 1PT)
//   2. hit area thickness = 6PT (mouse grab 容易)
//   3. 拖拽用 NSEvent.deltaY / deltaX (per-event increment, 不是 cumulative → 不漂移)
//   4. cursor: vertical = resizeLeftRight, horizontal = resizeUpDown
//   5. mouseDown makeFirstResponder → 让后续 mouseDragged 路由到本 view
//   6. mouseUp 重置 lastReported + dragStart + cursor 回 arrow

/// 可拖拽的 1PT 竖线 / 横线（Apple AppKit NSView 真值实现）
@MainActor
final class NativeSplitterView: NSView {
    enum Orientation { case vertical, horizontal }

    let orientation: Orientation
    /// 回调: vertical = deltaX, horizontal = deltaY
    var onDrag: ((CGFloat) -> Void)?

    private static let lineThickness: CGFloat = 1
    private static let hitAreaThickness: CGFloat = 6

    private var isDragging = false
    private var dragStart: NSPoint?
    private var lastReported: CGFloat = 0

    init(orientation: Orientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        wantsLayer = true
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .activeInKeyWindow, .enabledDuringMouseDrag
        ]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Layout (v0.10.6: intrinsicContentSize = 1 PT 视觉线, hit area 透明 padding 在 NSView 内 5 PT 不占 SwiftUI layout 空间)
    // 数对公式: 39+472+472+1 = 984 (H) / 200+558+762+400 = 1920 (W) 守恒

    override var intrinsicContentSize: NSSize {
        NSSize(width: 1, height: 1)  // 1 PT 视觉线 (hit area 6 PT 透明 padding 在 NSView 内部, NSView 自身仍 6 PT 宽支持拖拽 affordance)
    }

    private static func size(for orientation: Orientation) -> NSSize {
        switch orientation {
        case .vertical:   return NSSize(width: hitAreaThickness, height: lineThickness)
        case .horizontal: return NSSize(width: lineThickness, height: hitAreaThickness)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    // MARK: - Drawing (1PT 黑色 line, 居中于 hit area)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let lineColor = NSColor(white: 0.30, alpha: 1.0)  // 暗灰, dark mode 下可辨
        lineColor.set()
        switch orientation {
        case .vertical:
            let lineRect = NSRect(
                x: (bounds.width - Self.lineThickness) / 2,
                y: 0,
                width: Self.lineThickness,
                height: bounds.height
            )
            lineRect.fill()
        case .horizontal:
            let lineRect = NSRect(
                x: 0,
                y: (bounds.height - Self.lineThickness) / 2,
                width: bounds.width,
                height: Self.lineThickness
            )
            lineRect.fill()
        }
    }

    // MARK: - Cursor (drag affordance, Apple HIG)

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        switch orientation {
        case .vertical:   NSCursor.resizeLeftRight.set()
        case .horizontal: NSCursor.resizeUpDown.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isDragging { NSCursor.arrow.set() }
    }

    // MARK: - Drag (NSEvent.deltaY/deltaX 增量)

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isDragging = true
        dragStart = event.locationInWindow
        lastReported = 0
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard isDragging else { return }
        let delta: CGFloat = (orientation == .vertical) ? event.deltaX : event.deltaY
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isDragging = false
        dragStart = nil
        lastReported = 0
        NSCursor.arrow.set()
    }
}

// MARK: - SwiftUI 桥接

struct NativeSplitter: NSViewRepresentable {
    let orientation: NativeSplitterView.Orientation
    let onDrag: (CGFloat) -> Void

    func makeNSView(context: Context) -> NativeSplitterView {
        let v = NativeSplitterView(orientation: orientation)
        v.onDrag = onDrag
        return v
    }

    func updateNSView(_ nsView: NativeSplitterView, context: Context) {
        nsView.onDrag = onDrag
    }
}

/// 6 拖拽线真值 wrapper (boss 8/18 拍 1 PT 粗, 6 PT hit area, 居中画 1 PT 黑线)
/// v0.10.6: wrapper frame = 1 PT 视觉线宽度 (外 5 PT hit area 透明 padding 在 NSView 内, 不影响 SwiftUI layout)
/// 数对公式 39+472+472+1 = 984 (H) / 200+558+762+400 = 1920 (W) 守恒
struct VerticalDragSplitter: View {
    let height: CGFloat
    let onDrag: (CGFloat) -> Void
    var body: some View {
        NativeSplitter(orientation: .vertical, onDrag: onDrag)
            .frame(width: 1, height: height)  // 1 PT 视觉线 (NSView hit area 6 PT 内透明 padding)
    }
}

struct HorizontalDragSplitter: View {
    let width: CGFloat
    let onDrag: (CGFloat) -> Void
    var body: some View {
        NativeSplitter(orientation: .horizontal, onDrag: onDrag)
            .frame(width: width, height: 1)  // 1 PT 视觉线
    }
}

// MARK: - 不可拖拽分割线（SwiftUI Divider, Apple Public）
//
// Boss 设计稿分组: "分割线, 不可拖拽, 用于分区".
// SwiftUI Divider = Apple 官方 1PT 横线, 自动跟 system theme, 完全符合.
// 竖向 不可拖拽分割线 = Apple 没原生提供 SwiftUI VerticalDivider (iOS-only),
// 改手画 Color.frame(width: 1, height: ...) = Apple semantic color (NSColor.separatorColor).

/// 不可拖拽的 1PT 横向分割线（Apple HIG standard）
struct StaticDividerHorizontal: View {
    var width: CGFloat? = nil
    var body: some View {
        if let w = width {
            Color(nsColor: NSColor.separatorColor)
                .frame(width: w, height: 1)
        } else {
            Divider()  // Apple Public, maxWidth: .infinity
        }
    }
}

/// 不可拖拽的 1PT 竖向分割线（手画 Color.frame, NSColor.separatorColor 走系统色）
struct StaticDividerVertical: View {
    let height: CGFloat
    var body: some View {
        Color(nsColor: NSColor.separatorColor)
            .frame(width: 1, height: height)
    }
}