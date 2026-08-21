# 43 — 聊天区顶栏 tab 真切换 (backlog 20) + picker ↔ UserDefaults 同步 (out-of-scope #5)

**What to build:**
2 修复 streak (Q38 streak模式 老板 8/22 拍 "工程管理自行决策" + Q54 全推荐):

A. **backlog 20 聊天区顶栏 tab 真切换功能** (老板 2026-08-22 06:22 拍 backlog 阶段):
- 当前真值: ChatZoneView ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"]) 3 个 SF Symbol 占位, 点无响应
- 老板原话: "实现真正的 teb 切换功能" (老板拼了 tab = = "teb")
- 老板原话: "第一个用机器人, 第二个第三个保留现在的这个, 先放着, 后面实现对应的两个视图的功能"
- 修复: ChatZoneView 加 ChatZoneTab enum + @State selectedTab + 点击 tab 触发 selectedTab 切换 + body switch 视图

B. **picker ↔ UserDefaults 同步修复** (修复聊天链路时发现的 out-of-scope bug, ticket 38 commit 修复后):
- 当前真值: ChatZoneView Menu Button action 写 UserDefaults.standard.set(entry.id, forKey: "wenshu.llm.model"), 但 ChatViewModel.currentModel 是 UserDefaults.standard.string(forKey:) 读 init default. 两个 state 链没绑 = 切 picker 后 ChatViewModel.currentModel 可能 stale (老板截图 ticket 39 时发现)
- 老板拍法 (Q54 决定): 改用 @AppStorage("wenshu.llm.model") (Apple SwiftUI 真值, 源单一 UserDefaults, 自动响应)

**Boss feedback verbatim:**
- backlog 20: "实现真正的 teb 切换功能, 聊天区, 顶栏的 ICON, 第一个用机器人, 第二个第三个, 可以保留现在的这个, 先放着, 后面实现对应的两个视图的功能, 先记需求, 一会排期实现"
- picker sync: 老板 2026-08-22 17:55 拍 "工程管理我不懂, 你来决定" → Q38 streak模式 + agent 拍板

**Q63 verify-before-claim 当前真值 (代码层面锁):**

```swift
// Sources/WenshuApp/App.swift L1028
ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])

// Sources/WenshuApp/App.swift L1119-1138 (ChatZoneView Menu)
Menu {
    ForEach(ModelDisplay.curated(availableModels), id: \.self) { entry in
        Button(entry.display) {
            currentModel = entry.id
            UserDefaults.standard.set(entry.id, forKey: "wenshu.llm.model")
        }
    }
} label: { ... }
.menuStyle(.button)
.buttonStyle(.plain)
```

```swift
// Sources/WenshuApp/Views/Chat/ChatView.swift L75
public var currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? MiniMaxModel.m3.rawValue

// L131
let currentModel: String = UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? "MiniMax-M3"
```

**真因**:
1. ChatZoneView Menu 写 UserDefaults → 但 ChatZoneView currentModel 是 @State (不绑 UserDefaults)
2. ChatViewModel.currentModel 读 UserDefaults 拿 init default → 但不响应 UserDefaults 变化 (只读一次)
3. ChatViewModel.send() 重新读 UserDefaults (L131) → 但 UserDefaults 写跟 ChatViewModel.currentModel 不同步
4. 修复: ChatZoneView.currentModel + ChatViewModel.currentModel + UserDefaults 三方不同步, 切 picker 后发问走老 model

**Spec 真值 (Q34 第 1 轮 grill 拍板, Q62 + Q54 + Q61 全推荐):**

Step 1 — NSLog trace 真值 (commit 1, Q63 verify-before-claim):
- ChatZoneView body 加 `[wenshu.tab] selectedTab: <tab> onAppear: <tab>` trace
- ChatViewModel.send() 加 `[wenshu.model] effective model: <id> source: UserDefaults|ChatVM` trace
- 跑真 .app 切 picker, 发问, 抓 stderr 真值: 锁当前 model 不一致真因

Step 2 — 修复 A: tab 真切换 (commit 2, 老板拍 A 选项):
- 新建 ChatZoneTab enum (Apple SwiftUI 真值): `.chat` / `.search` / `.settings` (3 case, 第 2/3 stub)
- ChatZoneView 加 @State selectedTab: ChatZoneTab
- ZoneTopToolbar 改 API: 接受 selectedTab binding + onSelect callback (Apple HIG 真值)
- ZoneTopToolbar body: HStack 中每个 icon 用 Button(.plain) + contentShape(Rectangle()) (ticket 17 + 21 已修复范式)
- selected icon 加 .foregroundStyle(.accentColor) (老板视觉: 选中态 = accent 颜色)
- ChatZoneView body 加 switch selectedTab: { case .chat: ChatView; case .search: stub "开发中"; case .settings: stub "开发中" }
- 第 1 个 icon: book.closed → person.crop.circle.badge.questionmark (老板拍 "用机器人" = robot face, ticket 30 + 33 已修复)

Step 3 — 修复 B: picker ↔ UserDefaults 同步修复 (commit 3, agent 拍板 Q54):
- ChatZoneView Menu Picker 改用 @AppStorage("wenshu.llm.model") var currentModel: String (Apple SwiftUI 真值)
- @AppStorage 自动响应 UserDefaults 变化 (源单一, 双向同步)
- ChatViewModel.currentModel 改 init default: UserDefaults.standard.string(forKey: "wenshu.llm.model") ?? MiniMaxModel.m3.rawValue (已修复 ticket 38, 不动)
- ChatViewModel.send() L131 不动 (UserDefaults.standard.string 读, 每次 send 都重新读, 保证真值)
- Q20 不动: ChatViewModel.send() body / ticket 38 wire / ticket 39 union decode / ticket 40 binding / ticket 41 auto scroll / ticket 42 去外壳

Step 4 — domain-modeling (commit 4, Q57):
- CONTEXT.md 加 ChatZoneTabSwitching domain word
- 真因 chain + fix 范式 + Apple SwiftUI @AppStorage 真值 + ChatZoneView tab 范式
- 未来 SwiftUI 多 tab view 标准修法

**不动 (Q20):**
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatViewModel.send() body
- Sources/WenshuApp/Views/Chat/ChatView.swift ChatView body VStack 结构 (Q51 父组件不动)
- Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift send 真值 (ticket 39 union decode)
- Sources/WenshuApp/Core/Agent/WenshuConductor.swift handle model param (ticket 38 wire)
- ticket 38 + 39 + 40 + 41 + 42 已 commit chain 不动
- ZoneTopToolbar toolbarHeight 30 PT 不动 (Q20 ticket 008)
- ZoneTopToolbar 占位文字 "占位文字" 不动 (Q20 ticket 008)

**依赖:**
- ticket 17 (providerApiTab 整条热区响应 Button(.plain) + contentShape) — 已 commit, 复用
- ticket 30 + 33 (robot face SF Symbol person.crop.circle.badge.questionmark) — 已 commit, 复用
- ticket 38 (model switching wire) — 已 commit, 复用 UserDefaults 读路径
- ticket 42 (model picker 去外壳) — 已 commit, 复用 Menu Button (.plain) 范式

**Q47 + Q51 + Q20 + Q63 锁定:**
- Q47 锁定实现方式 = SwiftUI @State + @Observable + @AppStorage (Apple SwiftUI 真值) + Button(.plain) + contentShape (Q58.3) + Apple 默认动画 .animation(.default, value:) (Q58.4) 不切 framework
- Q51 父组件不动 = ChatZoneView VStack { ChatView; toolbar } 结构 + ZoneTopToolbar height 30 PT + ZoneModule .aiChat case body
- Q20 不动 = ChatViewModel.send() / ticket 38 wire / ticket 39 union decode / ticket 40 binding / ticket 41 auto scroll / ticket 42 去外壳 / ChatView body
- Q63 verify-before-claim = impl 前必须 NSLog 真验 (Step 1), 不靠推测修复

**Apple HIG 真值引用:**
- https://developer.apple.com/documentation/swiftui/appstorage
- https://developer.apple.com/documentation/swiftui/state
- https://developer.apple.com/documentation/swiftui/button/init(_:action:label:)
- https://developer.apple.com/documentation/swiftui/view/contentshape(_:eoofill:)
- https://developer.apple.com/documentation/swiftui/view/animation(_:value:) (Q58.4 Apple 默认动画)

**关联:**
- history: ticket 42 fix(wenshu): v0.21 ticket 42 model picker 去外壳
- history: ticket 41 fix(wenshu): v0.21 ticket 41 step 2 ChatView .defaultScrollAnchor + content-based onChange
- history: ticket 40 fix(wenshu): v0.21 ticket 40 step 2 ChatZoneView 读 vm.contextUsed
- history: ticket 38 fix(wenshu): v0.21 ticket 38 model switching actually wired
- history: ticket 30 fix(wenshu): v0.21 ticket 30 AI 状态指示器修复到消息列表 + 小机器人 ICON
- branch: feature/agentan-bottom-toolbar-in-child (Q53 ticket 10 起, 续)