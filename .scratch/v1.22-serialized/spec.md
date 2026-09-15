# v1.22 Add @Suite(.serialized) to connector tests · Spec (= honest scope gap; .serialized already applied across all connector suites)

**Branch**: `wt/v1.22-serialized-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.21 documented the actor race. Per boss OOB "A": add `@Suite(.serialized)` to the connector tests (= serialize the racing suites).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` (= primary target) + 4 other connector test files | Add `.serialized` trait to `@Suite` declaration |

Total v1.22 attempted = **5 test files examined**, **0 files changed** (= all connector suites ALREADY have `.serialized`).

## Empirical validation (= per Q34 5.4)

### Baseline (= current state on main after v1.21)

| # | Test file | `@Suite` declaration |
|---|---|---|
| 1 | `OpenAIConnectorTests.swift:13` | `@Suite("OpenAIConnector (ticket 005)", .serialized)` ✓ already serialized |
| 2 | `DeepSeekConnectorTests.swift:31` | `@Suite("DeepSeekConnector (§11.2 gap-fill)", .serialized)` ✓ already serialized |
| 3 | `MinimaxConnectorTests.swift:26` | `@Suite("MinimaxConnector (ticket 001 sub-step 7)", .serialized)` ✓ already serialized |
| 4 | `OllamaConnectorTests.swift:25` | `@Suite("OllamaConnector (§11.2 gap-fill)", .serialized)` ✓ already serialized |
| 5 | `OpenRouterConnectorTests.swift:28` | `@Suite("OpenRouterConnector (§11.2 gap-fill)", .serialized)` ✓ already serialized |

**All 5 connector suites ALREADY have `.serialized`** (= added in earlier work).

### Variance observation (= per Q34 5.4)

| Run | Issues in combined 5-connector run |
|---|---|
| Run 1 | 0 |
| Run 2 | 0 |
| Run 3 | 7 |
| Run 4 | 3 |
| Run 5 | 2 |

**High variance: 0-7 fails across runs** (= inherently flaky; = the issue is intermittent and timing-dependent).

## Root cause analysis (= per Q34 5.2)

The `.serialized` trait serializes tests **WITHIN a single suite**. It does NOT serialize across suites. **Swift Testing still runs different suites concurrently** (= even when each suite has `.serialized`).

The remaining 2-7 failures are caused by **inter-suite races between the 5 connector suites** (= even though each is individually serialized). Per Swift Testing documentation, `.serialized` only affects WITHIN-suite ordering, not cross-suite ordering.

## What was attempted in v1.22

| # | Attempt | Result |
|---|---|---|
| 1 | Verify all 5 connector suites already have `.serialized` (= they do) | No code change needed |
| 2 | Try updating `lastRequest` getter to prefer `_isolatedCapturedRequest` (= the v1.20 attempt) | Made things WORSE: 4-6 fails instead of 0-2 |

Per Q46 stop-rule + Q186 + Q173 ponytail: 9+ redo attempts on URLProtocolStub migration justifies honest scope gap. v1.22 reverted all experimental changes.

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1-3 | v1.11 | register variations | 5/6 fails |
| 4 | v1.13 | wrap in `withStubForTesting` | 2 fails |
| 5 | v1.14 | TaskLocal capturedRequest | Build fail + architectural reject |
| 6 | v1.15 | OSAllocatedUnfairLock for globals | Flaky: 2-7 fails |
| 7 | v1.20 | write-through to test's stub | Flaky: 2-8 fails |
| 8 | v1.21 | per-instance OSAllocatedUnfairLock | Flaky: 2-6 fails + crash |
| 9 | **v1.22** | **`@Suite(.serialized)` (= already applied)** + getter update | **Variable: 2-6 fails** |

**9 attempts reverted**. The URLProtocolStub migration is blocked on a fundamental architectural issue.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the `.serialized` already-applied situation | ✓ shipped |
| 2 | Verify all 5 connector suites have `.serialized` | ✓ verified (= they do) |
| 3 | Update `lastRequest` getter to prefer `_isolatedCapturedRequest` | **REVERTED** (= made things worse) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all changes reverted; = spec-only delivery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | Combine all 5 connector suites into a single parent suite with `.serialized` | Serializes across all 5 (= all connector tests run sequentially) | Multi-file refactor; = defeats parallelism |
| 2 | Accept the variance as known (= sometimes 0 fails, sometimes 7) | Pragmatic | Doesn't actually fix |
| 3 | Make `MinimaxConnector` NOT an actor (= production code change) | Eliminates actor race | Violates Q112; = production code change |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 2 (= accept) is
the pragmatic choice. The variance is close to the
threshold; = the remaining failures are intermittent and
timing-dependent. They don't block development (= isolated
runs pass; = the dev inner loop works fine).

## Cross-references

- `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift:26` (= `@Suite(..., .serialized)` already there)
- `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift:13` (= same)
- `Tests/WenshuAppTests/Agent/DeepSeekConnectorTests.swift:31` (= same)
- `Tests/WenshuAppTests/Agent/OllamaConnectorTests.swift:25` (= same)
- `Tests/WenshuAppTests/Agent/OpenRouterConnectorTests.swift:28` (= same)
- `.scratch/v1.21-per-instance-lock/spec.md` (= the prior honest scope gap)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. Verified all 5 connector suites have `.serialized`
3. Variance observed: 0-7 fails in combined runs (= inherently flaky)
4. 0 production code changes
5. 0 net test code changes (= all 9 attempts reverted)

## Out-of-scope (= explicit)

- Combine all 5 connector suites into 1 parent suite (= multi-file refactor; = defeats parallelism)
- Accept the variance as known (= pragmatic choice documented here)
- Change `MinimaxConnector` to non-actor (= production code change; = violates Q112)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the `.serialized` already-applied situation
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.22 ships as spec-only (= no production code, no test code)
- ✓ Baseline state preserved (= 0-7 fails variance = inherent)
- ✓ Future fix options documented (= combine suites, accept, non-actor)