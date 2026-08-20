# 02 — ProviderKeychain 多 provider key 存储

**Blocked by:** ticket 01 (Provider enum).

**Status:** ready-for-agent

## 修法真值

重构 `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` → `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift`:
- `kSecAttrAccount = provider.slug` (每 provider 一 key)
- `actor ProviderKeychain { func saveKey(_ key: String, for provider: Provider) throws }`
- `func loadKey(for provider: Provider) throws -> String?`
- `func deleteKey(for provider: Provider) throws`
- `static func loadKeySync(for provider: Provider) -> String?` (init 等 sync context)

保留 `LLMKeychain.loadKeySync()` 旧 API (= `loadKeySync(for: .minimaxCn)`)，tickets 04/03 不动

## Acceptance

- [ ] ProviderKeychain actor + saveKey/loadKey/deleteKey for provider
- [ ] LLMKeychain.loadKeySync() 仍 work (= loadKeySync(for: .minimaxCn))
- [ ] swift build exit 0
- [ ] swift test exit 0

## 不动

- v0.21 ticket 04 MiniMaxModelFetcher (后续重构)
- v0.21 ticket 01 Provider enum
- App.swift Settings (ticket 04)

## 关联

- 依赖: ticket 01
- 被依赖: ticket 03, 04
