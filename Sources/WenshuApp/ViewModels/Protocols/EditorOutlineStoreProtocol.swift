// EditorOutlineStoreProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: EditorOutlineStore 抽象接口 — 章节 sidebar 列表
// Inputs: (load 入口)
// Outputs: chapters、[projectId]
// Dependencies: EditorOutlineStore (默认实现)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): EditorOutlineStore 抽象接口。 暴露
/// `chapters` read-only + `chapter(withId:)` 衍生 + `load()` 入口。
@MainActor
protocol EditorOutlineStoreProtocol: AnyObject {
    var chapters: [ChapterSnapshot] { get }
    var projectId: UUID { get }
    func load() async
    func chapter(withId id: String?) -> ChapterSnapshot?
}