// DefaultSelectionService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: SelectionService 委派实现 — 透明转发现有顶层 @State
// Inputs: UUID?、String?、ProjectManagementTab
// Outputs: @Observable 公开属性
// Dependencies: LayoutShellViewModel (panelID 落位)、MainView (AppRoute 路由)
// Threading: @MainActor @Observable

import Foundation
import Observation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 默认实现
/// 把 protocol 字段直接转发到一个持有 @MainActor @Observable 包装。
/// B+ 重阶段仍由 LayoutShellView 顶层 @State 持有真值,本类型仅
/// 提供 protocol 满足编译需要 + 后续派单替换顶层 state 的过渡点。
@MainActor
@Observable
final class DefaultSelectionService: SelectionService {
    var selectedProjectID: UUID?
    var selectedChapterID: String?
    var activeTab: ProjectManagementTab

    init(
        selectedProjectID: UUID? = nil,
        selectedChapterID: String? = nil,
        activeTab: ProjectManagementTab = .projects
    ) {
        self.selectedProjectID = selectedProjectID
        self.selectedChapterID = selectedChapterID
        self.activeTab = activeTab
    }
}