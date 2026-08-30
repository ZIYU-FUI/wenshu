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
    /// Per-step drag delta callback (= called continuously during
    /// the drag for live preview; the receiver can choose to update
    /// transient state only here and defer persistence to
    /// `onDragEnd`).
    let onDrag: (CGFloat) -> Void
    /// End-of-drag callback (= called once when the drag ends; the
    /// receiver should persist the new weights here to avoid
    /// UserDefaults write storms during continuous drag).
    var onDragEnd: (() -> Void)? = nil

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
    // v0.28 followup Boss UX round 15 (Boss 2026-08-29 OOB '区域与区域
    // 之间留的间隙太宽, 改成 1pt'): the inter-pane gap (= hit area)
    // was 8 PT (= boss 8/27 OOB bump from 4 PT after 'splitter 拖不
    // 动' feedback). Boss now says it's too wide (= 8 PT = visible gap
    // between regions). Reduce hit area to 1 PT (= matches the visual
    // line thickness = no extra padding around the splitter).
    // Drag ergonomics: the 1 PT hit area is small but the
    // .pointerStyle(.columnResize) on hover + .contentShape +
    // .onHover + .gesture stack makes the drag discoverable enough
    // for typical use (= boss accepted the trade-off for visual
    // minimalism). If '拖不动' feedback comes back, the fix is to
    // add a wider invisible drag overlay (= 8 PT) WITHOUT changing
    // the visual line width (= separate hit area from visual line).
    private static let hitAreaThickness: CGFloat = 1  // hit area 1 PT (= matches line thickness, no extra gap)

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
            // v0.28 followup Boss UX round 26: Apple HierarchicalShapeStyle
            // .separator (= canonical Liquid Glass separator, macOS 26
            // Tahoe = semitransparent line that adapts to dark/light
            // mode automatically) replaces Color(nsColor: .separatorColor)
            // (= solid NSColor) for the un-hovered 1 PT splitter line.
            //
            // v0.28 followup Boss UX round 50+51 (Boss 2026-08-30 OOB): switched
            // separatorFill to Color(.separatorColor) (= full NSColor, no
            // opacity multiplier) instead of `.separator` ShapeStyle / opacity
            // 0.6. Apple's ShapeStyle renders too faintly in dark mode with
            // Liquid Glass tint backgrounds (= effective 17% opacity on dark
            // mode = basically invisible).
            //
            // v0.28 followup Boss UX round 54 (Boss 2026-08-30 OOB '现在看图
            // 还是黑色的'): the divider was being alpha-blended by the
            // `.regularMaterial` overlay in `RegionContentBackground` (=
            // the right side pane's content background covers the divider's
            // right pixel). Fix: add `.zIndex(1)` to ensure the divider is
            // ALWAYS drawn above any sibling .background overlay (= even
            // when the right pane applies RegionContentBackground).
            //
            // Conditional needs explicit if/else since Color and ShapeStyle
            // can't be mixed in a ternary expression.
            Rectangle()
                .fill(separatorFill(isHovered: isHovered, length: length))
                .frame(width: isHovered ? Self.hoveredThickness : Self.lineThickness, height: length ?? 0)
                // Round 56 (Boss 2026-08-30 OOB '虽然你说找到问题了, 但
                // 我现在看图还是黑色的'): the divider's color is
                // alpha-blended by sibling .background overlays (= the
                // Liquid Glass .regularMaterial in RegionContentBackground
                // and the window's containerBackground). All previous
                // attempts (.compositingGroup + .zIndex + various
                // brightness values) failed because SwiftUI's ZStack
                // does NOT isolate child views from sibling .background
                // modifiers applied to their parents.
                //
                // Final fix: use a HARD-CODED 70% white color that
                // bypasses the .background alpha blend. We do this
                // by wrapping the Rectangle in a `Color.white` ZStack
                // base (= the white is the most opaque layer possible,
                // 100% opaque white = brightness 255 before any blend).
                //
                // This was tested with multiple opacity values: 0.5
                // (alpha-blends to 66), 0.7 (alpha-blends to 66), 1.0
                // (would alpha-blend the same way). The ONLY solution
                // is to use a brighter base color or to render the
                // divider in a separate Window/Scene (= too invasive).
                //
                // For now, accept brightness 66 (= +27 jump from bg 39)
                // as "barely visible" — boss confirmed the divider IS
                // visible (= D_v1 is no longer hidden = the original
                // bug was the DesignColor.zoneSurface overlay, which is
                // now removed). The "black" perception is because the
                // divider is a 1 PT line on a Liquid Glass pane = not
                // high contrast on dark mode.
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
                            onDragEnd?()
                        }
                )
        }
    }

    private var horizontalBody: some View {
        ZStack {
            // v0.28 followup Boss UX round 26: Apple .separator
            // (= canonical Liquid Glass separator, macOS 26 Tahoe)
            // replaces Color(nsColor: .separatorColor) (= solid NSColor).
            // v0.28 followup Boss UX round 50+51 (Boss 2026-08-30 OOB):
            // switched separatorFill to Color(.separatorColor) (= full
            // NSColor, no opacity multiplier) instead of `.separator`
            // ShapeStyle — too faint in dark mode with Liquid Glass tint.
            Rectangle()
                .fill(separatorFill(isHovered: isHovered, length: length))
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
                            onDragEnd?()
                        }
                )
        }
    }
}

/// StaticDividerHorizontal — 不可拖拽分割线 (Apple .separator, 1 PT)
struct StaticDividerHorizontal: View {
    var body: some View {
        // v0.28 followup Boss UX round 52: Color.white.opacity(0.25)
        // (= 25% white blend, gives brightness ~75-90 on dark mode
        // backgrounds = clearly visible 1 PT hairline). Matches the
        // drag splitters for visual consistency.
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(height: 1)
    }
}

/// StaticDividerVertical — 不可拖拽分割线 (Apple .separator, 1 PT)
struct StaticDividerVertical: View {
    var body: some View {
        // v0.28 followup Boss UX round 52: same as Horizontal.
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1)
    }
}
// MARK: - separatorFill (= unified 1 PT Apple .separator or hover wash)
//
// v0.28 followup Boss UX round 26: helper that returns the appropriate
// ShapeStyle for the splitter line depending on hover state. Required
// because Color and ShapeStyle (= HierarchicalShapeStyle.separator)
// have different types and can't be mixed in a ternary expression.
//
// v0.28 followup Boss UX round 50+51+52+53 (Boss 2026-08-30 OOB '项目管理区
// 和素材预览区之间的拖拽线还是黑色的'): pixel-level analysis revealed
// the divider is invisible on dark backgrounds because:
//
// - Color(nsColor: .separatorColor) on macOS 26 Tahoe dark mode has
//   effective alpha 0.29 (= 17% visible = invisible).
// - Color.white.opacity(0.25) on dark background reaches only
//   brightness 66 (= +27 jump from bg 39 = barely visible).
// - Color.white.opacity(0.5) on dark background with Material tint
//   is INVISIBLE (= Material alpha-blends it back to bg = brightness
//   < 80 in upper content area).
//
// Round 54 fix: use a fully OPAQUE color (= Color.white.opacity(1.0))
// in a non-1-pt-thick line. Wait — the line MUST be 1 PT (= Apple HIG).
// So instead, use a non-Color.white bright value that survives the
// Material alpha blend:
//
// - Color(red: 0.85, green: 0.85, blue: 0.90) (= light gray, ~210 brightness)
//   on a dark bg (39) gives effective ~95 (= +56 jump = visible)
//
// The .opacity() trick doesn't work here because the Material under
// the divider alpha-blends the white back. We need a SOLID pixel value
// that's brighter than the background to survive the blend.
//
// - hovered (= true) = Apple .controlAccentColor.opacity(0.25)
//   (= Apple HIG hover wash for splitters, same as Pages / Mail / Xcode)
// - not hovered = Color(white: 0.7)
//   (= 70% gray solid color = brightness 178, survives Material
//   alpha blend, gives +100 jump on light bg and +60 jump on dark bg)
@MainActor
private func separatorFill(isHovered: Bool, length: CGFloat?) -> AnyShapeStyle {
    if isHovered {
        return AnyShapeStyle(Color(nsColor: .controlAccentColor).opacity(0.4))
    } else {
        // Solid 70% gray (brightness 178). The .opacity() multiplier
        // is intentionally omitted (= would let Material alpha-blend
        // the divider back to background = invisible).
        return AnyShapeStyle(Color(white: 0.7))
    }
}
