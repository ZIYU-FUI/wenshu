// LayoutShellTypes.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: Views/Layout/LayoutShellTypes (value type)
// Responsibilities: PanelID enum + PanelVisibilityState + PanelStatesEnvelope +
//   LayoutMetrics (纯几何函数) + menuTitle/isCollapsed extension
// Inputs: PanelID, LayoutSnapshot, PanelVisibilityState
// Outputs: 标题字符串、宽度/高度几何点
// Dependencies: Models/LayoutState.swift (PanelCollapsedState / LayoutSnapshot)
// Threading: @MainActor (PanelID 配套布局主控用)
//
// 沿 t_0f6bd6f6 LayoutShellViewModel.swift 拆出。 PanelCollapsedState
// 已在 Models/LayoutState.swift (172 行) 落档,本文件不重复定义 (沿红线:
// 不动 Models/LayoutState.swift)。

import Foundation
import SwiftUI

// MARK: - Panel identity

enum PanelID: Hashable, CaseIterable {
    case topLeft, topCenter, topRight, bottomLeft, bottomRight

    var title: String {
        switch self {
        case .topLeft: return "项目管理"
        case .topCenter: return "文档"
        case .topRight: return "检视"
        case .bottomLeft: return "聊天"
        case .bottomRight: return "状态"
        }
    }

    var symbolName: String {
        switch self {
        case .topLeft: return "folder"
        case .topCenter: return "doc.text"
        case .topRight: return "sidebar.right"
        case .bottomLeft: return "bubble.left.and.bubble.right"
        case .bottomRight: return "checklist"
        }
    }

    var menuShortcut: KeyEquivalent {
        switch self {
        case .topLeft: return "1"
        case .topCenter: return "2"
        case .topRight: return "3"
        case .bottomLeft: return "4"
        case .bottomRight: return "5"
        }
    }

    var isDismissible: Bool { true }

    var isCollapsible: Bool {
        switch self {
        case .topCenter, .bottomLeft: return false
        default: return true
        }
    }
}

// MARK: - Panel visibility

struct PanelVisibilityState: Codable, Sendable, Equatable {
    var topLeft: Bool
    var topCenter: Bool
    var topRight: Bool
    var bottomLeft: Bool
    var bottomRight: Bool

    init(topLeft: Bool = true, topCenter: Bool = true, topRight: Bool = true,
         bottomLeft: Bool = true, bottomRight: Bool = true) {
        self.topLeft = topLeft
        self.topCenter = topCenter
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func isVisible(_ panel: PanelID) -> Bool {
        switch panel {
        case .topLeft: return topLeft
        case .topCenter: return topCenter
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }
}

// MARK: - panel_states JSON envelope

enum PanelStatesEnvelope {
    private struct Payload: Codable {
        var collapsed: PanelCollapsedState
        var visible: PanelVisibilityState
    }

    static func encode(collapsed: PanelCollapsedState, visible: PanelVisibilityState) -> String {
        let payload = Payload(collapsed: collapsed, visible: visible)
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    static func decode(_ string: String) -> (collapsed: PanelCollapsedState, visible: PanelVisibilityState) {
        guard !string.isEmpty, let data = string.data(using: .utf8) else {
            return (PanelCollapsedState(), PanelVisibilityState())
        }
        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return (payload.collapsed, payload.visible)
        }
        return (LayoutSnapshot.decodeCollapsed(string), PanelVisibilityState())
    }
}

// MARK: - VM extension: menu titles + isCollapsed

extension LayoutShellViewModel {
    func menuTitle(for panel: PanelID) -> String {
        let verb = isVisible(panel) ? "隐藏" : "显示"
        return "\(verb) \(panel.title)"
    }

    func menuCollapseTitle(for panel: PanelID) -> String {
        let verb = isCollapsed(panel) ? "展开" : "折叠"
        return "\(verb) \(panel.title)"
    }

    func isCollapsed(_ panel: PanelID) -> Bool {
        switch panel {
        case .topLeft: return snapshot.collapsed.topLeft
        case .topCenter: return snapshot.collapsed.topCenter
        case .topRight: return snapshot.collapsed.topRight
        case .bottomLeft: return snapshot.collapsed.bottomLeft
        case .bottomRight: return snapshot.collapsed.bottomRight
        }
    }
}

// MARK: - LayoutMetrics (pure geometry, no UI state)

/// Pure geometry helpers for the 5-zone shell.
///
/// Precedence per panel: hidden → 0pt · collapsed → gutter · else →
/// its share of what's left, renormalised against the other *expanded*
/// panels' ratios.
enum LayoutMetrics {

    /// Number of splitter bars actually rendered between `visibleCount`
    /// adjacent panels.
    static func splitterCount(visibleCount: Int) -> Int {
        max(0, visibleCount - 1)
    }

    /// (topLeft, topCenter, topRight) widths in points.
    static func upperWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat, CGFloat) {
        let hidden = [!visibility.topLeft, !visibility.topCenter, !visibility.topRight]
        let isCollapsed = [collapsed.topLeft, collapsed.topCenter, collapsed.topRight]
        let r = ratios.count == 3 || ratios.count == 5
            ? [ratios[0], ratios[1], ratios[2]]
            : [LayoutSnapshot.default.ratios[0],
               LayoutSnapshot.default.ratios[1],
               LayoutSnapshot.default.ratios[2]]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        let gutter = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<3).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * gutter)

        let expandedSum = (0..<3)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return gutter }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1), width(2))
    }

    /// (bottomLeft, bottomRight) widths in points. `ratios[4]` is
    /// bottomLeft's share of the lower band.
    static func lowerWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat) {
        let leftRatio = ratios.count == 5 ? ratios[4] : LayoutSnapshot.default.ratios[4]
        let hidden = [!visibility.bottomLeft, !visibility.bottomRight]
        let isCollapsed = [collapsed.bottomLeft, collapsed.bottomRight]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        // A collapsed lower panel keeps only its header bar; horizontally
        // it still needs a readable strip, so we reuse the upper gutter
        // width as its minimum footprint.
        let strip = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<2).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * strip)

        let r = [leftRatio, 1.0 - leftRatio]
        let expandedSum = (0..<2)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return strip }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1))
    }

    /// Height of the lower band. If every lower panel is hidden the band
    /// collapses to 0 and the upper band takes the whole window (and
    /// vice-versa) — otherwise `ratios[3]` splits them.
    ///
    /// LT-01-fix5 fallback: when every dismissible panel is hidden and
    /// only 文档 + 聊天 remain visible, force a 50:50 split regardless
    /// of `ratios[3]`. Persisted ratios are not overwritten during
    /// fallback — manual un-hide restores ratio-driven layout.
    static func lowerBandHeight(
        totalHeight: CGFloat,
        ratios: [Double],
        visibility: PanelVisibilityState
    ) -> CGFloat {
        let lowerVisible = visibility.bottomLeft || visibility.bottomRight
        let upperVisible = visibility.topLeft || visibility.topCenter || visibility.topRight
        if !lowerVisible { return 0 }
        if !upperVisible { return totalHeight }
        if isFallbackLayout(visibility: visibility) {
            return totalHeight * 0.5
        }
        let r = ratios.count == 5 ? ratios[3] : LayoutSnapshot.default.ratios[3]
        return totalHeight * CGFloat(r)
    }

    /// LT-01-fix5: 当所有 dismissible panel (项目管理 / 检视 /
    /// 状态) 都被隐藏, 只剩 文档 + 聊天 这两块不可隐藏的核心区可见
    /// 时, 返回 `true`. 这是 "文档:聊天 = 50:50 fallback layout" 的
    /// 触发条件.
    static func isFallbackLayout(visibility: PanelVisibilityState) -> Bool {
        guard visibility.topCenter, visibility.bottomLeft else { return false }
        return !visibility.topLeft
            && !visibility.topRight
            && !visibility.bottomRight
    }
}
