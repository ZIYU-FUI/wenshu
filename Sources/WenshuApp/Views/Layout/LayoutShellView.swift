// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix9
//
// 5-zone shell — the root of the macOS window in v0.02.0.
//
// Geometry (AGENTS.md §8.1):
//
//   ┌────────────────────────────────────────────────────────────────┐
//   │ (native macOS title bar — traffic lights only)                  │
//   ├──────────┬───────────────────────────┬──────────────────────────┤
//   │ 项目管理   │ 文档内容浏览器               │ inspector                 │
//   │ topLeft  │ topCenter (editor area)   │ topRight                  │
//   ├──────────┴───────────────────────────┴──────────────────────────┤
//   │ 聊天区 (bottomLeft)               │ 状态 (bottomRight)            │
//   └────────────────────────────────────┴────────────────────────────┘
//
// LT-01-fix3 (装机 user 8/7 实机验 + macOS HIG): the in-window toolbar
// row is GONE — the app version moved to 文枢 → 关于文枢, "重置布局"
// moved to 显示 → 重置布局, and the 4 per-panel chevrons were replaced by
// View → 项目管理/文档/检视/聊天/状态 (Cmd+1…5). Panel chrome now carries
// no controls at all, matching Final Cut Pro / Pages / Numbers.
//
// LT-01-fix9 (装机 user 8/7 实机拍 "全部原生"): 4 个 `PanelSplitter` 替换为
// `NativeSplitter` (= NSSplitView divider 风格 NSView, 1pt 细线 +
// NSCursor 自动设 + NSEvent 原生 drag). Drop-in 替换, 调用接口一致
// (`orientation` + `onDrag` closure), LayoutShellView 的 VStack/HStack
// 结构不变。 见 docs/wenshu/LAYOUT-APPKIT-INVENTORY.md §1.1-1.2。
//
// Splitters (see LayoutShellViewModel for delta math):
//   - 2 vertical in upper row (between topLeft↔topCenter, topCenter↔topRight)
//   - 1 horizontal between upper and lower bands
//   - 1 vertical in lower row (between bottomLeft↔bottomRight)
//   → 4 functional splitters. AGENTS §8.1 says "共 5 个"; the geometry
//     only fits 4. ACCEPTANCE-v0.02.0-LT-01.md documents the discrepancy.
//   A splitter is only rendered when both of its neighbours are visible.
//
// Widths/heights come from `LayoutMetrics` (pure, unit-tested) fed by
// `vm.snapshot.ratios` + `vm.snapshot.collapsed` + `vm.visibility`.
//
// Persistence: the View Model handles .ws read/write via
// `WenshuStoreActor` (see LayoutShellViewModel). The View only mutates
// the model through View Model methods.

import SwiftUI

struct LayoutShellView: View {
    // LT-01-fix3: shared instance so the macOS menu bar commands in
    // App.swift drive the same state (a @StateObject here would be
    // unreachable from a CommandMenu).
    @ObservedObject private var vm = LayoutShellViewModel.shared

    var body: some View {
        geometryBody
            .frame(minWidth: 900, minHeight: 600)
            .task {
                await vm.load()
            }
    }

    // MARK: - 5-zone body

    private var geometryBody: some View {
        GeometryReader { geo in
            let lowerHeight = LayoutMetrics.lowerBandHeight(
                totalHeight: geo.size.height,
                ratios: vm.snapshot.ratios,
                visibility: vm.visibility
            )
            VStack(spacing: 0) {
                if upperBandVisible {
                    upperBand(in: geo.size.width)
                        .frame(height: geo.size.height - lowerHeight)
                }
                if upperBandVisible && lowerBandVisible {
                    // LT-01-fix13: VM 的 `adjustXxx` 返回 Bool (= applied,
                    // clamp 没截断), 但 NativeSplitter 的 `onDrag` 是
                    // `(CGFloat) -> Void`, 把 Bool 透传给 caller 也无用
                    // (NativeSplitterView 内部没用返回值 — fix14 后
                    // `lastReported` 字段已删, 没东西可 reset)。 直接
                    // discardableResult 调, 跟 NativeSplitter 接口契约
                    // 对齐。
                    NativeSplitter(orientation: .vertical) { delta in
                        vm.adjustBottomHeight(
                            delta: delta,
                            totalHeight: geo.size.height
                        )
                    }
                }
                if lowerBandVisible {
                    lowerBand(in: geo.size.width)
                        .frame(height: lowerHeight)
                }
            }
        }
    }

    private var upperBandVisible: Bool {
        vm.isVisible(.topLeft) || vm.isVisible(.topCenter) || vm.isVisible(.topRight)
    }

    private var lowerBandVisible: Bool {
        vm.isVisible(.bottomLeft) || vm.isVisible(.bottomRight)
    }

    // MARK: - Upper row: 3 columns

    private func upperBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.topLeft, width: split.0)
            if vm.isVisible(.topLeft) && vm.isVisible(.topCenter) {
                // LT-01-fix13: 同上 — VM 返回 Bool 但 NativeSplitter
                // `(CGFloat) -> Void` 不消费, discardableResult 调用。
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(
                        splitterIndex: 0,
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.topCenter, width: split.1)
            if vm.isVisible(.topCenter) && vm.isVisible(.topRight) {
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(
                        splitterIndex: 1,
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.topRight, width: split.2)
        }
    }

    // MARK: - Lower row: 2 areas

    private func lowerBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.lowerWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.bottomLeft, width: split.0)
            if vm.isVisible(.bottomLeft) && vm.isVisible(.bottomRight) {
                // LT-01-fix13: 同上 — discardableResult 调用。
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustLowerColumn(
                        delta: delta,
                        totalWidth: totalWidth
                    )
                }
            }
            panel(.bottomRight, width: split.1)
        }
    }

    // MARK: - One panel slot

    /// Hidden panels render nothing at all (no gutter, no header) — the
    /// only way back is the View menu. Collapsed panels keep their
    /// header/gutter chrome, which LT-01-fix3 leaves reachable only via
    /// persisted state (no chevron).
    @ViewBuilder
    private func panel(_ id: PanelID, width: CGFloat) -> some View {
        if !vm.isVisible(id) {
            EmptyView()
        } else if isCollapsed(id) {
            CollapsedGutter(panelID: id)
                .frame(width: width)
        } else {
            PanelContainer(panelID: id) {
                if id == .bottomLeft {
                    ChatPanelView()
                } else if id == .topRight {
                    // WO-LT-02-v2: inspector 2 tab 嵌入 (伏笔真读
                    // CDForeshadow + 修订 mock 3 条)。 InspectorView
                    // 是 InspectorViewModel.shared 的 @ObservedObject
                    // consumer — inspector 状态 (折叠 / 选 tab /
                    // 拉伏笔列表) 跟左 / 中半 layout 完全解耦, 拖
                    // topRight 改宽不影响其他 panel。 严禁在这里走
                    // sheet / NavigationStack push — 见 AGENTS §6。
                    InspectorView()
                } else {
                    PlaceholderContent(panel: id)
                }
            }
            .frame(width: width)
        }
    }

    private func isCollapsed(_ id: PanelID) -> Bool {
        switch id {
        case .topLeft: return vm.snapshot.collapsed.topLeft
        case .topCenter: return vm.snapshot.collapsed.topCenter
        case .topRight: return vm.snapshot.collapsed.topRight
        case .bottomLeft: return vm.snapshot.collapsed.bottomLeft
        case .bottomRight: return vm.snapshot.collapsed.bottomRight
        }
    }
}
