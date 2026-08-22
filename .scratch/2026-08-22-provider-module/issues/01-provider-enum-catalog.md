# 01 — Provider enum + Catalog (Hermes truth)

**Blocked by:** None.

**Status:** ready-for-agent

## Fix approach (2 steps)

1. `Sources/WenshuApp/Core/Provider/Provider.swift` — `enum Provider` truth
   - 10 cases: openrouter / nous / minimax / minimax-cn / openai-codex / copilot / copilot-acp / xai-oauth / stepfun / anthropic / custom
   - Each case: `slug` (String, unique key, hermes `_PROVIDER_ALIASES` truth), `name` (display name), `defaultBaseURL`, `apiMode` ("anthropic_messages" / "openai_chat"), `authHeader` ("x-api-key" / "Authorization"), `requiresOAuth: Bool`, `defaultModels: [String]` (curated)
2. `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — static provider list + curated models truth

## Acceptance

- [ ] Provider.swift enum 11 cases (10 + custom)
- [ ] ProviderCatalog.swift static list
- [ ] swift build exit 0
- [ ] 老板 macOS real verification (later ticket wires UI)

## Do not touch (Q20)

- ticket 04 MiniMaxModelFetcher (later refactor)
- ticket 03 LLMKeychain (later refactor)
- App.swift (later ticket wires UI)

## Related

- Depends on: none
- Depended on by: ticket 02 (ProviderKeychain), ticket 03 (ProviderFetcher), ticket 04 (SettingView)
