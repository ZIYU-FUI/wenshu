# 03 — LLM Keychain integration (老板 2026-08-21 ruled)

**What to build:**
老板 8/21 macOS-verified ChatView: echo → Error: Operation could not be completed (MiniMax key missing, dev env). 老板 8/21 provided the LLM key on the spot (老板 entered it directly in a macOS NSAlert prompt on the spot — not stored in files / log / commit).

CLAUDE.md L42 project baseline truth: "LLM key stored in macOS Keychain, not in files, not in logs, not in commits".

Fix specification (4 steps, Apple official paradigm):
1. Create `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` (actor truth, Keychain read / write / delete)
   - `func saveKey(_ key: String) throws` → `kSecClassGenericPassword` + `kSecAttrService="com.wenshu.app.minimax"`, `kSecValueData`
   - `func loadKey() throws -> String?` → `SecItemCopyMatching`
   - `func deleteKey() throws` → `SecItemDelete`
2. `MiniMaxVerifier.init` change: prefer `Keychain.loadKey()`, fallback to env `MINIMAX_CN_API_KEY` (backward-compatible; dev env still works)
3. End of `App.swift` `applicationDidFinishLaunching`: if Keychain has no key + env has no key, show NSAlert "Please set MiniMax API Key" (input field + Save button → `Keychain.saveKey`)
4. 1 ticket 1 commit + real verify (`pkill` + build + open + 老板 macOS verification)

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (4 steps)

1. Create `Sources/WenshuApp/Core/Agent/LLMKeychain.swift` (actor truth, Keychain read / write / delete)
   - `func saveKey(_ key: String) throws` → `kSecClassGenericPassword` + `kSecAttrService="com.wenshu.app.minimax"`, `kSecValueData`
   - `func loadKey() throws -> String?` → `SecItemCopyMatching`
   - `func deleteKey() throws` → `SecItemDelete`
2. `MiniMaxVerifier.init` change: prefer `Keychain.loadKey()`, fallback to env `MINIMAX_CN_API_KEY` (backward-compatible; dev env still works)
3. End of `App.swift` `applicationDidFinishLaunching`: if Keychain has no key + env has no key, show NSAlert "Please set MiniMax API Key" (input field + Save button → `Keychain.saveKey`)
4. 1 ticket 1 commit + real verify (`pkill` + build + open + 老板 macOS verification)

## Acceptance

- [ ] `LLMKeychain` actor + `saveKey` / `loadKey` / `deleteKey` truth (Apple Security framework)
- [ ] `MiniMaxVerifier.init` prefers Keychain read
- [ ] App startup shows NSAlert if Keychain has no key
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] New tests: `testLLMKeychainSaveLoad` (save → load returns consistent) + `testLLMKeychainLoadEmpty` (no key returns `nil`)
- [ ] 老板 macOS verification: ChatView sends a message and gets a real LLM Chinese reply (not Error)

## Out of scope (Q20 hard constraint)

- `MiniMaxVerifier.chat / send / ping` interfaces (unchanged)
- `WenshuConductor` / `AgentProtocol` (not rewritten)
- `AppIcon.icon/` (v0.21 ticket 04 landed; 老板 ruled: leave it for now)
- Settings page UI (commit `0082bd1fe` passed)

## Apple HIG references

- https://developer.apple.com/documentation/security/keychain_services
- https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- CLAUDE.md L42 "LLM key stored in macOS Keychain — not in files / log / commit"

## References

- Depends on: none
- Required by: ticket 04 (real verify) — not a dependency, can run in parallel
