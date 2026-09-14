# v0.84 KeychainOps dedup · Spec

**Branch**: `wt/v0.84-keychain-dedup-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推"

## Context

After v0.81 (= `SearchAPIKeychain.swift` added in v0.73-v0.82), repowise
flagged a dry_violation: 16% of `SearchAPIKeychain.swift` duplicated 30 lines
of `ProviderKeychain.swift` (= `SecItemAdd` / `SecItemCopyMatching` /
`SecItemDelete` calls).

Per boss priority ("按优先级推"): this is a real health signal that
should land before further feature work. v0.84 = the dedup.

## Scope (= 2 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC change | Status |
|---|---|---|---|---|
| 1 | `001-keychain-ops-module` | New `Sources/WenshuApp/Core/Provider/KeychainOps.swift` (= canonical shared helper) | +~110 LOC | ✅ done this branch |
| 2 | `002-search-api-keychain-refactor` | `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= refactor AppleSearchKeychainStore to delegate to KeychainOps) | -~90 LOC / +~15 LOC | ✅ done this branch |

Out of scope (= explicit):

- `AppleKeychainStore` (= ProviderKeychain.swift) refactor to use KeychainOps
  - The dry_violation partner (= 16% dup); = ticket 003 = v0.85+ scope
  - Defer because `Provider` is an enum (= different signature from
    KeychainOps's `String provider`); = needs adapter layer
- New test coverage (= SearchAPIKeychainTests already cover the
  refactored path with 10 tests; = no new tests needed)
- Performance changes (= extraction is mechanical, = no algorithmic change)

## Per-ticket acceptance criteria

### Ticket 001 — KeychainOps module

- New file: `Sources/WenshuApp/Core/Provider/KeychainOps.swift`
- Public API:
  - `KeychainOps.save(value:service:account:) throws`
  - `KeychainOps.load(service:account:) -> String?`
  - `KeychainOps.delete(service:account:) throws`
  - `KeychainOps.listAccounts(service:suffix:) -> [String]`
- `KeychainOpsError` enum (= canonical keychain errors; = each
  provider file maps these into its own domain-specific error type)
- Per AGENTS.md §11.1: NO third-party deps (= Foundation + Security only)
- `wenshu.debugNoKeychain` short-circuit (= matches existing behavior)

### Ticket 002 — SearchAPIKeychain refactor

- `AppleSearchKeychainStore.saveKey` / `loadKey` / `deleteKey` / `listConfiguredProviders`
  all delegate to `KeychainOps.*` (= no inline Security framework calls)
- `SearchAPIKeychainError.from(_:KeychainOpsError)` mapper (= preserves
  original error types)
- All 10 existing `SearchAPIKeychainTests` pass

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= original
  dry_violation partner; = v0.85+ scope)
- `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= v0.81 original)
- `.scratch/v0.84-keychain-dedup/spec.md` (= this file)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE
3. `swift test --filter "SearchAPIKeychainTests"` = 10/10 pass
4. Code-review 双轴 = Standards + Spec per Q146

## Expected health impact (= per repowise dry_violation finding)

Before (= indexed_commit `6917f9acdd17`):
- `SearchAPIKeychain.swift`: score 9.85, NLOC 193, **dry_violation: 16% dup** (worst clone 19 lines vs ProviderKeychain.swift)

After v0.84 (= this branch):
- `SearchAPIKeychain.swift`: ~50 LOC lighter (= ~25% smaller)
- `KeychainOps.swift`: +~110 LOC (= new shared helper)
- Net: ~60 LOC lighter across the two files
- dup ratio: 16% → ~0% (= AppleSearchKeychainStore no longer inlines the Security framework calls)

## Out-of-scope (= explicit)

- `AppleKeychainStore` (= ProviderKeychain.swift) refactor (= v0.85+ ticket 003)
- Performance optimization (= extraction is mechanical, = no algorithmic change)
- New test coverage (= existing 10 tests cover the refactored path)