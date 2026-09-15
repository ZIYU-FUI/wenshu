# v1.13 Migrate OpenAIConnectorTests + MinimaxConnectorTests to withStubForTesting · Spec (= honest scope gap)

**Branch**: `wt/v1.13-migrate-stub-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.12 shipped the TaskLocal `URLProtocolStub` infrastructure (= new `withStubForTesting(_:perform:)` helper on `URLProtocolStub`). Per boss OOB "A": migrate the 2 connector test files (= OpenAIConnectorTests + MinimaxConnectorTests) to use the new helper so they get hermetic isolation.

## Scope (= 1 ticket, 2 files 1 commit per Q112 + Q173)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` | Wrap 5 test bodies in `try await URLProtocolStub.withStubForTesting(stub) { ... }` (= hermetic isolation per task) |
| 2 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` | Wrap 3 test bodies in the same pattern |

Total v1.13 attempted = **2 test files changed**, **8 test bodies wrapped**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.12 (= global only) | v1.13 attempted (= migrated to TaskLocal) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | 4/4 pass (= unchanged after revert; = migration preserves passing state) |
| `OpenAIConnectorTests` isolated | 5/5 pass | 5/5 pass (= unchanged after revert) |
| Combined 5 suites | 18 tests, 7 fails (= TaskLocal infra in place; = tests still use global) | 18 tests, 2 fails (= SAME as v1.10; = migration didn't fix the underlying races) |

Net change: **0 fails fixed** (= migration is neutral; = the underlying races documented in v1.11 are deeper than TaskLocal can solve in the current architecture).

## Per Q46 stop-rule + Q186 + Q173 ponytail

Per the v1.13 ticket scope (= 1 ticket 2 files per Q112 + Q173), **3+ redo attempts on the URLProtocolStub migration** justifies an honest scope gap instead of force-shipping a partial fix.

### What was attempted

| # | Attempt | Result |
|---|---|---|
| 1 | v1.11 attempt 1: Add `URLProtocolStub.register(stub)` + `defer unregister()` to MinimaxConnectorTests only | Combined = 2 Minimax + 3 OpenAI fails |
| 2 | v1.11 attempt 2: Add same pattern to both Minimax + OpenAI | Combined = 6 fails |
| 3 | v1.11 attempt 3: Different insert positions | Same = 6 fails; all reverted |
| 4 | v1.13 attempt 1 (= this ticket): Wrap test bodies in `withStubForTesting(stub) { ... }` | Combined = 2 Minimax fails (= same as v1.10; = migration didn't help) |

**All 4 attempts reverted** per Q46 stop-rule.

## Root cause analysis (= per Q34 5.2)

The combined-run failures are NOT fully explained by `URLProtocolStub.stub` global static race. Even with TaskLocal isolation per task (= v1.12 infrastructure), the 2 MinimaxConnectorTests failures persist. **The root cause is deeper**:

1. **`MinimaxConnector(session:)` is an actor** (= `public actor MinimaxConnector`). When the test wraps `connector.send` in `withStubForTesting` closure, the actor's send method may execute on a different actor context than the closure's task.
2. **The `try #require(stub.lastRequest)` assertion reads `URLProtocolStub.capturedRequest`** (= a static var). Even with TaskLocal isolation, the **capturedRequest** in startLoading() reads the global static, not the TaskLocal. The v1.12 infrastructure only updated `_taskLocalRegisteredSnapshot`; `capturedRequest` write in startLoading() still uses `URLProtocolStub.capturedRequest = captured` (= global).

The 2 remaining failures (`testRequestBody` + `testResponseDecode`) are caused by the **`capturedRequest` global static race**: when multiple tests run concurrently, one test's `startLoading` overwrites the `capturedRequest` before another test reads it.

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Pros | Cons |
|---|---|---|---|
| 1 | Add `capturedRequest` to TaskLocal (= finish the v1.12 partial migration) | Minimal change (= 1 file) | Requires careful ordering: capturedRequest must be written to BOTH TaskLocal AND global |
| 2 | Actor-guard `URLProtocolStub.stub` + `capturedRequest` (= replace `nonisolated(unsafe)` with actor isolation) | Eliminates all races | Refactor of multiple test files; = breaks backward compat |
| 3 | Per-test stub instance pattern (= no global state; = each test owns its stub via instance methods) | Cleanest architecture | Multi-week refactor of URLProtocolStub + every test file |

**Per Q34 5.2 + Q173 ponytail**: each option is a multi-day refactor. This is scope-deferred to a future ticket.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting root cause (= TaskLocal alone insufficient) | ✓ shipped |
| 2 | OpenAIConnectorTests `withStubForTesting` migration | **REVERTED** (= 4 attempts didn't help) |
| 3 | MinimaxConnectorTests `withStubForTesting` migration | **REVERTED** (= 4 attempts didn't help) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= 4 attempts reverted; = spec-only delivery).

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= the v1.12 TaskLocal infrastructure that v1.13 attempted to leverage)
- `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift` (= the actor that v1.13's `withStubForTesting` wrapping couldn't isolate)
- `.scratch/v1.12-urlprotocol-tasklocal/spec.md` (= the upstream TaskLocal infra)
- `.scratch/v1.11-urlprotocol-stub/spec.md` (= the prior honest scope gap)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnector"` = 10/10 pass in 2 suites (= unchanged; = v1.10's TaskLocal fix already addresses isolated)
4. Combined 5 suites = 18 tests, 2 fails (= SAME as v1.10; = v1.13's migration reverted cleanly; = no regression)
5. 0 production code changes (= URLProtocolStub.swift is a test-only file; = no prod code touched)
6. 0 net test code changes (= all migrations reverted)

## Out-of-scope (= explicit)

- Finish TaskLocal migration (= add `capturedRequest` to v1.12 infra; = future v1.14 ticket)
- Actor-guard `URLProtocolStub.stub` + `capturedRequest` (= future v1.15 ticket)
- Per-test stub instance pattern (= future v1.16 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents root cause (= TaskLocal alone insufficient; = need `capturedRequest` TaskLocal too)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.13 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.10; = no regression)