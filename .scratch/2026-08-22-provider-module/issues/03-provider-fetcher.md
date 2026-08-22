# 03 — ProviderFetcher multi-provider live fetch

**Blocked by:** ticket 01 (Provider enum).

**Status:** ready-for-agent

## Fix approach

Refactor `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` → `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift`:
- `fetchLiveModelIds(provider: Provider, apiKey: *** async -> [String]?`:
  - openai_chat mode → Bearer token, GET `{base_url}/models`
  - anthropic_messages mode → x-api-key + anthropic-version: 2023-06-01, GET `{base_url}/v1/models`
- `loadModelIds(provider: Provider, apiKey: *** async -> [String]`:
  - cache 1h TTL per provider
  - fallback to Provider.defaultModels (curated)

Preserve `MiniMaxModelFetcher` legacy API (= ProviderFetcher.loadModelIds(apiKey: *** stub for minimax), ticket 04/chat do not touch

## Acceptance

- [ ] ProviderFetcher.fetchLiveModelIds multi-provider pattern
- [ ] ProviderFetcher.loadModelIds cache + fallback
- [ ] MiniMaxModelFetcher legacy API still works (delegates to ProviderFetcher for minimax)
- [ ] swift build exit 0
- [ ] swift test exit 0

## Do not touch

- v0.21 ticket 01 Provider enum
- v0.21 ticket 02 ProviderKeychain
- v0.21 chat bottom bar (reuses MiniMaxModelFetcher)
- App.swift Settings (ticket 04)

## Related

- Depends on: ticket 01
- Depended on by: ticket 04
