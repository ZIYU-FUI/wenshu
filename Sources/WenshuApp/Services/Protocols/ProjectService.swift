// ProjectService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: 项目列表/加载/保存的抽象接口
// Inputs: 项目 id、ProjectSnapshot
// Outputs: ProjectSnapshot、[ProjectSnapshot]
// Dependencies: WenshuProjectStore (默认实现委派)
// Threading: Sendable，async 函数跨 actor 调度

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): 项目数据访问的最小抽象。 默认实现
/// 委派给 `WenshuProjectStore.shared` 单例(红线 #3 不破现有单例),
/// 后续派生单测 / mock / 多 store 场景可直接换实现。
protocol ProjectService: Sendable {
    func loadProject(id: UUID) async throws -> ProjectSnapshot
    func saveProject(_ snapshot: ProjectSnapshot) async throws
    func listProjects() async throws -> [ProjectSnapshot]
}