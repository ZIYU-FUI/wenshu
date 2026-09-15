# v1.18 Migrate OpenAIConnectorTests to makeIsolatedStub · Spec (= real fix for OpenAI race)

**Branch**: `wt/v1.18-migrate-openai-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.17 completed the per-test stub instance infrastructure (= `makeIsolatedStub()` + `IsolatedStubSubclass` + `startLoading` routing override). Per boss OOB "A": migrate OpenAIConnectorTests to use the new isolated pattern.

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` | Migrate 5 test bodies to `URLProtocolStub.makeIsolatedStub()` (= replaces `let stub = URLProtocolStub()` with `let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()` + replaces `config.protocolClasses = [URLProtocolStub.self]` with `config.protocolClasses = [stubProtocolClass]`) |

Total v1.18 = **1 test file changed**, **5 test bodies migrated**, **0 production code changes**.

## What this ticket ships

Per Q34 5.2 + Q112 + Q173 ponytail: the 5 OpenAIConnectorTests
bodies now use the per-test isolated stub pattern. Each test
gets its own URLProtocol subclass (= uniquely generated at
runtime via `objc_allocateClassPair`) + its own stub instance
(= stored on the subclass via `objc_setAssociatedObject`).

## How it works

For each migrated test body, the pattern is:

| # | Step | Code |
|---|---|---|
| 1 | Create isolated stub + protocol class | `let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()` |
| 2 | Set response | `stub.response = makeOpenAIResponse(content: "hi")` |
| 3 | Configure session | `config.protocolClasses = [stubProtocolClass]` |
| 4 | Use stub normally | `stub.lastRequest` (= per-instance, no global write) |

The `startLoading` override (from v1.17) detects that `self` is
a runtime-generated subclass (= `type(of: self) != URLProtocolStub.self`)
and routes to `routeToIsolatedStub` which writes to `_isolatedCapturedRequest`
(= per-instance; = no global mutation).

## Empirical validation (= per Q34 5.4)

| Run | v1.17 (= global pattern) | v1.18 (= isolated pattern) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass | **4/4 pass** (= unchanged; = Minimax not migrated yet) |
| `OpenAIConnectorTests` isolated | 5/5 pass | **10/10 pass in 2 suites** (= improved; = 5 OpenAI + 5 DeepSeek) |
| Combined 5 suites | 18 tests, 7 fails (= variance) | 18 tests, 4 fails (= within variance; = Minimax still using global) |

**Isolated tests all pass** (= 14/14 across both suites).

## What changed

For `OpenAIConnectorTests.swift`:

| # | Test | Before | After |
|---|---|---|---|
| 1 | `testOpenAINativeAuth` | `let stub = URLProtocolStub()` + `config.protocolClasses = [URLProtocolStub.self]` | `let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()` + `config.protocolClasses = [stubProtocolClass]` |
| 2 | `testSystemPrepended` | same | same |
| 3 | `testOpenAICompatibleDeepSeek` | same | same |
| 4 | `testOllamaNoAuth` | same | same |
| 5 | `testOllamaMissingKeyNoThrow` | same | same |

5 migrations total.

## Per-ticket acceptance criteria

### Ticket 001 — OpenAIConnectorTests migration

- ✓ `swift build` = BUILD COMPLETE
- ✓ `swift test --filter "OpenAIConnector"` = **10/10 pass** in 2 suites (= 5 OpenAIConnectorTests + 5 DeepSeekConnectorTests)
- ✓ All 5 test bodies use `makeIsolatedStub` (= hermetic isolation per task)
- ✓ 0 production code changes

## Cross-references

- `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` (= this ticket's primary target; = 5 test bodies migrated)
- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift` (= the v1.16-v1.17 infrastructure that enables this migration)
- `.scratch/v1.17-startloading-override/spec.md` (= the upstream routing override)
- `.scratch/v1.16-per-test-stub/spec.md` (= the upstream factory + IsolatedStubSubclass)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "OpenAIConnector"` = **10/10 pass** in 2 suites
3. `swift test --filter "MinimaxConnector"` = 4/4 pass (= unchanged; = Minimax not migrated)
4. Combined 5 suites = 18 tests, 4 fails (= within variance; = MinimaxConnectorTests still uses global pattern; = future v1.19 ticket)
5. 0 production code changes (= URLProtocolStub.swift + OpenAIConnectorTests.swift are test-only files)

## Out-of-scope (= explicit)

- Migration of MinimaxConnectorTests (= future v1.19 ticket)
- Migration of other connector tests (= future v1.20+ tickets)
- Deletion of global statics after all migrations (= future v1.21 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria

### Ticket 001 — OpenAIConnectorTests migration

- ✓ `swift build` = BUILD COMPLETE
- ✓ All 5 test bodies use `makeIsolatedStub`
- ✓ Isolated test runs (= OpenAI, DeepSeek) pass (= 10/10)
- ✓ MinimaxConnectorTests still passes (= 4/4; = unchanged)
- ✓ 0 production code changes