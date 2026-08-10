// ResourceLibraryTab.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Tab 4 = 资料. 占位, 显 "v0.04.0 实现"。
// 沿用 ChatPanelView 的 disabledContent 范式 (SF Symbol + 文案 + 灰)。

import SwiftUI

struct ResourceLibraryTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: ProjectManagementTab.resources.symbolName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(ProjectManagementTab.resources.placeholder)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(true)
        .navigationTitle("资料")
    }
}
