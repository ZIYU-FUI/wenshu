// DefaultLLMService.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: Services/Defaults
// Responsibilities: LLMCompletionService 委派实现 — 透传到现有 LLMService 类
// Inputs: prompt、model 字符串
// Outputs: completion 字符串、可用模型列表
// Dependencies: LLMService.shared (existing 类,不替换)
// Threading: Sendable

import Foundation

/// B+ 重 (沿 DECISION §4.2 #1 + 红线 #3): 委派不替代。 minimax cn
/// (Anthropic 兼容协议) 真 LLM 调用仍走 `LLMService` 类(命名冲突
/// 解决 = protocol 改名 `LLMCompletionService`)。 默认实现仅在
/// keychain 有 key 时返回真模型列表,否则抛 missingAPIKey。
struct DefaultLLMService: LLMCompletionService {
    func complete(prompt: String, model: String) async throws -> String {
        let svc = try LLMService.shared
        let stream = svc.streamChat(system: prompt, messages: [])
        var collected = ""
        for try await chunk in stream {
            collected += chunk
        }
        return collected
    }

    var availableModels: [String] {
        get async {
            // minimax cn 模型白名单(沿 CLAUDE.md §9):
            ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed",
             "MiniMax-M2.5", "MiniMax-M2.5-highspeed",
             "MiniMax-M2.1", "MiniMax-M2.1-highspeed",
             "MiniMax-M2", "M2-her"]
        }
    }
}