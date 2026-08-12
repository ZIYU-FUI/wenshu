// EditorContentStoreProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: EditorContentStore 抽象接口 — 章节正文读写 + flush
// Inputs: 新正文
// Outputs: content、isLoading、isDirty、wordCount
// Dependencies: EditorContentStore (默认实现)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): EditorContentStore 抽象接口。 暴露
/// `content` / `isLoading` / `isDirty` read-only + `wordCount` 衍生
/// + `load()` / `updateContent(_:)` / `flush()` 三入口。
@MainActor
protocol EditorContentStoreProtocol: AnyObject {
    var content: String { get }
    var isLoading: Bool { get }
    var isDirty: Bool { get }
    var wordCount: Int { get }
    var chapterId: String { get }
    func load() async
    func updateContent(_ newContent: String)
    func flush() async
}