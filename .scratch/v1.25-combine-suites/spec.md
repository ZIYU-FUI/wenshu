# v1.25 Combine 5 connector suites into 1 parent suite · Spec (= honest scope gap; @Suite nesting multiplies test count)

**Branch**: `wt/v1.25-combine-suites-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A" → "B"

## Context

v1.24 closed the URLProtocolStub migration arc as an acceptance
(= 2 pre-existing MinimaxConnectorTests flakes accepted as known).
Per boss OOB 2026-09-14 "A 推完了, 推 B": ship the multi-file
refactor to combine 5 connector suites into 1 parent suite
with `.serialized` (= the future fix option #1 from AGENTS.md §11.5).

## Scope (= multi-file refactor per boss approval)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/Connector-tests/_old/MinimaxConnectorTests.swift` | Move (= delete original) |
| 2 | `Tests/WenshuAppTests/Agent/connector-tests/_old/OpenAIConnectorTests.swift` | Move (= delete original) |
| 3 | `Tests/WenshuAppTests/Agent/connector-tests/_old/DeepSeekConnectorTests.swift` | Move (= delete original) |
| 4 | `Tests/WenshuAppTests/Agent/connector-tests/_old/OllamaConnectorTests.swift` | Move (= delete original) |
| 5 | `Tests/WenshuAppTests/Agent/connector-tests/_old/OpenRouterConnectorTests.swift` | Move (= delete original) |
| 6 | `Tests/WenshuAppTests/Agent/ConnectorTests.swift` | Create (= combined parent with all 5 nested suites) |

Total v1.25 attempted = **5 files moved + 1 file created**, **~556 LOC moved**.

## What was attempted

Combined all 5 connector test files into a single
`ConnectorTests.swift` with:
- Parent `@Suite("ConnectorTests", .serialized)` struct
- 5 nested `@Suite` classes (= one per original suite)
- All `@Test` methods moved into their respective nested class
- 2 private helper functions at file scope

## Empirical validation (= per Q34 5.4)

| Run | v1.24 (= 5 separate files) | v1.25 attempted (= combined) |
|---|---|---|
| Run 1 | 0-7 fails (= inherent variance) | **49 tests, 13 fails** (= WORSE; = tests multiplied) |
| Run 2 | 0-7 fails | **49 tests, 11 fails** (= WORSE) |
| Run 3 | 0-7 fails | **49 tests, 13 fails** (= WORSE) |

**Build: BUILD COMPLETE in 163s**. Test discovery worked (= 49 tests run = 18 original tests + nested duplicates), but the @Suite nesting pattern doesn't achieve cross-suite serialization as hoped.

## Root cause analysis (= per Q34 5.2)

The `@Suite` nested type pattern (= parent struct with nested
classes) doesn't achieve the cross-suite serialization that
the v1.25 design intended. Swift Testing runs the nested
classes as separate suites; = `@Suite(.serialized)` on the
parent does NOT serialize the nested children.

The 49 tests (= 18 original + extra discoveries) suggests
Swift Testing may be running each @Test multiple times due to
nested type discovery. The exact behavior depends on Swift
Testing's internal suite composition algorithm.

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
| 11 | **v1.25** | **@Suite nested types (multi-file)** | **49 tests, 11-13 fails (= worse than baseline)** |

**11 attempts reverted**. The URLProtocolStub migration arc
remains closed at v1.24 (= acceptance closure); = v1.25 was a
re-open attempt that failed.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting the @Suite nesting failure | ✓ shipped |
| 2 | Combined `ConnectorTests.swift` with 5 nested suites | **REVERTED** (= tests multiplied) |
| 3 | 5 source files deleted | **RESTORED** (= all 5 back in place) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= all experimental changes reverted; = spec-only delivery).

## Why this approach failed

The `@Suite` nested type pattern (= struct with nested
classes, each decorated with `@Suite`) doesn't achieve the
cross-suite serialization that the v1.25 design intended.

Per Swift Testing documentation: `@Suite(.serialized)` on a
parent does NOT serialize the nested children. Each nested
class is its own suite (= which may or may not be serialized
itself; = depends on whether each has its own `.serialized`
trait).

Additionally, **Swift Testing may discover the same @Test
multiple times when nested types are involved** (= the 49
tests run vs the 18 expected tests suggests duplicate
discovery).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Why it works | Why it's deferred |
|---|---|---|---|
| 1 | **Use a process-wide test ordering lock** (= `static let _testLock` in URLProtocolStub.swift + `init()` in each suite acquires the lock) | Cross-suite serialization | Multi-file change; = requires v1.24 acceptance to be reversed |
| 2 | **Accept the variance** (= current state per v1.24) | Cheap | Doesn't fix |
| 3 | **Make `MinimaxConnector` non-actor** (= production code change) | Eliminates actor race | Violates Q112; = production code change |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 2 (= accept the
variance) is the pragmatic choice. The v1.24 acceptance
closure stands.

## Cross-references

- `AGENTS.md §11.5` (= the acceptance closure from v1.24)
- `.scratch/v1.23-shared-serialization/spec.md` (= the prior spec documenting the multi-file refactor)
- `.scratch/v1.22-serialized/spec.md` (= the prior spec documenting the variance)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= all changes reverted)
2. All 5 original connector test files RESTORED
3. Variance observed: 0-7 fails (= SAME as v1.24 baseline)
4. 0 production code changes
5. 0 net test code changes (= all 11 attempts reverted)

## Out-of-scope (= explicit)

- Process-wide test ordering lock (= future v1.26+ ticket; = requires v1.24 acceptance reversal)
- Accept the variance as known (= already done in v1.24)
- Make `MinimaxConnector` non-actor (= production code change; = violates Q112)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents the @Suite nesting failure
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.25 ships as spec-only (= no production code, no test code)
- ✓ v1.24 acceptance closure stands (= variance = known)
- ✓ Future fix options documented (= process-wide lock, accept, non-actor)