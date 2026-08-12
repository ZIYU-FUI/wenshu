// ZoneContext.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆 Zone/ (t_1831ad61)
//
// Doc-Role: Zone/ZoneContext
// Responsibilities: 5 区入口 View 共享的 binding 注入点
// Inputs: 顶层 5 binding + panelID
// Outputs: ZoneContext (panelID + 5 binding)
// Dependencies: LayoutShellView (顶层 @State 源)
// Threading: @MainActor (跟 LayoutShellView 一致)
//
// 字段数 = 6 (panelID + 5 binding, 其中 activeTab 仅 topLeft 接收)。
// 5 Zone binding 接收非均匀分布 (避免 god object):
//   - TopLeftZone:    4 binding (projects / navPath / activeTab / selectedProjectID)
//   - TopCenterZone:  2 binding (selectedProjectID / selectedChapterID)
//   - TopRightZone:   0 binding (走 InspectorViewModel.shared 单例)
//   - BottomLeftZone: 0 binding (走 ChatViewModel env obj)
//   - BottomRightZone:0 binding (占位, 红线 #4)

import SwiftUI

struct ZoneContext {
    let panelID: PanelID
    let selectedProjectID: Binding<UUID?>
    let selectedChapterID: Binding<String?>
    let navPath: Binding<[AppRoute]>
    let projects: Binding<[ProjectSnapshot]>
    let activeTab: Binding<ProjectManagementTab>
}
