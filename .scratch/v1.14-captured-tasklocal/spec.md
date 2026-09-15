# v1.14 Finish URLProtocolStub TaskLocal migration (= capturedRequest) · Spec (= honest scope gap; TaskLocal fundamental limitation)

**Branch**: `wt/v1.14-captured-tasklocal-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.13 documented the root cause for the 2 remaining `MinimaxConnectorTests` failures (= `URLProtocolStub.capturedRequest` global static race). Per boss OOB "A": finish the TaskLocal migration by adding `capturedRequest` to TaskLocal (= mirror v1.09's `ProviderKeychain.backend` fix).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` | Write `_taskLocalCapturedRequest` in `startLoading()` + prefer it in `lastRequest` getter |

Total v1.14 attempted = **1 test infrastructure file changed**, **~15 LOC added**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Attempt | Result |
|---|---|
| 1 | **Build failure**: `@TaskLocal` properties are get-only by design. Cannot assign to `_taskLocalCapturedRequest` outside `withValue` block. |
| 2 | **Architectural rejection**: Even if the assignment were possible, `URLSession.startLoading()` runs on a **different task** (= URLSession's internal delegate queue), NOT the test body's task. `TaskLocal` values set via `withValue` in the test body DO NOT propagate to `startLoading()`. This is a **fundamental TaskLocal limitation** (= not specific to URLProtocolStub; = affects any global state written in a callback that runs on a different task). |

## Root cause analysis (= per Q34 5.2)

The v1.13 spec correctly identified that `URLProtocolStub.capturedRequest` is a global static race. **However, TaskLocal is NOT the right tool** because:

1. **`startLoading()` is a callback invoked by URLSession on its internal delegate queue** (= a different task from the test body's task).
2. **TaskLocal values are scoped to the current task + child tasks**. URLSession's internal tasks are NOT children of the test body's task (= they are siblings of the test process's main task).
3. **Even if the test body wraps `connector.send` in `withStubForTesting`, the TaskLocal set there does NOT propagate to `URLSession.startLoading`'s task.**

This is documented Swift Concurrency behavior (= see SE-0311 "Task Local Values"): TaskLocals do not cross task boundaries unless via `Task { ... }` (= child tasks inherit the parent's TaskLocals; = but URLSession creates its own tasks internally, not from the test's task).

## Per Q46 stop-rule + Q186 + Q173 ponytail

Per the v1.14 ticket scope (= 1 ticket 1 file per Q112), **the architectural assumption was wrong**. Combined with prior attempts:

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1 | v1.11 | Add `URLProtocolStub.register` to Minimax only | 5 fails |
| 2 | v1.11 | Add to both Minimax + OpenAI | 6 fails |
| 3 | v1.11 | Different insert positions | Same |
| 4 | v1.13 | Wrap in `withStubForTesting` | 2 fails (= same as v1.10) |
| 5 | **v1.14** | **Add `_taskLocalCapturedRequest` write** | **Build failure + architectural rejection** |

**5 attempts reverted** per Q46 stop-rule.

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | Actor-guard `URLProtocolStub.stub` + `capturedRequest` (= replace `nonisolated(unsafe)` with actor isolation) | Eliminates all races; = serial access to globals | Requires updating URLProtocolStub + every test file that uses it |
| 2 | Per-test stub instance pattern (= no global state; = each test owns its stub via instance methods) | Cleanest architecture; = no shared state | Multi-week refactor of URLProtocolStub + every test file |
| 3 | `@MainActor` isolation on URLProtocolStub (= all access serialized via main actor) | Simple; = one-line change | May break parallel test execution (= defeats the purpose) |

**Per Q34 5.2 + Q173 ponytail**: each option is a multi-day refactor. This is scope-deferred to a future ticket.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the TaskLocal fundamental limitation | ✓ shipped |
| 2 | `_taskLocalCapturedRequest` write in `startLoading()` | **REVERTED** (= build failure + architectural rejection) |
| 3 | `lastRequest` getter update | **REVERTED** (= no longer needed without TaskLocal write) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all attempts reverted; = spec-only delivery).

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= the file where v1.14 attempted changes; = now unchanged)
- SE-0311 "Task Local Values" (= the Swift Concurrency proposal documenting TaskLocal scope behavior)
- `.scratch/v1.13-migrate-stub/spec.md` (= the prior honest scope gap that motivated v1.14)
- `.scratch/v1.12-urlprotocol-tasklocal/spec.md` (= the v1.12 TaskLocal infrastructure that v1.14 attempted to leverage)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnector"` = 10/10 pass in 2 suites (= unchanged; = v1.10's TaskLocal fix already addresses isolated)
4. Combined 5 suites = 18 tests, 2 fails (= SAME as v1.10/v1.12; = no regression; = 5 attempts reverted cleanly)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file)
6. 0 net test code changes (= all 5 attempts reverted)

## Out-of-scope (= explicit)

- Actor-guard `URLProtocolStub.stub` + `capturedRequest` (= future v1.15 ticket)
- Per-test stub instance pattern (= future v1.16 ticket)
- `@MainActor` isolation on URLProtocolStub (= future v1.17 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the TaskLocal fundamental limitation (= startLoading runs on different task; = TaskLocal doesn't propagate)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.14 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.10/v1.12; = no regression)
- ✓ Future fix options documented (= actor-guard, per-test instance, @MainActor)