# 39 — MiniMax M2.7 chat error 真因 (DecodingError "数据丢失")

**What to build:**
修复切到 MiniMax M2.7 发问报 `Error: 未完成操作。(WenshuApp.MiniMaxError 错误 2。) Error: 未能读取数据，因为数据丢失。`

**Spec 真值 (Q63 verify-before-claim, 必须先做):**

Step 1 — NSLog trace 真值 (commit 1, trace line 不动业务):
- `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` send() 加 3 行 NSLog:
  - `[wenshu.chat] request: model=<m> max_tokens=<n> messages=<count>`  发出前
  - `[wenshu.chat] response status: <code> body: <truncated utf8 500 char>`  收到后
  - `[wenshu.chat] decoder error: <error>` 在 try decoder.decode 抛错时 catch 打印
- 跑真 .app, 切到 MiniMax M2.7, 发问 "你在用的什么模型", 抓 stderr 真值
- trace line Q49 audit gate pass (英文 + 唯一称谓 = 老板)

Step 2 — 修复 (commit 2, Q57 ticket chain):
- 根据 NSLog 真值决定修法方向 (Q34 第 2 轮 grill 拍板):
  - 候选 A: MiniMaxResponse 加可空字段 + 多 content block 支持 (content: [MiniMaxBlock] union text/thinking/tool_use) — 最稳
  - 候选 B: decoder 改 permissive (JSONSerialization 手动 parse, 容错所有未知字段) — 中稳
  - 候选 C: M2.7 临时 fallback 走 M3, 不真用 — 不优雅, 不推荐
- ChatViewModel.send 兜底 try catch DecodingError → 显"模型 <m> 返回数据格式不支持"中文错误 (Q36 ChatMessage.source = .error)

Step 3 — domain-modeling (commit 3, Q57):
- CONTEXT.md 加 MiniMaxResponseShape domain word
- 真因 chain + fix 范式 + 未来 model 协议扩展方式

**不动 (Q20):**
- Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift init / Keychain 真值范式 (Q43)
- Sources/WenshuApp/Core/Agent/WenshuConductor.swift handle model 参数 (ticket 38)
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatViewModel.send currentModel pass (ticket 38)
- ticket 34 + 35a + 35b + 36 + 37 + 38 已 commit chain 不动

**依赖:**
- ticket 38 (model switching actually wired) — 已 commit, 复用
- ticket 34 (real tokens) — 已 commit, 复用
- ticket 35b (推理强度 picker) — wire 不在本 ticket 范围 (ticket 35c outstanding)

**Q47 + Q51 + Q20 + Q63 锁定:**
- Q47 锁定实现方式 = Swift Codable + Apple URLSession, 不切实现
- Q51 父组件不动 = MiniMaxVerifier.swift + WenshuConductor.swift + ChatViewModel 不动主结构
- Q20 不动 = ticket 38 model switching wire + ProviderKeychain Keychain 范式不动
- Q63 verify-before-claim = impl 前必须 NSLog 真验, 不靠推测修复

**Apple HIG 真值引用:**
- https://developer.apple.com/documentation/foundation/jsondecoder
- https://developer.apple.com/documentation/foundation/codable
- minimax cn /anthropic /v1/messages API doc (Anthropic compatible)

**关联:**
- history: ticket 38 fix(wenshu): v0.21 ticket 38 model switching actually wired
- history: ticket 34 fix(wenshu): v0.21 ticket 34 context usage real tokens from LLM API
- backlog 19 done commit `35ff3b4ab docs(wenshu): v0.21 backlog 18 + 19 done`
- branch: feature/agentan-bottom-toolbar-in-child (Q53 ticket 10 起, 续)