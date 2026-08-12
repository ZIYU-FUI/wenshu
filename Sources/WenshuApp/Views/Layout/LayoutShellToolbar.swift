// LayoutShellToolbar.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: Views/Layout/LayoutShellToolbar (FCP 范式 macOS title bar buttons)
// Responsibilities: 7 toolbar 按钮封装 — 3 个新建/打开/导入占位 + 3 个折叠
//   toggle + 1 个分享占位。
// Inputs: LayoutShellViewModel (依赖 .shared, 沿红线 #3 不破)
// Outputs: 7 View 子节点供 LayoutShellView.toolbar 调用
// Dependencies: LayoutShellViewModel.shared
// Threading: @MainActor (跟 LayoutShellView 一致)
//
// 沿 DECISION §4.2 #4: LayoutShellView 拆主控 → 7 toolbar 按钮拆出。
// Notification.Name 仍由 LayoutShellView 持 (本地 extension), toolbar
// 文件只读不持。

import SwiftUI

struct LayoutShellToolbar: ToolbarContent {
    let vm: LayoutShellViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            toolbarNewProjectButton
            toolbarOpenProjectButton
            toolbarImportProjectButton
            Spacer().frame(width: 8)
            foldToggleViewerButton
            foldToggleBottomBandButton
            foldToggleInspectorButton
            toolbarSharePlaceholderButton
        }
    }

    /// 新建项目 + ICON (红黄绿后紧跟, FCP 范式)。
    private var toolbarNewProjectButton: some View {
        Button {
            NotificationCenter.default.post(
                name: .wenshuShowCreateProject, object: nil
            )
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("新建项目 (⌘N)")
    }

    /// 打开项目 + ICON (新建后面, FCP 范式 3 ICON 群)。
    private var toolbarOpenProjectButton: some View {
        Button {
            NotificationCenter.default.post(
                name: .wenshuOpenProjectURL, object: nil
            )
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("打开项目... (⌘O)")
    }

    /// 导入项目 + ICON (打开后面, 占位, v0.04.0 真修真导入逻辑)。
    private var toolbarImportProjectButton: some View {
        Button {
            // placeholder — v0.04.0+ 接 NSOpenPanel import 真修真
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("导入... (v0.04.0)")
        .disabled(true)
    }

    // MARK: - v0.04.0 t_bfa84198 FCP 折叠按钮

    /// 按钮 1 ↔ `.topCenter` (中上 viewer 文档)。
    private var foldToggleViewerButton: some View {
        FoldToggleButton(
            symbol: vm.isVisible(.topCenter)
                ? "rectangle.split.3x1"
                : "rectangle.split.3x1.fill",
            isVisible: vm.isVisible(.topCenter),
            action: { vm.togglePanelVisibility(.topCenter) },
            help: "隐藏/显示 文档 (⌘2)"
        )
    }

    /// 按钮 2 ↔ `.bottomLeft` + `.bottomRight` (整条下半栏)。
    private var foldToggleBottomBandButton: some View {
        FoldToggleButton(
            symbol: "rectangle.split.3x1.fill",
            isVisible: vm.isBottomBandVisible(),
            action: { vm.toggleBottomBand() },
            help: "隐藏/显示 状态栏 (⌘4+⌘5)"
        )
    }

    /// 按钮 3 ↔ `.topRight` (检视)。
    private var foldToggleInspectorButton: some View {
        FoldToggleButton(
            symbol: "checklist",
            isVisible: vm.isVisible(.topRight),
            action: { vm.togglePanelVisibility(.topRight) },
            help: "隐藏/显示 检视 (⌘3)"
        )
    }

    /// Share 占位按钮 (v0.04.0+ 接 NSSharingServicePicker 派单时改 .disabled(false))。
    private var toolbarSharePlaceholderButton: some View {
        Button {
            // placeholder — v0.04.0+ 接 share 真修真
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("分享 (v0.04.0+)")
        .disabled(true)
    }
}
