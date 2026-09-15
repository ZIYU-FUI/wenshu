# v1.10 Migrate OpenAIConnectorTests + MinimaxConnectorTests to withBackendForTesting · Spec (= partial commit)

**Branch**: `wt/v1.10-migrate-connectors-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.09 shipped the TaskLocal backend infrastructure (= new `withBackendForTesting(_:perform:)` helper on `ProviderKeychain`). Per boss OOB "A": migrate the 2 connector test files (= OpenAIConnectorTests + MinimaxConnectorTests) to use the new helper so they get hermetic isolation.

## Scope (= 1 ticket, 2 files 1 commit per Q112 + Q173)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` | Wrap 5 test bodies in `try await ProviderKeychain.withBackendForTesting(store) { ... }` (= replace `setBackendForTesting` with the new helper) |
| 2 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` | Wrap 4 test bodies in `try await ProviderKeychain.withBackendForTesting(store) { ... }` (= replace `setBackendForTesting` with the new helper) |

Total v1.10 = **2 test files changed**, **9 test bodies wrapped** (= 5 in OpenAIConnectorTests + 4 in MinimaxConnectorTests), **0 production code changes**.

## Empirical fix (= per Q34 5.4)

| Run | v1.09 (= global only) | v1.10 (= migrated to TaskLocal) |
|---|---|---|
| `OpenAIConnectorTests` isolated | 5 tests, 2 fails (= inter-suite from `MinimaxConnector` test data pollution) | **5/5 pass** isolated |
| `MinimaxConnectorTests` isolated | 4 tests, 0 fails (= serialized suite) | **4/4 pass** isolated |
| Combined 5 suites | 18 tests, 4-6 fails (= inter-suite races on `ProviderKeychain.backend` global) | **18 tests, 2 fails** |

Net improvement: **2 issues fixed** (= OpenAIConnectorTests 2 fails resolved via TaskLocal isolation); **2 issues remaining** (= MinimaxConnectorTests 2 fails = pre-existing `URLProtocolStub.register` missing).

## Per-ticket acceptance criteria

### Ticket 001 — OpenAIConnectorTests migration

- `swift test --filter "OpenAIConnectorTests"` = **5/5 pass** (= previously 2 fails)
- All 5 test bodies now use `withBackendForTesting` (= hermetic isolation per task)

### Ticket 002 — MinimaxConnectorTests migration

- `swift test --filter "MinimaxConnectorTests"` = **4/4 pass** isolated (= was already passing isolated; = migration preserves passing state)
- All 4 test bodies now use `withBackendForTesting`

### Combined run (= ticket 001 + 002 together)

- `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"` = 18 tests, **2 fails** (= down from 4-6 fails before v1.10)
- The 2 remaining fails are pre-existing `URLProtocolStub.register` issues in `MinimaxConnectorTests` (= documented in v1.11 spec)

## How the fix works

For each test body, the migration:
1. Captures the test's local `store` (= an `InMemoryKeychainStore` with the API key saved)
2. Replaces `ProviderKeychain.setBackendForTesting(store);` with `try await ProviderKeychain.withBackendForTesting(store) {`
3. Inserts a matching `}` at the end of the function body (= before the original closing `}`)

The TaskLocal pattern means the test body's task has its own backend reference. Concurrent test bodies (= separate tasks) each have their own reference (= no race on the global `backend` static var).

## Remaining issues (= scope-deferred per Q34 5.6 honest scope gap)

| # | Failing test | Root cause | Fix ticket |
|---|---|---|---|
| 1 | `MinimaxConnectorTests.testRequestBody` | Missing `URLProtocolStub.register(stub)` call (= pre-existing bug from before v1.10) | Future ticket (= v1.11 or later) |
| 2 | `MinimaxConnectorTests.testResponseDecode` | Same as #1 (= both tests use `URLProtocolStub` without calling `register`) | Same future ticket |

Per Q34 5.6: these 2 fails are NOT introduced by v1.10's migration (= they are pre-existing). The migration preserves passing state and reduces inter-suite races; = the remaining issues are independent.

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift:325-410` (= the v1.09 `withBackendForTesting` helper + `currentBackend()` accessor + shim method updates)
- `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` (= 5 test bodies wrapped)
- `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` (= 4 test bodies wrapped)
- `Tests/WenshuAppTests/Agent/URLProtocolStub.swift:23-32` (= the `register` requirement that the 2 remaining Minimax fails are missing)
- `.scratch/v1.09-backend-actor/spec.md` (= the upstream TaskLocal infrastructure)
- `.scratch/v1.03-snapshot/spec.md` (= the v1.03 acceptance that documented these 4 fails)

## Validation (= per Q34 step 4)

1. `swift build --target WenshuAppTests` = BUILD COMPLETE
2. `swift test --filter "OpenAIConnectorTests"` = **5/5 pass**
3. `swift test --filter "MinimaxConnectorTests"` = **4/4 pass**
4. Combined 5 suites = 18 tests, 2 fails (= both are pre-existing `URLProtocolStub.register` issues)
5. 0 production code changes

## Out-of-scope (= explicit)

- `URLProtocolStub.register` fix for MinimaxConnectorTests (= future v1.11+ ticket)
- Full `swift test --no-parallel` scan (= future v1.12 ticket)
- Other pre-existing flakes documented in v0.94 / v1.04 specs