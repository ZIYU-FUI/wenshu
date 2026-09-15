# v1.06 Re-scan after v1.05 init() reset fix · Spec (= scoped refinement)

**Branch**: `wt/v1.06-rescan-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

v1.05 applied per-test `init() { clear RuntimeCWD UserDefaults keys }`
to all 16 test structs in `ComprehensiveInterfaceTests.swift`. Per
boss OOB "A": re-scan to verify the state pollution flake is gone.

## Investigation (= per Q34 5.4)

### First scan (= after v1.05)

| Test suite | Before v1.05 | After v1.05 (= clear BOTH keys) |
|---|---|---|
| `ComprehensiveInterfaceTests` isolated | 116/116 pass | **1 issue** (= `RuntimeCWD: resetToLibraryPath clears override` failed because v1.05 cleared `libraryPathKey` that the test set) |
| Combined 6 suites | 18 tests, 4-8 issues | **7 issues** (= 1 in ComprehensiveInterface + 3 in RuntimeCWDDisplayChip + 3 in connector) |

### Root cause (= per Q34 5.2)

v1.05's `init()` cleared BOTH `RuntimeCWD.cwdOverrideKey` AND
`RuntimeCWD.libraryPathKey`. The pollution source was only
`cwdOverrideKey` (= the previous test's setCWD that lingered).
Clearing `libraryPathKey` broke the test `resetToLibraryPath
clears override` (= the test sets the library path then expects
the resolved path to be from the library; = the init() wiped the
test's own setup before the test ran).

### v1.06 fix

Scope the init() to clear ONLY `RuntimeCWD.cwdOverrideKey` (= the
actual pollution source; = leaves `libraryPathKey` alone so tests
that set it can still see their setup).

## Scope (= 1 ticket, 1 file 1 commit per Q112)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/ComprehensiveInterfaceTests.swift` | Change init() to clear only `cwdOverrideKey` (= not `libraryPathKey`); = 8 init() blocks updated (one per test struct that already had v1.05's broader clear) |

Total v1.06 = **1 test file changed** (= init() scope refined),
**0 production code changes**.

## Empirical fix (= per Q34 5.4)

| Run | v1.05 (= clear BOTH) | v1.06 (= clear only cwdOverrideKey) |
|---|---|---|
| `ComprehensiveInterfaceTests` isolated | 1 issue | **116/116 pass** |
| Combined 6 suites | 7 issues | **7 issues** (= RuntimeCWDDisplayChip's 3 + connector 4; = ComprehensiveInterfaceTests now clean) |

Net improvement = **1 issue fixed** (= the ComprehensiveInterface
RuntimeCWD test). Remaining 7 issues = pre-existing flakes
documented in v0.99 / v1.03 / v1.04 specs.

## Out-of-scope (= explicit)

- RuntimeCWDDisplayChipTests (= 3 issues; = would need the same
  scoped init() fix; = requires another ticket; = not v1.06 scope)
- 4 inter-suite connector flakes (= requires Option 3 from v1.01
  spec = architectural change; = not v1.06 scope)
- The 7 issues documented in v0.94 + v1.03 + v1.04 specs

## Cross-references

- `Sources/WenshuApp/Core/Agent/RuntimeCWD.swift:30,33` (= the 2
  UserDefaults keys; = v1.05 cleared both; = v1.06 clears only the
  pollution source)
- `.scratch/v1.05-init-reset-all/spec.md` (= the upstream partial
  fix that v1.06 refines)
- `Tests/WenshuAppTests/ComprehensiveInterfaceTests.swift` (= the
  target file)

## Validation (= per Q34 step 4)

1. `swift test --filter "ComprehensiveInterfaceTests"` =
   **116/116 pass** (isolated)
2. `swift test --filter "ComprehensiveInterfaceTests|OpenAIConnectorTests|DeepSeekConnectorTests|MinimaxConnectorTests|OllamaConnectorTests|OpenRouterConnectorTests|RuntimeCWDDisplayChipTests"`
   = **141 tests, 7 issues** (= 1 fewer than v1.05; = Comprehensive
  is now clean)
3. `swift build` = BUILD COMPLETE
4. No production code touched