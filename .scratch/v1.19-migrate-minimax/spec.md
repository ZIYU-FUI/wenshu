# v1.19 Migrate MinimaxConnectorTests to makeIsolatedStub · Spec (= partial fix; MinimaxConnector actor race)

**Branch**: `wt/v1.19-migrate-minimax-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.18 migrated OpenAIConnectorTests to `makeIsolatedStub` (= OpenAI isolated tests pass cleanly). Per boss OOB "A": migrate MinimaxConnectorTests the same way.

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` | Migrate 3 test bodies to `URLProtocolStub.makeIsolatedStub()` (= replaces `let stub = URLProtocolStub()` + `config.protocolClasses = [URLProtocolStub.self]`) |

Total v1.19 = **1 test file changed**, **3 test bodies migrated**, **0 production code changes**.

## What this ticket ships

Same pattern as v1.18: each test gets its own URLProtocol subclass (= uniquely generated) + own stub instance.

## Empirical validation (= per Q34 5.4)

| Run | v1.18 (= OpenAI migrated, Minimax global) | v1.19 (= both migrated) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | **4/4 pass** (= unchanged; = isolated was already passing) |
| `OpenAIConnectorTests` isolated | 10/10 pass in 2 suites | **10/10 pass** (= unchanged; = v1.18 already fixed isolated) |
| Combined 5 suites | 18 tests, 4 fails (= variance) | **18 tests, 2 fails** (= improved by 2) |

**Net improvement: 2 issues fixed** (= combined run now has 2 fails instead of 4).

## Remaining issues (= pre-existing MinimaxConnector actor race)

| # | Failing test | Root cause |
|---|---|---|
| 1 | `MinimaxConnectorTests.testRequestBody` | `MinimaxConnector` is `actor`; = `connector.send` runs on actor context; = continuation ordering race documented in v1.15 |
| 2 | `MinimaxConnectorTests.testResponseDecode` | Same root cause (= MinimaxConnector actor + URLSession interaction) |

**Per Q34 5.2**: The `MinimaxConnector` actor + URLSession interaction causes the race. When the actor's continuation resumes after `await connector.send(...)`, **another test's URLSession may have written to `_isolatedCapturedRequest` first** (= per the v1.17 routing, the isolated stub writes to per-instance state, but the instance is the URLSession-created one (= not the test's stub). The per-instance write goes to the URLSession-created instance's `_isolatedCapturedRequest` (= which the test cannot read because the test holds the original stub instance, not the URLSession-created one).

**Per Q34 5.2 + Q173 ponytail + Q186 + Q57**: this is a deeper architectural issue. The isolated pattern fixes the **write** (= per-instance state) but not the **read** (= test reads its own stub instance's `_isolatedCapturedRequest` which is never set because the URLSession-created instance wrote to ITS `_isolatedCapturedRequest`).

## The deeper architectural issue

| # | Layer | What happens |
|---|---|---|
| 1 | Test creates `(stub, stubProtocolClass) = makeIsolatedStub()` | Test gets `stub` (= URLProtocolStub instance, `_isolatedCapturedRequest = nil`) |
| 2 | Test calls `connector.send(...)` | Actor call (= jumps to actor context) |
| 3 | Connector calls `URLSession.dataTask` | URLSession creates a NEW URLProtocolStub instance (= via runtime-generated subclass) |
| 4 | URLSession calls `startLoading()` on the new instance | `routeToIsolatedStub` looks up the associated stub (= the test's `stub`) |
| 5 | `routeToIsolatedStub` writes to `_isolatedCapturedRequest` | **But on the URLSession-created instance** (= NOT the test's `stub`) |
| 6 | Test reads `stub.lastRequest` (= the test's instance) | Returns `nil` because `_isolatedCapturedRequest` on THIS instance was never written |

**The isolated pattern needs to also write to the test's stub instance**, not just to the URLSession-created instance. This requires modifying the test's `stub.lastRequest` to read from the associated stub (= or write through to the associated stub's state).

## Per-ticket acceptance criteria

### Ticket 001 — MinimaxConnectorTests migration

- ✓ `swift build` = BUILD COMPLETE
- ✓ `swift test --filter "MinimaxConnector"` = **4/4 pass** (= isolated works)
- ✓ All 3 test bodies use `makeIsolatedStub`
- ✓ Combined run improved: 18 tests, 4 fails → 2 fails (= 2 issues fixed)
- ⏸ Remaining 2 issues = `MinimaxConnector` actor race (= future v1.20 ticket)

## Cross-references

- `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` (= this ticket's primary target; = 3 test bodies migrated)
- `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38` (= `public actor MinimaxConnector` — the actor that complicates race analysis)
- `.scratch/v1.18-migrate-openai/spec.md` (= the upstream OpenAI migration that v1.19 mirrors)
- `.scratch/v1.17-startloading-override/spec.md` (= the routing override)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnector"` = **4/4 pass**
3. `swift test --filter "OpenAIConnector"` = **10/10 pass** in 2 suites
4. Combined 5 suites = **18 tests, 2 fails** (= improved from 4 fails in v1.18)
5. 0 production code changes (= MinimaxConnectorTests.swift is a test-only file)

## Out-of-scope (= explicit)

- Fix the MinimaxConnector actor race (= future v1.20 ticket; = needs to write `_isolatedCapturedRequest` on the test's stub instance, not just the URLSession-created one)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria

### Ticket 001 — MinimaxConnectorTests migration

- ✓ `swift build` = BUILD COMPLETE
- ✓ All 3 test bodies use `makeIsolatedStub`
- ✓ Isolated test runs (= Minimax, OpenAI) all pass (= 14/14)
- ✓ Combined run improved: 4 fails → 2 fails
- ⏸ Remaining 2 fails = MinimaxConnector actor race (= future v1.20 ticket)