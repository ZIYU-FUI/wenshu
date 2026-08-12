// LayoutShellViewModelProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: LayoutShellViewModel 抽象接口 — 5 区 ratios/visibility/collapse
// Inputs: PanelID、delta、totalWidth/Height
// Outputs: snapshot、visibility、isLoaded 公开字段
// Dependencies: LayoutShellViewModel (默认实现 .shared)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): LayoutShellViewModel 抽象接口。 暴露
/// snapshot/visibility read-only + load + adjustXxx 三入口 +
/// togglePanelVisibility/toggleBottomBand/showAllPanels/resetToDefaults。
@MainActor
protocol LayoutShellViewModelProtocol: AnyObject {
    var snapshot: LayoutSnapshot { get }
    var visibility: PanelVisibilityState { get }
    var isLoaded: Bool { get }
    func load() async
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) -> Bool
    func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) -> Bool
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) -> Bool
    func togglePanelVisibility(_ panel: PanelID)
    func toggleBottomBand()
    func isVisible(_ panel: PanelID) -> Bool
    func isCollapsed(_ panel: PanelID) -> Bool
    func showAllPanels()
    func resetToDefaults() async
}