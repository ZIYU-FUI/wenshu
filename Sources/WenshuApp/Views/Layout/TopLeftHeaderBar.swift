// TopLeftHeaderBar.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: Views/Layout/TopLeftHeaderBar (跨全宽 28pt header — 5 tab ICON)
// Responsibilities: 5 tab ICON 按钮渲染 + activeTab 状态切换。
// Inputs: ProjectManagementTab.allCases + activeTab binding
// Outputs: 顶部跨全宽 28pt header bar View
// Dependencies: ProjectManagementTab, IconLibrary
// Threading: @MainActor (跟 LayoutShellView 一致)
//
// 沿 DECISION §4.2 #4: LayoutShellView 拆主控 → topLeftHeaderBar 拆出。
// V0-fix-5 拍板: 5 tab Picker 从 ProjectListView 内部搬到 LayoutShellView
// 顶层 (跨全宽 38pt → V0-fix-11-1a retry-2 修真 28pt), 与 + 按钮平级。
// ProjectListView 接 @Binding activeTab 共享同一 state。
//
// v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): font 13 → 14 修真 (沿 OOB
// 线框图 "顶部 5 tab ICON 14pt"), 选中态加 8pt 底部 indicator (FCP timeline
// 红字 "选中 = 主色填充 + 底部 indicator")。 ProjectManagementTab.symbolName
// 已修真走 IconLibrary.shared.symbolName(for:) 单一真值源 (本视图不另存
// 字面量)。

import SwiftUI

struct TopLeftHeaderBar: View {
    @Binding var activeTab: ProjectManagementTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ProjectManagementTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 22)
                        .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                        .overlay(alignment: .bottom) {
                            // 选中态 8pt 底部 indicator — FCP timeline 红字
                            // "选中 = 主色填充 + 底部 indicator" (V0-fix-11-1a
                            // retry-2 范式: 8pt 高 .frame(maxWidth: .infinity)
                            // 居中 + .background(Color.accentColor))。
                            if activeTab == tab {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: 14, height: 2)
                                    .offset(y: 4)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
                .disabled(!tab.isEnabled)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .padding(.horizontal, 12)
    }
}
