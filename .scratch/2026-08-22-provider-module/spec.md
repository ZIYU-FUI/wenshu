# 05 — Full Provider module clone (Hermes pattern)

> Date: 2026-08-22
> 老板 2026-08-21 拍: "Replicate the whole thing — in the future users will configure their own keys too, not everyone has minimax. Clone the whole provider module: besides hermes' own commercial subscription, there are third-party hosted platforms, i.e. enumerate every model provider, users pick and configure themselves."

## Business language (老板-facing)

Settings → Providers tab:
- **List all providers** (= hermes pattern, openrouter / nous / minimax / minimax-cn + user-added)
- User picks 1 provider
- User fills in API key (= existing Keychain integration, add provider field)
- Settings page → Models tab fetches the current provider's `/v1/models` truth list
- "Configure then hide display" — 老板's original words preserved

## Hermes truth chain (scope to be replicated)

**`hermes_cli/model_switch.py` (2452 lines):**
- `parse_model_flags` / `resolve_persist_behavior` / `switch_model` — model-switch state machine
- `list_authenticated_providers` (1450) — list providers that have keys + curated models
- `list_picker_providers` — picker UI data (provider → model list)
- `prewarm_picker_cache_async` — background cache prewarming
- `_load_direct_aliases` / `_ensure_direct_aliases` — alias truth

**`hermes_cli/models.py` (4294 lines):**
- `_PROVIDER_MODELS` dict (provider → curated model list)
- `provider_model_ids(provider)` — provider model catalog (curated + live)
- `fetch_api_models` / `probe_api_models` — `/v1/models` truth fetch (5s timeout)
- `_fetch_anthropic_models` / `_fetch_github_models` / `fetch_nous_models` / `get_codex_model_ids` — per-provider endpoints
- `ModelCache` (1h TTL) — disk cache
- `_PROVIDER_ALIASES` — provider slug aliases

**Hermes-supported providers (reverse-engineered from config.yaml / models.py):**
- `openrouter` (OPENROUTER_API_KEY) — third-party platform, routes any model
- `nous` (OAuth, hermes auth) — Nous Portal
- `minimax` (MINIMAX_API_KEY) — MiniMax
- `minimax-cn` (MINIMAX_CN_API_KEY) — MiniMax (China)
- `openai-codex` (OAuth)
- `copilot` / `copilot-acp` (GitHub token)
- `xai-oauth` (OAuth)
- `stepfun` (API key)
- `anthropic` (API key, native Anthropic protocol)
- custom endpoints (user fills base_url + key)

## Fix scope (老板拍 "user self-configures" = multi-provider + self-filled key)

**Step 1 — Full provider module clone (this ticket's scope):**

1. `Sources/WenshuApp/Core/Provider/Provider.swift` — `enum Provider` truth
   - `openrouter`, `nous`, `minimax`, `minimax-cn`, `openai-codex`, `copilot`, `xai-oauth`, `stepfun`, `anthropic`, `custom`
   - Each case: `name`, `slug`, `baseURL`, `apiMode` ("anthropic_messages" / "openai_chat"), `authHeader` ("x-api-key" / "Authorization"), `defaultModels: [String]`
2. `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — truth
   - `static let providers: [Provider]` = hermes-pattern list
   - `static func defaultModels(for: Provider) -> [String]` — curated fallback
3. `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift` — refactor MiniMaxModelFetcher → multi-provider
   - `func fetchLiveModelIds(provider: Provider, apiKey: *** async -> [String]?`
   - Provider uses its own endpoint + headers (hermes truth)
   - fallback to curated
4. `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` — multi-provider key storage
   - `LLMKeychain` → per-provider storage (`kSecAttrAccount = provider.slug`)
   - `ProviderKeychain` enum shim preserves existing call sites (saveKeySync/loadKeySync/deleteKeySync/listProvidersWithKeys)
   - Backend swappable via `ProviderKeychain.setBackendForTesting(_:)` for test isolation (AppleKeychainStore production / InMemoryKeychainStore test)
5. `Sources/WenshuApp/App.swift` Settings page → add "Providers" tab (placed between General + Models)
   - Providers tab: List providers (radioGroup, currently selected provider highlighted) + when custom, show base_url input
   - Models tab: rewrite Picker to use the current provider's fetch result
6. 老板 macOS real verification:
   - Settings → Providers → select openrouter → prompt for OPENROUTER_API_KEY → Keychain stored
   - Settings → Models → Picker shows openrouter truth model list
   - Test multiple providers (minimax / openrouter / nous) all work

**Step 2 — Later (not in this ticket):**
- After provider switch, `sharedVerifier` rebuild (real hard violation)
- User-added custom provider UI
- OAuth flow (nous / copilot / openai-codex / xai-oauth)
- Custom base_url persistence

## Acceptance

- [ ] Provider.swift enum (10+ cases, hermes truth)
- [ ] ProviderCatalog.swift static list
- [ ] ProviderFetcher.swift multi-provider truth fetch
- [ ] ProviderKeychain.swift multi-provider key storage (enum shim + Storing protocol + AppleKeychainStore production + InMemoryKeychainStore test)
- [ ] MiniMaxVerifierTests.testPingReal: dev-env skip pattern (guard hasAPIKey else return, no Issue.record)
- [ ] ProviderKeychainTests: inject InMemoryKeychainStore via setBackendForTesting, no OS Keychain entitlement required
- [ ] SettingView rewrite: 4 tabs (General / Providers / Models / Shortcuts)
- [ ] Providers tab: radioGroup picker + current provider display + when custom show base_url
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] New tests: testProviderFetchOpenRouter + testProviderFetchFallback
- [ ] 老板 macOS real verification: select openrouter → Keychain stores key → Models tab shows openrouter truth list

## Do not touch (Q20 hard constraint)

- v0.21 chat streak tickets 02-06 (do not touch)
- v0.21 ticket 04 MiniMaxModelFetcher (refactor into ProviderFetcher, do not rewrite)
- v0.21 ticket 03 LLMKeychain (refactor into ProviderKeychain, do not rewrite)
- AppIcon.icon/ (老板拍 leave for now)

## Apple HIG ground truth references

- https://developer.apple.com/documentation/swiftui/picker (radioGroup truth)
- https://developer.apple.com/documentation/security/keychain_services
- hermes_cli/models.py probe_api_models (Hermes truth)
- hermes_cli/model_switch.py list_authenticated_providers (Hermes truth)

## Related

- Depends on: ticket 03 (Keychain) + ticket 04 (Model fetcher) — both committed, refactor not rewrite
- Depended on by: ticket 06 (fix mini LLM Keychain actor unsafe), ticket 07 (rebuild sharedVerifier after provider switch)
