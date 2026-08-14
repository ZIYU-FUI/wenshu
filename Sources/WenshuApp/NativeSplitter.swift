// NativeSplitter.swift · Wenshu (Wenshu) · v0.01.0 (= real LT-01-fix15 NativeSplitterView
// brought back from 11e2c1390)
//
// Source: Sources/WenshuApp/Views/Layout/NativeSplitter.swift @ commit 11e2c1390
//         (LT-01-fix15, by 8/7 装机 user, owner of the original feature boss拍"上次
//         的功能就实现了").
//
// LT-01-fix15 (= the real-version fix):
//   - 1pt 细线 (NSSplitView `.thin` style 视觉对齐)
//   - mouseEntered 自动设 NSCursor (resizeLeftRight / resizeUpDown)
//   - mouseExited 自动复位 cursor
//   - mouseUp 显式清 hover + cursor (= BUG1/BUG2 fix15: 鼠标仍在 hit area 内松手,
//     mouseExited 不 fire → 必须 mouseUp 显式清)
//   - NSEvent drag (AppKit 优化, 不走 SwiftUI render pipeline → 拖动不闪动)
//   - 5px click threshold (LT-01-fix5 装机 user 拍板)
//
// Boss 19:00 fix: v10 NativeSplitter (SwiftUI .onHover + DragGesture + .frame) had
//   - 鼠标不变: SwiftUI .onHover doesn't trigger NSCursor (Apple SwiftUI 14+ owns cursor)
//   - 拖拽闪烁: .frame(width:) re-frames children every drag tick
// Fix: use NSView + NSViewRepresentable (= AppKit owns cursor + drag, not SwiftUI).
//
// 不动 (= 老板之前的决定):
//   - SplitterOrientation enum (horizontal = 列 resize, vertical = 行 resize)
//   - 5px click threshold (装机 user 8/7 拍)
//   - cursor push/pop 配对 (BUG2 真根因 = 错栈风险)

import SwiftUI
import AppKit

// MARK: - SplitterOrientation

enum SplitterOrientation {
    case horizontal // drag left/right → resizes panels horizontally
    case vertical   // drag up/down    → resizes bands vertically
}

// MARK: - NativeSplitterView (NSView subclass)

final class NativeSplitterView: NSView {
    /// `.horizontal` = drag left/right (resizes columns)
    /// `.vertical`   = drag up/down (resizes bands)
    var orientation: SplitterOrientation = .horizontal

    /// Pixel delta since drag start (positive = drag direction).
    @MainActor var onDrag: ((CGFloat) -> Void)?

    // MARK: - Drag state
    private var dragStart: NSPoint = .zero
    private var previousLocation: NSPoint?
    private var isDragging: Bool = false

    // MARK: - Visual state
    private(set) var isHovered: Bool = false
    private(set) var cursorPushed: Bool = false

    /// For test introspection (= LT-01-fix15).
    private(set) var redrawRequestCount: Int = 0

    static let visibleDividerThickness: CGFloat = 1
        /// LT-01-fix17 (boss 19:20 "分割线的触发区域太小, 改成 5, 视觉 1, 鼠标触发 5"):
        /// hit area = 5pt (mouse interaction expanded beyond the 1pt visual line),
        /// visibleDividerThickness stays 1pt (= line still edge-to-edge, no gap).
        /// 5pt hit area = user can grab the splitter without pixel-perfect aim (= Apple
        /// HIG splitter drag region).
        static let hitAreaThickness: CGFloat = 5
        static let clickThreshold: CGFloat = 5

    // MARK: - Cursor mapping (LT-01-fix9)
    static func cursorForOrientation(_ o: SplitterOrientation) -> NSCursor {
        return (o == .horizontal) ? .resizeLeftRight : .resizeUpDown
    }

    // MARK: - lineRect helper (= boss 19:50 "线的边上有个间隔" + LT-01-fix17 5pt hit area)
// Boss 19:50: "线的边上有个间隔" → previously lineRect at x=0 (= line贴左 panel边界,
// 右4pt 空白看得见). Fix: place 1pt visual line at hit-area CENTER (= 两侧各 2pt 空白
// 不可见因为 panel 自己的 background.fill 已经填了 = 视觉上线在 panel 中间, 0 间距).
static func lineRect(in bounds: NSRect, orientation: SplitterOrientation) -> NSRect {
    let thickness = visibleDividerThickness  // 1pt
    let hitArea = hitAreaThickness            // 5pt
    let centerOffset = (hitArea - thickness) / 2  // = (5-1)/2 = 2pt
    if orientation == .horizontal {
        // Vertical 1pt line at hit-area center (= 左 2pt, 线, 右 2pt).
        return NSRect(x: centerOffset, y: 0, width: thickness, height: bounds.height)
    } else {
        // Horizontal 1pt line at hit-area center.
        return NSRect(x: 0, y: centerOffset, width: bounds.width, height: thickness)
    }
}

    // MARK: - Axis delta (LT-01-fix14 standard NSEvent delta algorithm)
    static func axisDelta(
        orientation: SplitterOrientation,
        from start: NSPoint,
        to current: NSPoint
    ) -> CGFloat {
        if orientation == .horizontal {
            return current.x - start.x
        } else {
            return start.y - current.y
        }
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    // MARK: - Layout / Drawing

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let lineRect = Self.lineRect(in: bounds, orientation: orientation)
        let dividerColor = isHovered
            ? NSColor.controlAccentColor
            : NSColor.separatorColor
        dividerColor.setFill()
        lineRect.fill()
    }

    // MARK: - Tracking (= AppKit NSSplitView divider built-in behavior)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

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
        cursorPushed = true
        redrawRequestCount += 1
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        redrawRequestCount += 1
        needsDisplay = true
        if !isDragging {
            previousLocation = nil
        }
    }

    // MARK: - Drag (NSEvent, not SwiftUI Gesture)

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
        dragStart = event.locationInWindow
        previousLocation = nil
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        let current = event.locationInWindow

        let ref = previousLocation ?? dragStart
        let incremental = Self.axisDelta(
            orientation: orientation,
            from: ref,
            to: current
        )

        let cumulative = Self.axisDelta(
            orientation: orientation,
            from: dragStart,
            to: current
        )
        guard abs(cumulative) >= Self.clickThreshold else {
            return
        }
        isDragging = true
        previousLocation = current
        onDrag?(incremental)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isDragging = false
        previousLocation = nil

        // LT-01-fix15: BUG1 + BUG2 cleanup.
        if isHovered {
            isHovered = false
            needsDisplay = true
        }
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        NSCursor.arrow.set()
    }

    /// Accept first responder so mouseDragged fires (= default NSView doesn't receive).
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - NativeSplitter (NSViewRepresentable wrapper)

struct NativeSplitter: NSViewRepresentable {
    let orientation: SplitterOrientation
    let onDrag: (CGFloat) -> Void

    func makeNSView(context: Context) -> NativeSplitterView {
        let view = NativeSplitterView()
        view.orientation = orientation
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: NativeSplitterView, context: Context) {
        nsView.orientation = orientation
        nsView.onDrag = onDrag
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NativeSplitterView, context: Context) -> CGSize? {
        let thickness = NativeSplitterView.hitAreaThickness
        if orientation == .horizontal {
            return CGSize(width: thickness, height: proposal.height ?? 0)
        } else {
            return CGSize(width: proposal.width ?? 0, height: thickness)
        }
    }
}