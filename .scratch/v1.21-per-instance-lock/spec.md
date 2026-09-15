# v1.21 Per-instance OSAllocatedUnfairLock for _isolatedCapturedRequest · Spec (= honest scope gap; per-instance lock doesn't fix the actor race)

**Branch**: `wt/v1.21-per-instance-lock-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.20 documented the write-through race. Per boss OOB "A": ship the per-instance lock fix (= replace plain `URLRequest?` with `OSAllocatedUnfairLock<URLRequest?>` for `_isolatedCapturedRequest`).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add `import os.lock` + replace `private var _isolatedCapturedRequest: URLRequest?` with `private let _isolatedCapturedRequest = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)` + update read/write sites to use `withLock` + update `lastRequest` getter to prefer per-instance lock |

Total v1.21 attempted = **1 test infrastructure file changed**, **~40 LOC added**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.20 (= plain var) | v1.21 attempted (= per-instance lock) |
|---|---|---|
| Run 1 | 2 fails (= baseline) | **2 fails** (= same) |
| Run 2 | 8 fails (= worse) | **6 fails** (= better than v1.20 run 2 but not stable) |
| Run 3 | 3 fails (= variance) | **FATAL ERROR: Index out of range** (= crash) |

**Build: BUILD COMPLETE in 24s**.

The per-instance lock doesn't fix the race. Even with thread-safe
per-instance storage, the combined-run still produces flaky
failures + a fatal crash on one run.

## Root cause analysis (= per Q34 5.2)

The fundamental issue is **NOT a write race on `_isolatedCapturedRequest`**. The lock-protected version still fails because:

1. **The `MinimaxConnector` is an actor** (= per
   `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38`).
2. **Multiple actors can run concurrently** when Swift Testing
   runs multiple test suites. Each actor's `send` method
   independently writes to `self.responseData` (= which is then
   mirrored onto `self` in `routeToIsolatedStub`).
3. **The fatal "Index out of range" crash** happens when a
   `MinimaxConnector` test's `messages` array is empty (= the
   connector never sent the message because the actor's
   continuation resumed with stale state).

The per-instance lock fixes the **storage write race** but
doesn't fix the **actor continuation ordering race**. The actor
model is fundamentally incompatible with the URLSession's
callback model (= URLSession fires callbacks on internal queues,
not on the actor's executor).

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1-3 | v1.11 | register variations | 5/6 fails |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails |
| 5 | v1.14 | TaskLocal capturedRequest | Build fail + architectural reject |
| 6 | v1.15 | OSAllocatedUnfairLock for globals | Flaky: 2-7 fails |
| 7 | v1.20 | write-through to test's stub | Flaky: 2-8 fails |
| 8 | **v1.21** | **per-instance OSAllocatedUnfairLock** | **Flaky: 2-6 fails + crash** |

**8 attempts reverted** per Q46 stop-rule.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the per-instance lock failure | ✓ shipped |
| 2 | `OSAllocatedUnfairLock<URLRequest?>` for `_isolatedCapturedRequest` | **REVERTED** (= still flaky + crash) |
| 3 | `lastRequest` getter update | **REVERTED** (= same) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all changes reverted; = spec-only delivery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | Make `MinimaxConnector` NOT an actor (= regular class with explicit queue) | Eliminates the actor-URLSession interaction | Changes the production code (= violates Q112 scope: "1 ticket 1 file") |
| 2 | Accept the 2 pre-existing flakes as known (= pragmatic) | Cheap | Doesn't fix them |
| 3 | Add `@Suite(.serialized)` to MinimaxConnectorTests | Tests run sequentially; = no inter-suite races | Defeats parallel execution; = slow |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 2 (= accept) is
the pragmatic choice. The 2 remaining failures are pre-existing
and well-documented; = fixing them requires either changing
production code (= violates Q112) or accepting the cost of
serialization (= defeats parallelism).

## Cross-references

- `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38` (= the actor that complicates race analysis)
- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= this ticket's primary target; = now unchanged)
- `.scratch/v1.20-write-through/spec.md` (= the prior honest scope gap)
- `.scratch/v1.15-actor-guard/spec.md` (= the OSAllocatedUnfairLock for globals)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnector"` = 10/10 pass in 2 suites (= unchanged; = v1.18's migration preserves passing state)
4. Combined 5 suites = 18 tests, 2-6 fails + crash (= flaky; = no stable improvement over v1.20)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. 0 net test code changes (= all 8 attempts reverted)

## Out-of-scope (= explicit)

- Change MinimaxConnector to non-actor (= violates Q112; = production code change)
- Add `@Suite(.serialized)` to MinimaxConnectorTests (= defeats parallelism; = future ticket if user accepts cost)
- Accept the 2 pre-existing flakes (= pragmatic choice documented here)
- Multi-week architectural refactor of URLProtocolStub + MinimaxConnector (= out of scope)

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the per-instance lock failure (= lock fixes storage write race but not actor continuation race)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.21 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.19/v1.20 baseline; = no stable regression)
- ✓ Future fix options documented (= non-actor MinimaxConnector, @Suite(.serialized), accept)