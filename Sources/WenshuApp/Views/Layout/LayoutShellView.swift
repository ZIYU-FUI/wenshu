// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// 5-zone shell — the new root of the macOS window in v0.02.0.
//
// Geometry (AGENTS.md §8.1):
//
//   ┌────────────────────────────────────────────────────────────────┐
//   │ toolbar  ("文枢 v0.02.0" + reset link)                          │
//   ├──────────┬───────────────────────────┬──────────────────────────┤
//   │ 项目管理   │ 文档内容浏览器               │ inspector                 │
//   │ topLeft  │ topCenter (editor area)   │ topRight                  │
//   ├──────────┴───────────────────────────┴──────────────────────────┤
//   │ 聊天区 (bottomLeft)               │ 状态 (bottomRight)            │
//   └────────────────────────────────────┴────────────────────────────┘
//
// Splitters (see LayoutShellViewModel for delta math):
//   - 2 vertical in upper row (between topLeft↔topCenter, topCenter↔topRight)
//   - 1 horizontal between upper and lower bands
//   - 1 vertical in lower row (between bottomLeft↔bottomRight)
//   → 4 functional splitters. AGENTS §8.1 says "共 5 个"; the geometry
//     only fits 4. ACCEPTANCE-v0.02.0-LT-01.md documents the discrepancy.
//
// Widths/heights are computed from `vm.snapshot.ratios` + per-panel
// `collapsed` flag. When a panel is collapsed it takes its post-collapse
// gutter size (50px upper / 30px lower) instead of its ratio-derived
// size.
//
// Persistence: the View Model handles .ws read/write via
// `WenshuStoreActor` (see LayoutShellViewModel). The View only mutates
// the model through View Model methods.

import SwiftUI

struct LayoutShellView: View {
    @StateObject private var vm = LayoutShellViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            geometryBody
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await vm.load()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.pages")
                .foregroundStyle(.secondary)
            Text("文枢 v0.02.0")
                .font(.headline)
            Spacer()
            if vm.isLoaded {
                Button {
                    Task { await vm.resetToDefaults() }
                } label: {
                    Label("重置布局", systemImage: "arrow.counterclockwise")
                        .labelStyle(.titleAndIcon)
                }
                .help("把所有分隔条比例和折叠状态重置成 AGENTS §8.1 默认值")
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - 5-zone body

    private var geometryBody: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                upperBand(in: geo.size.width)
                    .frame(height: upperBandHeight(totalHeight: geo.size.height))
                PanelSplitter(orientation: .vertical) { delta in
                    vm.adjustBottomHeight(delta: delta, totalHeight: geo.size.height)
                }
                lowerBand(in: geo.size.width)
                    .frame(height: lowerBandHeight(totalHeight: geo.size.height))
            }
        }
    }

    private func upperBandHeight(totalHeight: CGFloat) -> CGFloat {
        let ratio = vm.snapshot.ratios[safe: 3] ?? 0.5
        return totalHeight * (1.0 - ratio)
    }

    private func lowerBandHeight(totalHeight: CGFloat) -> CGFloat {
        let ratio = vm.snapshot.ratios[safe: 3] ?? 0.5
        return totalHeight * ratio
    }

    // MARK: - Upper row: 3 columns

    private func upperBand(in totalWidth: CGFloat) -> some View {
        let split = computeUpperSplit(totalWidth: totalWidth)
        return HStack(spacing: 0) {
            upperPanel(.topLeft, width: split.0)
            PanelSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 0, delta: delta, totalWidth: totalWidth)
            }
            upperPanel(.topCenter, width: split.1)
            PanelSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 1, delta: delta, totalWidth: totalWidth)
            }
            upperPanel(.topRight, width: split.2)
        }
    }

    /// Compute (leftWidth, centerWidth, rightWidth) using the snapshot's
    /// ratio[0/1/2]. If a panel is collapsed it takes the gutter width
    /// (50px) and the freed space redistributes proportionally to the
    /// remaining expanded panels in the upper row.
    private func computeUpperSplit(totalWidth: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let totalSplitters = 2 * LayoutSnapshot.splitterPixels
        let available = max(0, totalWidth - totalSplitters)
        let collapsedGutter = LayoutSnapshot.topCollapsedPixels
        let r = vm.snapshot.ratios
        let leftCollapsed = vm.snapshot.collapsed.topLeft
        let centerCollapsed = vm.snapshot.collapsed.topCenter
        let rightCollapsed = vm.snapshot.collapsed.topRight
        let collapsedCount = (leftCollapsed ? 1 : 0) + (centerCollapsed ? 1 : 0) + (rightCollapsed ? 1 : 0)

        if collapsedCount == 3 {
            return (collapsedGutter, collapsedGutter, collapsedGutter)
        }
        let availableForExpanded = max(0, available - CGFloat(collapsedCount) * collapsedGutter)
        var expandedSum: Double = 0
        if !leftCollapsed { expandedSum += r[0] }
        if !centerCollapsed { expandedSum += r[1] }
        if !rightCollapsed { expandedSum += r[2] }
        guard expandedSum > 0 else { return (available / 3, available / 3, available / 3) }

        let left = leftCollapsed ? collapsedGutter
                                  : CGFloat(availableForExpanded * (r[0] / expandedSum))
        let center = centerCollapsed ? collapsedGutter
                                      : CGFloat(availableForExpanded * (r[1] / expandedSum))
        let right = rightCollapsed ? collapsedGutter
                                    : CGFloat(availableForExpanded * (r[2] / expandedSum))
        return (left, center, right)
    }

    @ViewBuilder
    private func upperPanel(_ id: PanelID, width: CGFloat) -> some View {
        if isCollapsed(id) {
            CollapsedGutter(panelID: id, onToggle: { vm.toggle(id) })
        } else {
            PanelContainer(
                panelID: id,
                isCollapsed: false,
                onToggle: { vm.toggle(id) }
            ) {
                PlaceholderContent(panel: id)
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

    // MARK: - Lower row: 2 areas

    private func lowerBand(in totalWidth: CGFloat) -> some View {
        let split = computeLowerSplit(totalWidth: totalWidth)
        return HStack(spacing: 0) {
            lowerPanel(.bottomLeft, width: split.0)
            PanelSplitter(orientation: .horizontal) { delta in
                vm.adjustLowerColumn(delta: delta, totalWidth: totalWidth)
            }
            lowerPanel(.bottomRight, width: split.1)
        }
    }

    /// Compute (leftWidth, rightWidth) for the lower band using ratios[4].
    /// Collapsed bottom panels take the bottomCollapsedPixels (30px).
    private func computeLowerSplit(totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        let available = max(0, totalWidth - LayoutSnapshot.splitterPixels)
        let collapsedHeight = LayoutSnapshot.bottomCollapsedPixels
        let r = vm.snapshot.ratios
        let leftCollapsed = vm.snapshot.collapsed.bottomLeft
        let rightCollapsed = vm.snapshot.collapsed.bottomRight

        if leftCollapsed && rightCollapsed {
            return (collapsedHeight, totalWidth - collapsedHeight - LayoutSnapshot.splitterPixels)
        }
        if leftCollapsed {
            return (collapsedHeight, max(0, available - collapsedHeight))
        }
        if rightCollapsed {
            return (max(0, available - collapsedHeight), collapsedHeight)
        }
        let left = CGFloat(available * r[4])
        let right = CGFloat(available * (1.0 - r[4]))
        return (left, right)
    }

    @ViewBuilder
    private func lowerPanel(_ id: PanelID, width: CGFloat) -> some View {
        if isCollapsed(id) {
            CollapsedHeaderBar(
                panelID: id,
                onToggle: { vm.toggle(id) }
            )
            .frame(width: width)
        } else {
            PanelContainer(
                panelID: id,
                isCollapsed: false,
                onToggle: { vm.toggle(id) }
            ) {
                PlaceholderContent(panel: id)
            }
            .frame(width: width)
        }
    }
}

// MARK: - Collapsed header bar for lower row
//
// AGENTS §8.1: 下半折叠到只剩标题栏 (≈ 30px). The PanelContainer header
// is height-flexible so we just render it inside a 30px-tall frame for
// collapsed lower panels.

struct CollapsedHeaderBar: View {
    let panelID: PanelID
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("展开 \(panelID.title)")

            Image(systemName: panelID.symbolName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(panelID.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LayoutSnapshot.bottomCollapsedPixels)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - Safe array access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
