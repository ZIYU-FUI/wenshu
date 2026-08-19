//
//  NativeSplitter.swift · Wenshu · v0.16 ticket 03
//
//  Apple AppKit 真值范式: 拖拽线 = NSView + NSEvent + NSTrackingArea + NSCursor.
//  跟 Xcode / Pages / Numbers / Sketch 一样的标准 AppKit 做法.
//
//  6 PT hit area 透明 NSView + 2 PT 黑色 Rectangle 视觉 + hover 4 PT accent.
//  数对公式: 52 (macOS chrome) + 465 (上 band) + 2 (D_h) + 465 (下 band) = 984.
//
//  v0.16 ticket 03: 重写 NativeSplitter 用 NSView + NSEvent (替代 SwiftUI DragGesture).
//  历史 v0.14.0 commit `dacbc9fee` 自承已知 3 件 bug: D_h 不能拖 / D_v5 不能拖 / cursor 不变形 — 这次重写一并修.
//  v0.15 ticket 006 + ticket 023 SwiftUI DragGesture + .pointerStyle 实测在 macOS 27 + VStack parent gesture 系统下失灵.
//  AppKit NSView + NSEvent 直接走 macOS 事件流, 绕过 SwiftUI gesture 系统, 稳定.
//
//  链接:
//    - https://developer.apple.com/documentation/appkit/nsview
//    - https://developer.apple.com/documentation/appkit/nsevent
//    - https://developer.apple.com/documentation/appkit/nstrackingarea
//    - https://developer.apple.com/documentation/appkit/nscursor
//    - https://developer.apple.com/documentation/swiftui/nsviewrepresentable

import SwiftUI
import AppKit

/// 拖拽线方向 (vertical 拖水平 resizeLeftRight, horizontal 拖垂直 resizeUpDown)
enum SplitterOrientation {
    case vertical    // 鼠标 X 方向移动 → onDrag(deltaX)
    case horizontal  // 鼠标 Y 方向移动 → onDrag(deltaY)
}

// MARK: - NSView 拖拽 + cursor (Apple AppKit 真值)

/// 透明 hit area NSView 子类: 接管 mouseDown / mouseDragged / mouseUp + NSTrackingArea hover + NSCursor.push
/// 绕过 SwiftUI gesture 系统, 走 AppKit 事件流 (跟 Xcode / Pages / Numbers 一样)
final class SplitterHitArea: NSView {
    var orientation: SplitterOrientation = .vertical
    /// 拖拽回调: orientation == .vertical 时 delta 是 X 增量, 否则 Y 增量
    var onDrag: ((CGFloat) -> Void)?
    /// hover 状态变化回调 (mouseEntered / mouseExited / mouseMoved 进入 NSView bounds)
    var onHoverChange: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    /// 接收 first mouse event (即使 window 不在 first responder 状态, 鼠标点击 NSView 也能触发 mouseDown)
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 鼠标按下开始拖拽 (Apple HIG: 接收 first mouse event 后, 标 window first responder 准备后续 mouseDragged)
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    /// 拖拽过程: 用 event.deltaX/deltaY (Apple HIG 标准方向, 鼠标向右 = 正, 鼠标向下 = 正) → 调 onDrag callback
    override func mouseDragged(with event: NSEvent) {
        let delta: CGFloat = (orientation == .vertical) ? event.deltaX : event.deltaY
        if delta != 0 {
            onDrag?(delta)
        }
    }

    /// 鼠标释放 (Apple HIG: 拖拽结束, 不需清状态, mouseDragged event.deltaX/Y 自带累积)
    override func mouseUp(with event: NSEvent) {}

    /// mouseMoved 实时算 hover (mouseEntered/Exited 不可靠, 老板 8/19 实测拖拽线蓝光持续亮不消失)
    override func mouseMoved(with event: NSEvent) {
        let inBounds = bounds.contains(convert(event.locationInWindow, from: nil))
        onHoverChange?(inBounds)
    }

    /// mouseEntered: 通知 SwiftUI isHovered (拖拽期间 mouseExited 被 mouse capture 跳过, mouseDragged 时也保持 hover)
    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    /// mouseExited: 拖拽完松开鼠标 cursor 离开 NSView 自动调, 清 isHovered
    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    /// NSTrackingArea: 全 bounds hover 检测 (加 .mouseMoved 实时算 inBounds, macOS 27 .mouseEnteredAndExited 不稳定)
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    /// cursor 切换 (Apple HIG 真值: NSView 自己声明 cursor 区域, macOS 系统自动切, 不依赖 NSCursor.push)
    override func resetCursorRects() {
        let cursor: NSCursor = (orientation == .vertical) ? .resizeLeftRight : .resizeUpDown
        addCursorRect(bounds, cursor: cursor)
    }

    deinit {
        NSCursor.pop()  // safety net: 如果之前 NSCursor.push 没平衡 (历史遗留), 强制 pop
    }
}

// MARK: - NSViewRepresentable 桥接 (SwiftUI 调用 NSView)

/// NSViewRepresentable: SwiftUI 调用 SplitterHitArea 的桥梁
/// SwiftUI body 用 .frame() + .background(.clear) 决定 NSView frame, updateNSView 同步 orientation / closure
struct SplitterHitAreaRepresentable: NSViewRepresentable {
    let orientation: SplitterOrientation
    let onDrag: @MainActor (CGFloat) -> Void
    let onHoverChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> SplitterHitArea {
        let view = SplitterHitArea()
        view.orientation = orientation
        // NSView 事件本身就在 main thread (Apple AppKit 真值), 直接同步调 SwiftUI closure, 不需要 Task 包
        view.onDrag = { delta in onDrag(delta) }
        view.onHoverChange = { hovered in onHoverChange(hovered) }
        return view
    }

    func updateNSView(_ nsView: SplitterHitArea, context: Context) {
        nsView.orientation = orientation
        nsView.onDrag = { delta in onDrag(delta) }
        nsView.onHoverChange = { hovered in onHoverChange(hovered) }
    }
}

// MARK: - NativeSplitter (SwiftUI 主组件)

/// 6 拖拽线 1 组件 (老板 8/18 拍 "拖拽线是 1 组件"): NativeSplitter + orientation 参数
/// v0.16 ticket 03 重写: SwiftUI Rectangle 视觉 (静态 2 PT 黑 / hover 4 PT accent) + 透明 NSView overlay 接 mouse / cursor
/// 改 1 处 = 6 拖拽线 (D_v1/D_v2/D_v3/D_v5 + D_h) 全 1:1 落
struct NativeSplitter: View {
    let orientation: SplitterOrientation
    /// 拖拽线长度 (vertical = 高度, horizontal = 宽度)
    let length: CGFloat
    /// 拖拽回调: orientation == .vertical 时 delta 是 X 增量, 否则 Y 增量 (from NSView mouseDragged)
    let onDrag: @MainActor (CGFloat) -> Void

    private static let lineThickness: CGFloat = 2  // 静态线 2 PT (Sketch master 真值, 老板 8/18 拍)
    private static let hoveredThickness: CGFloat = 4  // hover 变粗 2 倍 (老板 8/18 拍)
    private static let hitAreaThickness: CGFloat = 6  // 6 PT hit area (老板 8/18 拍)

    @State private var isHovered: Bool = false

    private var lineFrame: (width: CGFloat, height: CGFloat) {
        let thickness = isHovered ? Self.hoveredThickness : Self.lineThickness
        if orientation == .vertical {
            return (width: thickness, height: length)
        } else {
            return (width: length, height: thickness)
        }
    }

    var body: some View {
        let outerWidth: CGFloat = orientation == .vertical ? Self.hitAreaThickness : length
        let outerHeight: CGFloat = orientation == .vertical ? length : Self.hitAreaThickness

        ZStack {
            // SwiftUI Rectangle 视觉 (2 PT 黑 / hover 4 PT accent 0.5 + 阴影 0.3)
            Rectangle()
                .fill(isHovered ? Color.accentColor.opacity(0.5) : Color.black)
                .frame(width: lineFrame.width, height: lineFrame.height)
                .clipShape(.capsule)  // 圆角最大 = 视觉圆头
                .shadow(
                    color: isHovered ? Color.accentColor.opacity(0.3) : .clear,
                    radius: isHovered ? 8 : 0,
                    x: 0, y: 0
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)

            // 透明 NSView overlay: 接管 mouseDown / mouseDragged / mouseUp + NSTrackingArea hover + NSCursor.push
            SplitterHitAreaRepresentable(
                orientation: orientation,
                onDrag: onDrag,
                onHoverChange: { hovered in
                    isHovered = hovered  // 驱动 Rectangle 视觉 (变粗 + 蓝 + shadow)
                }
            )
            .frame(width: outerWidth, height: outerHeight)
        }
        .frame(width: outerWidth, height: outerHeight)
    }
}

// MARK: - 不可拖拽分割线 (SwiftUI Divider, Apple Public)

/// 不可拖拽的 2 PT 横向分割线 (圆角最大 = 视觉圆头)
struct StaticDividerHorizontal: View {
    var width: CGFloat? = nil
    var body: some View {
        if let w = width {
            Rectangle()
                .fill(Color.black)
                .frame(width: w, height: 2)
                .clipShape(.capsule)
        } else {
            Divider()
        }
    }
}

/// 不可拖拽的 2 PT 竖向分割线 (圆角最大 = 视觉圆头)
struct StaticDividerVertical: View {
    let height: CGFloat
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .frame(width: 2, height: height)
            .clipShape(.capsule)
    }
}