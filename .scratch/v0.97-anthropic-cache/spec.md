# v0.97 Anthropic cache_control decoder fix · Spec (= honest scope gap)

**Branch**: `wt/v0.97-anthropic-cache-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v0.94 documented `AnthropicConnectorTests.testSystemFieldCacheControl` as a
pre-existing flake (= the Anthropic-native system field with
`cache_control` decoder fails). Per boss OOB "A": investigate and fix.

## Investigation (= per Q34 5.4)

### Production code state

- `Sources/WenshuApp/Core/Agent/Connector/RequestHelpers.swift:92-97`
  already builds the system field as a structured dict:
  ```
  body["system"] = [
      "type": "text",
      "text": sys,
      "cache_control": ["type": "ephemeral"]
  ]
  ```
  (= the boss 2026-08-24 cache_control fix was already applied to
  the Anthropic request builder).
- `Sources/WenshuApp/Core/Agent/Connector/AnthropicConnector.swift:62`
  passes `useCacheControl` (= ticket 002 PromptCaching.applyCacheControl
  is wired).
- Production code is correct (= already passes the test contract).

### Test file state

- `Tests/WenshuAppTests/Agent/AnthropicConnectorTests.swift:11`
  already declares `@Suite(..., .serialized)` (= applied by some
  prior v0.90-style fix that was not in v0.94's scope).
- All 5 tests pass when run in isolation.

### Empirical validation

- `swift test --filter "AnthropicConnectorTests.testSystemFieldCacheControl"`
  = **1/1 pass** (isolated).
- `swift test --filter "AnthropicConnectorTests"` = **5/5 pass**
  (combined run).
- `swift test --filter "Anthropic"` (broader filter) = **no failures**.

## Scope (= 1 ticket, 1 spec doc 1 commit per Q112)

**This ticket ships the spec doc only** (= no production code
changes; = no test changes; = Anthropic test suite was already fixed
by prior work).

## Root cause (= v0.94 spec vs current state)

The v0.94 spec was generated from a `swift test` log captured **before**
the v0.90-style `.serialized` fix was applied to
`AnthropicConnectorTests`. The fix was applied in some intermediate
commit (= likely as part of the v0.90 work on cross-test pollution
flakes, but not specifically named in v0.94's spec).

Per Q57: 3rd-party verdict (= stale v0.94 trace) ≠ authority; =
the current state of the test suite is the ground truth.

## Cross-references

- `Sources/WenshuApp/Core/Agent/Connector/RequestHelpers.swift:92-97`
  (= the system field builder that already produces the correct
  shape)
- `Tests/WenshuAppTests/Agent/AnthropicConnectorTests.swift:11`
  (= the suite declaration with `.serialized` already applied)
- `.scratch/v0.94-remaining-flakes/spec.md` (= the upstream analysis
  that this ticket was supposed to fix)

## Validation (= per Q34 step 4)

1. `swift test --filter "AnthropicConnectorTests.testSystemFieldCacheControl"`
   = **1/1 pass**
2. `swift test --filter "AnthropicConnectorTests"` = **5/5 pass**
3. `swift test --filter "Anthropic"` = **no failures**
4. `swift build` = BUILD COMPLETE (= no source code changes)

## Out-of-scope (= explicit)

- Any production code change (= the fix was already applied)
- Any test change (= the fix was already applied)
- The remaining pre-existing flakes from v0.94 (= I18n SPM cache,
  v0.95 already documented; = future ticket)