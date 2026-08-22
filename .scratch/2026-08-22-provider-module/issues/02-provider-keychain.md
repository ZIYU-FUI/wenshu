# 02 — ProviderKeychain multi-provider key storage

**Blocked by:** ticket 01 (Provider enum).

**Status:** ready-for-agent

## Fix approach

Refactor `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` → `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift`:
- `kSecAttrAccount = provider.slug` (one key per provider)
- `actor ProviderKeychain { func saveKey(_ key: String, for provider: Provider) throws }`
- `func loadKey(for provider: Provider) throws -> String?`
- `func deleteKey(for provider: Provider) throws`
- `static func loadKeySync(for provider: Provider) -> String?` (init and other sync contexts)

Preserve `LLMKeychain.loadKeySync()` legacy API (= `loadKeySync(for: .minimaxCn)`), tickets 04/03 do not touch

## Acceptance

- [ ] ProviderKeychain actor + saveKey/loadKey/deleteKey for provider
- [ ] LLMKeychain.loadKeySync() still works (= loadKeySync(for: .minimaxCn))
- [ ] swift build exit 0
- [ ] swift test exit 0

## Do not touch

- v0.21 ticket 04 MiniMaxModelFetcher (later refactor)
- v0.21 ticket 01 Provider enum
- App.swift Settings (ticket 04)

## Related

- Depends on: ticket 01
- Depended on by: ticket 03, 04
