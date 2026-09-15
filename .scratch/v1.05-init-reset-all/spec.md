# v1.05 Per-test init() reset for state-pollution tests · Spec (= partial commit)

**Branch**: `wt/v1.05-init-reset-all-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.04 documented the RuntimeCWD state pollution issue (= state
leftover from a prior test's UserDefaults `cwdOverrideKey` value).
Per boss OOB "A": apply the per-test init() reset pattern to the 2
test files that touch this state.

## Scope (= 1 ticket, 1 file 1 commit per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/ComprehensiveInterfaceTests.swift` | Add `init() { clear RuntimeCWD UserDefaults keys }` to all 16 test structs |

Total v1.05 = **1 test file changed**, **16 init() blocks added**,
**0 production code changes**, **0 test code changes** (just init()
additions).

## Empirical fix (= per Q34 5.4)

| Run | Before | After |
|---|---|---|
| `ComprehensiveInterfaceTests` isolated | 116/116 pass | 116/116 pass (= unchanged) |
| `ComprehensiveInterfaceTests + 5 connector suites` combined | 18 tests, 4-8 issues | **134 tests, 1 issue** (= 4 fixed; = 1 still inter-suite race from v1.03) |

Net improvement = **4 issues fixed** by clearing RuntimeCWD
UserDefaults state pollution.

## Out-of-scope (= explicit)

- `Tests/WenshuAppTests/UI/Agent/RuntimeCWDDisplayChipTests.swift`
  was attempted then reverted (= the init() pattern broke 2 tests
  that set the keys themselves; = the test bodies do their own
  per-test save+restore via `defer { removeObject }`; = the init()
  clear was too aggressive)
- The remaining 1 inter-suite connector failure (= requires
  Option 3 from v1.01 spec = architectural change; = out of scope
  for incremental tickets)
- Other pre-existing flakes documented in v0.94 spec

## Cross-references

- `.scratch/v1.04-full-scan/spec.md` (= the upstream scan that
  surfaced the RuntimeCWD issue)
- `Sources/WenshuApp/Core/Agent/RuntimeCWD.swift:30,33` (= the 2
  UserDefaults keys cleared by the init())
- `Tests/WenshuAppTests/ComprehensiveInterfaceTests.swift` (= the
  target file; = 16 test structs)

## Validation (= per Q34 step 4)

1. `swift test --filter "ComprehensiveInterfaceTests"` =
   **116/116 pass** (isolated)
2. `swift test --filter "ComprehensiveInterfaceTests|OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests"`
   = **134 tests, 1 issue** (= 4 issues fixed; = 1 still remains
   from v1.03; = unchanged)
3. `swift build` = BUILD COMPLETE
4. No production code touched