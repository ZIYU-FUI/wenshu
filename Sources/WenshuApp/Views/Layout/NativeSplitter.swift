//
//  NativeSplitter.swift · Wenshu
//
//  Drag splitter view with SwiftUI hover + cursor + drag gestures.
//  Visual: 1 PT Apple system separator color, 3 PT on hover.
//  Hit area: 6 PT, transparent overlay (Color.clear + .contentShape).
//  Cursor: SwiftUI .pointerStyle (.columnResize / .rowResize), macOS 15+.
//  Drag: SwiftUI DragGesture(.local, minimumDistance: 0).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// NativeSplitter — 拖拽线 (SwiftUI 范式, 替代 v0.16/v0.17 NSView 范式)
struct NativeSplitter: View {
    let orientation: Orientation
    let length: CGFloat?
    let onDrag: (CGFloat) -> Void

    @State private var isHovered: Bool = false
    // v0.27 boss 8/27 OOB: 拖拽线之前不能拖。Root cause =
    // DragGesture .onChanged 传给 onDrag 的 value.translation.width
    // 是 cumulative translation (= 自 drag gesture 开始到现在鼠标
    // 移动的总距离，不是单步 delta). 之前 onDrag 把 cumulative 直接
    // 喂给 vm.adjust(index, delta: cumulative, ...)，但 vm.adjust
    // 的逻辑是 `offsets[index] += cumulative / totalWidth` (= 累加)，
    // = 第一次 onChanged 触发后 offsets 累积到 maxOffset (= +0.15) =
    // 后续 onChanged 全部被 `guard newOffset <= Self.maxOffset`
    // 拒绝 = splitter 看起来完全不能拖。
    //
    // Fix: track last cumulative translation in @State (= stable
    // across gesture); compute the per-callback delta = current -
    // last; pass that delta (= the single-callback step) to onDrag.
    // vm.adjust now receives correct per-step delta = accumulates
    // offsets correctly over the lifetime of the drag.
    @State private var lastCumulativeTranslation: CGFloat = 0
    @State private var isDragging: Bool = false

    private static let lineThickness: CGFloat = 1   // 静态 1 PT (Apple 系统 divider 色)
    private static let hoveredThickness: CGFloat = 3  // hover 3 PT (Apple 系统亮色)
    // v0.27 boss 8/27 OOB: drag fix verification. Hit area was 4 PT
    // (reduced from 6 to fix sub-pixel rounding per v0.24 fix). 4 PT
    // is too small for some user mouse precision (= owner reported
    // 'splitter 拖不动'). Bump back to 8 PT (= comfortable hit area;
    // = 4 PT × 2 = clearly clickable without misfires on adjacent
    // zones; sub-pixel rounding issue resolved by .rounded() in
    // UpperBandZone body anyway).
    private static let hitAreaThickness: CGFloat = 8  // hit area 8 PT (boss 8/27 OOB)

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
                .frame(width: isHovered ? Self.hoveredThickness : Self.lineThickness, height: length ?? 0)
                .shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, radius: isHovered ? 8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            // 透明 hit area 6 PT — 接管 mouse / cursor / drag (SwiftUI 真值)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: Self.hitAreaThickness, height: length ?? 0)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: isHovered = true
                    case .ended: isHovered = false
                    }
                }
                .pointerStyle(.columnResize)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        // v0.27 boss 8/27 OOB: .updating kept for visual
                        // cursor tracking (no-op for state now; we use
                        // @State lastCumulativeTranslation to compute
                        // per-callback delta instead).
                        .onChanged { value in
                            if !isDragging {
                                // First callback of a new gesture =
                                // reset baseline.
                                isDragging = true
                                lastCumulativeTranslation = 0
                            }
                            let currentCumulative = orientation == .vertical ? value.translation.width : value.translation.height
                            let stepDelta = currentCumulative - lastCumulativeTranslation
                            lastCumulativeTranslation = currentCumulative
                            onDrag(stepDelta)
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastCumulativeTranslation = 0
                        }
                )
        }
    }

    private var horizontalBody: some View {
        ZStack {
            Rectangle()
                .fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .separatorColor))
                .frame(width: length ?? 0, height: isHovered ? Self.hoveredThickness : Self.lineThickness)
                .shadow(color: isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : .clear, radius: isHovered ? 8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: length ?? 0, height: Self.hitAreaThickness)
                .onContinuousHover { phase in
                    switch phase {
                    case .active: isHovered = true
                    case .ended: isHovered = false
                    }
                }
                .pointerStyle(.rowResize)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                lastCumulativeTranslation = 0
                            }
                            let currentCumulative = orientation == .vertical ? value.translation.width : value.translation.height
                            let stepDelta = currentCumulative - lastCumulativeTranslation
                            lastCumulativeTranslation = currentCumulative
                            onDrag(stepDelta)
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastCumulativeTranslation = 0
                        }
                )
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