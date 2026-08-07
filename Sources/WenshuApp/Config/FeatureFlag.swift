// FeatureFlag.swift · 文枢 (Wenshu) · v0.01.0 WO-005
//
// Compile-time / runtime switch for real LLM calls vs. mock fallback.
//
// Per WO-005 spec:
//   default = false (PM-direct / CI run without a key)
//   装机器 user 配 Keychain key + 把这里翻成 true → ChatViewModel 真调 minimax cn
//
// Why not a UI toggle in v0.01.0?
//   - Spec explicitly says: 本卡不做 UI toggle, 只写代码开关
//   - 装机器 user 改一行 `true` 即可, 后续 v0.01.x 再加 Settings → LLM toggle
//
// Scope of this file: ONE flag only. New flags land here too, never inline.
//
// Concurrency note: Swift 6 strict concurrency rejects plain `static var`
// as nonisolated global mutable state. We mark the flag `@MainActor` —
// ChatViewModel is already `@MainActor`, so readers don't pay any cost.
// 装机器 user mutates this once at app launch (still on MainActor).

import Foundation

enum FeatureFlag {

    /// `true` = ChatViewModel 真调 `LLMService.streamChat(...)`
    /// `false` = ChatViewModel 走 `MockLLMResponse.streamingChunks(...)`
    @MainActor
    static var useRealLLM: Bool = false
}
