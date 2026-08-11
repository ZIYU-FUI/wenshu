// ChatViewModel+LTN2.swift · 文枢 (Wenshu) · v0.03.0 LT-N2-cc-v2
//
// LT-N2 designer (commit 6698a49e4) 拍板 4 alias + 1 新方法 (DESIGN-LT-N2.md §5):
//   - sendChatMessage       → alias 现有 sendInitialStory (不破 v0.01.0 CharacterWorldView 路由)
//   - loadChatHistory       → 新增 (调 WenshuProjectStore.loadChatHistory, 真从 .ws 读)
//   - generateSkeletonOptions → alias (设置 expandOptions = MockLLMResponse.expandOptions())
//   - applySkeletonChoice   → 调 toggleSelection + selectDirections (alias, 不破 v0.01.0 路由)
//
// 派生约束:
//   - 不改 ChatViewModel API 名字 = 沿用 v0.01.0 + v0.02.0 LT-04 (派单硬规则: "流式打字完全沿用")
//   - 不动 @Published schema (AGENTS §12 红线: 改 = 越界)
//   - 不动 ChatView body (派单硬规则: ChatView 沿用 v0.01.0)
//   - 这些 alias 只为给 task-style 调用方 (e.g. cua-driver, 8 步实机验脚本)
//     提供稳定的命名面 (不破 v0.01.0 已实装的 CharacterWorldView 路由)

import Foundation
import SwiftUI

extension ChatViewModel {

    // MARK: - LT-N2 扩展 (alias 现有方法, 加 1 个新方法)

    /// 1. `sendChatMessage` — alias 现有 `sendInitialStory`, 不破 v0.01.0 CharacterWorldView 路由。
    /// task-style 调用方用这名 (cua-driver / 8 步实机验脚本), 内部仍调 `sendInitialStory`。
    @MainActor
    func sendChatMessage(_ text: String) async {
        await sendInitialStory(text)
    }

    /// 2. `loadChatHistory` — LT-N2 真新增, 调 `WenshuProjectStore.loadChatHistory` 从 .ws 读历史。
    ///
    /// 流程: WenshuProjectStore 拉 `[ChatHistoryEntry]` → map 成
    /// `[ChatMessage]` (role + content 一一对应)。 失败兜底: messages
    /// 保持原值 (不动现有 messages), 仅 stderr 记日志。 v0.01.0 没 UI
    /// affordance 报加载错误, 沿用 silent-fail 范式。
    @MainActor
    func loadChatHistory(projectId: UUID) async {
        do {
            let history = try await WenshuProjectStore.shared.loadChatHistory(projectId: projectId)
            messages = history.map { ChatMessage(role: $0.role, content: $0.content) }
        } catch {
            FileHandle.standardError.write(Data(
                "ChatViewModel.loadChatHistory: \(error)\n".utf8
            ))
            // 加载失败: messages 保持原值, 由 emptyHint 兜底
        }
    }

    /// 3. `generateSkeletonOptions` — alias 设置 `expandOptions` 字段。
    ///
    /// task-style 调用方用这名 (cua-driver), 内部直接设 expandOptions 字段。
    @MainActor
    func generateSkeletonOptions() async {
        expandOptions = MockLLMResponse.expandOptions()
    }

    /// 4. `applySkeletonChoice` — 调 `toggleSelection` + `selectDirections`。
    ///
    /// 沿用 `selectDirections()` 内部全流程: append "已选择方向" user message + 流式 AI reply + populate characters/worldRules + pendingNavigation = .characterWorld。
    @MainActor
    func applySkeletonChoice(_ choiceId: UUID) async {
        if !selectedDirectionIDs.contains(choiceId) {
            toggleSelection(choiceId)
        }
        await selectDirections()
    }
}
