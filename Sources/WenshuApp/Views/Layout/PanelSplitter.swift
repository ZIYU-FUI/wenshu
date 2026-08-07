// PanelSplitter.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix7
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
// LT-01-fix5 BUG1 fix (第一版, 不全): 装机 user 8/7 实机验发现 horizontal
// splitter 点一下不拖 = 状态被推成 10% / 聊天 90%. 修法: .onEnded 检查
// |translation| < 5px (装机 user 拍板阈值), 视为 click, 不回调任何
// handler. 但 fix5 只在 .onEnded 堵, 没在 .onChanged 入口堵 — 装机 user
// 实机验 fix5 后仍复现 90:10.
//
// LT-01-fix7 BUG1 真根因 fix: 派单 prompt 列的 4 个 hitTest / onTap /
// fromSnapshot hypothesis 全部 grep verify = 0 命中 (不在那些路径上)。
// 真根因 = `.onChanged` 在 click-equivalent gesture 上 fire `onDrag` 时,
// 由于 `@State var lastReportedDragValue` 跨 gesture 泄漏 (路径 B: .onEnded
// 不保证每次 fire — gesture 被取消 / View 重渲染 / focus 切换时 .onEnded
// 可能不 fire), 算出 -240 量级的 spurious incremental, 触发
// `adjustBottomHeight(-240)` → ratios[3] = 0.10 → 90:10. 还有路径 A:
// trackpad / Magic Mouse 在单次 "click" 内 .onChanged 多次 fire, 累加
// cumulative 到几十 ~ 上百 px。 修法: 在 .onChanged 入口判 |cumulative|
// < thresholdPixels → return early, 不 fire onDrag, 且顺手重置
// lastReportedDragValue = 0 (兜底路径 B 的状态泄漏)。 `.onEnded` 的 click
// check 保留作双保险。
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

/// LT-01-fix7: 把 `.onChanged` 的 click-vs-drag 决策抽成可测函数。
///
/// 单测直接调 `dragDelta(cumulative:lastReported:)`, 不用跑 SwiftUI
/// gesture host. View 调用 `dragDelta` 决定本次 `.onChanged` 是否调
/// `onDrag`. 抽出来也让 "5px click 阈值" 这条规则集中在一处, 跟
/// `SplitterClickDetector.isClick(translation:)` 在不同位置服务不同
/// 调用方 (一个在 .onChanged 入口判增量 delta, 一个在 .onEnded 判
/// cumulative translation — 语义不同, 不能合并)。
enum SplitterDragPolicy {
    /// LT-01-fix7 真根因 verify 后抽出来的核心策略:
    ///
    /// - `cumulative` 是 `.onChanged` 报告的当前手势累计 translation
    ///   (DragGesture 的 `value.translation` 在本 orientation 方向的轴)。
    /// - `lastReported` 是上次 `.onChanged` 缓存的 `cumulative`, 用于算
    ///   增量 delta。
    ///
    /// 返回:
    /// - `nil` → 本次 `.onChanged` 不调 `onDrag` (视为 click)。
    /// - `非 nil CGFloat` → 传给 `onDrag` 的增量 delta。
    ///
    /// 边界:
    /// - `|cumulative| < threshold` → click, 不调 onDrag (这是装机 user
    ///   8/7 拍板阈值 5px)。 同时按 LT-01-fix7 真根因路径 B, View 端
    ///   必须把 `lastReportedDragValue` 重置 0, 否则下次 drag 会算出
    ///   spurious 大 delta。
    /// - `incremental == 0` → 同位置多次 fire (e.g. .onChanged 被 View
    ///   重渲染触发但 translation 没变), 不调 onDrag。
    /// - 其他 → 返回 incremental。
    static func dragDelta(
        cumulative: CGFloat,
        lastReported: CGFloat,
        threshold: CGFloat = SplitterClickDetector.thresholdPixels
    ) -> CGFloat? {
        if abs(cumulative) < threshold { return nil }
        let incremental = cumulative - lastReported
        return incremental == 0 ? nil : incremental
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
                    // LT-01-fix7 BUG1 真根因 fix:
                    //
                    // fix5 只在 .onEnded 堵 click 路径, 但 .onChanged 在
                    // .onEnded 之前已经 fire 过 onDrag, 改不了。 装机 user
                    // 8/7 实机验 fix5 后仍复现"点一下 90:10"。
                    //
                    // 真根因 = .onChanged 在 click-equivalent gesture 上
                    // fire onDrag 时, 由于:
                    //   路径 A: trackpad / Magic Mouse 单次 click 内 .onChanged
                    //          多次 fire, cumulative 累加到几十 ~ 上百 px
                    //   路径 B: .onEnded 不保证每次 fire (gesture 取消 /
                    //          View 重渲染 / focus 切换), @State 跨 gesture
                    //          泄漏, 下次 click 的 .onChanged 算出
                    //          incremental = -240 (90:10 的必要 delta)
                    // → onDrag 累计 -240 → adjustBottomHeight(-240) →
                    //   ratios[3] = 0.10 → 上半 90% / 下半 10%。
                    //
                    // 修法: 入口判 |cumulative| < threshold → return early,
                    // 不 fire onDrag, 且顺手重置 lastReportedDragValue = 0
                    // (兜底路径 B 的状态泄漏)。
                    let cumulative = orientation == .horizontal
                        ? value.translation.width
                        : value.translation.height
                    guard let incremental = SplitterDragPolicy.dragDelta(
                        cumulative: cumulative,
                        lastReported: lastReportedDragValue
                    ) else {
                        // Click-equivalent gesture (|cumulative| < 5px) OR
                        // zero incremental (same position re-fire).
                        // 不要 fire onDrag. 重置 lastReportedDragValue 以
                        // 兜底真根因路径 B 的 @State 跨 gesture 泄漏。
                        lastReportedDragValue = 0
                        return
                    }
                    lastReportedDragValue = cumulative
                    onDrag(incremental)
                }
                .onEnded { value in
                    // LT-01-fix5 BUG1 click 路径堵 (双保险, 跟 fix7 入口
                    // check 配套): 如果累计 translation 都没超过 5px
                    // (= 装机 user 拍板阈值), 视为纯 click, 不回调任何
                    // handler。 fix7 已在 .onChanged 入口堵过一次, 这里
                    // 主要是给静态分析 / 防御性兜底: 即便 .onChanged
                    // 入口将来被改动, .onEnded 这道墙也能拦住 click。
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
