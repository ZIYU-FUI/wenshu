// SelectionService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: 全局选中态 (项目 / 章节 / tab) 抽象接口
// Inputs: 项目 id、章节 id、tab 枚举
// Outputs: @Observable 公开属性
// Dependencies: LayoutShellViewModel + WenshuProjectStore (默认实现委派)
// Threading: @MainActor @Observable (UI 状态在主线程)
//
// 注: @Observable 是宏 — 不能直接贴在 protocol 上。 默认实现类
// (`DefaultSelectionService`) 才是 @Observable, 本协议只声明字段
// 形状。 编译期通过宏扩展在 DefaultSelectionService 上展开。

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): 全局选中态抽象。 默认实现委派现有
/// `selectedProjectID` / `selectedChapterID` / `activeTab` 顶层
/// `@State` (LayoutShellView)。 B+ 重阶段 = 透明委派,不改 state 落位。
@MainActor
protocol SelectionService: AnyObject {
    var selectedProjectID: UUID? { get set }
    var selectedChapterID: String? { get set }
    var activeTab: ProjectManagementTab { get set }
}