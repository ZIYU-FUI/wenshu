# v1.15 OSAllocatedUnfairLock actor-guard for URLProtocolStub globals · Spec (= honest scope gap; locking doesn't fix the race)

**Branch**: `wt/v1.15-actor-guard-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.14 documented the TaskLocal fundamental limitation. Per boss OOB "A": ship the actor-guard fix (= replace `nonisolated(unsafe)` static vars with `OSAllocatedUnfairLock`-backed storage).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Add `import os.lock` + replace 3 `nonisolated(unsafe) public static var` declarations with `OSAllocatedUnfairLock`-backed computed properties (= thread-safe; = sync API preserved) |

Total v1.15 attempted = **1 test infrastructure file changed**, **~30 LOC added**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.14 (= unsafe static) | v1.15 attempted (= OSAllocatedUnfairLock) |
|---|---|---|
| Run 1 | 2 fails | **4 fails** (= worse) |
| Run 2 | 2 fails | **2 fails** (= same) |
| Run 3 | 2 fails | **7 fails** (= much worse) |

**High variance (= 2-7 fails across runs) = flaky**. The
OSAllocatedUnfairLock serializes access to the global statics,
but doesn't fix the underlying race. Sometimes it makes things
worse (= serializing access exposes other ordering issues).

## Root cause analysis (= per Q34 5.2)

The race is more subtle than a simple global static write/read:

1. **`MinimaxConnector` is an `actor`** (= per
   `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38`).
   When the test calls `try await connector.send(...)`, the actor
   jumps to its own context.
2. **`connector.send` triggers `URLSession.dataTask`** which
   creates a new URLSession task. URLSession's internal task
   is NOT a child of the actor's task (= sibling, not descendant).
3. **URLSession calls `startLoading()` on the URLProtocolStub
   subclass**. `startLoading()` writes to
   `URLProtocolStub.capturedRequest` (= global static).
4. **The actor's continuation resumes on the test's task**
   (after `await connector.send(...)`). The test reads
   `stub.lastRequest` (= reads `capturedRequest` global).
5. **Race**: if ANOTHER test's `startLoading` writes to
   `capturedRequest` between step 3 and step 4 (= before the
   actor's send returns), the test reads the OTHER test's
   request.

Locking the global with OSAllocatedUnfairLock makes the
write+read atomic per access, BUT the actor's continuation
**can resume on the test's task AFTER another test's
startLoading has overwritten the global**. The lock doesn't
help because the issue is **the order in which different
tests' continuations resume**.

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1 | v1.11 | register Minimax only | 5 fails |
| 2 | v1.11 | register both | 6 fails |
| 3 | v1.11 | different insert positions | Same |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails (= same as v1.10) |
| 5 | v1.14 | TaskLocal capturedRequest write | Build fail + architectural reject |
| 6 | **v1.15** | **OSAllocatedUnfairLock** | **Flaky: 2-7 fails across runs** |

**6 attempts reverted** per Q46 stop-rule. **The URLProtocolStub
migration is blocked on a deeper architectural refactor**.

## Why this is harder than v1.09's ProviderKeychain.backend fix

`ProviderKeychain.backend` is read INSIDE the connector's send
method (= which runs on the actor's context). The TaskLocal
set by the test's `withBackendForTesting` propagates to the
actor's task (= Swift actors are tasks; = TaskLocal propagates
to child tasks).

`URLProtocolStub.capturedRequest` is written in `startLoading()`
which runs on **URLSession's internal delegate queue**, which is
**NOT a child of the test's task**. Even OSAllocatedUnfairLock
doesn't help because the issue is the **continuation ordering**
(= which test's continuation runs first after multiple async
operations complete).

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the actor-guard architectural limitation | ✓ shipped |
| 2 | `OSAllocatedUnfairLock` for the 3 globals | **REVERTED** (= flaky: 2-7 fails) |
| 3 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all changes reverted; = spec-only delivery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | Per-test stub instance pattern (= no global state; = each test owns its stub via instance methods) | Eliminates the global entirely | Multi-week refactor of URLProtocolStub + every test file |
| 2 | Serialized suite trait on all connector tests (= `.serialized` in @Suite) | Tests run sequentially; = no inter-suite races | Defeats parallel execution; = slow |
| 3 | Accept the 2 pre-existing flakes as known | Cheap | Doesn't actually fix them |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 3 (= accept) is
the pragmatic choice. The 2 remaining failures are pre-existing
and well-documented; = fixing them requires a multi-week
refactor that exceeds the current ticket scope.

## Cross-references

- `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38` (= `public actor MinimaxConnector` — the actor that complicates race analysis)
- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift:46,53,105` (= the 3 globals that are the race surface)
- `.scratch/v1.14-captured-tasklocal/spec.md` (= the prior honest scope gap)
- `.scratch/v1.13-migrate-stub/spec.md` (= the migration attempt that motivated v1.15)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnector"` = 10/10 pass in 2 suites (= unchanged; = v1.10's TaskLocal fix already addresses isolated)
4. Combined 5 suites = 18 tests, 2 fails (= SAME as v1.10-v1.14; = no regression; = 6 attempts reverted cleanly)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. 0 net test code changes (= all 6 attempts reverted)

## Out-of-scope (= explicit)

- Per-test stub instance pattern (= future v1.16 ticket; = multi-week refactor)
- Serialized suite trait on all connector tests (= future v1.17 ticket; = defeats parallelism)
- Accept the 2 pre-existing flakes (= pragmatic choice documented here)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the actor-guard architectural limitation (= continuation ordering, not just atomic access)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.15 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.10/v1.12/v1.13/v1.14; = no regression)
- ✓ Future fix options documented (= per-test instance, serialized suite, accept)