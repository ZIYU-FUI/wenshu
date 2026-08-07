// PanelSplitter.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix9
//
// LT-01-fix9 (装机 user 8/7 实机拍 "全部原生"): `PanelSplitter` View struct
// **已废弃**, 替换为 `NativeSplitter` (= NSSplitView divider 风格的
// NSView, 1pt 细线 + NSCursor + NSEvent 原生 drag). 详见
// `NativeSplitter.swift` 注释 + docs/wenshu/LAYOUT-APPKIT-INVENTORY.md §1.1.
//
// 本文件**保留** 3 个 helper type (LT-01-fix5 / fix7 测试 + NativeSplitter
// 兜底逻辑都在用):
//   - `SplitterOrientation`     — orientation enum
//   - `SplitterClickDetector`   — 5px click 阈值检测 (LT-01-fix5)
//   - `SplitterDragPolicy`      — dragDelta 增量策略 (LT-01-fix7 真根因 fix)
//
// 这些 helper 没"view", 是纯函数 / enum, 不依赖 SwiftUI, 不依赖
// UIKit/AppKit — 单测可以直接 import。 测试不变 (`LT01Fix7Tests` /
// `LT01Fix5Tests` / `LayoutStateModelTests` 仍引用)。
//
// 为什么不删除 helper?
//   - NativeSplitterView 仍在调用 `SplitterDragPolicy.dragDelta(...)`
//     做 5px threshold 兜底 (fix9 留 safety net, 不破坏 fix7 contract)
//   - 删了 helper 会让现有 8+ 个测试 case compile 失败 (= 派单
//     "不删现有测试" 硬约束)

// 历史: LT-01-fix4 装机 user 拍板用 `DragGesture(minimumDistance: 1)` +
// 6px 自写 rect; LT-01-fix5 优化 click 路径检测 (5px threshold);
// LT-01-fix7 真根因 fix 90:10 BUG (`SplitterDragPolicy.dragDelta`)。

import Foundation
import CoreGraphics

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

/// LT-01-fix7: 把 `.onChanged` 的 click-vs-drag 决策抽成可测函数.
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
    ///
    /// LT-01-fix9: NativeSplitterView 在 `mouseDragged` 调用此函数
    /// (drop-in 替换原 PanelSplitter 的 `.onChanged` 入口逻辑)。
    /// 5px threshold 保留作 safety net (= 见文件头注释)。
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
