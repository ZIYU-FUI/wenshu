// PanelSplitter.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01-fix2
//
// Draggable splitter bar between two panels. Used for all 4 drag handles
// in the 5-zone shell:
//   - 2 vertical (between upper-left / upper-center, upper-center / upper-right)
//   - 1 horizontal (between upper band / lower band)
//   - 1 vertical (between lower-left / lower-right)
//
// (Spec said "共 5 个分隔条" but the geometry only fits 4 functional splitters.
// See ACCEPTANCE log for the discrepancy note.)
//
// Behavior (LT-01-fix2):
// - `DragGesture(minimumDistance: 5)` so a stray click (mouseDown + mouseUp
//   at the same spot, or a ≤4px jitter) does NOT enter the drag state at
//   all — SwiftUI only arms `onChanged` after the cursor moves 5+ pixels.
//   Before this fix, `minimumDistance: 0` armed the drag on bare mouseDown
//   and the splitter would sometimes commit a non-zero translate on a
//   pure click (装机 user 8/7 实机验 BUG: 点一下 splitter → 状态 collapse
//   到 gutter). 5px is well below the user's intentional drag motion
//   (typical drag = 50-200+ px) so there's no perceptible "dead zone".
// - `.onChanged` fires for every micro-pixel after the threshold; we hand
//   the translation delta to the View Model which keeps its own debounce
//   for persistence (see LayoutShellViewModel.scheduleSave).
// - `.onEnded` performs a second-layer check: if the final translation
//   magnitude is still < the clickThresholdPx, treat the gesture as a
//   click and skip any pending delta commit. This belt-and-suspenders
//   defends against edge cases where SwiftUI arms `onChanged` once with
//   a non-zero spurious delta on click.
// - The visual is a 6px-wide (or tall) rounded rect with a subtle hover
//   state: clear → light gray, hover → mid gray. macOS HIG minimum hit
//   target is 4px; we use 6px so a 1px-overshoot cursor still lands.
//
// Why this matters for "状态 collapse 到 gutter":
// Without the threshold, a click on the bottom horizontal splitter
// (聊天 ↔ 状态) could commit a tiny translate that pushed the lower
// band's ratio below the auto-collapse floor; the lower-band split is
// tightly bounded so a 1-2px error compounds with the geometry math
// and visually reads as "状态 disappeared". The 5px floor is the LT-01
// fix per 装机 user 8/7 实机验拍板.
//
// Concurrency: the gesture's value.translation is `CGSize` and is captured
// into `@State` from the main thread (gestures are MainActor by default).

import SwiftUI

/// Pixel threshold below which a pointer-down/up sequence is treated as
/// a click (no drag, no commit). Exposed as a static so tests can pin
/// the contract and 装机 user can review it from one place.
enum PanelSplitterClickPolicy {
    /// `DragGesture(minimumDistance:)` value — SwiftUI arms `onChanged`
    /// only after the cursor moves this many points. Below it, the
    /// gesture is never recognized as a drag.
    static let minimumDistance: CGFloat = 5

    /// Belt-and-suspenders guard in `.onEnded`: even if SwiftUI somehow
    /// armed `onChanged` for a sub-threshold click (rare edge cases on
    /// macOS trackpad tap-to-click with palm jitter), we skip any
    /// pending delta commit if the final magnitude is still below this.
    static let clickThresholdPx: CGFloat = 5
}

enum SplitterOrientation {
    case horizontal // drag left/right → resizes panels horizontally
    case vertical   // drag up/down    → resizes bands vertically
}

struct PanelSplitter: View {
    let orientation: SplitterOrientation
    /// Pixel delta since drag start (positive = drag direction).
    /// Only invoked when the gesture is recognized as a real drag
    /// (translation magnitude ≥ `PanelSplitterClickPolicy.clickThresholdPx`).
    let onDrag: (CGFloat) -> Void

    @State private var isHovering: Bool = false
    @State private var lastReportedDragValue: CGFloat = 0
    @State private var isDragActive: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())

            Rectangle()
                .fill(isHovering
                      ? Color.secondary.opacity(0.45)
                      : Color.secondary.opacity(0.20))
                .frame(
                    width: orientation == .horizontal ? LayoutSnapshot.splitterPixels : nil,
                    height: orientation == .vertical ? LayoutSnapshot.splitterPixels : nil
                )
        }
        .frame(
            width: orientation == .horizontal ? LayoutSnapshot.splitterPixels : nil,
            height: orientation == .vertical ? LayoutSnapshot.splitterPixels : nil
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: PanelSplitterClickPolicy.minimumDistance)
                .onChanged { value in
                    // Translation along the splitter's drag axis.
                    let absolute = orientation == .horizontal
                        ? value.translation.width
                        : value.translation.height
                    // Mark drag active once the user has moved far enough
                    // that we've cleared the click-threshold floor.
                    let magnitude = abs(absolute)
                    if magnitude >= PanelSplitterClickPolicy.clickThresholdPx {
                        isDragActive = true
                    }
                    guard isDragActive else {
                        // Still inside the click zone — ignore micro-jitter.
                        return
                    }
                    // We need incremental delta, not absolute translation.
                    // First call after activation: lastReportedDragValue ==
                    // 0 (or stale from prior gesture), so delta == absolute.
                    let incremental = absolute - lastReportedDragValue
                    lastReportedDragValue = absolute
                    if incremental != 0 {
                        onDrag(incremental)
                    }
                }
                .onEnded { value in
                    defer {
                        // Always reset so the next gesture starts clean.
                        lastReportedDragValue = 0
                        isDragActive = false
                    }
                    // Final click-vs-drag gate: if the cursor never made
                    // it past the threshold during the entire gesture,
                    // treat it as a click — do NOT touch ratios / collapse.
                    let magnitude = orientation == .horizontal
                        ? abs(value.translation.width)
                        : abs(value.translation.height)
                    guard magnitude >= PanelSplitterClickPolicy.clickThresholdPx else {
                        return
                    }
                    // If onChanged was bypassed (e.g. SwiftUI delivered a
                    // final onChanged + onEnded pair straddling the
                    // threshold), commit the residual delta so the panel
                    // doesn't snap back.
                    let residual = magnitude - abs(lastReportedDragValue)
                    if residual > 0 {
                        let sign: CGFloat = (orientation == .horizontal
                                             ? value.translation.width
                                             : value.translation.height) >= 0 ? 1 : -1
                        onDrag(residual * sign)
                    }
                }
        )
    }
}
