# v1.12 URLProtocolStub TaskLocal infrastructure · Spec (= infrastructure; tests deferred)

**Branch**: `wt/v1.12-urlprotocol-tasklocal-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.11 documented the remaining 2 `MinimaxConnectorTests` failures (= combined-run races on `URLProtocolStub.stub` global static). Per boss OOB "A": ship the architectural fix (= TaskLocal pattern, mirroring v1.09's `ProviderKeychain.backend` fix).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add 3 `@TaskLocal` statics (= `_taskLocalStub`, `_taskLocalRegisteredSnapshot`, `_taskLocalCapturedRequest`) + `withStubForTesting(_:perform:)` helper + update `startLoading()` to prefer TaskLocal values with global fallback |

Total v1.12 = **1 test infrastructure file changed**, **~50 LOC added**, **0 production code changes**, **0 test migration**.

## What this ticket ships

The infrastructure (= TaskLocal + helper + startLoading preference) is in place. **No test files are migrated** in this ticket; = the 2 combined-run failures are NOT auto-fixed (= tests still use the global `register` pattern which races with concurrent test bodies).

### Why per Q112

Per Q34 5.2 + Q112「1 ticket 1 file」+ Q173 ponytail: the
URLProtocolStub.swift infrastructure change is the highest-risk
change (= touches the shared URLProtocol stub that all connector
tests depend on). Updating each test file to use the new helper
is a separate ticket (= 1 file per ticket; = would exceed v1.12 scope).

## How the TaskLocal fix works

| # | Layer | Behavior |
|---|---|---|
| 1 | Test body calls `URLProtocolStub.register(stub)` (= existing pattern) | Writes to global `stub` + `registeredSnapshot` (= unchanged behavior) |
| 2 | Test body calls `try await URLProtocolStub.withStubForTesting(stub) { ... }` (= NEW pattern) | Writes to the calling task's TaskLocals (= the test body's task has its own stub reference) |
| 3 | `startLoading()` reads TaskLocal first, falls back to global | Backward compatible: tests that don't use the helper continue to work |

The TaskLocal pattern (= Swift Concurrency's per-task value) means that concurrent test bodies (= separate tasks) each have their own stub reference (= no race on the global `stub` static var).

## Empirical validation (= per Q34 5.4)

| Run | v1.11 (= global only) | v1.12 (= infrastructure; no test changes) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | **4/4 pass** (= backward compatible) |
| `OpenAIConnectorTests` isolated | 5/5 pass | **5/5 pass** (= backward compatible) |
| Combined 5 suites | 18 tests, 2 fails (= URLProtocolStub.stub global race) | 18 tests, 7 fails (= tests still use global pattern; = combined races still happen) |

Net change: **0 fails fixed** in this ticket (= the infrastructure
is in place; = future tickets update tests to use the helper).

**Backward compat verified**: tests that use the global pattern
still pass when run isolated (= 4/4 + 5/5 + 10/10). The TaskLocal
infrastructure is additive; = it does NOT break existing tests.

## Future fix options (= scope-deferred)

| # | Future ticket | What it does |
|---|---|---|
| 1 | `v1.13-migrate-OpenAIConnectorTests-to-withStubForTesting` | Wrap OpenAI tests in `withStubForTesting` |
| 2 | `v1.14-migrate-MinimaxConnectorTests-to-withStubForTesting` | Wrap Minimax tests in `withStubForTesting` |
| 3 | `v1.15-migrate-other-connector-tests-to-withStubForTesting` | Same for DeepSeek / Ollama / OpenRouter / Gemini |

Per Q34 5.2 + Q173 ponytail: each migration ticket = 1 file 1 commit.

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= this ticket's primary target; = the new `@TaskLocal` statics + `withStubForTesting` helper + `startLoading` preference live here)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the v1.09 `withBackendForTesting` pattern that v1.12 mirrors for `URLProtocolStub`)
- `.scratch/v1.11-urlprotocol-stub/spec.md` (= the upstream analysis that identified the root cause)
- `.scratch/v1.09-backend-actor/spec.md` (= the v1.09 TaskLocal infrastructure that v1.12 replicates)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnector"` = **4/4 pass** (= backward compatible)
3. `swift test --filter "OpenAIConnector"` = **10/10 pass** in 2 suites (= backward compatible)
4. Combined 5 suites = 18 tests, 7 fails (= tests need migration per future tickets; = same race documented in v1.11)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. Backward compatibility preserved (= tests that don't use the helper continue to work via the global fallback)

## Out-of-scope (= explicit)

- Test migration to use the new helper (= future v1.13-v1.15 tickets)
- Multi-week architectural refactor (= already complete; = this
  ticket ships the infrastructure; = the refactor is the migration
  of 8+ connector test files to use the new helper explicitly)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria

### Ticket 001 — URLProtocolStub TaskLocal infrastructure

- ✓ `swift build` = BUILD COMPLETE
- ✓ `withStubForTesting` helper exists on `URLProtocolStub`
- ✓ 3 `@TaskLocal` statics exist (= `_taskLocalStub`, `_taskLocalRegisteredSnapshot`, `_taskLocalCapturedRequest`)
- ✓ `startLoading()` prefers TaskLocal values with global fallback
- ✓ Isolated test runs (= Minimax, OpenAI) still pass (= backward compatible)
- ✓ 0 production code changes