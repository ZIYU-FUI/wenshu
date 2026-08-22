# 04 — Settings → Model tab: fetch real model list (Hermes `probe_api_models` paradigm)

**What to build:**
老板 8/21 ruled "model configuration reference hermes' provider settings implementation; hermes will auto-fetch the list of models usable by my configured keys". The current Settings > Model tab uses `MiniMaxModel` enum hardcoded with 3 cases (`MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`); 老板's macOS-verified key may unlock more models, and hardcoding misses them.

**Hermes truth (`hermes_cli/models.py`):**
- `probe_api_models(api_key, base_url, timeout=5.0, api_mode="anthropic_messages")` (= 老板's authoritative truth)
- `anthropic_messages` mode: `x-api-key` + `anthropic-version: 2023-06-01` headers (Anthropic native auth)
- Fallback: `Authorization: Bearer ...` (OpenAI mode)
- Candidate URLs: `{base_url}` + `{base_url}/v1` (heuristic; boss host may not include `/v1`)
- 5s timeout
- Parse: `data[].id` (OpenAI canonical)
- Cache: `provider_models_cache.json` 1h TTL (Hermes 1h)
- Failure fallback: curated built-in list (`MiniMaxModel.allCases` truth)

**Blocked by:** ticket 03 LLM Keychain integration (commit `143ff4845`) — already committed.

**Status:** ready-for-agent

## Fix specification (5 steps, Hermes paradigm truth)

1. `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` (actor truth)
   - `func fetchLiveModelIds(apiKey:baseUrl:timeout:5) async -> [String]?`:
     - Candidate URLs: `{base_url}` + `{base_url}/v1` (heuristic)
     - Headers: `x-api-key: ...` + `anthropic-version: 2023-06-01` (Anthropic mode)
     - `URLSession.shared.data(from:)` GET, 5s timeout
     - Parse `data[].id` → `[String]`
     - On failure return `nil` (don't throw)
2. Cache: `~/Library/Application Support/com.wenshu.app/model_cache.json` 1h TTL (Hermes 1h)
3. `SettingView` Model tab:
   - Extract `@MainActor func reloadModels() async` calling the fetcher
   - `onAppear`: `reloadModels` async (background, user sees no loading)
   - **Rewrite "hide display after configuration"** = `Picker` selection ≠ current label (switch to `Menu` + `.disabled("Already selected: \(current)"` suffix) truth
     - Actual Apple truth: `Menu(currentModel) { ForEach }` (= macOS standard "current + open menu" pattern, used by Pages settings)
4. Picker displays fetch result + fallback `MiniMaxModel.allCases`
5. User selects model → truth: write to UserDefaults `"wenshu.llm.model"` + update `sharedVerifier.model` field (commit `0589141` + `143ff4845` truth)

## Acceptance

- [ ] `MiniMaxModelFetcher` actor + `fetchLiveModelIds` + cache + fallback `MiniMaxModel.allCases`
- [ ] `SettingView` Model tab `onAppear` async reload (background, non-blocking)
- [ ] Picker displays the real fetched model list (Hermes truth)
- [ ] Fallback: network fail → curated `MiniMaxModel.allCases` (3 entries)
- [ ] ⌘, → Settings → Model tab → Hermes-paradigm auto-fetch truth
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (new `testModelFetcherFallback` truth)
- [ ] 老板 macOS verification: Model tab shows the Hermes-fetched real model list (≥3) + selecting a model takes effect immediately

## Out of scope (Q20 hard constraint)

- Settings > Appearance tab (commit `d8146ca7d` passed)
- `LLMKeychain` actor (commit `143ff4845` passed)
- v0.20 + v0.21 chat-streak tickets (untouched)
- `AppIcon.icon/` (老板 ruled: leave it for now)

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/foundation/urlsession
- `hermes_cli/models.py` `probe_api_models` (Hermes open-source truth)
- https://docs.anthropic.com/en/api/models-list

## References

- Depends on: ticket 03 (Keychain integration) — already committed
- Required by: none
