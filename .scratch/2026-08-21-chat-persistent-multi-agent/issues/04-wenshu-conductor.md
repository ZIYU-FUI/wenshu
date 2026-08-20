# 04 — 文枢主 agent 多模块调度 (KanbanStore 写任务)

**What to build:**
老板 2026-08-21 拍 "多 agent 协作由文枢调度, 通过看板给任务, 其他 agent 永远隐身". WenshuConductor = 文枢主 agent 调度器, actor + AgentProcess 范式. 收 user message → 分析意图 → 派 0-N 个 KanbanTask 给子 agent (复用 v0.19 12 模块后端) → 等结果 → 调 MiniMaxVerifier.send 拼装最终回复. 子 agent 进度走 KanbanStore, ChatView 不显.

**Blocked by:** ticket 02 (KanbanStore 已有, schema 需加 assignee / conductor_task_id 字段) + ticket 03 (LLM 真合成可用).

**Status:** ready-for-agent

## 修法真值

1. 新建 `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (actor + AgentProcess 范式, 跟 `AgentProtocol` 同模式).
2. WenshuConductor 持 AgentRuntime + KanbanStore + MiniMaxVerifier 引用.
3. `WenshuConductor.handle(userMessage: String, sessionId: String) async throws -> String`:
   - 调 MiniMaxVerifier.chat(`意图分析: \(userMessage) -> {assignee, task}`) 拿派任务清单
   - 拿 KanbanTask list → 写 KanbanStore (assignee = 子 agent name, conductor_task_id = 父任务 ID)
   - 派 AgentRuntime.delegateTask(to: assignee, ...) 给每个子 agent
   - 等所有子 agent task 完成 (轮询 KanbanStore.status == .done)
   - 调 MiniMaxVerifier.chat(`合成: 子 agent results + user message -> final reply`) 拿文枢最终回复
   - 返回 String 给 ChatViewModel
4. KanbanStore schema 加 2 列:
   ```sql
   ALTER TABLE kanban_tasks ADD COLUMN assignee TEXT;
   ALTER TABLE kanban_tasks ADD COLUMN conductor_task_id TEXT;
   ```
   (KanbanStore 加对应字段到 Task struct)
5. v0.19 12 模块 (LinkGraph / Search / Composer / Templates / Graph / Canvas / Bases / QuickSwitcher / WordCount / Outline / Bookmarks / Verifier) 作为可选 assignee — 注册到 AgentRuntime.
6. ChatViewModel.send() 改: 优先 WenshuConductor.handle (不直接 delegateTask), fallback verifier.chat(text) (跟 ticket 03 fallback 一致).

## Acceptance

- [ ] WenshuConductor actor + AgentProcess 范式落地
- [ ] handle(userMessage:) 派任务 → 等结果 → 拼装 真合成回复
- [ ] KanbanStore schema 加 assignee + conductor_task_id
- [ ] v0.19 12 模块注册为子 agent (assignee)
- [ ] ChatViewModel.send() 走 WenshuConductor
- [ ] 调度进度不进 ChatView (ChatMessage 流只有 user / wenshu / system)
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 发消息看文枢回复, 同时查 KanbanStore 看子任务 (未来 UI)

## 不动

- v0.19 12 模块 agent 实现 (只注册不重写)
- A2A protocol
- KanbanStore 7 状态 state machine (复用现有)

## 关联

- 依赖: ticket 02 + 03
- 被依赖: ticket 06 (ChatViewModel 集成 WenshuConductor)