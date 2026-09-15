# v1.11 URLProtocolStub.register fix for MinimaxConnectorTests · Spec (= honest scope gap)

**Branch**: `wt/v1.11-urlprotocol-stub-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.10 documented 2 remaining `MinimaxConnectorTests` failures (= pre-existing `URLProtocolStub.register` missing). Per boss OOB "A": add `URLProtocolStub.register(stub)` calls to fix them.

## Scope (= 1 ticket, 2 files 1 commit per Q112 + Q173)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` | Add `URLProtocolStub.register(stub)` + `defer { URLProtocolStub.unregister() }` to 3 test bodies (testRequestBody, testResponseDecode, testTransportError) |
| 2 | `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` | Add same register/unregister pattern to 5 test bodies (testOpenAINativeAuth, testSystemPrepended, testOpenAICompatibleDeepSeek, testOllamaNoAuth, testOllamaMissingKeyNoThrow) |

Total v1.11 = **2 test files changed**, **8 test bodies migrated**, **0 production code changes**.

## Empirical validation (= per Q34 5.4)

| Run | v1.10 (= before) | v1.11 (= register/unregister added) |
|---|---|---|
| `MinimaxConnectorTests` isolated | 4/4 pass (= serialized suite already passes) | **4/4 pass** (= unchanged; = isolated was already passing) |
| `OpenAIConnectorTests` isolated | 5/5 pass (= `withBackendForTesting` from v1.10 fixed it) | **5/5 pass** (= unchanged) |
| Combined 5 suites | 18 tests, 2 fails | 18 tests, 6 fails (= WORSE; = combined-run races on `URLProtocolStub.stub` global static) |

## Root cause analysis (= per Q34 5.2)

The combined-run failures are NOT caused by the `setBackendForTesting` race (= v1.10's TaskLocal fix already addressed that). **The remaining combined-run races are on `URLProtocolStub.stub`**, which is declared as:

```swift
nonisolated(unsafe) public static var stub: URLProtocolStub?
```

(= a global mutable static = inherent race surface when Swift Testing runs multiple suites concurrently).

The 6 issues break down as:
- 4 OpenAIConnectorTests issues: `Bearer auth` (= `auth == "Bearer ***"` fails because stub.lastRequest is nil) + `system message` (= decode fails because stub never intercepted) + 2 DeepSeek (= `captured?.url?.host` fails because stub.lastRequest is nil)
- 2 MinimaxConnectorTests issues: `testRequestBody` + `testResponseDecode` (= same root cause: stub.lastRequest is nil because another test's stub overwrote URLProtocolStub.stub via the global static)

**Root cause = the `register/unregister` calls only set the snapshot via the static. When two suites run concurrently and both register stubs, the LAST `register` call wins. The URLSession from the FIRST test gets its request captured by the SECOND test's stub** (= or vice versa, depending on timing).

## Per Q46 stop-rule + Q186 + Q173 ponytail

Per the v1.11 ticket scope (= 1 ticket 1 file per Q112, though I expanded to 2 files due to the related fix), **3+ redo attempts on this ticket** justifies an honest scope gap instead of force-shipping a broken fix.

### What was attempted

| # | Attempt | Result |
|---|---|---|
| 1 | Add `register` + `defer unregister` to MinimaxConnectorTests only | Minimax isolated = 4/4 pass; combined = 2 Minimax + 3 OpenAI fails (= OpenAI tests don't have register, so they leak state) |
| 2 | Add `register` + `defer unregister` to both MinimaxConnectorTests + OpenAIConnectorTests | Combined = 6 fails (= the register pattern doesn't fix the underlying `URLProtocolStub.stub` global static race) |
| 3 | Same as #2 but with different insert positions | Same result; = 6 fails |

**All 3 attempts reverted** per Q46 stop-rule.

## The real fix (= scope-deferred)

The `URLProtocolStub.stub` static needs to be either:
1. Made `@TaskLocal` (= like `ProviderKeychain.backend` in v1.09)
2. Or guarded by an actor (= lock-based serialization)
3. Or replaced with a per-test instance pattern (= each test owns its stub, = no global state)

**Per Q34 5.2 + Q173 ponytail**: each option is a multi-week refactor (= requires changes to `URLProtocolStub.swift` itself + every test file that uses URLProtocolStub). This is scope-deferred to a future ticket (= v1.12 or later).

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | Spec documenting root cause | ✓ shipped |
| 2 | MinimaxConnectorTests register fix | **REVERTED** (= 3 attempts didn't help) |
| 3 | OpenAIConnectorTests register fix | **REVERTED** (= 3 attempts didn't help) |
| 4 | Production code change | None (= 0 changes) |

**Net change to main**: 0 lines (= 3 attempts reverted; = spec-only delivery).

## Cross-references

- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift:34-40` (= the `nonisolated(unsafe) public static var stub` that's the root cause)
- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift:23-32` (= the comment explaining why `register` is required)
- `.scratch/v1.10-migrate-connectors/spec.md` (= the upstream task)
- `.scratch/v1.09-backend-actor/spec.md` (= the TaskLocal pattern that v1.12 could replicate for `URLProtocolStub.stub`)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE
2. `swift test --filter "MinimaxConnectorTests"` = 4/4 pass (= unchanged; = isolated was already passing)
3. `swift test --filter "OpenAIConnectorTests"` = 5/5 pass (= unchanged; = v1.10's TaskLocal fix already addresses isolated)
4. Combined 5 suites = 18 tests, 2 fails (= SAME as v1.10; = v1.11's register/unregister attempts didn't fix the combined-run races; = they reverted cleanly)

## Out-of-scope (= explicit)

- TaskLocal `URLProtocolStub.stub` (= future v1.12 ticket)
- Actor-guarded stub (= future v1.12 ticket)
- Per-test stub instance pattern (= future v1.12 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs

## Acceptance criteria (= revised per Q46 stop-rule)

This ticket's acceptance is:
- ✓ Spec documents root cause (`URLProtocolStub.stub` global static race)
- ✓ All experimental changes reverted (= no net code change)
- ✓ v1.11 ships as spec-only (= no production code, no test code)
- ✓ Combined-run state preserved (= 2 fails same as v1.10; = no regression)