//
//  NativeSplitter.swift · Wenshu
//
//  Boss 8/18 拍 2 PT 粗拖拽线 (Sketch "拖拽线" master 真值), 6 PT hit area, 居中画 1 PT 黑线
//  数对公式: 52 + 465 + 2 + 465 = 984 (设计总高 1:1 PT 落)

import SwiftUI
import AppKit

/// 可拖拽的 2 PT 竖线 / 横线 (Apple AppKit NSView 真值实现)
@MainActor
final class NativeSplitterView: NSView {
    enum Orientation { case vertical, horizontal }

    let orientation: Orientation
    /// 回调: vertical = deltaX, horizontal = deltaY
    var onDrag: ((CGFloat) -> Void)?

    private static let lineThickness: CGFloat = 2  // 老板 8/18 拍 2 PT 粗 (Sketch 拖拽线-横 frame h=2)
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

    // MARK: - Layout (SwiftUI 拿 1PT, hit area 走 .frame() 扩张)

    override var intrinsicContentSize: NSSize {
        Self.size(for: orientation)
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

    // MARK: - Drawing (2 PT 黑色线, 居中于 hit area)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let lineColor = NSColor.black  // 老板 8/18 拍 "纯黑色", dark mode 仍可见
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

/// 6 拖拽线真值 wrapper (boss 8/18 拍 2 PT 粗, 6 PT hit area, 居中画 1 PT 黑线)
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

// MARK: - 不可拖拽分割线 (SwiftUI Divider, Apple Public)

/// 不可拖拽的 1 PT 横向分割线 (Apple HIG standard)
struct StaticDividerHorizontal: View {
    var width: CGFloat? = nil
    var body: some View {
        if let w = width {
            Color(nsColor: NSColor.separatorColor)
                .frame(width: w, height: 1)
        } else {
            Divider()
        }
    }
}

/// 不可拖拽的 1 PT 竖向分割线 (手画 Color.frame, NSColor.separatorColor 走系统色)
struct StaticDividerVertical: View {
    let height: CGFloat
    var body: some View {
        Color(nsColor: NSColor.separatorColor)
            .frame(width: 1, height: height)
    }
}
