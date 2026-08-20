# 02 — ChatSessionStore SQLite 持久化

**What to build:**
老板 2026-08-21 拍 "关闭 app 再开, 上次聊的接续显示". ChatSessionStore = actor + SQLite, 跟 TodoStore / MemoryStore / KanbanStore 范式一致. ChatViewModel.init() load 历史, send() 后 append 写 SQLite. schema 2 表: chat_messages + chat_summaries.

**Blocked by:** ticket 01 (ChatMessage 有 source 字段才存).

**Status:** ready-for-agent

## 修法真值

1. 新建 `Sources/WenshuApp/Core/Chat/ChatSessionStore.swift` (actor + SQLite, 范式跟 `Sources/WenshuApp/Core/Todo/TodoStore.swift` 一致).
2. SQLite schema:
   ```sql
   CREATE TABLE IF NOT EXISTS chat_messages (
     id TEXT PRIMARY KEY,
     session_id TEXT NOT NULL DEFAULT 'default',
     source TEXT NOT NULL,
     content TEXT NOT NULL,
     timestamp REAL NOT NULL
   );
   CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, timestamp);

   CREATE TABLE IF NOT EXISTS chat_summaries (
     session_id TEXT PRIMARY KEY,
     summary TEXT NOT NULL,
     updated_at REAL NOT NULL,
     last_message_id TEXT
   );
   ```
3. 路径: `~/Library/Application Support/com.wenshu.app/chat.sqlite` (跟 Wenshu 项目基线一致).
4. API (actor methods):
   - `loadMessages(sessionId: String) async throws -> [ChatMessage]`
   - `append(_ message: ChatMessage, sessionId: String) async throws`
   - `clear(sessionId: String) async throws`
   - `loadSummary(sessionId: String) async throws -> String?`
   - `saveSummary(_ summary: String, sessionId: String, lastMessageId: UUID) async throws`
5. ChatMessage 加 `Codable` (id / source / content / timestamp, sessionId 存 DB 层不存 struct 里).
6. 跟 ChatMessage.swift (在 ChatView.swift 同文件) 加 `Codable` + `ChatSource: Codable` conformance.

## Acceptance

- [ ] ChatSessionStore actor + SQLite 文件落地
- [ ] 2 表 schema 正确 (chat_messages + chat_summaries)
- [ ] loadMessages 按 timestamp 排序返回
- [ ] append 异步写 SQLite 不阻塞 ChatView UI
- [ ] clear 清空 messages 但保留 summary
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 新增测试: testChatSessionStoreAppendLoad / testClear / testSessionIsolation (多 session_id 不混)

## 不动

- ChatView UI
- ChatViewModel 主流程 (本 ticket 只写 store, 不改 viewmodel 调用)
- ChatSession summary 生成逻辑 (ticket 05)

## 关联

- 依赖: ticket 01
- 被依赖: ticket 05 (summary 用 chat_summaries 表) / ticket 06 (ChatViewModel 集成 store)