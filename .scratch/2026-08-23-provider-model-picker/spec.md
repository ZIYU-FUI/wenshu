# Spec — 多 provider 模型分组 picker

> Boss 2026-08-23 拍: '聊天区低栏的模型切换现在是否支持从配置文件里读可用模型, 比如我配了三个厂家的 key, 那模型切换就应该分组展示我三个厂家的可用模型的合集, 供我选择'.

## Current state

ChatView (App.swift line 1271) holds:
```
@State private var availableModels: [String] = WenshuLLMModel.allCases.map { $0.rawValue }
```

Then `Menu { ForEach(availableModels) { entry in Button(...) } }` — flat single-section list, no provider grouping, no keychain awareness.

WenshuLLMModelFetcher (currently called from App.swift line 1341) fetches live model list from a SINGLE provider via API call. Only knows about minimax-cn (env var path).

## Boss requirement

User configures keys for N providers in Settings (e.g. minimax-cn + anthropic + openai). The chat zone bottom picker should:
1. Show models GROUPED by provider (Section per provider)
2. Each Section = provider's defaultModels (from Provider struct, hardcoded curated list)
3. Only show providers that have a key in Keychain (don't show providers user hasn't configured)
4. Currently-selected model highlighted (existing behavior)
5. Selection writes to UserDefaults "wenshu.llm.model" (existing behavior)

## Design

### Data flow

```
Settings page:
  User adds key for "minimax-cn" → AppleKeychainStore.saveKeySync(for: provider)
  User adds key for "anthropic"  → AppleKeychainStore.saveKeySync(for: provider)

ChatView onAppear / Refresh button:
  loadAvailableModels():
    1. Scan AppleKeychainStore for all providers with keys
    2. For each provider with key:
       - Get provider.defaultModels (static curated list)
       - Optionally fetch live models from provider API (if it supports it)
    3. Return [AvailableProviderModels(provider: ..., models: [...])]

Menu rendering:
  For each section:
    Section("Provider Name") {
      ForEach(section.models) { model in
        Button(model) { selectModel(model) }
      }
    }
```

### New types

```swift
public struct AvailableProviderModels: Sendable {
    public let provider: Provider
    public let models: [String]
    public var hasLiveFetch: Bool { /* true if WenshuLLMModelFetcher succeeded */ }
}

public enum AvailableModelsDiscovery {
    public static func loadFromKeychain() async -> [AvailableProviderModels]
    public static func loadFromKeychainSync() -> [AvailableProviderModels]  // sync variant
}
```

### Persistence

Discovery is run on:
- ChatView onAppear (already calls `loadAvailableModels`)
- When Settings page saves a key (NotificationCenter post → ChatView refresh)
- Manual refresh button (already exists)

NO persistent cache for `availableModels` — always re-read from Keychain (cheap, keychain lookup is fast). Keeps "Settings changes take effect immediately" promise from ticket 010.002.

## Files to touch (leaf only)

1. `Sources/WenshuApp/Core/Provider/AvailableModelsDiscovery.swift` (new) — discovery logic
2. `Sources/WenshuApp/Views/Chat/ChatView.swift` — change `availableModels: [String]` → `availableSections: [AvailableProviderModels]`
3. `Sources/WenshuApp/App.swift` (line 1271+) — update Menu rendering to use Sections
4. `Tests/WenshuAppTests/Core/Provider/AvailableModelsDiscoveryTests.swift` (new)
5. `CONTEXT.md` — add AvailableModelsDiscovery domain word

## Acceptance criteria

- [ ] `AvailableModelsDiscovery.loadFromKeychain()` scans all providers
- [ ] Returns only providers with non-empty keys in Keychain
- [ ] Each returned section has provider.defaultModels as the model list
- [ ] Menu renders Sections grouped by provider name
- [ ] Selection writes to UserDefaults "wenshu.llm.model" (existing)
- [ ] swift build exit 0
- [ ] swift test: 404 + new tests pass
- [ ] Code-review 2 axes (Standards + Spec)

## Risks

- Keychain lookup on every chat load = latency (~5-20ms per provider). Mitigation: 7 providers × 10ms = 70ms, acceptable.
- Sandbox test environment has no Keychain keys. Mitigation: tests verify the discovery function logic via mock provider list, not actual Keychain.

## Out of scope

- Live fetching from non-minimax providers (ProviderFetcher.swift exists but not yet wired for anthropic/openai)
- Per-provider model caching (deferred — wenshu has 7 providers × ~5 models = 35 total, trivial)