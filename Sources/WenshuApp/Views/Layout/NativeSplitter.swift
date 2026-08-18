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

    private static let lineThickness: CGFloat = 2  // 老板 8/18 拍 2 PT 粗
    private static let hitAreaThickness: CGFloat = 6  // 老板 8/18 拍 6 PT hit area

    /// 拖拽手势 (Apple 官方, 用 translation 增量, 不漂移)
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta: CGFloat = (orientation == .vertical) ? value.translation.width : value.translation.height
                onDrag(delta)
            }
    }

    /// Apple 官方 cursor 切换 (columnResize / rowResize, macOS 15+)
    private var pointerStyle: PointerStyle {
        (orientation == .vertical) ? .columnResize : .rowResize
    }

    var body: some View {
        ZStack {
            // 透明 hit area (Color.clear 填充命中)
            Color.clear
                .contentShape(.rect)
            // 2 PT 黑色线居中 (master 真值 0,n,1,2 PT)
            Rectangle()
                .fill(Color.black)
                .frame(
                    width: orientation == .vertical ? Self.lineThickness : length,
                    height: orientation == .vertical ? length : Self.lineThickness
                )
        }
        .frame(
            width: orientation == .vertical ? Self.hitAreaThickness : length,
            height: orientation == .vertical ? length : Self.hitAreaThickness
        )
        .pointerStyle(pointerStyle)
        .gesture(dragGesture)
    }
}

// MARK: - 不可拖拽分割线 (SwiftUI Divider, Apple Public)

/// 不可拖拽的 1 PT 横向分割线 (Apple HIG standard)
struct StaticDividerHorizontal: View {
    var width: CGFloat? = nil
    var body: some View {
        if let w = width {
            Color.black
                .frame(width: w, height: 1)
        } else {
            Divider()
        }
    }
}

/// 不可拖拽的 1 PT 竖向分割线 (手画 Color.frame, 纯黑色)
struct StaticDividerVertical: View {
    let height: CGFloat
    var body: some View {
        Color.black
            .frame(width: 1, height: height)
    }
}
