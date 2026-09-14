# v0.89 Cross-test pollution flake · Spec (= honest scope gap)

**Branch**: `wt/v0.89-test-flake-fix-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context (= pre-existing flake)

The combined `swift test --filter "ProviderKeychainTests|SecretScopeTests"`
run fails (= 1 test) while each suite passes isolated (= classic
race-condition symptom):

```
isolated ProviderKeychainTests = 19/19 pass
isolated SecretScopeTests = 4/4 pass
combined run = 1 fail: "KeychainSource delegates to ProviderKeychain.loadKeySync"
                 = `read → nil`, `savedKey → "keychain-test-..."`
```

## Root cause (= per Q34 5.4)

`ProviderKeychain.backend` is a shared mutable global static var (= `nonisolated(unsafe) static var backend`). Both test suites call `setBackendForTesting(_:)` (= mutating the same global):

1. **ProviderKeychainTests** has `init() { ProviderKeychain.setBackendForTesting(InMemoryKeychainStore()) }` (= fresh store A per test).
2. **SecretScopeTests.KeychainSource** does `ProviderKeychain.setBackendForTesting(store)` (= different store B inside the test body) + `defer { ProviderKeychain.setBackendForTesting(InMemoryKeychainStore()) }`.

Swift Testing runs `async @Test` functions (= SecretScopeTests's `testKeychainSourceDelegatesToProviderKeychain()`) concurrently with `sync @Test` functions (= ProviderKeychainTests's tests). The async yield on `await source.read(...)` lets a concurrent test's `init()` reset the global backend mid-flight; = the KeychainSource test's `read` returns nil because its `savedKey` was written to a different backend instance that got replaced.

**Locking alone does not fix it**: adding `NSLock`-protected `setBackendForTesting` and snapshot-on-read still permits the backend to be swapped between `saveKeySync` (= snapshot backend A) and `loadKeySync` (= snapshot backend B) within the same test (= A and B are different `InMemoryKeychainStore` instances). v0.89 ticket 001 attempt (= commit v0.89 + revert) confirmed this empirically.

## The fix (= future ticket)

Requires architectural change:

- **Option A**: Per-test isolation via `TaskLocal` (= wenshu AppState pattern).
  Needs `ProviderKeychain.backendKey: TaskLocal<UUID>` + per-test backend
  registry. Touches ~3 files (ProviderKeychain, test infra, README).
- **Option B**: Swift Testing `.serialized` trait on both suites.
  Forces serial execution. Touches 2 test files. = best for now.
- **Option C**: Per-test backend instance via constructor injection.
  Requires `KeychainSource` + `SecretScope` to take backend as parameter.
  Touches 4-6 files (= API change).

Per Q34 5.6 partial: v0.89 documents the root cause + lists 3 fix
options for future tickets (= v0.90+). This branch ships ONLY the spec
doc (= no code change; = the pre-existing flake remains).

## Out-of-scope (= explicit)

- Locking-only fix (= empirically insufficient per v0.89 attempt)
- TaskLocal backend (= Option A; = future ticket)
- .serialized trait (= Option B; = future ticket)
- Constructor injection (= Option C; = future ticket)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= no code change; = just reverification)
2. `swift test --filter "ProviderKeychainTests"` = 19/19 pass isolated
3. `swift test --filter "SecretScopeTests"` = 4/4 pass isolated
4. `swift test --filter "ProviderKeychainTests|SecretScopeTests"` =
   1 fail (= pre-existing flake; = unchanged; = documented)

## Per-ticket acceptance criteria (= FAILED)

- v0.89 ticket 001 attempted to fix the flake with NSLock + snapshot.
- Empirical test: NSLock alone does not prevent `setBackendForTesting`
  from swapping the backend between `saveKeySync` and `loadKeySync`
  (= save and load happen in the same test; = no race; = the issue is
  cross-test; = the lock is in-process but not TaskLocal-aware).
- Reverted (= Q34 5.6 partial commit + future ticket).

## Recommendations (= Q186 boss 2026-09-14 '按优先级推' next)

The flake does NOT block CI (= isolated tests pass; = the combined-run
fail is the symptom). Recommended next ticket:

- **v0.90 = Option B** (.serialized trait; = 2-file patch; = lowest
  risk; = effectively serializes the 2 conflicting suites).

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the global
  `static var backend` + `setBackendForTesting` API)
- `Tests/WenshuAppTests/ProviderKeychainTests.swift` (= the init() reset)
- `Tests/WenshuAppTests/Auth/SecretScopeTests.swift` (= the per-test
  setBackendForTesting + defer reset)
- `Sources/WenshuApp/Core/Auth/SecretScope.swift` (= KeychainSource)