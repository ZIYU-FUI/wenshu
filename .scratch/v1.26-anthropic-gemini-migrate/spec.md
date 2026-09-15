# v1.26 Migrate Anthropic + Gemini tests to makeIsolatedStub · Spec (= honest scope gap; same race as Minimax)

**Branch**: `wt/v1.26-anthropic-gemini-migrate-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "把你所有待办清完，不用问我"

## Context

After v1.25 (= combine 5 connector suites honest scope gap), full
test scan identified that Anthropic + Gemini connector tests STILL
use the global URLProtocolStub pattern (= unlike the 5 connector
tests that v1.18 + v1.19 migrated to `makeIsolatedStub`). Per boss
OOB "清完待办": migrate Anthropic + Gemini to `makeIsolatedStub` to
fix the variance + complete the per-test stub migration arc.

## Scope (= 1 ticket, 2 files 1 commit per Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/AnthropicConnectorTests.swift` | Migrate 4 test bodies to `URLProtocolStub.makeIsolatedStub()` |
| 2 | `Tests/WenshuAppTests/Agent/GeminiNativeConnectorTests.swift` | Migrate 2 test bodies to `URLProtocolStub.makeIsolatedStub()` |

Total v1.26 attempted = **2 test files changed**, **6 test bodies migrated**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.25 baseline (= global pattern for Anthropic + Gemini) | v1.26 attempted (= migrated) |
|---|---|---|
| Run 1 | (= 0-7 variance) | **8 tests, 4 fails** |
| Run 2 | (= 0-7 variance) | **8 tests, 1 fail + crash** |
| Run 3 | (= 0-7 variance) | **8 tests, fatal error: nil Optional** |

**Build: BUILD COMPLETE in 170s**. Migration **REVERTED** per Q46
stop-rule + Q186.

## Root cause analysis (= per Q34 5.2)

**Same root cause as v1.20** (= the same write-through race that
hit Minimax + OpenAI in v1.20). When `makeIsolatedStub` is used
without updating the `lastRequest` getter to prefer
`_isolatedCapturedRequest`, the test reads from the global
`URLProtocolStub.capturedRequest` (= which was written by a
DIFFERENT test's URLSession instance via the global path).

The v1.18 + v1.19 migrations to OpenAI + Minimax worked only
because the **global path** still ran (= the migrated tests
had a `@Suite(.serialized)` parent + the migration didn't
break the global write). For Anthropic + Gemini, the
`@Suite(.serialized)` already exists but the race manifests
differently because Anthropic + Gemini tests use different
assertion patterns.

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1-3 | v1.11 | register variations | 5/6 fails |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails |
| 5 | v1.14 | TaskLocal capturedRequest | Build fail + architectural reject |
| 6 | v1.15 | OSAllocatedUnfairLock for globals | Flaky: 2-7 fails |
| 7 | v1.20 | write-through to test's stub | Flaky: 2-8 fails |
| 8 | v1.21 | per-instance OSAllocatedUnfairLock | Flaky: 2-6 + crash |
| 9 | v1.22 | `@Suite(.serialized)` (= already applied) | 0-7 variance |
| 10 | v1.23 | multi-file refactor (>Q112) | spec-only |
| 11 | v1.25 | @Suite nesting multiplies tests | 49 tests, 11-13 fails |
| 12 | **v1.26** | **migrate Anthropic + Gemini to makeIsolatedStub** | **8 tests, 1-4 fails + crash** |

**12 attempts reverted**. Per Q46 stop-rule: **STOP** on
URLProtocolStub migration attempts.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the Anthropic + Gemini migration failure | ✓ shipped |
| 2 | AnthropicConnectorTests migration to `makeIsolatedStub` | **REVERTED** (= same write-through race as Minimax) |
| 3 | GeminiNativeConnectorTests migration to `makeIsolatedStub` | **REVERTED** (= same race) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all changes reverted; = spec-only delivery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | **Update `lastRequest` getter** to prefer `_isolatedCapturedRequest` (= the v1.20 approach) | Test reads from per-instance state | Same write-through race documented in v1.20 (= flaky) |
| 2 | **Process-wide test ordering lock** (= multi-file) | Cross-suite serialization | Multi-file; = requires v1.24 acceptance reversal |
| 3 | **Accept the variance** (= current state per v1.24) | Cheap | Already accepted in v1.24 |
| 4 | **Make Anthropic + Gemini non-actor** (= production code) | Eliminates actor race | Violates Q112; = production code change |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 3 (= accept the
variance) is the pragmatic choice. The v1.24 acceptance
closure stands. Anthropic + Gemini tests already pass in
isolated runs; = the dev inner loop works fine.

## Cross-references

- `AGENTS.md §11.5` (= the v1.24 acceptance closure)
- `.scratch/v1.25-combine-suites/spec.md` (= the v1.25 honest scope gap)
- `.scratch/v1.20-write-through/spec.md` (= the v1.20 race documentation that v1.26 hit again)
- `.scratch/v1.24-accept-flakes/spec.md` (= the v1.24 acceptance closure)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. All Anthropic + Gemini tests RESTORED to global pattern
3. Combined 5-connector runs = 0-7 fails variance (= SAME as v1.24 baseline; = no regression)
4. 0 production code changes
5. 0 net test code changes (= all 12 URLProtocolStub migration attempts reverted)

## Out-of-scope (= explicit)

- Process-wide test ordering lock (= future v1.27+ ticket; = requires v1.24 acceptance reversal)
- Accept the variance as known (= already done in v1.24)
- Make Anthropic + Gemini non-actor (= production code change; = violates Q112)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the Anthropic + Gemini migration failure (= same write-through race)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.26 ships as spec-only (= no production code, no test code)
- ✓ v1.24 acceptance closure stands (= variance = known inherent)
- ✓ Future fix options documented (= process-wide lock, accept, non-actor)
- ✓ **Q46 stop-rule invoked: 12 URLProtocolStub migration attempts all reverted; STOP**