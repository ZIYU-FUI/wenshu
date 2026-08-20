# Spec — 文枢 ChatView 单显多 agent 隐身 + 会话持久化 + 上下文不爆 (老板 2026-08-21 拍)

> Date: 2026-08-21
> 老板 2026-08-21 拍 "用户永远看到的只有一个会话, 看似唯一会话能延续继续聊, 多 agent 协作只显示文枢单一 agent, 其他由文枢调度, 通过看板给任务, 其他 agent 永远隐身".
> grill 第 1 轮 3 项决策: 1A 多 agent 复用 v0.19 12 模块 / 2A 看板复用 v0.18 KanbanStore / 3A 上下文 = 滑动窗口 + 持久化摘要.

## 业务语言 (老板懂)

- 用户打开 wenshu, 左下 zone 显示 ChatView
- 用户发消息 → 文枢 1 个 agent 回复 (UI 永远只看到文枢)
- 文枢背后可能调度 5-12 个 agent (v0.19 模块), 但 UI 不露 (隐身)
- 调度进度走看板 (KanbanStore, 不进 chat 流)
- 长聊累积不会让 LLM token 爆 (sliding window + summary)
- 关闭 app 再开, 上次聊的接续 (持久化)

## 真因链

### 1. 文枢回复不是真 LLM (当前 bug)

- `Sources/WenshuApp/Core/Agent/AgentProtocol.swift` L188-190 echo user message 前 50 字符当 agent 回复
- `Sources/WenshuApp/Views/Chat/ChatView.swift` L70 `runtime.delegateTask` 调 AgentProtocol.handle, 永远成功 (不抛), 永远拿到 echo, fallback `verifier.ping` 永不触发
- 老板看到的"回复" = echo 字符串, 不是 LLM 真回复

### 2. 会话不持久化 (当前 bug)

- `ChatViewModel.messages: [ChatMessage] = []` (L44) = 内存数组, 不写磁盘
- `init()` 不 load 历史
- 重启 app → `messages = []` → 空

### 3. 上下文无限累积 (潜在 bug)

- 没 sliding window
- 没 summary
- 长聊后喂 LLM 全部历史 → token 爆

### 4. 多 agent 隐身 UI (新需求)

- 当前 ChatMessage 只有 `.user / .agent / .system` 3 role, 没标 source
- 即使文枢调了 5 个 agent, UI 也只看到 1 条 `.agent` 回复, 但用户看不到这是哪个 agent 的合成
- 加 `source: .user / .wenshu / .system`, 文枢背后多 agent 协同结果不显 ChatMessage (走 KanbanStore 看板)

## 修法 (6 ticket, 1 ticket 1 commit)

### Ticket 01 — ChatMessage 加 source 字段 + ChatView 文枢单显

#### 业务语言
- 消息列表每条消息能区分是用户发的 / 文枢回的 / 系统报错
- 用户看不到多 agent 调度痕迹 (走 KanbanStore, 不进 chat 流)

#### 修法真值 (3 步)
1. `ChatMessage` 加 `source: ChatSource` 字段 (.user / .wenshu / .system), `Equatable` 同步加 source 比较
2. `ChatView` 渲染时按 source 标 ICON + 配色 (Apple HIG 标准, 用户能区分)
3. AgentProtocol.handle 调度结果不入 ChatMessage 流, 只入 KanbanStore

#### 不动
- ChatViewModel.send 主流程
- runtime.delegateTask 调通路径

### Ticket 02 — ChatSessionStore SQLite 持久化

#### 业务语言
- 关闭 app 再开, 上次聊的接续显示
- 上下文不丢

#### 修法真值 (4 步)
1. 新建 `Sources/WenshuApp/Core/Chat/ChatSessionStore.swift` (actor + SQLite, 跟 TodoStore / MemoryStore 范式一致)
2. SQLite schema:
   - `chat_messages(id TEXT PRIMARY KEY, session_id TEXT, source TEXT, content TEXT, timestamp REAL)`
   - `chat_summaries(session_id TEXT PRIMARY KEY, summary TEXT, updated_at REAL, last_message_id TEXT)`
3. `ChatViewModel.init()` 调 `store.loadMessages(session_id)` → fill messages
4. `ChatViewModel.send()` 后调 `store.append(message)` 异步写 SQLite

#### 不动
- ChatView UI
- runtime.delegateTask / AgentProtocol

### Ticket 03 — AgentProtocol.handle 改真合成 (删 echo)

#### 业务语言
- 文枢回复是真 LLM 答的 (不是 echo 占位)
- LLM 失败显 Error, 不显假回复

#### 修法真值 (3 步)
1. `AgentProtocol.handleMessageSend` 删 L188-190 echo 真值
2. 改成调 MiniMaxVerifier.send (真发 user message 给 MiniMax-M3, 拿 content 回写 AgentMessage.role=.agent)
3. LLM 失败 throw AgentRuntimeError.llmFailed, ChatViewModel 走到 fallback `verifier.ping` (已有路径)

#### 不动
- A2A protocol message/send / task/get / task/list 接口
- AgentRuntime.delegateTask 调用链

### Ticket 04 — 文枢主 agent 多模块调度 (KanbanStore 写任务)

#### 业务语言
- 文枢收到用户消息, 分析后可能派任务给 5-12 个 v0.19 模块 agent (LinkGraph / Search / Composer / Templates 等)
- 任务进度走看板 (KanbanStore), 用户能查
- 文枢等结果, 真合成最终回复

#### 修法真值 (4 步)
1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` 新建 (actor + AgentProcess 范式), 文枢主 agent 调度器
2. `WenshuConductor.handle(userMessage)` 分析意图 → 派 0-N 个 KanbanTask 给子 agent → 等结果 → 调 MiniMaxVerifier.send 拼装最终回复
3. KanbanStore schema 加 `assignee TEXT` (子 agent name) + `conductor_task_id TEXT` (回写关联)
4. 调度进度在 ChatView 不显 (隐身), 用户可查 KanbanStore.list() (未来 UI)

#### 不动
- v0.19 各模块 agent 实现 (LinkGraph / Search / ...)
- A2A protocol

### Ticket 05 — Sliding window + 持久化摘要 (上下文不爆)

#### 业务语言
- 长聊后 LLM 不会 token 爆
- 老的历史仍能被 LLM 引用 (通过 summary)

#### 修法真值 (4 步)
1. `ChatSessionStore` 加 `summarizeIfNeeded(sessionId, lastN: 10, threshold: 20)` (actor method)
2. 当 messages.count > 20 → 调 MiniMaxVerifier.send 拿前 20 条生成 summary → 写 chat_summaries 表 → 删老的原文
3. `ChatViewModel.buildContextForLLM()` 拼装: `summary + last 10 原文`
4. 喂 LLM 时走 `buildContextForLLM()` 而不是 `messages`, token 控制

#### 不动
- ChatView UI 渲染 (UI 仍看全部 messages)
- KanbanStore

### Ticket 06 — ChatViewModel 集成 + chat session 单例

#### 业务语言
- 用户体验 = 1 个永远延续的会话
- 跨 session 状态保持

#### 修法真值 (3 步)
1. `ChatViewModel` 加 `private let store: ChatSessionStore` + `private let sessionId: String = "default"` (单例)
2. `WenshuAppDelegate.sharedChatStore = ChatSessionStore()` (跟 sharedRuntime / sharedVerifier 同范式)
3. App.swift L554-561 ChatView init 传 store 进去

#### 不动
- v0.20 ticket 01 ChatView UI

## po main flow 6 步

1. ✅ grill-with-docs (3 项决策已拍: 1A + 2A + 3A)
2. ✅ to-spec (本文件)
3. → to-tickets (`.scratch/2026-08-21-chat-persistent-multi-agent/issues/01-06-*.md`)
4. → implement (1 ticket 1 commit, 老板拍streak模式)
5. → code-review (双轴 Standards + Spec, 全部 6 ticket commit 后跑一次)
6. → domain-modeling (CONTEXT.md 加 ChatSession / WenshuConductor / ChatSource / ConversationSummary 4 domain word)

## 验收标准 (老板 8/19 evening 拍 "工程管理你自行决策" + "不需要验收", streak 模式)

- 每个 ticket: `swift build` exit 0 + `swift test` exit 0
- 6 ticket 全 commit 后: 双轴 code-review 跑 (Standards + Spec sub-agent 并行)
- hard violation 修法聚合 commit
- 老板 macOS 真验: 重启 app 接续 chat + 文枢真回复 (不是 echo) + 长聊不爆 token

## 不动 (Q20 硬约束)

- v0.20 logo + 菜单栏 ticket (已 commit, 不动)
- v0.19 12 模块 agent 实现 (不复用不重写, 文枢调度 + 看板派任务即可)
- v0.18 hermes-replica 9 模块 (KanbanStore / MemoryStore / TodoStore 等已沉淀, 复用)
- AGENTS.md / CLAUDE.md (基线不动)
- macOS-only (不上 iOS / iPadOS / Catalyst)

## 关联 commit

- v0.20 ticket 01 (`cf121f77a`) — ChatView + Agent 对话左下 zone 接入 (基础, 不动)
- v0.20 ticket 04 (`a97719b92`) + 05 (`3c712b987`) — LOGO + .app bundle (无关, 不动)
- v0.19 ticket 12-23 — LinkGraph / Canvas / Graph / Templates / Composer / Search / Bases / QuickSwitcher / WordCount / Outline / Bookmarks / Verifier (被文枢调度, 不动)
- v0.18 ticket 01-09 — hermes-replica 9 模块 (复用, 不动)