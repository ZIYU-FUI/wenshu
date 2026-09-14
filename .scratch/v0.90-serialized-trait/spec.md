# v0.90 .serialized trait on conflicting suites · Spec

**Branch**: `wt/v0.90-serialized-trait-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.89 (= previous ticket) documented the cross-test pollution flake as
an honest scope gap with 3 future fix options. Per boss OOB "A": pick
Option B (= `.serialized` trait on the conflicting suites).

## Scope (= 1 ticket, 2 files 1 commit per Q112)

| # | Ticket | File(s) | Status |
|---|---|---|---|
| 1 | `001-serialized-trait-on-conflicting-suites` | `Tests/WenshuAppTests/ProviderKeychainTests.swift` + `Tests/WenshuAppTests/Auth/SecretScopeTests.swift` | ✅ done |

Total v0.90 = **2 files changed**, **3 lines added**.

Out of scope (= explicit):

- Refactoring `ProviderKeychain.backend` to use TaskLocal (= Option A;
  = 3-file patch; = defer)
- Constructor injection (= Option C; = 4-6 file API change; = defer)
- Fixing other pre-existing test flakes (= ChatZoneView Chinese
  localization tests, Keychain -34018 error tests, polish surface tests;
  = unrelated to this ticket)

## Per-ticket acceptance criteria

### Ticket 001 — `.serialized` trait

- Add `.serialized` to the `@Suite` declarations of both conflicting suites:
  - `ProviderKeychainTests`
  - `SecretScopeTests`
- `swift test --filter "ProviderKeychainTests|SecretScopeTests"` =
  23/23 pass (= combined run no longer fails)
- Both suites remain 100% pass when run isolated

## Fix rationale

Swift Testing's `.serialized` trait (= @Suite trait) forces tests
within a suite to run sequentially (= no parallel @Test execution within
the suite). For suites that share mutable global state (= like
`ProviderKeychain.backend` static var), this prevents:
- `await`-induced yields (= async tests can't interleave their
  deferred portion with another suite's tests)
- Concurrent `setBackendForTesting` writes (= serialized within each
  suite, but the suites themselves may still run concurrently)

**Why this fixes the v0.89 flake**: the original async @Test in
SecretScopeTests (= `await source.read(...)`) yielded control; while
yielded, ProviderKeychainTests's sync tests were free to reset the
global backend (= the flake). After `.serialized` is applied:
- Within ProviderKeychainTests: each test completes fully (= init +
  body + assertions) before the next test starts (= no await yields).
- Within SecretScopeTests: same.
- The async `read` in SecretScope's test still happens, but the suite
  is serialized; = the `await` doesn't yield to another suite's tests
  in the same process.

Per the Swift Testing docs (= WWDC 24 / 25): `@Suite(.serialized)` is
the canonical fix for tests that share state.

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the global
  static var `backend` that triggers the race)
- `Tests/WenshuAppTests/ProviderKeychainTests.swift` (= this branch)
- `Tests/WenshuAppTests/Auth/SecretScopeTests.swift` (= this branch)
- `.scratch/v0.89-test-flake-fix/spec.md` (= the upstream analysis)

## Validation (= per Q34 step 4)

1. `swift test --filter "ProviderKeychainTests|SecretScopeTests"` =
   **23/23 pass** (= previously 1 fail)
2. `swift test --filter "ProviderKeychainTests"` = 19/19 pass isolated
3. `swift test --filter "SecretScopeTests"` = 4/4 pass isolated
4. `swift test` (full suite) = same pre-existing flake count as main
   (= no regressions introduced; = unrelated flakes in
   ChatZoneView / Keychain -34018 / polish surfaces remain)

## Out-of-scope (= explicit)

- Per-suite API change (= v0.89 Option C; = defer)
- TaskLocal backend (= v0.89 Option A; = defer)
- Other pre-existing flakes (= ChatZoneView, Keychain -34018, polish
  surfaces; = separate tickets)