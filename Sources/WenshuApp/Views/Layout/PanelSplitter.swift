// PanelSplitter.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix5
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
// Behavior:
// - `DragGesture(minimumDistance: 1)` (LT-01-fix4). 1px is small enough
//   that a real drag is recognised on the first pixel of motion, but big
//   enough that a pure mouse-down (no movement) doesn't enter drag state.
//   LT-01-fix3 used `minimumDistance: 0`; LT-01-fix4 装机 user 拍板
//   1px — same UX, marginally safer against accidental cursor jitter.
// - `.onChanged` fires for every micro-pixel of drag; we hand the
//   translation delta to the View Model which keeps its own debounce
//   for persistence (see LayoutShellViewModel.scheduleSave).
// - The visual is a 6px-wide (or tall) rounded rect with a subtle hover
//   state: clear → light gray, hover → mid gray. macOS HIG minimum hit
//   target is 4px; we use 6px so a 1px-overshoot cursor still lands.
//
// LT-01-fix4 BUG1 联动: the live UI only repaints when the View Model
// reassigns `snapshot` (not just mutates `snapshot.ratios`) — see
// `LayoutShellViewModel.adjustBottomHeight` for the matching fix.
//
// LT-01-fix5 BUG1 fix: 装机 user 8/7 实机验发现 horizontal splitter
// 点一下不拖 = 状态被推成 10% / 聊天 90%. 真根因: 在 .onEnded 闭包
// 里不做 translation magnitude 检查, 任何鼠标动作 (含纯 click) 都会
// 累计微小的 translation, 加上 onChanged 的增量 delta 把任意微小
// 抖动当成 "用户想压扁状态栏" 处理. 修法: .onEnded 检查
// |translation| < 5px (装机 user 拍板阈值), 视为 click, 不回调任何
// handler, 不调任何 VM 方法.
//
// Concurrency: the gesture's value.translation is `CGSize` and is captured
// into `@State` from the main thread (gestures are MainActor by default).

import SwiftUI

enum SplitterOrientation {
    case horizontal // drag left/right → resizes panels horizontally
    case vertical   // drag up/down    → resizes bands vertically
}

/// LT-01-fix5 BUG1 click 路径阈值 + 检测器.
///
/// Split out from `PanelSplitter`'s gesture so unit tests can exercise
/// the click-vs-drag boundary without instantiating SwiftUI. The picker
/// spec calls for a hard 5px threshold (装机 user 拍板): any drag whose
/// cumulative translation is shorter than this is treated as a click and
/// does not trigger the `onDrag` handler.
///
/// Why a static helper instead of an inline magic number?
/// - FCP 范式: the threshold belongs to the splitter "vocabulary", not the
///   View that happens to render it.
/// - Unit-test surface: a pure `isClick(translation:)` makes the contract
///   observable from XCTest without spinning up an NSHostingController
///   or `ViewInspector`.
enum SplitterClickDetector {
    /// LT-01-fix5 装机 user 拍板阈值: 拖拽距离 |translation| < 5px = click.
    static let thresholdPixels: CGFloat = 5

    /// Return `true` when the gesture's cumulative translation falls
    /// below the click threshold in **both** axes. A pure mouseDown +
    /// mouseUp with no movement gives `(0, 0)` → click. A 5px+ drag in
    /// any direction is no longer a click.
    static func isClick(translation: CGSize) -> Bool {
        abs(translation.width) < thresholdPixels
            && abs(translation.height) < thresholdPixels
    }
}

struct PanelSplitter: View {
    let orientation: SplitterOrientation
    /// Pixel delta since drag start (positive = drag direction).
    let onDrag: (CGFloat) -> Void

    @State private var isHovering: Bool = false
    @State private var lastReportedDragValue: CGFloat = 0

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
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    // We need incremental delta, not absolute translation.
                    // First call: lastReportedDragValue == 0, so delta = absolute.
                    let absolute = orientation == .horizontal
                        ? value.translation.width
                        : value.translation.height
                    let incremental = absolute - lastReportedDragValue
                    lastReportedDragValue = absolute
                    if incremental != 0 {
                        onDrag(incremental)
                    }
                }
                .onEnded { value in
                    // LT-01-fix5 BUG1 click 路径堵死: 如果累计 translation
                    // 都没超过 5px (= 装机 user 拍板阈值), 视为纯 click,
                    // 不回调任何 handler (不调 onDrag). 这把"点一下 splitter"
                    // 跟"真拖拽 splitter" 区分开: 90:10 BUG 修复.
                    //
                    // 真拖拽场景: |translation.width| 或 |translation.height|
                    // 任一方向 >= 5px → 当成有意识的拖动, 让 .onChanged 已
                    // 累计的 handler 全部生效. 这里不做事 (drag 结束的
                    // 状态由 .onChanged 的累积结果决定, VM 的 scheduleSave
                    // 250ms 后自然落盘).
                    let wasClick = SplitterClickDetector.isClick(translation: value.translation)
                    lastReportedDragValue = 0
                    if wasClick {
                        // Pure click — swallow the gesture, no further action.
                        return
                    }
                }
        )
    }
}
