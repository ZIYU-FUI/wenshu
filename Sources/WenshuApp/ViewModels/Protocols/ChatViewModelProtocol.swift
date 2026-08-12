// ChatViewModelProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: ChatViewModel 抽象接口 — 给 chat 相关 View / 测试用
// Inputs: 用户故事文本、方向 ID
// Outputs: messages、isGenerating 公开字段
// Dependencies: ChatViewModel (默认实现)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): ChatViewModel 抽象接口。 暴露
/// `sendInitialStory` / `selectDirections` + read-only messages /
/// isGenerating,保留 v0.01.0 + LT-N2 alias API 完整调用面。
@MainActor
protocol ChatViewModelProtocol: AnyObject {
    var messages: [ChatMessage] { get }
    var isGenerating: Bool { get }
    func sendInitialStory(_ text: String) async
    func selectDirections() async
}