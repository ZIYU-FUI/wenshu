// TopLeftHeaderBar.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: Views/Layout/TopLeftHeaderBar (跨全宽 28pt header — 5 tab ICON)
// Responsibilities: 5 tab ICON 按钮渲染 + activeTab 状态切换。
// Inputs: ProjectManagementTab.allCases + activeTab binding
// Outputs: 顶部跨全宽 28pt header bar View
// Dependencies: ProjectManagementTab
// Threading: @MainActor (跟 LayoutShellView 一致)
//
// 沿 DECISION §4.2 #4: LayoutShellView 拆主控 → topLeftHeaderBar 拆出。
// V0-fix-5 拍板: 5 tab Picker 从 ProjectListView 内部搬到 LayoutShellView
// 顶层 (跨全宽 38pt → V0-fix-11-1a retry-2 修真 28pt), 与 + 按钮平级。
// ProjectListView 接 @Binding activeTab 共享同一 state。

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
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 22)
                        .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
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
