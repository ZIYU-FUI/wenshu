// LLMService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: LLM completion 抽象接口 (provider 委派给 MinimaxProvider)
// Inputs: prompt、model 字符串
// Outputs: completion 字符串、可用模型列表
// Dependencies: LLMProvider (默认实现委派 .shared)
// Threading: Sendable，async 函数跨 actor 调度

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): LLM completion 抽象。 默认实现委派
/// `LLMService.shared` (existing Sources/WenshuApp/LLM/LLMService.swift
/// 实际类,与同名协议共存 — 协议名同现有类型名会冲突,这里改成
/// `LLMCompletionService` 避免命名冲突,原 `LLMService` class 不动)。
protocol LLMCompletionService: Sendable {
    func complete(prompt: String, model: String) async throws -> String
    var availableModels: [String] { get async }
}