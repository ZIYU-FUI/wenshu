# 05 — Replace the 2 placeholder strings in the chat bottom bar (Hermes source reference, 老板 2026-08-21 ruled)

**What to build:**
老板 8/21 macOS screenshot: the chat bottom bar has 2 placeholder strings:
1. Red box 1: "MiniMax-M3" → replace with the real Hermes model picker (`MiniMax M3 · Med` dropdown)
2. Red box 2: "0/20 ●○○○" → replace with the real Hermes context usage bar (`441.6k / 1M 44%`)

老板 8/21 ruled:
- "Model selection = associate providers; with multiple keys configured, auto-fetch the models usable by each key. MED is not implemented (med = analysis strength), MOA multi-model joint analysis is temporarily not needed."
- "Context usage + MED = look at the source code"

**Hermes source truth (apps/desktop/src/):**
- `context-usage-panel.tsx` — `UsageStats { context_max, context_used, context_percent }` + `ContextBreakdown { categories: [{id, label, color, tokens}] }`, displays `compactNumber(used) / compactNumber(max) percent%`
- `model-menu-panel.tsx` — `ModelOptionsResponse { providers: [{slug, name, models: [id], capabilities: {id: {fast, reasoning}}}] }`, displays the current model + reasoning effort meta
- `helpers.ts` — `providerGroup(envVarName)` returns the display name
- `models.py:3513` — `probe_api_models(api_key, base_url, timeout, api_mode)` — hermes_provider_catalog truth

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (3 steps, satisfying principles 1 + 4)

### Step 1: Extract `LLMProvider` enum + `LLMProviderDiscovery` actor (Hermes truth)
- `Sources/WenshuApp/Core/Agent/LLMProvider.swift`:
  - `enum LLMProvider: String, CaseIterable` — `minimax-cn`, `minimax`, `openrouter`, `anthropic`, `nous`
  - `var displayName: String` (= Hermes `providerGroup` truth)
  - `var keychainAccount: String` (= like `MINIMAX_CN_API_KEY`)
  - `var baseUrl: String`
  - `var apiMode: String` (= "anthropic_messages" / "chat_completions")
- `actor LLMProviderDiscovery`:
  - `func authenticatedProviders() async -> [LLMProvider]`: iterate `LLMProvider.allCases`; call `LLMKeychain.loadKey(account: provider.keychainAccount)`; non-empty = truth
  - `func modelIds(for provider: LLMProvider) async -> [String]`: call `MiniMaxModelFetcher.fetchLiveModelIds` + cache 1h

### Step 2: Extract `ContextUsageTracker` actor (Hermes truth)
- `Sources/WenshuApp/Core/Chat/ContextUsageTracker.swift`:
  - `actor ContextUsageTracker`:
    - `func update(contextTokens: Int, contextMax: Int)` — real value after 老板 sends a message
    - `func current() -> (used: Int, max: Int, percent: Int)`
    - `// Truth: wenshu does not have LLM API context_max feedback; 老板 8/21 ruled "look at source" → set as model truth: MiniMax-M3 = 128k context window`
    - `private var contextMax: Int = 131072` (= MiniMax-M3 128k truth)
- `func trackAfterSend(messages: [ChatMessage])` — estimate tokens of the latest N messages (4 chars/token heuristic), call update

### Step 3: Replace the 2 placeholders in the ChatView bottom bar
- `ChatView.swift` find the bottom bar L201-L235 (around the input field):
  - Left "MiniMax-M3" placeholder → `ModelPickerMenu` (dropdown):
    - `Menu("MiniMax M3") { ForEach(authenticatedProviders) { provider in Provider submenu { ForEach(modelIds) { model in Button(model) { selectModel(provider, model) } } } } }`
    - Don't display the current selection (= 老板 8/21 ruled "hide display after configuration" → dropdown-label mode, configured = no model name shown)
    - Reasoning effort not implemented (老板 8/21 ruled "MED not implemented")
  - Right "0/20 ●○○○" placeholder → `ContextUsageBar`:
    - `ProgressView(value: Double(percent) / 100)` with `ProgressViewStyle.linear`
    - Right-side label: `compactNumber(used) / compactNumber(max)` format
    - `compactNumber`: 1k → "1.0k", 1.5M → "1.5M" (Hermes `format_token_count_compact` truth)

### Domain-modeling (Step 6)
- Add to `CONTEXT.md`:
  - `LLMProvider` (new domain word)
  - `LLMProviderDiscovery` (Hermes truth)
  - `ContextUsageTracker` (Hermes truth)
  - `compactNumber` (Hermes `format_token_count_compact` truth)

## Acceptance

- [ ] `LLMProvider` enum + `LLMProviderDiscovery` actor (Hermes truth)
- [ ] `ContextUsageTracker` actor (estimates the latest N message tokens at 4 chars/token)
- [ ] `ChatView` bottom bar left = `ModelPickerMenu` dropdown (Hermes truth)
- [ ] `ChatView` bottom bar right = `ContextUsageBar` progress (Hermes truth)
- [ ] After `ChatView` actually invokes the LLM, context usage updates live
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: chat bottom bar's 2 placeholder strings = `ModelPickerMenu` + `ContextUsageBar` (Hermes paradigm)

## Out of scope (Q20 hard constraint)

- v0.20 LOGO + menubar (untouched)
- v0.21 chat-streak tickets 02-06 (untouched)
- `LLMKeychain` (commit `143ff4845` already passed)
- `MiniMaxModelFetcher` (commit `e45fac768` already passed)
- Settings > Model tab Picker (commit `e45fac768` already passed, kept)
- `AppIcon.icon/` (kept as-is)

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/swiftui/progressview
- https://developer.apple.com/documentation/foundation/formatstyle
- hermes apps/desktop/src/app/shell/context-usage-panel.tsx
- hermes apps/desktop/src/app/shell/model-menu-panel.tsx
- hermes hermes_cli/models.py probe_api_models
- hermes hermes_cli/provider_catalog.py

## References

- Depends on: none (`LLMKeychain` + `MiniMaxModelFetcher` already committed)
- Required by: none
