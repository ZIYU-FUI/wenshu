# 01 — ChatMessage 加 source 字段 + ChatView 文枢单显

**What to build:**
老板 2026-08-21 拍 "用户永远看到的只有一个会话, 多 agent 协作只显示文枢单一 agent, 其他 agent 永远隐身". ChatMessage 加 source 字段 (区分 .user / .wenshu / .system), ChatView 渲染按 source 标 ICON + 配色. 多 agent 调度结果不进 ChatMessage 流, 走 KanbanStore 看板 (后续 ticket 04).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## 修法真值

1. `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatMessage` struct 加 `source: ChatSource` 字段, `Equatable` 同步比较 source.
2. 新增 enum `ChatSource: String, Equatable, Sendable { case user, wenshu, system }`.
3. `ChatMessage.init` 加 source 参数 (默认 .wenshu 保持向后兼容).
4. `ChatViewModel.send()` user message 用 `.user`, agent reply 用 `.wenshu`, error 用 `.system`.
5. `ChatMessageView` 渲染按 source:
   - .user → 右侧气泡, 蓝色背景
   - .wenshu → 左侧气泡, 系统色背景, "文枢" label
   - .system → 居中灰色文字, Error 图标
6. `AgentProtocol.handleMessageSend` 派子 agent 结果不显 ChatMessage, 留口子 ticket 04 接 KanbanStore.

## Acceptance

- [ ] ChatMessage struct 有 source 字段, default .wenshu
- [ ] ChatSource enum: .user / .wenshu / .system
- [ ] ChatViewModel.send() 用 source 字段标消息类型
- [ ] ChatMessageView 按 source 显示不同 ICON + 配色
- [ ] swift build exit 0
- [ ] swift test exit 0 (现有 test 不破)
- [ ] 新增测试: testChatMessageSource (.user / .wenshu / .system 各 1 条)

## 不动 (Q20 硬约束)

- runtime.delegateTask / AgentProtocol.handleMessageSend L188-190 echo (ticket 03 改)
- ChatViewModel.send 主流程 + fallback verifier.ping
- v0.20 ticket 01 ChatView UI (cf121f77a 已 commit, 只加 source 不改结构)

## 关联

- 依赖: 无
- 被依赖: ticket 02 (ChatSessionStore 用 source 字段) / ticket 06 (ChatViewModel 集成)