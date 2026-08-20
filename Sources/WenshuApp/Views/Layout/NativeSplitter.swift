//
//  NativeSplitter.swift · Wenshu · v0.20 ticket 02 (cursor 切 ↕/↔ 退回 SwiftUI)
//
//  拖拽线 v0.20 ticket 02 — cursor 切 ↕/↔ 退回 SwiftUI .pointerStyle (Apple HIG macOS 15+).
//  老板 2026-08-20 拍 "鼠标还是没有变形" (v0.17 ticket 03 commit f65bb3292 挂 ZStack 父级, 实测失灵).
//  真因 (cursor investigation report v2 实证): NSViewRepresentable 桥接 SplitterHitAreaRepresentable 屏蔽 SwiftUI .pointerStyle 穿透.
//  修法: 退 v0.14 SwiftUI DragGesture 范式 (v0.14 失灵真因 = gesture 挂错层, 这次挂对).
//
//  不动: 拖拽线视觉 (1 PT fill / 3 PT hover / 1 PT hit area / Apple 系统色 / 不圆头) — v0.17 ticket 02/08 拍死原则.
//  动: 拖拽响应 (SwiftUI DragGesture 替代 NSView + NSEvent) + hover 切 (SwiftUI .onContinuousHover) + cursor 切 (SwiftUI .pointerStyle).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// NativeSplitter — 拖拽线 (SwiftUI 范式, 替代 v0.16/v0.17 NSView 范式)
struct NativeSplitter: View {
    let orientation: Orientation
    let length: CGFloat
    let onDrag: (CGFloat) -> Void

    @State private var isHovered: Bool = false
    @GestureState private var dragDelta: CGFloat = 0

    private static let lineThickness: CGFloat = 1   // 静态 1 PT (Apple 系统 divider 色)
    private static let hoveredThickness: CGFloat = 3  // hover 3 PT (Apple 系统亮色)
    private static let hitAreaThickness: CGFloat = 6  // hit area 6 PT (Apple 标准 hit area)

    /// Orientation 真值
    enum Orientation: Sendable {
        case vertical
        case horizontal
    }

    var body: some View {
        if orientation == .vertical {
            verticalBody
        } else {
            horizontalBody
        }
    }

    private var verticalBody: some View {
        ZStack {
            // 视觉 1 PT → hover 3 PT (Apple 系统色)
            Rectangle()
                .fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .separatorColor))
                .frame(width: isHovered ? Self.hoveredThickness : Self.lineThickness, height: length)
                .shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, radius: isHovered ? 8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            // 透明 hit area 6 PT — 接管 mouse / cursor / drag (SwiftUI 真值)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: Self.hitAreaThickness, height: length)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: isHovered = true
                    case .ended: isHovered = false
                    }
                }
                .pointerStyle(.columnResize)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($dragDelta) { value, state, _ in state = value.translation.width }
                    .onChanged { value in onDrag(value.translation.width) })
        }
    }

    private var horizontalBody: some View {
        ZStack {
            Rectangle()
                .fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .separatorColor))
                .frame(width: length, height: isHovered ? Self.hoveredThickness : Self.lineThickness)
                .shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, radius: isHovered ? 8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: length, height: Self.hitAreaThickness)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: isHovered = true
                    case .ended: isHovered = false
                    }
                }
                .pointerStyle(.rowResize)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($dragDelta) { value, state, _ in state = value.translation.width }
                    .onChanged { value in onDrag(value.translation.height) })
        }
    }
}

/// StaticDividerHorizontal — 不可拖拽分割线 (Apple 系统色, 1 PT)
struct StaticDividerHorizontal: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
    }
}

/// StaticDividerVertical — 不可拖拽分割线 (Apple 系统色, 1 PT)
struct StaticDividerVertical: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
    }
}