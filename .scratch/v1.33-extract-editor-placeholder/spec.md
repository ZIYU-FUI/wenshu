# v1.33 Extract EditorPlaceholder from WorkspaceView · Spec (= REAL FIX)

**Branch**: `wt/v1.33-extract-editor-placeholder-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "我想把这些修掉"

## Context

Per boss OOB 2026-09-14 "我想把这些修掉": v1.32 extracted
`ZoneModuleView` from `WorkspaceView.swift` (= -390 lines).
v1.33 continues the split (= extract `EditorPlaceholder`).

Per repowise `get_health` directive (2026-09-14):
  fix_first: WorkspaceView.swift (= score 4.15, 2062 NLOC, 30 deps)

## Scope (= 1 ticket, 3 files 1 commit per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift` | NEW file (= 901 lines = 25-line header + 876-line extracted struct) |
| 2 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Modified (= removed EditorPlaceholder block = -880 lines; = 1749 → 869) |
| 3 | `Tests/WenshuAppTests/Views/Workspace/EditorPlaceholderTests.swift` | Modified (= rewrote path to use #filePath = works regardless of worktree location) |

Total v1.33 = **3 files**, **1 new + 2 modified**, **0 production code logic changes** (= pure refactor = move struct to own file).

## What this ticket ships

**Real fix** (= per Q34 5.4 + Q173 ponytail + Q186 + Q57 + Q112):
- **WorkspaceView.swift = 1749 → 869 lines** (= drop of 880 lines = 50% reduction from v1.32; = 58% reduction from original 2062)
- **EditorPlaceholder.swift = new file with 901 lines** (= extracted struct)
- **EditorPlaceholderTests.swift = path-independent** (= uses #filePath)
- **8/8 EditorPlaceholder tests pass** (= all green)
- **No regression** (= 50/50 tests pass across ZoneModuleView + EditorPlaceholder + ForeshadowingView + PlaceholderView + MinimaxConnector)

## Why this split is safe

| # | Property | Value |
|---|---|---|
| 1 | EditorPlaceholder is `public` (= accessible from `WenshuApp` module) | ✓ |
| 2 | EditorPlaceholder's dependencies (= AppState, BookStore, EditorMode, MarkdownEngine) are all in the same module | ✓ |
| 3 | EditorPlaceholderTests existed BEFORE this split (= v0.93 ticket 002) | ✓ (= independent test file) |
| 4 | Swift's `import` resolution treats all files in the same target as one module | ✓ (= no new import needed) |
| 5 | WorkspaceView.swift still contains WorkspaceView + EditorPaperCanvas (= 2 more structs to split in future) | ✓ |

Per Q34 5.2 + Q173 ponytail + Q186: split is mechanically safe.

## Empirical validation (= per Q34 5.4)

| # | Metric | Value |
|---|---|---|
| 1 | `swift build --target WenshuAppTests` | **BUILD COMPLETE in 94.31s** |
| 2 | `swift test --filter "EditorPlaceholder"` | **8/8 tests pass in 0.003s** |
| 3 | Regression check: 5 suites combined | **50/50 tests pass** |
| 4 | WorkspaceView.swift line count | 1749 → 869 (= -880, = 50% reduction) |
| 5 | EditorPlaceholder.swift line count (= new file) | 901 (= 25 header + 876 struct) |

## Cumulative impact (= v1.32 + v1.33)

| # | File | Before v1.32 | After v1.33 | Reduction |
|---|---|---|---|---|
| 1 | `WorkspaceView.swift` | 2062 LOC | 869 LOC | **-1193 (-58%)** |
| 2 | `ZoneModuleView.swift` | (extracted) | 398 LOC | (= new file) |
| 3 | `EditorPlaceholder.swift` | (extracted) | 901 LOC | (= new file) |
| 4 | **Total** | **2062** | **2168** | (+106 = 5% overhead from headers + imports) |

Per Q34 5.2 + Q173 ponytail + Q186: the 5% overhead is from
file headers + per-file imports (= the right tradeoff for
maintainability).

## What did NOT change

| # | Property | Status |
|---|---|---|
| 1 | EditorPlaceholder's public API | Unchanged (= same struct name + init + body) |
| 2 | EditorPlaceholder's dependencies | Unchanged |
| 3 | WorkspaceView's 30 dependents | Unchanged |
| 4 | Test assertions (= the 8 source-level tests) | Updated to use #filePath (= worktree-independent) |

## Cross-references

- `Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift` (= this ticket's primary target = new file)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (= modified: removed 880 lines)
- `Tests/WenshuAppTests/Views/Workspace/EditorPlaceholderTests.swift` (= updated to use #filePath)
- `.scratch/v1.32-extract-zonemodule/spec.md` (= v1.32 sibling split)

## What was the v0.93 test path problem?

The v0.93 test file (= `EditorPlaceholderTests.swift`) had 8 hardcoded
absolute paths. The v1.32 lesson learned: use `#filePath` for
worktree-independent path resolution.

Per Q34 5.2 + Q173 ponytail + Q186: v1.33 fixes this once for all
future extractions (= same pattern can be applied to other v0.93
test files that need path updates).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Notes |
|---|---|---|
| 1 | **Continue splitting WorkspaceView** (= EditorPaperCanvas = ~437 LOC) | v1.34 future ticket per Q112 |
| 2 | **Split NavigationSplitShell** (= 1564 NLOC, top #2) | Future ticket |
| 3 | **Split PaneNSController** (= 1587 NLOC, top #4) | Future ticket |
| 4 | **Split PreviewPane** (= 1472 NLOC, top #3) | Future ticket |

**Per Q34 5.2 + Q173 ponytail + Q186 + Q112**: each subsequent
extraction = 1 ticket per file. WorkspaceView is now below 1000 LOC
(= 869) so it's "fixable" per repowise (= was 2062 = needs_work;
= now closer to "good" range).

## Acceptance criteria

### Ticket 001 — Extract EditorPlaceholder from WorkspaceView

- ✓ swift build --target WenshuAppTests = **BUILD COMPLETE in 94.31s**
- ✓ swift test --filter "EditorPlaceholder" = **8/8 pass in 0.003s**
- ✓ No regression (= 50/50 tests across 5 suites)
- ✓ WorkspaceView.swift reduced 1749 → 869 lines (-880, = 50% reduction)
- ✓ EditorPlaceholder.swift created (= 901 lines = 25 header + 876 struct)
- ✓ EditorPlaceholderTests.swift path-independent (= uses #filePath)
- ✓ EditorPlaceholder's public API unchanged
- ✓ 0 production code logic changes (= pure file move)