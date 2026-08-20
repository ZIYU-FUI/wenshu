# 05 — Sliding window + 持久化摘要 (上下文不爆)

**What to build:**
老板 2026-08-21 拍 "看似唯一会话能延续继续聊, 上下文不能爆". Sliding window + persistent summary: 最近 10 轮原文 + 老历史 LLM 生成的 summary 单独存 SQLite (chat_summaries 表). 喂 LLM 时拼装 (summary + last 10), token 控制. UI 仍看全部 messages (不删), 只在喂 LLM 时用 context window.

**Blocked by:** ticket 02 (chat_summaries 表已建) + ticket 03 (LLM 真合成可调).

**Status:** ready-for-agent

## 修法真值

1. `Sources/WenshuApp/Core/Chat/ChatSessionStore.swift` 加 actor method:
   - `summarizeIfNeeded(sessionId: String, lastN: Int = 10, threshold: Int = 20) async throws`
   - 当 `loadMessages(sessionId).count > threshold` → 触发 summary
   - 拿前 `count - lastN` 条 messages → 调 MiniMaxVerifier.chat(`总结以下聊天: [messages] -> 200 字 summary`)
   - 写 chat_summaries 表 (覆盖) + 删老的原文 (DELETE FROM chat_messages WHERE id IN (...))
2. `ChatViewModel.buildContextForLLM() async throws -> String`:
   - loadSummary(sessionId) + last 10 messages
   - 拼装: `summary + "\n\n---\n\n最近对话:\n" + last10messages`
   - 返回 String 给 WenshuConductor.handle 喂 LLM
3. `WenshuConductor.handle` 改: 调 LLM 时用 `buildContextForLLM()` 当 prompt prefix, 不是 `userMessage` 单独喂.
4. `ChatViewModel.send()` 调 `summarizeIfNeeded` 异步触发 (不阻塞 send 主流程).

## Acceptance

- [ ] ChatSessionStore.summarizeIfNeeded 实现 + 真值
- [ ] 触发条件: messages.count > 20
- [ ] 喂 LLM 时用 buildContextForLLM() 拼装
- [ ] UI 仍显示全部 messages (不删 UI 渲染层)
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 新增测试: testSummarizeIfNeeded (构造 25 条 → 触发 → summary 存 + 老 messages 删)

## 不动

- ChatView UI 渲染 (看全部 messages)
- KanbanStore
- WenshuConductor 调度逻辑 (只改 LLM prompt 来源)

## 关联

- 依赖: ticket 02 + 03
- 被依赖: ticket 06 (ChatViewModel 集成 buildContextForLLM)