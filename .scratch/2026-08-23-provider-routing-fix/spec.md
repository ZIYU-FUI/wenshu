# Spec — Bug fix: provider routing + dynamic key resolution

> Boss 2026-08-23 拍: '我担心一个场景, 用户的 a key a 模型用量到了, 手动切换了 b 模型, 但只有主 agent 切换了, 我们的程序就卡住了'.

## Bug analysis (3 related bugs found)

### Bug 1: WenshuVerifier.apiKey frozen at init
- `WenshuConductor` holds 1 `WenshuVerifier` instance.
- `WenshuVerifier.init(baseURL:apiKey:model:)` resolves apiKey from Keychain ONCE, stores in `private let apiKey`.
- When user changes API key in Settings page → `LLMKeychain.saveKeySync()` writes new key → but `verifier.apiKey` is unchanged.
- All subsequent LLM calls (主 agent + 5 sub-agents + Auditor) use OLD apiKey.

### Bug 2: WenshuVerifier.baseURL frozen at init
- baseURL hardcoded to `https://api.minimaxi.com/anthropic`.
- When user switches to `anthropic` provider → baseURL should change to `https://api.anthropic.com` → but it doesn't.

### Bug 3: model name has no provider mapping
- WenshuLLMModel enum = single provider case (M3 = minimax cn).
- When user selects "claude-3.7-sonnet" → verifier still uses minimax baseURL + key → fails.

## Boss scenario

> User uses MiniMax-M3 (minimax cn) heavily. Reaches A key usage limit. Goes to Settings page, switches to B key + B model (e.g. claude-3.7-sonnet from anthropic).

What should happen:
1. Settings page saves new key + provider + model to UserDefaults / Keychain.
2. WenshuConductor (and its verifier) reloads from new config.
3. All 6 agents (1 main + 5 sub) use new key + baseURL + model on next call.

What currently happens:
- model parameter changes (Boss 8/23 ticket 38 wire) ✓
- apiKey + baseURL frozen ✗
- Result: 401 Unauthorized or connection refused.

## Fix design

### Fix 1: Dynamic resolution on each call

Replace `private let apiKey: ***` + `private let baseURL: String` with **resolution functions**:

```swift
public actor WenshuVerifier {
    private let model: String  // model parameter — the ONLY thing captured at init

    public init(model: WenshuLLMModel = .m3) {
        // No apiKey, no baseURL capture.
        // Resolve at call time.
        self.model = model.rawValue
    }

    private func resolveCredentials() throws -> (apiKey: String, baseURL: String) {
        // 1. Read provider from UserDefaults "wenshu.provider.slug"
        // 2. Look up provider in ProviderCatalog
        // 3. Load key from AppleKeychain for that provider
        // 4. Return (key, baseURL)
    }

    public func send(...) async throws -> WenshuLLMResponse {
        let creds = try resolveCredentials()
        // build urlRequest with creds.apiKey + creds.baseURL
    }
}
```

### Fix 2: Model → Provider mapping

Currently WenshuLLMModel enum has 1 model (M3 = minimax cn). Expand:

```swift
public enum WenshuLLMModel: String, CaseIterable, Codable, Sendable {
    case m3 = "MiniMax-M3"
    case claudeSonnet = "claude-3.7-sonnet"
    case gpt4o = "gpt-4o"
    // ... future

    /// Provider slug for routing.
    public var providerSlug: String {
        switch self {
        case .m3: return "minimax-cn"
        case .claudeSonnet: return "anthropic"
        case .gpt4o: return "openai"
        }
    }
}
```

When user switches model, WenshuLLMModel.providerSlug tells the system which provider's key + baseURL to use.

### Fix 3: Settings change → conductor reload

When Settings page saves new config, post NotificationCenter notification. WenshuConductor listens (or, since it now resolves per call, no listener needed — just resolves fresh on each call).

This makes Fix 3 trivial: **no listener needed** because resolveCredentials() runs per call. Settings page just saves, next LLM call picks up new values.

## Files to touch (leaf only)

1. `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` — replace frozen apiKey/baseURL with per-call resolution
2. `Sources/WenshuApp/Core/Agent/WenshuLLMModel.swift` — add providerSlug mapping
3. `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — ensure lookup function is available
4. New tests file: `Tests/WenshuAppTests/Core/Agent/ProviderResolutionTests.swift`
5. `CONTEXT.md` — add ProviderResolution domain word

## Acceptance criteria

- [ ] WenshuVerifier.init has no apiKey/baseURL params (or they're optional override only)
- [ ] WenshuVerifier.send() calls resolveCredentials() per call (logs show re-resolution)
- [ ] WenshuLLMModel.providerSlug returns correct slug for each model
- [ ] When UserDefaults "wenshu.provider.slug" changes between calls, next call uses new provider
- [ ] When Keychain key for new provider is updated, next call uses new key
- [ ] swift build exit 0
- [ ] swift test: 396 + new tests pass
- [ ] Code-review 2 axes (Standards + Spec)

## Risks

- Per-call keychain read adds ~1ms latency. Mitigation: keep an actor-local cache (key+url, invalidate on Settings change notification).
- Apple Keychain access in sandboxed app can prompt for permissions. Mitigation: only access when user explicitly changes provider in Settings (first-time), cache thereafter.

## Out of scope

- Live streaming partial results (separate work item)
- Per-query budget cap (separate work item)
- Auto-failover (A key exhausts → auto-switch to B key without user action — deferred to v0.25+)
---

## v0.23 audit #014 update (2026-08-23)

Boss 2026-08-23 audit found: this spec proposes adding `.claudeSonnet` / `.gpt4o` cases to `WenshuLLMModel`. But boss 2026-08-21 拍 (v0.21 ticket 04) was "3 个 default model" = `.m3 / .m2 / .reasoning`, all MiniMax. Adding anthropic/openai cases was NOT in boss's original scope. Multi-provider routing (current implementation, ticket 010.001) supports anthropic/openai via WenshuVerifier.resolveCredentials reading UserDefaults `wenshu.llm.provider` + ProviderCatalog, but the WenshuLLMModel enum intentionally stays MiniMax-only per boss's 8/21 directive.

Decision (autonomous, pending boss review):
- Spec proposed adding cases → deferred to v0.24 (boss 8/25 review)
- Current code (3 MiniMax cases + dynamic provider resolution) works per boss's 8/21 directive
- If boss 8/25 wants anthropic/openai cases added, that's a 1-line additive change (new enum cases + providerSlug switch arms). Currently deferred.
