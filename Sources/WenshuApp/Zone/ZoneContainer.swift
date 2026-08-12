// ZoneContainer.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆 Zone/ (t_1831ad61)
//
// Doc-Role: Zone/ZoneContainer
// Responsibilities: 主控容器化,替换 LayoutShellView.panel() 5 if/else 硬路由
// Inputs: PanelID + ZoneContext
// Outputs: 5 Zone 入口 View 之一 (PanelContainer 包裹)
// Dependencies: PanelContainer, ZoneRenderer
// Threading: @MainActor
//
// 替换 LayoutShellView.swift panel(_:width:) 5 case switch (沿 t_0f6bd6f6
// 已落地 switch 5 case),本类做容器化封装:
//   - 单一 switch on panelID
//   - PanelContainer 包裹 + 折叠态保留
//   - 显隐态由 caller (LayoutShellView) 决定,本类只做内容渲染路由
//
// 红线:
//   - 不加 ViewModel 关联类型
//   - 不暴露 store/actor (ZoneContext 已不含)
//   - 不实装 bottomRight (placeholder 即可)

import SwiftUI

struct ZoneContainer: View {
    let panelID: PanelID
    let context: ZoneContext

    var body: some View {
        PanelContainer(panelID: panelID) { content }
    }

    @ViewBuilder
    private var content: some View {
        switch panelID {
        case .topLeft:     TopLeftZone(context: context)
        case .topCenter:   TopCenterZone(context: context)
        case .topRight:    TopRightZone(context: context)
        case .bottomLeft:  BottomLeftZone(context: context)
        case .bottomRight: BottomRightZone(context: context)
        }
    }
}
