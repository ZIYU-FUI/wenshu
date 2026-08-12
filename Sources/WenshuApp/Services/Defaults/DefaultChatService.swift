// DefaultChatService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: ChatService 委派实现 — 透传到 ChatViewModel 单例
// Inputs: [ChatMessage]
// Outputs: AsyncThrowingStream<String, Error>
// Dependencies: ChatViewModel (红线 #3)
// Threading: @MainActor (ChatViewModel 是 @MainActor, 默认值需同 actor)

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 chat 流
/// 抽象由 ChatViewModel 内部 streamFromMock / streamFromRealLLM
/// 暴露,B+ 重协议层仅做最小透传(throw notImplemented 给 v0.06.0+
/// 真接 service protocol 时补)。
@MainActor
struct DefaultChatService: ChatService {
    private let vm: ChatViewModel

    init(vm: ChatViewModel = ChatViewModel()) {
        self.vm = vm
    }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            // B+ 重 stub: chat 流协议 v0.06.0+ 才接。 现阶段 throw 让
            // 调用方走 vm 直接路径 (vm.sendInitialStory / selectDirections)。
            continuation.finish(throwing: ChatServiceError.notImplemented)
        }
    }

    func cancel() {
        // B+ 重 stub: 等协议真接后再实装。
    }
}

enum ChatServiceError: Error {
    case notImplemented
}