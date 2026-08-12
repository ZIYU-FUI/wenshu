// ChatService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Protocols
// Responsibilities: 聊天流式响应的抽象接口
// Inputs: [ChatMessage]
// Outputs: AsyncThrowingStream<String, Error>
// Dependencies: ChatViewModel (默认实现委派)
// Threading: @MainActor (ChatViewModel 是 @MainActor)

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1): 聊天流式响应抽象。 默认实现委派
/// `ChatViewModel` 单例,内部仍走 `MockLLMResponse` / `LLMService.shared`
/// (沿 ChatViewModel 现有逻辑)。
@MainActor
protocol ChatService: Sendable {
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
    func cancel()
}
