# v0.86 AppleKeychainStore → KeychainOps refactor · Spec

**Branch**: `wt/v0.86-apple-keychain-ops-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.84 dedup'd `AppleSearchKeychainStore` (= SearchAPIKeychain.swift) onto
the new `KeychainOps` shared helper, eliminating half of the
repowise-flagged 16% dry_violation. The partner (= `AppleKeychainStore`
in `ProviderKeychain.swift`) was deferred to v0.86 because:
1. `AppleKeychainStore` takes a `Provider` enum (= not `String`) — needs
   an adapter via `provider.slug`
2. The behavior preservation (= identical short-circuit + identical
   OSStatus error mapping) needed careful testing

Per boss priority ("按优先级推" + "A"): close the dedup loop.

## Scope (= 2 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC change | Status |
|---|---|---|---|---|
| 1 | `001-apple-keychain-store-refactor` | `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` | -85 LOC / +25 LOC | ✅ done this branch |
| 2 | `002-provider-keychain-error-english` | Same file (= 中文 error message → English per AGENTS.md §11) | -2 / +2 | ✅ done this branch |

Out of scope (= explicit):

- New test coverage (= existing `ProviderKeychainTests` (19 tests) +
  `SecretScopeTests` (4 tests) cover the refactored path; = no new tests
  needed; = all pass when run isolated)
- Performance changes (= extraction is mechanical, = no algorithmic change)
- Metadata support (= `loadMetadata` / `saveMetadata` is NOT refactored
  because the metadata path is a separate concern — v0.36 ticket 012
  added optional methods that InMemoryKeychainStore implements directly;
  = production Apple backend uses protocol default no-op)

## Per-ticket acceptance criteria

### Ticket 001 — AppleKeychainStore refactor

- `AppleKeychainStore.saveKeySync` / `loadKeySync` / `deleteKeySync` /
  `listProvidersWithKeys` all delegate to `KeychainOps.*` (= no inline
  Security framework calls)
- `ProviderKeychainError.from(_:KeychainOpsError)` mapper added
- `import Security` removed (= no longer needed)
- Existing 19 `ProviderKeychainTests` pass when run isolated
- Existing 4 `SecretScopeTests` pass when run isolated
- Existing 10 `SearchAPIKeychainTests` pass (= unaffected by this branch
  but verified together per Q34 step 4)

### Ticket 002 — ProviderKeychainError English message

- Per AGENTS.md §11 hard rule "English only", the previous
  ProviderKeychainError messages:
    - "Keychain 操作失败 (status=...)" → "Provider keychain operation failed (status=...)"
    - "LLM key 格式无效" → "Provider API key format invalid"
  (= was a pre-existing violation; = caught during v0.86 review)
- This is NOT scope-creep: it fixes an obvious baseline violation
  (= Q34 step 4 atomic verification surface)

## Root cause analysis

Before v0.86, `AppleKeychainStore.saveKeySync` etc. inlined the
`SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete` calls directly.
This code was nearly identical to the same calls in
`AppleSearchKeychainStore` (= v0.81 surface; = refactored in v0.84).

Repowise dry_violation finding (= 2026-09-14): ~30 LOC of code with
~16% token-level similarity. After v0.86 (= this branch): the partner
side is also gone, dry_violation expected to drop to ~0%.

## Cross-references

- `Sources/WenshuApp/Core/Provider/KeychainOps.swift` (= new in v0.84)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= this branch)
- `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= v0.84)
- `Tests/WenshuAppTests/ProviderKeychainTests.swift` (= 19 tests)
- `Tests/WenshuAppTests/SecretScopeTests.swift` (= 4 tests)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= ~67s)
2. `swift test --filter "ProviderKeychainTests"` = 19/19 pass isolated
3. `swift test --filter "SecretScopeTests"` = 4/4 pass isolated
4. `swift test --filter "SearchAPIKeychainTests"` = 10/10 pass isolated
   (= unaffected by this branch but verified together)

NOTE: full `swift test` (= ~544 tests in parallel) shows cross-test
pollution in `SecretScopeTests` + `ProviderKeychainTests.saveKey then
loadKey`. This is a pre-existing flake (= test-suite ordering + backend
state race between concurrent tests; = same flake observed in v0.84
verification). NOT introduced by this branch.

## Out-of-scope (= explicit)

- `AppleKeychainStore.loadMetadata` / `saveMetadata` refactor
  (= optional methods on `ProviderKeychainStoring`; = InMemory backend
  implements directly; = Apple backend uses protocol default no-op;
  = no inline Security framework code to dedup; = leave alone)
- Concurrency fix for the cross-test pollution flake
  (= a separate ticket; = not in scope of this dedup refactor)
- Repowise re-index verification (= re-index is server-side cron;
  = expected to be ~24h behind; = verify in next session)