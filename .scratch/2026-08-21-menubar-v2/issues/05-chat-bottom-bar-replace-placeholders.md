# 05 — 聊天底栏两个占位文字替换 (Hermes 源码参考, 老板 2026-08-21 拍)

**What to build:**
老板 8/21 macOS 截屏: 聊天底栏有 2 个占位文字:
1. 红框 1: "MiniMax-M3" → 替换为 Hermes 真值 model picker (MiniMax M3 · Med dropdown)
2. 红框 2: "0/20 ●○○○" → 替换为 Hermes 真值 context usage bar (441.6k / 1M 44%)

老板 8/21 拍:
- "模型选择 = 关联提供方, 配了多个 key 自动获 key 可以用的模型, MED 不实现 (med = 分析强度), MOA 多模型联合分析暂时用不到"
- "上下文用量 + MED 查源码"

**Hermes 源码真值 (apps/desktop/src/):**
- `context-usage-panel.tsx` — `UsageStats { context_max, context_used, context_percent }` + `ContextBreakdown { categories: [{id, label, color, tokens}] }`, 显示 `compactNumber(used) / compactNumber(max) percent%`
- `model-menu-panel.tsx` — `ModelOptionsResponse { providers: [{slug, name, models: [id], capabilities: {id: {fast, reasoning}}}] }`, 显示当前 model + reasoning effort meta
- `helpers.ts` — `providerGroup(envVarName)` 返回 display name
- `models.py:3513` — `probe_api_models(api_key, base_url, timeout, api_mode)` — hermes_provider_catalog 真值

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则 1 + 4 满足)

### Step 1: 抽 `LLMProvider` enum + `LLMProviderDiscovery` actor (Hermes 真值)
- `Sources/WenshuApp/Core/Agent/LLMProvider.swift`:
  - `enum LLMProvider: String, CaseIterable` — `minimax-cn`, `minimax`, `openrouter`, `anthropic`, `nous`
  - `var displayName: String` (= Hermes `providerGroup` 真值)
  - `var keychainAccount: String` (= 类似 `MINIMAX_CN_API_KEY`)
  - `var baseUrl: String`
  - `var apiMode: String` (= "anthropic_messages" / "chat_completions")
- `actor LLMProviderDiscovery`:
  - `func authenticatedProviders() async -> [LLMProvider]`: 遍历 `LLMProvider.allCases`, 调 `LLMKeychain.loadKey(account: provider.keychainAccount)`, 非空 = 真值
  - `func modelIds(for provider: LLMProvider) async -> [String]`: 调 `MiniMaxModelFetcher.fetchLiveModelIds` + 缓存 1h

### Step 2: 抽 `ContextUsageTracker` actor (Hermes 真值)
- `Sources/WenshuApp/Core/Chat/ContextUsageTracker.swift`:
  - `actor ContextUsageTracker`:
    - `func update(contextTokens: Int, contextMax: Int)` — 老板发消息后真值
    - `func current() -> (used: Int, max: Int, percent: Int)`
    - `// 真值真值 wenshu 没有 LLM API context_max 反馈, 老板 8/21 拍 "查源码" → 设为 model 真值: MiniMax-M3 = 128k context window
    - `private var contextMax: Int = 131072` (= MiniMax-M3 128k 真值)
- `func trackAfterSend(messages: [ChatMessage])` — 算最近 N 条 msg token 估算 (4 chars/token 真值估算), 调 update

### Step 3: ChatView 底栏替代 2 个占位
- `ChatView.swift` 找底栏 L201-L235 (输入框上下相关):
  - 左侧 "MiniMax-M3" 占位 → `ModelPickerMenu` (下拉):
    - `Menu("MiniMax M3") { ForEach(authenticatedProviders) { provider in Provider submenu { ForEach(modelIds) { model in Button(model) { selectModel(provider, model) } } } } }
    - 当前 selection 不显 (= 老板 8/21 拍 "配完省略显示" → 显示 dropdown label 模式, 配完不显 model 名)
    - Reasoning effort 不实现 (老板 8/21 拍 "MED 不实现")
  - 右侧 "0/20 ●○○○" 占位 → `ContextUsageBar`:
    - `ProgressView(value: Double(percent) / 100)` style ProgressViewStyle.linear
    - 右 label: `compactNumber(used) / compactNumber(max)` 格式
    - `compactNumber`: 1k → "1.0k", 1.5M → "1.5M" (Hermes `format_token_count_compact` 真值)

### Domain-modeling (Step 6)
- 加 `CONTEXT.md`:
  - `LLMProvider` (新 domain word)
  - `LLMProviderDiscovery` (Hermes 真值)
  - `ContextUsageTracker` (Hermes 真值)
  - `compactNumber` (Hermes `format_token_count_compact` 真值)

## Acceptance

- [ ] LLMProvider enum + LLMProviderDiscovery actor (Hermes 真值)
- [ ] ContextUsageTracker actor (估算最近 N 条 msg token 4 chars/token)
- [ ] ChatView 底栏左侧 = ModelPickerMenu 下拉 (Hermes 真值)
- [ ] ChatView 底栏右侧 = ContextUsageBar progress (Hermes 真值)
- [ ] ChatView 真实 LLM 调通后, context usage 实时更新
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 聊天底栏 2 个占位文字 = ModelPickerMenu + ContextUsageBar (Hermes 范式)

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏 (不动)
- v0.21 chat-streak ticket 02-06 (不动)
- LLMKeychain (commit 143ff4845 已过)
- MiniMaxModelFetcher (commit e45fac768 已过)
- Settings > 模型 tab Picker (commit e45fac768 已过, 保留用)
- AppIcon.icon/ (留底)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/swiftui/progressview
- https://developer.apple.com/documentation/foundation/formatstyle
- hermes apps/desktop/src/app/shell/context-usage-panel.tsx
- hermes apps/desktop/src/app/shell/model-menu-panel.tsx
- hermes hermes_cli/models.py probe_api_models
- hermes hermes_cli/provider_catalog.py

## 关联

- 依赖: 无 (LLMKeychain + MiniMaxModelFetcher 已 commit)
- 被依赖: 无
