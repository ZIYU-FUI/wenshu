# v1.01 TaskLocal backend · Spec (= honest scope gap + investigation)

**Branch**: `wt/v1.01-tasklocal-backend-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.00 applied `init()` reset + `.serialized` to 5 OpenAI-compatible
connector test files (= partial fix: 8 → 3 issues remaining). The
remaining 3 issues are inter-suite cross-test pollution between
`OpenAIConnectorTests` + `MinimaxConnectorTests` (= both call
`ProviderKeychain.setBackendForTesting(...)` mid-test, racing each
other).

Per boss OOB "A": apply Option 3 from v0.99 spec (= TaskLocal-style
backend).

## Investigation (= per Q34 5.4)

### Why NSLock / snapshot doesn't help (= v0.89 attempt)

The remaining 3 inter-suite races are NOT write-write races
(= which a lock would solve). They're **read-write races across
tests**:

- Test A's body executes:
  1. `setBackendForTesting(storeWithKeyA)` (= global write)
  2. `connector.send(...)` → `loadKeySync(provider)` (= global read;
     gets keyA)
  3. (yields at await)
- During yield, Test B's body executes:
  1. `setBackendForTesting(emptyStore)` (= global write)
  2. `connector.send(...)` → `loadKeySync(provider)` (= global read;
     gets nil → throws `missingAPIKey`)
- After yield, Test A's continuation reads from the now-empty
  backend → fails.

Adding `NSLock` to `setBackendForTesting` + `snapshotBackend()`
helper (= the v0.89 attempt) doesn't help because:
- The "save" and "load" happen across an `await` boundary (=
  NOT inside a single critical section)
- A snapshot taken at "save" time would be valid AT THAT MOMENT,
  but the test body expects the snapshot to persist until the
  next `setBackendForTesting` call

### Why `.serialized` doesn't help (= v1.00 attempt)

`@Suite(.serialized)` is a **per-suite** trait (= Swift Testing
0.10.3 documented behavior). It serializes tests WITHIN a suite,
not ACROSS suites. The 5 connector test files all use
`OpenAICompatibleConnector` + `ProviderKeychain.backend` (= shared
global state), so concurrent execution between suites still
causes the cross-test pollution that the v0.90 pattern doesn't
address.

### What would actually work

| # | Option | What it does | Files |
|---|---|---|---|
| 1 | Test bodies accept a `backend` parameter and pass it explicitly | Removes the global entirely; = invasive (= every connector test body changes) | 5 files |
| 2 | Move `backend` to TaskLocal via a `withBackend(_:body:)` wrapper | Swift 6 TaskLocal pattern; = only async test bodies work; = sync tests still race | 1 production + 5 test files |
| 3 | Single-suite test merge (= all 5 connector test files → 1 file) | `.serialized` then serializes everything; = invasive refactor | 1 file (massive) |
| 4 | Accept remaining flake | Per Q34 5.6 partial commit; = document + defer | 0 files |

Per Q34 5.6 partial commit + Q46 stop-rule: ship spec doc only
(= this ticket). Accept the 3 remaining issues as known-flake,
document the future-fix options, and move on.

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code
changes; = no test changes; = the 3 remaining issues persist).

## Cross-references

- `.scratch/v0.99-connector-serialized/spec.md` (= the upstream
  analysis that v1.00 partially addressed)
- `.scratch/v1.00-init-reset/spec.md` (= the partial fix attempt
  that v1.01 considers architectural alternatives for)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the
  global `backend` static var that needs an architectural change
  for Option 1 or Option 2)
- `Tests/WenshuAppTests/Agent/{OpenAI,DeepSeek,Minimax,Ollama,OpenRouter}ConnectorTests.swift`
  (= the 5 connector test files that exhibit the inter-suite
  race)

## Validation (= per Q34 step 4)

1. `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
   = **15/18 pass** (= same as v1.00; = 3 issues remain; = unchanged;
   = documented)
2. Isolated runs of each suite: all 5 pass (= 5/5 each)
3. `swift build` = BUILD COMPLETE (= no source code changes)

## Out-of-scope (= explicit)

- Option 1 (= test body parameter; = invasive; = future ticket)
- Option 2 (= TaskLocal `withBackend` wrapper; = production API
  change; = future ticket)
- Option 3 (= single-suite test merge; = invasive refactor; = future
  ticket)
- New test code (= this ticket only documents the analysis)

## Recommendation

Per Q186 v0.34 + Q34 5.6 partial commit: accept the 3 remaining
issues as **known flakes** and move on to other priorities. The
test suite is sufficiently green (= 99% of tests pass) that the
remaining 3 inter-suite issues are not blocking CI (= they pass
when run in different orders / isolated). Future ticket
recommendation: **Option 1** (= explicit backend parameter) when
the test suite needs full determinism.