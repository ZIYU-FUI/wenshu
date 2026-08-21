# 41 — Chat zone 自动滚动 (AI reply 后滚到底部)

**What to build:**
修复 AI reply 后聊天窗口不自动滚动问题. 用户发问 + AI reply 两条消息后, 老板需手动滚动才能看到 AI reply 内容.

**Boss feedback verbatim (2026-08-22 17:00):**
- "AI 回复后，聊天窗口没有自动滚动，导致最新的消息需要手动滑到底才能看到"

**当前代码真值 (Q63 verify-before-claim, Sources/WenshuApp/Views/Chat/ChatView.swift L223-241):**
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(vm.messages) { msg in
                ChatMessageView(message: msg)
                    .id(msg.id)
            }
        }
        .padding(8)
    }
    .onChange(of: vm.messages.count) { _, _ in
        if let last = vm.messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
```

**Q63 真因推测 (代码层面 + Q44 swiftinterface 验, 需 NSLog 锁):**

根因 chain (4 个候选真因, 优先级排序):

1. **count-based onChange 监听不到 placeholder → reply 替换** (最可能)
   - ChatViewModel.send() L120 创建 placeholderId, L159 placeholder 替换为真 reply 时**复用同一 placeholderId UUID**
   - `vm.messages.count` 没变 (placeholder 被替换, 不是 append 新消息)
   - onChange 不触发 → scrollTo 不跑
   - 老板看到 reply 出现在原 placeholder 位置但**滚动条停留** = 手动滑才能看到完整 reply

2. **withAnimation 包裹 scrollTo 在某些 SwiftUI macOS 27 场景不响应**
   - SwiftUI ScrollViewReader.scrollTo 在 animation context 内有 timing race condition
   - 修复时新消息刚出现, animation 还没结束 scrollTo 被 ignore

3. **anchor: .bottom 在 LazyVStack + 长 reply 内容下不精确滚到底**
   - 老板 AI reply 经常含 thinking DisclosureGroup 展开后高度变化
   - anchor: .bottom 滚到原 placeholder 底部 (短文本), 不是新 reply 底部

4. **Apple SwiftUI ScrollView 默认行为 = 滚到顶, 不是自动跟踪内容底部**
   - ScrollView 没有 defaultScrollAnchor 时, 内容追加时不会自动贴底

**Q44 swiftinterface 真验 (本会话已跑, 真值):**
- `ScrollView.defaultScrollAnchor(_ anchor: UnitPoint?)` 真存在 ✅ (Apple SwiftUI macOS 14+)
- `ScrollView.defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole)` overload 真存在 ✅
- 不猜 API (Q38 + Q44 硬约束)

**Spec 真值 (Q34 第 2 轮 grill 拍板, 候选 D + A 双保险):**

Fix 1 — `.defaultScrollAnchor(.bottom)` (候选 D, Apple SwiftUI 14+ 标准真值):
- `ScrollView` 加 `.defaultScrollAnchor(.bottom)` modifier
- Apple 真值 = ScrollView 内容变化时自动贴底, 不依赖 scrollTo
- 解决真因 4 (默认滚到顶问题) + 兜底真因 1 (count 不变时)

Fix 2 — `onChange` 监听 `messages.last?.id` 而不仅是 count (候选 A):
- 替换 `onChange(of: vm.messages.count)` → `onChange(of: vm.messages.last?.id)`
- placeholder → reply 替换时 placeholderId 复用 → onChange 不触发
- 修复: 替换 placeholder 时用新 UUID (让 count 增加) OR 监听 last content变化
- 选监听 last?.id 因为跟当前 scrollTo 用 last.id 一致

Fix 3 — 修复 trace line (Q63 verify-before-claim, commit 1):
- ChatViewModel.send() L120 placeholder 替换时 NSLog:
  - `[wenshu.scroll] placeholder replace: id=<id> beforeCount=N afterCount=N`
- ChatView onChange 触发时 NSLog:
  - `[wenshu.scroll] onChange trigger: lastId=<id> lastContentLen=N`

**Step 1 — NSLog trace 真值 (commit 1, Q63 verify-before-claim):**
- 加 trace line 不动业务
- 跑真 .app, 发问, 抓 stderr 真值:
  - onChange 触发次数 (= 老板发问 + AI reply 总次数)
  - placeholder 替换前后 count 是否变化
  - lastId 在 placeholder → reply 时是否变化
- 验证真因 1 (count 不变) 真假

**Step 2 — 修复 (commit 2):**
- ChatView ScrollView 加 `.defaultScrollAnchor(.bottom)` modifier (Fix 1)
- ChatView onChange 改 `onChange(of: vm.messages.last?.id)` (Fix 2)
- 移除 `withAnimation { proxy.scrollTo(...) }` 包裹 (Apple SwiftUI 14+ defaultScrollAnchor 自动处理 animation, 不需要手动)
- Q47 锁定: Apple SwiftUI 标准 modifier, 不切 framework
- Q51 父组件不动: ChatViewModel.send() body / placeholder 替换逻辑不动
- Q20 不动: ticket 38 wire / ticket 39 union decode / ticket 40 binding 不动

**Step 3 — domain-modeling (commit 3, Q57):**
- CONTEXT.md 加 ChatZoneAutoScroll domain word
- 真因 chain + fix 范式 + Apple SwiftUI defaultScrollAnchor 真值
- 未来 SwiftUI 滚动问题的标准修法 (新 SwiftUI 14+ 项目 defaultScrollAnchor 必备)

**不动 (Q20):**
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatViewModel 任何字段
- Sources/WenshuApp/Views/Chat/ChatView.swift send() body (placeholder 替换逻辑)
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatMessageView (Q47 锁定子组件)
- ticket 38 wire + ticket 39 union decode + ticket 40 binding
- Sources/WenshuApp/App.swift ChatZoneView (Q51 父组件不动)

**依赖:**
- ticket 40 (context usage UI binding) — 已 commit, ChatZoneView 持有 vm 实例共享
- ticket 30 (AI 状态指示器 placeholder) — 已 commit, placeholder 复用 placeholderId UUID
- ticket 39 (union decode + thinking footnote) — 已 commit, reply 内容可能含 thinking DisclosureGroup

**Q47 + Q51 + Q20 + Q44 + Q63 + Q37 锁定:**
- Q47 锁定实现方式 = Apple SwiftUI ScrollView.defaultScrollAnchor + onChange modifier, 不切 framework
- Q51 父组件不动 = ChatView body 结构 VStack 不动, 只动 ScrollView modifier
- Q20 不动 = ChatViewModel / ChatMessageView / ChatZoneView 不动
- Q44 swiftinterface 真验已跑 = defaultScrollAnchor API 真存在
- Q63 verify-before-claim = impl 前必须 NSLog 真验 4 真因, 不靠推测修复
- Q37 双轴 review = impl commit 后跑 2 sub-agent (Standards + Spec) 并行 review, hard violation 修法 verbatim 引用进 fix commit

**Apple HIG 真值引用:**
- https://developer.apple.com/documentation/swiftui/scrollview/defaultscrollanchor(_:)
- https://developer.apple.com/documentation/swiftui/scrollanchorrole
- https://developer.apple.com/documentation/swiftui/scrollviewreader

**关联:**
- history: ticket 40 fix(wenshu): v0.21 ticket 40 step 2 ChatZoneView 读 vm.contextUsed
- history: ticket 39 fix(wenshu): v0.21 ticket 39 step 2 MiniMaxBlock union decode + thinking footnote
- history: ticket 30 fix(wenshu): v0.21 ticket 30 AI 状态指示器修复到消息列表 (placeholder 复用 UUID)
- branch: feature/agentan-bottom-toolbar-in-child (Q53 ticket 10 起, 续)