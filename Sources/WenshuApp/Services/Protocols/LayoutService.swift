// LayoutService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: 5 区 layout (panel ratios / visibility / reset) 抽象接口
// Inputs: PanelID、Double ratio
// Outputs: [PanelID: Double]
// Dependencies: LayoutShellViewModel (默认实现委派 .shared)
// Threading: Sendable，async 函数跨 actor 调度

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): 5 区 layout state 读写抽象。 默认
/// 实现走 `LayoutShellViewModel.shared`(红线 #3 不破现有单例)。
/// PanelID / PanelCollapsedState 在 LayoutShellViewModel.swift 里
/// 已定义,这里直接复用。
protocol LayoutService: Sendable {
    var panelRatios: [PanelID: Double] { get async }
    func setRatio(panel: PanelID, ratio: Double) async
    func resetLayout() async
}