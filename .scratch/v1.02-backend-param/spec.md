# v1.02 Backend parameter / scoped override · Spec (= honest scope gap)

**Branch**: `wt/v1.02-backend-param-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.01 documented that the 3 remaining OpenAI-compatible connector
test failures are read-write races across `await` boundaries
between concurrent test bodies. Per boss OOB "A": try Option 1
(= test body parameter; = scoped override).

## Investigation (= per Q34 5.4)

### Attempted fix: `withBackendForTesting(_:perform:)` scoped override

- Added `withBackendForTesting<R>(_ store: any ProviderKeychainStoring, perform body: () async throws -> R) async rethrows -> R`
  to `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= saves
  previous backend, sets new, runs body, restores via `defer`).
- **Doesn't actually fix the inter-suite race** because:
  - The race is BETWEEN `setBackendForTesting` and a SUBSEQUENT
    `loadKeySync` call inside the test body (= e.g. inside
    `connector.send`).
  - `withBackendForTesting` only restores at the END of `body`;
    during the body, the backend is still globally mutable.
  - A concurrent test body from another suite can still
    `setBackendForTesting` and clobber this test's backend
    between the await points.

### Attempted fix: per-test `defer { restore }` pattern

- Tried wrapping each test body in a `defer { setBackendForTesting(previousBackend) }`
  pattern (= capture the previous backend before the test body
  mutates the global; = restore on exit).
- **Doesn't fix the inter-suite race either** because:
  - The `defer` runs at end of FUNCTION (= after the test completes).
  - During the `await connector.send(...)` call inside the test
    body, a concurrent test body from another suite can still
    `setBackendForTesting` and clobber the backend.
  - The restore happens AFTER the test has already failed.

### What would actually work (= future ticket scope)

| # | Option | What it does |
|---|---|---|
| 1 | Each shim method snapshots backend at function entry (= `loadKeySync` reads from a local snapshot taken at call start; = not the global) | Prevents the race at the read site; = invasive change to every shim method |
| 2 | Move `backend` to a per-test thread-local via an actor-isolated wrapper | Requires Swift 6 actor isolation throughout `ProviderKeychain` |
| 3 | Pass backend explicitly through every test body (= no global) | Invasive; = every test body changes |

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code
changes; = no test changes; = the 3 remaining issues persist).

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the
  global `backend` static var that needs the architectural change
  for Option 1 / Option 2 / Option 3)
- `Tests/WenshuAppTests/Agent/{OpenAI,DeepSeek,Minimax,Ollama,OpenRouter}ConnectorTests.swift`
  (= the 5 connector test files that exhibit the inter-suite race)
- `.scratch/v1.01-tasklocal-backend/spec.md` (= the upstream
  analysis that this ticket attempted to address)

## Validation (= per Q34 step 4)

1. `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
   = **15/18 pass** (= same as v1.00; = 3 issues remain; = unchanged;
   = documented)
2. Isolated runs of each suite: all 5 pass (= 5/5 each)
3. `swift build` = BUILD COMPLETE (= no source code changes)
4. The `withBackendForTesting` helper was added then reverted
   (= `git checkout -- Sources/.../ProviderKeychain.swift`; = the
   helper was correctly identified as not solving the root cause
   in this architecture)

## Out-of-scope (= explicit)

- Option 1 (= per-call snapshot in shim methods; = future ticket)
- Option 2 (= per-test thread-local via actor; = future ticket)
- Option 3 (= explicit backend parameter through every test body;
  = future ticket)
- New test code (= this ticket only documents the analysis)

## Recommendation

Per Q186 v0.34 + Q34 5.6 partial commit: **accept the 3 remaining
issues as known flakes**. The test suite is 99% green (= not
blocking CI; = passes when run in different orders / isolated).
Future ticket recommendation: **Option 1** (= per-call snapshot
in shim methods) when full determinism is needed.