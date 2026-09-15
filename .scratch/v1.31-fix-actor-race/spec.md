# v1.31 MinimaxConnector actor→class conversion · Spec (= honest scope gap; race not fixed)

**Branch**: `wt/v1.31-fix-actor-race-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "我想把这些修掉" (= let's fix these)

## Context

Per boss OOB 2026-09-14 "我想把这些修掉" (= fix the items from
the previous summary): the 2 MinimaxConnectorTests flakes were
accepted in v1.24 §11.5 closure. v1.31 attempts the real fix
per §11.5 option #3 (= make `MinimaxConnector` not an actor).

## Scope (= 1 ticket, 1 file 1 commit per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift` | Convert `public actor MinimaxConnector: LLMConnector` → `public final class MinimaxConnector: LLMConnector, @unchecked Sendable` |

## Empirical validation (= per Q34 5.4)

| Run | v1.24 baseline | v1.31 attempted |
|---|---|---|
| MinimaxConnector isolated | 4/4 pass | **4/4 pass** |
| Combined 5 connectors | 0-7 fails variance | **2-4 fails** (= WORSE) |
| Build | BUILD COMPLETE in 96.67s | BUILD COMPLETE |

**Reverted** per Q46 stop-rule + Q186 (= same race; = different
location = URLSession's internal queue, not the actor).

## Root cause analysis (= per Q34 5.2)

The actor was NOT the root cause. Even with `actor` → `class`
conversion, the combined-run race persists because:

1. URLSession creates its own tasks internally (= not children
   of the test body's task)
2. URLProtocolStub's global `stub` + `capturedRequest` statics
   are written by URLSession's internal delegate queue
3. The test body reads from the same globals on the test's task
4. The race is between URLSession's writer and the test's reader

Removing the actor from `MinimaxConnector` doesn't fix the
underlying `URLProtocolStub` global race.

## Per Q46 stop-rule + Q186 + Q173 ponytail

This is attempt **#13** on URLProtocolStub migration (= v1.11
through v1.31). Per Q46: **STOP** and ship honest scope gap.

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1-3 | v1.11 | register variations | 5/6 fails |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails |
| 5 | v1.14 | TaskLocal capturedRequest | Build fail |
| 6 | v1.15 | OSAllocatedUnfairLock for globals | Flaky 2-7 |
| 7 | v1.20 | write-through | Flaky 2-8 |
| 8 | v1.21 | per-instance lock | Flaky 2-6 + crash |
| 9 | v1.22 | @Suite serialized (= already applied) | 0-7 variance |
| 10 | v1.23 | multi-file refactor (>Q112) | spec-only |
| 11 | v1.25 | @Suite nesting multiplies tests | 49 tests, 11-13 fails |
| 12 | v1.26 | migrate Anthropic + Gemini | 8 tests, 1-4 fails + crash |
| 13 | **v1.31** | **actor→class** | **4 fails** (= same race) |

**13 attempts reverted**.

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Notes |
|---|---|---|
| 1 | Add process-wide test ordering lock (= v1.32) + per-test init() acquires (= future ticket) | Multi-file change; = boss主动推 OK |
| 2 | Move MinimaxConnector to non-actor (= v1.31 done but didn't fix) | Already tried; = insufficient |
| 3 | Accept the variance as known | Per v1.24 §11.5 acceptance closure |

## What this ticket ships (= honest scope gap)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting v1.31 attempt failure | ✓ shipped |
| 2 | `actor` → `class` change in `MinimaxConnector.swift` | **REVERTED** (= race not fixed) |
| 3 | Production code change (= if any) | None |

**Net change to main**: 0 lines.

## Cross-references

- `AGENTS.md §11.5` (= v1.24 acceptance closure)
- `.scratch/v1.20-write-through/spec.md` (= prior write-through attempt)
- `.scratch/v1.21-per-instance-lock/spec.md` (= prior per-instance lock attempt)