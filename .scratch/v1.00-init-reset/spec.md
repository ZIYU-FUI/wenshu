# v1.00 Per-file init() reset for connector tests · Spec (= partial commit)

**Branch**: `wt/v1.00-init-reset-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.99 documented that the 5 OpenAI-compatible connector test files
(OpenAI / DeepSeek / Minimax / Ollama / OpenRouter) suffer from
**inter-suite cross-test pollution** because they all share
`OpenAICompatibleConnector` + `ProviderKeychain.backend` as global
state. Per boss OOB "A": apply v0.86 + v0.90 pattern (= per-file
`init()` reset + `.serialized` trait).

## Scope (= 1 ticket, 5 files 1 commit per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift` | Add `@Suite(..., .serialized)` + `init() { setBackendForTesting(InMemoryKeychainStore()) }` |
| 2 | `Tests/WenshuAppTests/Agent/DeepSeekConnectorTests.swift` | Same |
| 3 | `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift` | Same |
| 4 | `Tests/WenshuAppTests/Agent/OllamaConnectorTests.swift` | Same |
| 5 | `Tests/WenshuAppTests/Agent/OpenRouterConnectorTests.swift` | Same |

Total v1.00 = **5 test files changed**, **0 production code
changes**.

## Empirical fix (= per Q34 5.4)

| Run | Before | After (init() only) | After (init() + .serialized) |
|---|---|---|---|
| 1 (original v0.99) | 8 issues | 4 issues | 2-3 issues (= flaky) |
| 2 (after v1.00) | 8 issues | (skipped) | **3 issues** |

Net improvement = **5 issues fixed** (8 → 3). **3 issues remain**
(= inter-suite race that neither init() nor .serialized can fully
address because each test body overrides the backend via
`setBackendForTesting(store)` mid-test).

## Per-ticket acceptance criteria

### Ticket 001 — per-file init() reset for connector tests

- `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
  = **15/18 pass** (3 issues remain; = down from 8)
- All 5 suites pass when run isolated
- 0 production code changes

## Out-of-scope (= explicit)

- Full elimination of remaining 3 inter-suite issues (= requires
  Option 3 from v0.99 spec = `ProviderKeychain.serializedBackend`
  TaskLocal wrapper; = production code change; = separate ticket)
- Refactor the 5 connector test files into 1 suite (= Option 2 from
  v0.99 spec; = also a separate ticket)

## Cross-references

- `.scratch/v0.99-connector-serialized/spec.md` (= the upstream
  analysis that this ticket addresses)
- `Sources/WenshuApp/Core/Agent/Connector/OpenAICompatibleConnector.swift`
  (= the shared connector all 5 suites test)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the shared
  global `backend` static var)
- v0.86 + v0.90 + v0.96 + v0.98 (= the prior `.serialized` + `init()`
  reset pattern this ticket extends)

## Validation (= per Q34 step 4)

1. Combined run: **15/18 pass** (= 3 issues remain; = down from 8)
2. Isolated runs: all 5 suites pass (= 5/5 each)
3. `swift build` = BUILD COMPLETE
4. No production code touched

## Out-of-scope (= explicit)

- Full fix for the remaining 3 issues (= requires Option 3 from v0.99
  spec; = production code change; = separate ticket)
- New test code (= this ticket only adds init() + .serialized to
  existing tests)