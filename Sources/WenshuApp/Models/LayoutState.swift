// LayoutState.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Codable value types that capture the 5-zone layout's geometry state.
//
// Persistence shape (per AGENTS.md §8.1 + LT-01 spec):
// - `CDLayoutState` entity carries exactly 2 String columns:
//     panel_states  (JSON of PanelCollapsedState)
//     panel_ratios  (JSON of [Double] of length 5)
// - `LayoutSnapshot` is the in-memory aggregate View Model works with.
//   Both halves round-trip through JSON for storage.
//
// Boundaries (CC contract per AGENTS §5 "PM 改" vs "CC 改"):
// - Pure value type + JSON helpers. No UI dependency. Lives in Models/.
// - View layer (Layout/*) imports this; Tests import it via @testable import.
// - Persistence layer (WenshuStoreActor) uses raw String I/O via the
//   static encode/decode helpers so the entity-row API stays
//   storage-format agnostic (the JSON shape is exactly the on-disk shape).
//
// Why a value type instead of a class?
// - The whole snapshot is replaced as one when any field changes
//   (Equatable + struct semantics → SwiftUI re-renders cleanly).
// - Sendable: value type with primitive members is automatically Sendable
//   under Swift 6 strict concurrency.

import Foundation

// MARK: - Panel collapse flags

/// One bool per panel. `true` = collapsed (gutter/header only);
/// `false` = expanded (computed width from ratios).
///
/// 5 panels map exactly to AGENTS §8.1's 5 zones:
///   topLeft      → 项目管理
///   topCenter    → 文档内容浏览器 (editor)
///   topRight     → inspector
///   bottomLeft   → 聊天区
///   bottomRight  → 状态 (明盒) — empty in v0.02.0, lands in v0.03.0/v0.04.0
struct PanelCollapsedState: Codable, Sendable, Equatable {
    var topLeft: Bool
    var topCenter: Bool
    var topRight: Bool
    var bottomLeft: Bool
    var bottomRight: Bool

    init(
        topLeft: Bool = false,
        topCenter: Bool = false,
        topRight: Bool = false,
        bottomLeft: Bool = false,
        bottomRight: Bool = false
    ) {
        self.topLeft = topLeft
        self.topCenter = topCenter
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

// MARK: - Layout snapshot (view model + storage aggregate)

/// AGENTS §8.1 5-zone layout grammar state.
///
/// `ratios` index layout (5 entries, sum invariants enforced by `clamp`):
///   [0] topLeft     — fraction of upper-row width (0..1)
///   [1] topCenter   — fraction of upper-row width (0..1)
///   [2] topRight    — fraction of upper-row width (0..1)
///                      → ratios[0]+ratios[1]+ratios[2] ≈ 1.0
///   [3] bottom      — fraction of total window height taken by lower band
///                      → 1.0 - ratios[3] = upper band's share
///   [4] bottomLeft  — fraction of lower-band width taken by bottomLeft
///                      → 1.0 - ratios[4] = bottomRight's share
struct LayoutSnapshot: Codable, Sendable, Equatable {
    var collapsed: PanelCollapsedState
    var ratios: [Double]

    /// Defaults: 20 / 60 / 20 upper split, **80 / 20 lower split**,
    /// 50 / 50 upper-vs-lower split.
    ///
    /// The bottom-band 80:20 (聊天 80% / 状态 20%) is a 装机 user 8/7
    /// 实机验 override of the previous 70:30 split — 装机 user 拍板
    /// "让状态初始与检视同宽 = 20%". Status panel stays visible (not
    /// collapsed) at 20% which equals the inspector's width per AGENTS
    /// §8.1's 20% top-right default. 20% is enough for v0.03.0 阶段门
    /// / v0.04.0 长篇工具 tags + chevron + view-mode toggle.
    ///
    /// 装机 user hard constraint (LT-01-fix2 拍板真值): 状态(下右)可见
    /// 宽度 = 检视(右上)宽度 = 20%. Therefore bottomLeft (聊天) = 80%,
    /// not 60% — the ticket's "聊天 60%" wording is interpreted as
    /// "聊天 still dominant" relative to the prior 70:30, NOT as a
    /// literal 60% figure (which would push 状态 to 40%, violating the
    /// 状态=检视=20% hard constraint).
    static let `default` = LayoutSnapshot(
        collapsed: PanelCollapsedState(),
        ratios: [0.2, 0.6, 0.2, 0.5, 0.8]
    )

    /// FCP actual threshold from AGENTS §8.1: dragging a panel below 30px
    /// auto-collapses it. Used by the View layer's drag handler.
    static let autoCollapsePixels: Double = 30

    /// Upper-row collapsed gutter width (≈50px per AGENTS §8.1).
    static let topCollapsedPixels: Double = 50

    /// Lower-row collapsed header-bar height (≈30px per AGENTS §8.1).
    static let bottomCollapsedPixels: Double = 30

    /// Visual width / height of a single draggable splitter bar.
    /// Sized for a 6px drag target on macOS (Apple HIG minimum is 4px,
    /// but 6px is more forgiving for the FCP-style double-click chevron
    /// gesture landing on a hit target that overlaps with the bar).
    static let splitterPixels: Double = 6

    // MARK: - JSON helpers (the persistence contract)

    /// Encode `collapsed` to a JSON string for `CDLayoutState.panel_states`.
    /// Returns "{}" if JSON serialization fails (defensive — schema drift
    /// between model versions or corrupted rows won't crash a cold launch).
    static func encodeCollapsed(_ collapsed: PanelCollapsedState) -> String {
        guard let data = try? JSONEncoder().encode(collapsed),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Decode `CDLayoutState.panel_states` JSON back to a struct.
    /// Returns the canonical default on any parse failure. We never throw
    /// from `loadLayoutState`: a malformed row degrades to defaults instead
    /// of bricking the shell render path.
    static func decodeCollapsed(_ string: String) -> PanelCollapsedState {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let value = try? JSONDecoder().decode(PanelCollapsedState.self, from: data) else {
            return PanelCollapsedState()
        }
        return value
    }

    /// Encode `ratios` to a JSON string for `CDLayoutState.panel_ratios`.
    static func encodeRatios(_ ratios: [Double]) -> String {
        guard let data = try? JSONEncoder().encode(ratios),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// Decode `CDLayoutState.panel_ratios` JSON back to `[Double]`. Returns
    /// the canonical default if the row is missing, malformed, or the array
    /// length is wrong (defensive — schema version drift funnel to defaults).
    static func decodeRatios(_ string: String) -> [Double] {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Double].self, from: data),
              arr.count == 5 else {
            return LayoutSnapshot.default.ratios
        }
        return arr
    }
}
