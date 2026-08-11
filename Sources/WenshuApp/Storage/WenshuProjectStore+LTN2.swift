// WenshuProjectStore+LTN2.swift · 文枢 (Wenshu) · v0.03.0 LT-N2-cc-v2
//
// LT-N2 designer (commit 6698a49e4) 拍板 1 新方法 (DESIGN-LT-N2.md §6),
// PM-direct 拍 "4 新方法"。本文件落 4 个公开 API (load / append / count / clear),
// 跟现有 save() 沿用同一 tag-scoping 范式:
//
//   - save():         tags = "project-<uuid>"  (initial story 一句话故事)
//   - chat history:   tags = "chat-<uuid>"     (新, LT-N2 引入)
//
// tag 前缀不同 = 不冲突, 旧 v0.01.0 .ws 文件自动兼容 (AGENTS §12 schema
// 红线: 不动 CDNote schema, 只加 tag 前缀字符串约定)。
//
// 存储格式: text 字段 = JSON 编码的 {role, content} dict。 这样保留
// `role` 信息 (user / assistant) 不进 schema。 fetch 时用
// JSONSerialization 反解, 任何字段缺失返回 nil (一行坏数据不破整个 chat
// 加载)。
//
// ChatViewModel.loadChatHistory 是这 4 个方法的唯一上层 caller
// (沿 v0.01.0 + v0.02.0 LT-04 "流式打字完全沿用" 派单硬规则)。
//
// 设计文档原建议 return `[[String: Any]]`, 但 Swift 6 Sendable 边界要
// 求跨 actor 返回值是 Sendable, `[[String: Any]]` 不 Sendable。 用
// `ChatHistoryEntry` (typed struct) 替代, 保留 `role` + `content` 两
// 字段语义。

import Foundation

extension WenshuProjectStore {

    /// LT-N2 tag 前缀。跟现有 `project-<uuid>` 区分, 不冲突。
    private static let chatHistoryTagPrefix = "chat-"

    /// 算 chat history 的 tag-scoping tag。 给所有 4 个公开方法用。
    private func chatHistoryTag(for projectId: UUID) -> String {
        "\(Self.chatHistoryTagPrefix)\(projectId.uuidString)"
    }

    // MARK: - 1. loadChatHistory

    /// 从 .ws 拉指定项目的全部聊天历史。
    ///
    /// 流程:
    ///   1. 调 `WenshuStoreActor.listNotesWithMetadata(tag:)` 全量拉
    ///      `chat-<uuid>` tag 的 CDNote rows
    ///   2. 每行 text = JSON 编码的 {role, content} → JSONSerialization 反解
    ///   3. 按 createdAt 升序排 (聊天时序)
    ///   4. 任何解析失败兜底为 nil (一行坏数据不破整次加载)
    ///
    /// Returns: array of `ChatHistoryEntry` (typed Sendable struct)。 caller
    /// (`ChatViewModel.loadChatHistory`) 把每条 entry 转 `ChatMessage`。
    /// 空项目 (无聊天) 返回 `[]`。
    func loadChatHistory(projectId: UUID) async throws -> [ChatHistoryEntry] {
        let tag = chatHistoryTag(for: projectId)
        let rows = try await storeActor.listNotesWithMetadata(tag: tag)
        // 按 createdAt 升序 (聊天的自然时序)。 rows 来自
        // listNotesWithMetadata 暂无 sort descriptor (LT-N2 不加,
        // 避免动 storeActor 现有 signature), 在这里按 row.createdAt 排。
        let sortedRows = rows.sorted { $0.createdAt < $1.createdAt }
        return sortedRows.compactMap { row -> ChatHistoryEntry? in
            guard let data = row.text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let role = json["role"] as? String,
                  let content = json["content"] as? String
            else { return nil }
            return ChatHistoryEntry(role: role, content: content)
        }
    }

    // MARK: - 2. appendChatMessage

    /// 追加一条聊天消息到 .ws (给项目 `projectId` 加 1 条 `chat-<uuid>` tag 的 CDNote)。
    ///
    /// 文本格式: JSON 编码 {role, content}。
    /// `role`: `"user"` 或 `"assistant"` (跟 ChatMessage.role 对齐)。
    /// `content`: 消息文本。
    /// `createdAt`: 现在。
    ///
    /// Errors: JSON 编码失败 / CoreData 写入失败 → 向上抛, caller
    /// (`ChatViewModel`) silent-fail 兜底 (沿 v0.01.0 `persist()` 范式)。
    func appendChatMessage(projectId: UUID, role: String, content: String) async throws {
        let payload: [String: Any] = [
            "role": role,
            "content": content
        ]
        // JSON 编码失败 (理论上不可能, dict 全 String 值) → 抛错
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let jsonText = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "WenshuProjectStore.LTN2",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "JSON 编码失败"]
            )
        }
        try await storeActor.createNote([
            "text": jsonText,
            "tags": chatHistoryTag(for: projectId),
            "createdAt": Date()
        ])
    }

    // MARK: - 3. countChatMessages

    /// 数指定项目的聊天历史条数 (= `chat-<uuid>` tag 的 CDNote 行数)。
    /// 给测试 + 未来 diagnostics 用。
    func countChatMessages(projectId: UUID) async throws -> Int {
        try await storeActor.countChatNotes(tag: chatHistoryTag(for: projectId))
    }

    // MARK: - 4. clearChatHistory

    /// 清空指定项目的聊天历史 (= 删 `chat-<uuid>` tag 的全部 CDNote)。
    /// 给重置 / 测试 / 装机 user 主动清理用。
    ///
    /// 注意: 不会动 v0.01.0 `project-<uuid>` tag 的 initial story (CDNote)。
    func clearChatHistory(projectId: UUID) async throws {
        try await storeActor.deleteNotes(tag: chatHistoryTag(for: projectId))
    }
}

// MARK: - ChatHistoryEntry (LT-N2 chat history wire format)

/// Sendable wire-format for one chat history row。 跨 actor 边界用
/// (WenshuProjectStore 是 actor, ChatViewModel 是 @MainActor), 不能
/// 用 `[[String: Any]]` (`Any` 非 Sendable)。
///
/// 设计文档原建议 `[[String: Any]]`, Swift 6 strict concurrency 不允许,
/// 改 typed struct: 2 字段 `role` + `content`, 跟 ChatMessage.role /
/// ChatMessage.content 一一对应。 caller 在 main actor 上 .map 转
/// ChatMessage。
struct ChatHistoryEntry: Sendable, Equatable {
    let role: String
    let content: String

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
