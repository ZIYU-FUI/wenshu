# B-10 phase B activation procedure

Date prepared: 2026-09-04.
Source: Boss OOB '跳过我验收,往后推进'. B-10 phase A shipped (= codesign entitlements scaffold + InMemoryKeychainStore default, commit `bc1197375`). Phase B = real AppleKeychainStore as default backend.

## Gate (= when this procedure runs)

Apple Developer Program paid enrollment is active (= TeamIdentifier assigned to wenshu's bundle identifier). Ad-hoc codesign without TeamIdentifier SIGKILLs the process on `SecItemAdd` (= exit code -9), so this activation MUST NOT run before paid enrollment.

## Activation steps (= execute in this exact order)

1. Set `B10_PHASE_B_ENABLED=1` in build settings.
   - In Xcode: target `WenshuApp` -> Build Settings -> Swift Compiler - Custom Flags -> Other Swift Flags -> add `-D B10_PHASE_B_ENABLED` (= alternative to `SWIFT_ACTIVE_COMPILATION_CONDITIONS += B10_PHASE_B_ENABLED`).
   - In Package.swift / SPM CLI builds: pass `-Xswiftc -DB10_PHASE_B_ENABLED` on the swift build / swift test invocation.
   - Verify: `grep -n B10_PHASE_B_ENABLED Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` returns 1+ hit (= flag wired).

2. Re-add `--options runtime` to `codesign` in `Scripts/build-app.sh`.
   - Replace `codesign --force --deep --sign - "$APP_DIR"` with `codesign --force --deep --options runtime --sign - "$APP_DIR"`.
   - `--options runtime` enables the Hardened Runtime (= required for SecItemAdd under TeamIdentifier-signed binaries).
   - Verify: `grep -n 'options runtime' Scripts/build-app.sh` returns 1+ hit.

3. Flip the SwiftUI Settings -> LLM Connector key field to use real `SecItemAdd`.
   - In `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift`, uncomment the four real-implementation blocks (`saveKeySync` body, `loadKeySync` body, `deleteKeySync` body, `listProvidersWithKeys` body) — each is currently a `/* ... */` block preceded by an emergency-stub early return.
   - Remove the stub-return statements so the real Security framework calls execute.
   - Verify: `grep -n 'kSecClass.*kSecClassGenericPassword' Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` returns 4+ hits (= real Keychain code present).

4. Run `swift test --filter ProviderKeychain` (= verify Phase B tests pass).
   - Both `testBackendDefault_isInMemoryStore` (= always runs) AND `testBackendPhaseBEnabled_returnsAppleKeychainStore` (= runs only when `B10_PHASE_B_ENABLED` is set) must pass.
   - Expect 2/2 when flag is ON, 1/2 when flag is OFF (= phase B test is conditionally compiled out).

5. Manual verify: Settings -> enter key -> relaunch app -> key persists.
   - Launch wenshu.app from Finder (= NOT from build output dir, to ensure codesign is the production variant).
   - Settings -> LLM Connector -> enter a test key for `anthropic` -> save.
   - macOS SecurityAgent modal appears (= Apple HIG auth flow, expected on first save) -> accept.
   - Quit wenshu.app (Cmd+Q) -> relaunch from Finder.
   - Settings -> LLM Connector -> the test key is still present (= real Keychain round-trip succeeded).

## Acceptance (= phase B is active when ALL hold)

- `swift build` exits 0 with `B10_PHASE_B_ENABLED` flag set.
- `swift test --filter ProviderKeychainBackend` = 2/2 pass.
- Manual round-trip (step 5) shows key persists across app relaunch.
- `grep -rn 'wenshu.debug.api.key' Sources/` = 0 hits (= debug stub removed).
- `grep -rn 'kSecClass.*kSecClassGenericPassword' Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` = 4+ hits (= real Keychain code present and exercised).

## Rollback (= if phase B misbehaves)

1. Set `B10_PHASE_B_ENABLED=0` (= or unset the build setting).
2. Re-comment the four real-implementation blocks in `ProviderKeychain.swift` (= restore the emergency stubs).
3. Revert `Scripts/build-app.sh` to `codesign --force --deep --sign - "$APP_DIR"` (= drop `--options runtime`).
4. `swift build` + `swift test` to confirm Phase A still functions (= InMemoryKeychainStore default).

## Out of scope (= intentionally NOT in this activation)

- Migration of existing callers to a newer API surface (= `ProviderKeychain` is already single source of truth; no migration needed).
- New `LLMKeychain.swift` revival (= deleted as dead code in the B-10 cleanup this session).
- Replacing stub with keychain-export-via-env-var (= LLM keys in process env is a security regression; out).

---

Last line: fact.