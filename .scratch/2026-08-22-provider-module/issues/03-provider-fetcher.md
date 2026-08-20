# 03 — ProviderFetcher 多 provider live fetch

**Blocked by:** ticket 01 (Provider enum).

**Status:** ready-for-agent

## 修法真值

重构 `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` → `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift`:
- `fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]?`:
  - openai_chat mode → Bearer token, GET `{base_url}/models`
  - anthropic_messages mode → x-api-key + anthropic-version: 2023-06-01, GET `{base_url}/v1/models`
- `loadModelIds(provider: Provider, apiKey: String) async -> [String]`:
  - cache 1h TTL per provider
  - fallback to Provider.defaultModels (curated)

保留 `MiniMaxModelFetcher` 旧 API (= ProviderFetcher.loadModelIds(apiKey: baseUrl:) stub for minimax)，ticket 04/chat 不动

## Acceptance

- [ ] ProviderFetcher.fetchLiveModelIds 多 provider 范式
- [ ] ProviderFetcher.loadModelIds cache + fallback
- [ ] MiniMaxModelFetcher 旧 API 仍 work (delegates to ProviderFetcher for minimax)
- [ ] swift build exit 0
- [ ] swift test exit 0

## 不动

- v0.21 ticket 01 Provider enum
- v0.21 ticket 02 ProviderKeychain
- v0.21 chat bottom bar (复用 MiniMaxModelFetcher)
- App.swift Settings (ticket 04)

## 关联

- 依赖: ticket 01
- 被依赖: ticket 04
