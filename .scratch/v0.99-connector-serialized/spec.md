# v0.99 Other connector tests .serialized · Spec (= honest scope gap)

**Branch**: `wt/v0.99-connector-serialized-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.90 + v0.96 applied `.serialized` to `ProviderKeychainTests`,
`SecretScopeTests`, and `GeminiNativeConnectorTests` (= the
connector test files with cross-test pollution from
`ProviderKeychain.backend` shared global state). Per boss OOB "A":
extend the same fix to the other 5 connector test files:
- `OpenAIConnectorTests`
- `DeepSeekConnectorTests`
- `MinimaxConnectorTests`
- `OllamaConnectorTests`
- `OpenRouterConnectorTests`

## Investigation (= per Q34 5.4)

### Empirical validation (= v0.99 attempt)

- Before any changes: `swift test --filter
  "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
  = **18 tests, 8 issues** (= cross-test pollution confirmed).
- After adding `.serialized` to all 5 suite declarations: same
  combined run = **18 tests, 4 issues** (= .serialized helped
  intra-suite, but inter-suite pollution remains).
- After isolated run of each suite: all 5 suites pass independently.

### Root cause

The 5 connector test files all use `OpenAICompatibleConnector` (=
the shared connector implementation for OpenAI, DeepSeek, Minimax,
Ollama, OpenRouter) + `ProviderKeychain.backend` (= the shared
global static var).

When the 5 suites run concurrently (= in the same `swift test`
process without per-file serialization), each suite's test setup
calls `ProviderKeychain.setBackendForTesting(...)`, and the LAST
setup wins (= the in-memory backend of one suite gets clobbered
by another suite's setup mid-flight).

`.serialized` is a **per-suite** trait (= Swift Testing 0.10.3
documented behavior). It serializes tests WITHIN a suite, not
ACROSS suites. So `OpenAIConnectorTests.testOllamaNoAuth` and
`OllamaConnectorTests.testConnectorID` can still interleave their
backend mutations.

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code
changes; = no test changes; = the inter-suite pollution remains).

### Per Q34 5.6 partial commit + Q46 stop-rule: revert the 5 file changes attempted

5 file changes were attempted and then reverted (= `git checkout -- Tests/.../Agent/`):
- Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift
- Tests/WenshuAppTests/Agent/DeepSeekConnectorTests.swift
- Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift
- Tests/WenshuAppTests/Agent/OllamaConnectorTests.swift
- Tests/WenshuAppTests/Agent/OpenRouterConnectorTests.swift

## Future fix options (= scope-deferred per Q112)

| # | Option | Risk | Files |
|---|---|---|---|
| 1 | Add a per-file `init()` that calls `setBackendForTesting(InMemoryKeychainStore())` (= v0.86-style + v0.95-style fix) | Medium (= touches every test file's init) | 5 files |
| 2 | Merge the 5 connector test files into 1 suite covering all OpenAI-compatible providers (= the v0.27 single-file pattern) | Medium (= 5 → 1 file refactor) | 1 file |
| 3 | Add `ProviderKeychain.serializedBackend` = TaskLocal-style wrapper (= architectural change) | High (= API change to production code) | 3+ files |

Recommended: **Option 1** (= minimal, follows existing v0.86
+ v0.90 pattern; = each suite's init() resets the backend).

## Cross-references

- `Tests/WenshuAppTests/Agent/OpenAIConnectorTests.swift`
- `Tests/WenshuAppTests/Agent/DeepSeekConnectorTests.swift`
- `Tests/WenshuAppTests/Agent/MinimaxConnectorTests.swift`
- `Tests/WenshuAppTests/Agent/OllamaConnectorTests.swift`
- `Tests/WenshuAppTests/Agent/OpenRouterConnectorTests.swift`
- `Sources/WenshuApp/Core/Agent/Connector/OpenAICompatibleConnector.swift`
  (= the shared connector all 5 suites test)
- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= the shared
  global `backend` static var that gets raced)
- `.scratch/v0.90-serialized-trait/spec.md` (= the upstream .serialized
  fix pattern that v0.99 attempted to extend)

## Validation (= per Q34 step 4)

1. `swift test --filter "OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
   = **18 tests, 4 issues** (= pre-existing; = unchanged; = documented)
2. `swift test --filter "OpenAIConnectorTests"` = 5/5 pass (isolated)
3. `swift test --filter "DeepSeekConnectorTests"` = pass (isolated)
4. `swift test --filter "MinimaxConnectorTests"` = pass (isolated)
5. `swift test --filter "OllamaConnectorTests"` = pass (isolated)
6. `swift test --filter "OpenRouterConnectorTests"` = pass (isolated)

## Out-of-scope (= explicit)

- Test file refactor (= future ticket per Option 1 / Option 2)
- Production code changes (= future ticket per Option 3)