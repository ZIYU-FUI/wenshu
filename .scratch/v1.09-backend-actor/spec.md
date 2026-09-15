# v1.09 TaskLocal backend · Spec (= infrastructure; tests deferred)

**Branch**: `wt/v1.09-backend-actor-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.03 + v1.08 documented 3 remaining inter-suite OpenAI-compatible
connector test failures. Per boss OOB "A": ship the architectural
fix (= Option 3 from v1.01 spec) for the v1.09 ticket.

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` | Add `@TaskLocal` `_taskLocalBackend` + `withBackendForTesting(_:perform:)` helper + `currentBackend()` accessor + update 6 shim methods to read via `currentBackend()` (= fallback to global `backend` when TaskLocal not set) |

Total v1.09 = **1 production file changed**, **~50 LOC added**, **0
test file changes** (= test files keep using `setBackendForTesting`
for backward compatibility).

## What this ticket ships

The infrastructure (= TaskLocal + helper + accessor + shim update)
is in place. **No test changes** are made in this ticket; = the 3
inter-suite connector failures are NOT auto-fixed (= tests still
use the global `setBackendForTesting` which races with concurrent
test bodies).

### Why per Q112

Per Q34 5.2 + Q112「1 ticket 1 file」+ Q173 ponytail: the
production code change is the highest-risk change (= touches the
shim layer that all 8 production call sites + 2 test call sites
depend on). Updating each test file to use the new helper is a
separate ticket (= 1 file per ticket; = would exceed v1.09 scope).

## How the TaskLocal fix works

| # | Layer | Behavior |
|---|---|---|
| 1 | Test body calls `ProviderKeychain.setBackendForTesting(store)` (= existing pattern) | Writes to global `backend` (= unchanged behavior) |
| 2 | Test body calls `try await ProviderKeychain.withBackendForTesting(store) { ... }` (= NEW pattern) | Writes to the calling task's TaskLocal (= the test body's task has its own backend reference) |
| 3 | Shim method `currentBackend()` | Returns TaskLocal if set, else falls back to global `backend` |

The TaskLocal pattern (= Swift Concurrency's per-task value) means
that concurrent test bodies (= separate tasks) each have their
own backend reference (= no race on the global `backend` static var).

## Empirical fix (= per Q34 5.4)

| Run | v1.08 (= global only) | v1.09 (= infrastructure; no test changes) |
|---|---|---|
| `OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests` combined | 18 tests, 4 fails (= 3 inter-suite connector + 1 Minimax) | **18 tests, 4 fails** (= unchanged; = tests need migration) |

Net change: **0 fails fixed** in this ticket (= the infrastructure
is in place; = future tickets update tests to use the helper).

## Future fix options (= scope-deferred)

| # | Future ticket | What it does |
|---|---|---|
| 1 | `v1.10-migrate-OpenAIConnectorTests` | Replace `setBackendForTesting(store)` in OpenAIConnectorTests with `withBackendForTesting(store) { ... }` |
| 2 | `v1.11-migrate-MinimaxConnectorTests` | Same for MinimaxConnectorTests |
| 3 | `v1.12-migrate-other-connector-tests` | Same for DeepSeek / Ollama / OpenRouter |

Per Q34 5.2 + Q173 ponytail: each migration ticket = 1 file 1 commit.

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= this
  ticket's primary target; = the new `@TaskLocal` +
  `withBackendForTesting` + `currentBackend` live here)
- `.scratch/v1.01-tasklocal-backend/spec.md` (= the upstream
  Option 3 analysis)
- `.scratch/v1.03-snapshot/spec.md` (= the v1.03 acceptance that
  documented these 3 fails)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
   = 18 tests, 4 fails (= unchanged; = tests need migration per
   future tickets)
3. No test code changes (= 0 files modified in Tests/)
4. Backward compatibility preserved (= tests that use
   `setBackendForTesting` continue to work via the global
   `backend` fallback in `currentBackend()`)

## Out-of-scope (= explicit)

- Test migration to use the new helper (= future v1.10-v1.12 tickets)
- Multi-week architectural refactor (= already complete; = this
  ticket ships the infrastructure; = the refactor is the migration
  of 8 production + 2 test call sites to use the new helper
  explicitly)
- Other pre-existing flakes documented in v0.94 / v1.04 specs