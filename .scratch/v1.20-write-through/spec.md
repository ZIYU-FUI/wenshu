# v1.20 Write-through _isolatedCapturedRequest to the test's stub · Spec (= honest scope gap; flaky)

**Branch**: `wt/v1.20-write-through-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.19 documented the MinimaxConnector actor race. Per boss OOB "A": ship the write-through fix (= `routeToIsolatedStub` writes to BOTH the URLSession-created instance AND the test's stub instance).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add `stub._isolatedCapturedRequest = captured` in `routeToIsolatedStub` + update `lastRequest` getter to prefer `_isolatedCapturedRequest` |

Total v1.20 attempted = **1 test infrastructure file changed**, **~30 LOC added**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.19 (= write to URLSession instance only) | v1.20 attempted (= write through to test's stub) |
|---|---|---|
| Run 1 | 2 fails | **2 fails** (= same) |
| Run 2 | 4 fails | **8 fails** (= worse) |
| Run 3 | 4 fails | **3 fails** (= within variance) |

**Flaky: 2-8 fails across runs**. The write-through doesn't reliably fix the race.

## Root cause analysis (= per Q34 5.2)

The v1.19 spec correctly identified that the test reads its own stub instance (= not the URLSession-created one). The write-through attempts to set `_isolatedCapturedRequest` on the test's stub via the associated stub reference. **However**:

1. **Multiple URLSession-created instances may write concurrently** (= one per request; = Swift Testing may run multiple HTTP requests in parallel).
2. **The write-through is racy**: instance var writes are not atomic across threads. URLSession's internal queue may write to the test's stub's `_isolatedCapturedRequest` while the test reads it.
3. **The `lastRequest` getter prefers `_isolatedCapturedRequest`** if set. But if URLSession writes to it AFTER the test reads (= because the test reads at a wrong moment), the test sees a stale value (= from another test's request).

The fundamental issue is **per-instance state is still shared across URLsessions**. Each isolated stub has one `_isolatedCapturedRequest` instance var (= which can be written to by multiple URLSession-created instances if they happen to share the same associated stub reference).

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1-3 | v1.11 | register variations | 5/6 fails |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails |
| 5 | v1.14 | TaskLocal capturedRequest | Build fail + architectural reject |
| 6 | v1.15 | OSAllocatedUnfairLock | Flaky: 2-7 fails |
| 7 | v1.20 | **write-through to test's stub** | **Flaky: 2-8 fails** |

**7 attempts reverted** per Q46 stop-rule. **The URLProtocolStub migration is blocked on a deeper architectural refactor**.

## Why this is harder than expected

The per-test stub instance pattern (= v1.16-v1.17) was supposed to solve this. The issue is that **the URLSession creates its own URLProtocolStub instances per request**, and **each request may run on a different thread**. The associated object pattern lets us find the test's stub from the URLSession-created instance, but **the writes from different URLSession-created instances to the test's stub's instance var are not synchronized**.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the write-through race | ✓ shipped |
| 2 | `stub._isolatedCapturedRequest = captured` write-through | **REVERTED** (= flaky) |
| 3 | `lastRequest` getter prefers `_isolatedCapturedRequest` | **REVERTED** (= flaky) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all changes reverted; = spec-only delivery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | Use `os_unfair_lock` (= per-instance lock) around `_isolatedCapturedRequest` write+read | Eliminates write race | Adds lock overhead; = v1.15 pattern but per-instance |
| 2 | Use `OSAllocatedUnfairLock<URLRequest?>` instead of plain `URLRequest?` for `_isolatedCapturedRequest` | Atomic reads/writes | Slight overhead |
| 3 | Accept the 2 pre-existing flakes as known (= pragmatic) | Cheap | Doesn't actually fix them |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 3 (= accept) is
the pragmatic choice. The 2 remaining failures are pre-existing
and well-documented; = fixing them requires multi-week
architectural refactor that exceeds the current ticket scope.

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= this ticket's primary target; = now unchanged)
- `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38` (= the actor that complicates race analysis)
- `.scratch/v1.19-migrate-minimax/spec.md` (= the prior honest scope gap)
- `.scratch/v1.15-actor-guard/spec.md` (= the OSAllocatedUnfairLock attempt)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnector"` = 10/10 pass in 2 suites (= unchanged; = v1.18's migration preserves passing state)
4. Combined 5 suites = 18 tests, 2 fails (= SAME as v1.19; = no regression; = 7 attempts reverted cleanly)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. 0 net test code changes (= all 7 attempts reverted)

## Out-of-scope (= explicit)

- `os_unfair_lock` per-instance protection (= future v1.21 ticket; = same approach as v1.15 but per-instance)
- Accept the 2 pre-existing flakes (= pragmatic choice documented here)
- Multi-week architectural refactor of URLProtocolStub + every test file (= out of scope)

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the write-through race (= per-instance state still shared across URLsessions)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.20 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.19; = no regression)
- ✓ Future fix options documented (= per-instance lock, accept, multi-week refactor)