# 06 — ChatViewModel 集成 + chat session 单例

**What to build:**
老板 2026-08-21 拍 "用户永远看到的只有一个会话". ChatViewModel 集成 ChatSessionStore + WenshuConductor, 单 session_id = "default" 永远延续. App.swift 装入 sharedChatStore + sharedConductor singleton, ChatView init 传进去.

**Blocked by:** ticket 01 + 02 + 03 + 04 + 05.

**Status:** ready-for-agent

## 修法真值

1. `Sources/WenshuApp/App.swift` WenshuAppDelegate 加:
   ```swift
   static let sharedChatStore = ChatSessionStore()
   static let sharedConductor: WenshuConductor
   ```
   `applicationDidFinishLaunching` 初始化 sharedConductor (传 sharedRuntime + sharedVerifier + sharedChatStore + kanbanStore).
2. `ChatViewModel.init` 加参数 `store: ChatSessionStore`, `conductor: WenshuConductor`, `sessionId: String = "default"`.
3. `ChatViewModel.init` 调 `Task { await store.loadMessages(sessionId) }` → fill `messages` 数组.
4. `ChatViewModel.send()` 改:
   - 调 conductor.handle(userMessage, sessionId) (不直接 delegateTask)
   - 拿 final reply → append ChatMessage(source: .wenshu, ...)
   - 持久化: `store.append(userMsg)` + `store.append(agentMsg)` 异步写
   - 调 `store.summarizeIfNeeded(sessionId)` 异步触发
5. App.swift L554-561 ChatView init 传 store + conductor:
   ```swift
   ChatView(
     store: WenshuAppDelegate.sharedChatStore,
     conductor: WenshuAppDelegate.sharedConductor
   )
   ```
6. 删 ChatViewModel 旧字段 `runtime` / `verifier` / `agentName` (conductor 包装).

## Acceptance

- [ ] WenshuAppDelegate.sharedChatStore + sharedConductor 落地
- [ ] ChatViewModel 集成 store + conductor
- [ ] ChatViewModel.init 异步 load 历史
- [ ] ChatViewModel.send 走 conductor + 异步持久化
- [ ] App.swift ChatView init 传 store + conductor
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 重启 app 接续 chat + 文枢真回复 + 长聊不爆 token + 多 agent 隐身

## 不动

- ChatView UI (cf121f77a 已 commit, 只改 init 签名)
- v0.18 + v0.19 + v0.20 已 commit 模块

## 关联

- 依赖: ticket 01 + 02 + 03 + 04 + 05
- 被依赖: 无 (收尾 ticket)