# Spec — Replace the 2 placeholder strings in the chat bottom bar (Hermes source reference, 老板 2026-08-21 ruled)

> Date: 2026-08-21
> 老板 8/21 macOS screenshot: the chat bottom bar has 2 placeholder strings:
> 1. Red box 1: "MiniMax-M3" (= static Picker, placeholder) → replace with the real Hermes model picker
> 2. Red box 2: "0/20 ●○○○" (= token progress placeholder, but 老板's actual requirement is "context usage", not token billing) → replace with the real Hermes context usage bar
> 老板 8/21 ruled:
> - "Model selection should reference hermes source, associate providers, and auto-fetch the models usable by the configured keys. MED is not implemented (med = analysis strength / reasoning effort). MOA multi-model joint analysis is temporarily not needed."
> - "Context usage = look at the source code, see how hermes implemented it."
> - "MED also = look at the source code, see how hermes gets it."

## Business language (老板-facing)

The 2 placeholder strings 老板 sees in the chat bottom bar on macOS should be replaced with the real Hermes desktop equivalents:
- Left side = multimodal provider/model picker (= Hermes truth: dropdown + provider group + reasoning effort meta)
- Right side = context usage bar (= Hermes truth: used/max/percent + category breakdown segments)

## Hermes source truth (apps/desktop/src/)

### Context Usage Panel (apps/desktop/src/app/shell/context-usage-panel.tsx)
- Type: `UsageStats { context_max, context_used, context_percent }` + `ContextBreakdown { categories: [{id, label, color, tokens}] }`
- Data source: `SessionRuntimeInfo.usage` (live) + `session.context_breakdown` RPC (per-category breakdown, each category a color)
- Display: `compactNumber(used) / compactNumber(max) percent%` (e.g. "441.6k / 1M 44%")
- Progress bar: `ContextUsageBar` renders segments, width = `category.tokens / segmentTotal * 100%`

### Model Menu Panel (apps/desktop/src/app/shell/model-menu-panel.tsx)
- Type: `ModelOptionsResponse { providers: [{slug, name, models: [id], capabilities: {id: {fast, reasoning}}, is_current, warning}] }`
- Data source: `model.options` RPC `requestModelOptions({gateway, sessionId, refresh, explicitOnly})`
- Render: provider group sorted alphabetically by provider name; default top-N per provider; current model always shown; search spans all
- Reasoning effort: meta field "Med" / "Low" / "High" (e.g. "MiniMax M3 · Med")
- MoA: not implemented (老板 ruled MOA is not needed)

### Provider env var truth (apps/desktop/src/app/settings/helpers.ts)
- Multiple env vars map to 1 provider (e.g. `MINIMAX_CN_API_KEY` → "MiniMax (China)", `MINIMAX_API_KEY` → "MiniMax")
- `providerGroup(envVarName)` returns the display name
- `isKeyVar(envVarName, info)` checks whether the field is a key field

### probe_api_models (hermes_cli/models.py:3513)
- `anthropic_messages` mode: `x-api-key` + `anthropic-version: 2023-06-01` headers
- Candidate URLs: `{base_url}` + `{base_url}/v1` (heuristic)
- 5s timeout
- Parse `data[].id` → `[String]`
- Cache: `provider_models_cache.json` 1h TTL
- Failure fallback: curated list

## Wenshu current state (working tree)

- `LLMKeychain` actor (commit `143ff4845`) — `loadKey()` / `saveKey()` / `deleteKey()` + `loadKeySync()` (synchronous read at init)
- `MiniMaxModelFetcher` (commit `e45fac768`) — `fetchLiveModelIds(apiKey:)` + `loadModelIds()` + `ModelCache` actor with 1h TTL
- `ChatView` ChatViewModel — current msg/user display + "Enter message…" TextField
- Current `ChatView` bottom bar: placeholder "MiniMax-M3" + "0/20 ●○○○" progress bar (= old `LayoutShellView` 6-zone layout placeholders)

## Fix specification (3 steps, satisfying principles 1 + 4)

### Step 1: Extract `LLMProvider` enum + `LLMProviderDiscovery` actor (Hermes truth)
- `Sources/WenshuApp/Core/Agent/LLMProvider.swift`:
  - `enum LLMProvider: String, CaseIterable` — `minimax-cn`, `minimax`, `openrouter`, `anthropic`, `nous`
  - `var displayName: String` (= Hermes `providerGroup` truth)
  - `var keychainAccount: String` (= like `MINIMAX_CN_API_KEY`)
  - `var baseUrl: String`
  - `var apiMode: String` (= "anthropic_messages" / "chat_completions")
- `actor LLMProviderDiscovery`:
  - `func authenticatedProviders() async -> [LLMProvider]`: iterate `LLMProvider.allCases`; call `LLMKeychain.loadKey(account: provider.keychainAccount)`; non-empty = truth.
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
