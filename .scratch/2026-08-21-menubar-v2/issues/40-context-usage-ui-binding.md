# 40 — 上下文用量 UI 真接通 LLM API usage (chat zone 底栏红框2)

**What to build:**
修复 chat zone 底栏右 context usage UI 显示永远 = 0 / 131.1k 的 bug.
当前 UI Text 显示 ChatZoneView 自己的 `@State contextUsed: Int = 0` (独立 state),
但 ChatViewModel.recomputeContextUsed() 累加 ChatMessage.tokens 改的是 ChatViewModel.contextUsed
— 两条状态链断开, 老板 UI 看到永远 = 0.

**Boss feedback verbatim (2026-08-22 16:10):**
- "切换发问已经通过" (= ticket 39 真值 done)
- "但是右边的那个上下文用量实现了吗" (= context usage UI 没接通)

**NSLog 真值 (Q63 verify-before-claim):**
- `[wenshu.chat] response status=200 body=...usage:{"input_tokens":41,"output_tokens":30,...}`
- replyTokens = 71 写进 ChatMessage.tokens ✅
- ChatViewModel.recomputeContextUsed() = 71 ✅
- ChatZoneView.@State contextUsed = 0 ❌ (不绑 ChatViewModel.contextUsed)

**根因 (Q3 audit gate honest disclosure):**
- ChatZoneView (App.swift L1117) `@State private var contextUsed: Int = 0` 独立 state
- ChatViewModel.contextUsed 是 Observable property
- 两条 state 没有任何 binding / bridge
- Q47 SwiftUI @Observable 范式要求 Observable property 自动 propagate,
  但 ChatZoneView 不持有 ChatViewModel 实例 = 拿不到更新

**Spec 真值 (Q34 第 1 轮 grill 拍板):**

Step 1 — NSLog trace (commit 1, Q63 verify-before-claim):
- `[wenshu.context] sum tokens after send: N` (ChatViewModel.recomputeContextUsed() 后 print)
- `[wenshu.context] ChatZoneView.@State contextUsed: N` (ChatZoneView.onAppear + onChange(of: vm.messages.count) print)
- 跑真 .app 发问, 抓 stderr 真值, 确认 ChatViewModel.contextUsed 累加 ✅, ChatZoneView.@State 永不变 ❌

Step 2 — 修复 (Q57 ticket chain, 单 commit):
- ChatZoneView 持有自己的 ChatViewModel 实例 (@State private var vm = ChatViewModel(...))
- ChatView init 加 overload: `init(conductor:store:sessionId:vm: ChatViewModel? = nil)` — 如果传 vm 就用
- ChatZoneView 把自己的 vm 实例传给 ChatView (共享 Observable 实例)
- ChatZoneView bottom toolbar 改读 `vm.contextUsed` (Apple @Observable 自动 propagate, 不再独立 @State contextUsed)
- contextMax = ChatViewModel.contextMax (vm.contextMax, 不再写死 131072)
- Q20 不动: ChatViewModel.send() body / .recomputeContextUsed() 实现 / ticket 38 wire
- Q51 父组件不动: ZoneModule .aiChat case body 不动, ChatZoneView body 结构 VStack { ChatView; toolbar } 不动
- Q47 锁定: SwiftUI @Observable + Apple @State + Observable 实例共享, 不切 framework

Step 3 — domain-modeling (commit 2, Q57):
- CONTEXT.md 加 ChatZoneContextBinding domain word
- 真因 chain + fix 范式 + Q51 子组件 override 修法 (vm 注入共享)

**不动 (Q20):**
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatViewModel.send() / .recomputeContextUsed() 实现 (ticket 38 wire 不动)
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatView body 结构 (Q47 锁定)
- Sources/WenshuApp/Core/Agent/WenshuConductor.swift handle 真值 (ticket 38)
- Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift send 真值 (ticket 39 union decode)
- ticket 34 + 35a + 35b + 36 + 37 + 38 已 commit chain 不动

**依赖:**
- ticket 34 (real tokens from LLM API) — 已 commit, 复用
- ticket 38 (model switching wire) — 已 commit, 复用 ChatViewModel.send 真调
- ticket 39 (union decode + thinking footnote) — 已 commit, ChatMessage.tokens 真值路径

**Q47 + Q51 + Q20 + Q63 锁定:**
- Q47 锁定实现方式 = SwiftUI @Observable 实例共享 + @State 持有 + Apple @Environment 不引
- Q51 父组件不动 = ZoneModule .aiChat case body + ChatZoneView VStack 结构不动
- Q20 不动 = ChatViewModel.send() body + ChatView body + ticket 38 wire 不动
- Q63 verify-before-claim = impl 前必须 NSLog 真验, 不靠推测修复

**Apple HIG 真值引用:**
- https://developer.apple.com/documentation/swiftui/state
- https://developer.apple.com/documentation/swiftui/observable
- Apple SwiftUI Observable 实例共享 范式 (跟 Pages / Numbers 同)

**关联:**
- history: ticket 39 fix(wenshu): v0.21 ticket 39 step 2 MiniMaxBlock union decode + thinking footnote
- history: ticket 38 fix(wenshu): v0.21 ticket 38 model switching actually wired
- history: ticket 34 fix(wenshu): v0.21 ticket 34 context usage real tokens from LLM API
- branch: feature/agentan-bottom-toolbar-in-child (Q53 ticket 10 起, 续)