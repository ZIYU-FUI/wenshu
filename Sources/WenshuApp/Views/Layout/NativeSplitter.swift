//
//  NativeSplitter.swift · Wenshu · v0.14.0
//
//  老板 8/18 拍 Apple 官方 API: 拖拽线 = DragGesture + .pointerStyle
//  (替代手写 NSView, NSCursor 在 SwiftUI 顶层 window 不生效)
//
//  6 PT hit area + 2 PT 视觉线 + 纯黑色 + 1 PT 视觉线居中
//  数对公式: 52 + 465 + 2 + 465 = 984 (设计总高 1:1 PT 落)
//
//  调研: mcp__sketch__run_code 没用对应 SwiftUI 拖拽线组件 (HSplitView / VSplitView 都不可定制 divider 颜色, divider 颜色改不了; NSView 自写 NSCursor 在 SwiftUI 顶层 window 不生效).
//  Apple 官方指引: 用 DragGesture (translation 增量) + .pointerStyle(.columnResize / .rowResize) 替代自写 NSView.
//  链接:
//    - https://developer.apple.com/documentation/swiftui/pointerstyle
//    - https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize
//    - https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize
//    - https://developer.apple.com/documentation/swiftui/draggesture
//
//  老板 8/18 拍 "拖拽线是 1 组件 = 改 1 处全改" → 1 NativeSplitter 组件 + orientation 参数, 替代之前的 wrapper 2 个.

import SwiftUI

/// 拖拽线方向 (vertical 拖水平 resizeLeftRight, horizontal 拖垂直 resizeUpDown)
enum SplitterOrientation {
    case vertical    // 控制左右 zone 宽度 → translation.width
    case horizontal  // 控制上下 zone 高度 → translation.height
}

/// 6 拖拽线 1 组件 (老板 8/18 拍 "拖拽线是 1 组件")
/// 改 1 处 = 5 拖拽线 (D_v1/D_v2/D_v3/D_v5 + D_h) 全 1:1 落
struct NativeSplitter: View {
    /// 拖拽线方向
    let orientation: SplitterOrientation
    /// 拖拽线长度 (vertical = 高度, horizontal = 宽度)
    let length: CGFloat
    /// 拖拽回调: vertical = deltaX (from SwiftUI translation.width), horizontal = deltaY (from translation.height)
    let onDrag: @MainActor (CGFloat) -> Void

    private static let lineThickness: CGFloat = 2  // 老板 8/18 拍 2 PT (跟分割线一样粗, 竖/横都 2)
    // 老板 8/18 拍 hover 变粗: 静态 2 PT → hover 4 PT (2 倍动效, 竖/横一致)
    private static let hoveredThickness: CGFloat = 4
    private static let hoveredThicknessHorizontal: CGFloat = 4
    private static let hitAreaThickness: CGFloat = 6  // 老板 8/18 拍 6 PT hit area

    /// hover 状态 (1 组件 1 @State, 改 1 处全改)
    @State private var isHovered: Bool = false
    /// 拖拽中 (drag 时 = true, 期间 zone 宽度不动画 = 跟手不抖动)
    @State private var isDragging: Bool = false
    /// 上次 translation 值, 用于算 onChanged 之间的增量 (防止拉飞)
    @State private var lastTranslation: CGFloat = 0

    /// 拖拽手势 (Apple 官方, 用 translation 增量, 不漂移, 不拉飞, 拖拽时禁用动画 = 不抖动)
    /// 关键: withTransaction(disablesAnimations: true) 包 onDrag → SwiftUI zone width 重算不动画
    /// gesture 挂外层 ZStack (实测 macOS 27 SwiftUI 4 inner Rectangle gesture 拖拽线不响应)
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging { isDragging = true }
                let current: CGFloat = (orientation == .vertical) ? value.translation.width : value.translation.height
                let delta = current - lastTranslation
                lastTranslation = current
                if delta != 0 {
                    // Apple 官方修法: 拖拽过程禁用 zone width 动画 → 60 fps 跟手不抖动
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) { onDrag(delta) }
                }
            }
            .onEnded { _ in
                isDragging = false
                lastTranslation = 0
            }
    }

    /// Apple 官方 cursor 切换 (columnResize / rowResize, macOS 15+)
    private var pointerStyle: PointerStyle {
        (orientation == .vertical) ? .columnResize : .rowResize
    }

    /// 老板 8/18 拍 hover 变粗 (原本 1 PT, 竖 3 倍 / 横 6 倍), 居中
    private var lineFrame: (width: CGFloat, height: CGFloat) {
        let thickness: CGFloat
        if orientation == .vertical {
            thickness = isHovered ? Self.hoveredThickness : Self.lineThickness
        } else {
            thickness = isHovered ? Self.hoveredThicknessHorizontal : Self.lineThickness
        }
        if orientation == .vertical {
            return (width: thickness, height: length)
        } else {
            return (width: length, height: thickness)
        }
    }

    var body: some View {
        // 真实 rect frame (线性 PT bounds)
        let outerWidth: CGFloat = orientation == .vertical ? Self.hitAreaThickness : length
        let outerHeight: CGFloat = orientation == .vertical ? length : Self.hitAreaThickness

        ZStack {
            // 老板 8/18 拍 "圆头线" = 用 .clipShape(.capsule) 最大圆角 (Apple 官方 SwiftUI capsule shape)
            // vertical = 矩形 2 PT 宽 → 胶囊端圆; horizontal = 矩形 2 PT 高 → 胶囊端圆
            Rectangle()
                .fill(isHovered ? Color.accentColor.opacity(0.6) : Color.black)
                .frame(width: lineFrame.width, height: lineFrame.height)
                .clipShape(.capsule)  // 圆角最大 = 视觉圆头
                .shadow(
                    color: isHovered ? Color.accentColor.opacity(0.4) : .clear,
                    radius: isHovered ? 8 : 0,
                    x: 0, y: 0
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .frame(width: outerWidth, height: outerHeight)
        .contentShape(.rect)
        // cursor 用 Apple HIG SwiftUI .pointerStyle (macOS 15+ 官方 cursor 入口).
        // hover 视觉 (Rectangle 变 accent + shadow) 由 isHovered state 驱动, isHovered 由 .onContinuousHover set.
        // 删 v0.15 ticket 023 的 NSCursor.push/pop + NSApp.windows.disableCursorRects (跟 .pointerStyle 互打架).
        // https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
        .pointerStyle(pointerStyle)
        .onContinuousHover { phase in
            // 仅更新 isHovered state 驱动 hover 视觉, 不调 NSCursor (避免跟 .pointerStyle race condition)
            switch phase {
            case .active: isHovered = true
            case .ended: isHovered = false
            }
        }
        .gesture(dragGesture)
    }
}

// MARK: - 不可拖拽分割线 (SwiftUI Divider, Apple Public)

/// 不可拖拽的 2 PT 横向分割线 (圆角最大 = 视觉圆头, 老板 8/18 拍)
struct StaticDividerHorizontal: View {
    var width: CGFloat? = nil
    var body: some View {
        if let w = width {
            Rectangle()
                .fill(Color.black)
                .frame(width: w, height: 2)
                .clipShape(.capsule)  // Apple 官方 SwiftUI capsule = 最大圆角 (圆头线)
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
            .clipShape(.capsule)  // Apple 官方 SwiftUI capsule = 最大圆角 (圆头线)
    }
}
