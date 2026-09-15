# v1.32 Extract ZoneModuleView from WorkspaceView · Spec (= REAL FIX)

**Branch**: `wt/v1.32-extract-zonemodule-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "我想把这些修掉"

## Context

Per boss OOB 2026-09-14 "我想把这些修掉" (= fix the items from
the previous summary): the 4 fat files (>1400 NLOC) were identified
as the biggest problem. v1.32 takes the first split (= extract
`ZoneModuleView` from `WorkspaceView.swift`).

Per repowise `get_health` directive (2026-09-14):
  fix_first: WorkspaceView.swift (= score 4.15, 2062 NLOC, 30 deps)
  reason: Hotspot with no paired test file (= needs split)

## Scope (= 1 ticket, 3 files 1 commit per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Sources/WenshuApp/Views/Workspace/ZoneModuleView.swift` | NEW file (= 398 lines = 28-line header + 370-line extracted struct) |
| 2 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Modified (= removed ZoneModuleView block = -390 lines; = 2139 → 1749) |
| 3 | `Tests/WenshuAppTests/Views/Workspace/ZoneModuleViewTests.swift` | Modified (= 1) updated hardcoded path from WorkspaceView.swift to ZoneModuleView.swift; = 2) rewrote path to use #filePath (= works regardless of worktree location); = 3) fixed ZoneSlot case names (= actual enum is .projectSidebar, .projectPreview, .specializedTools, .aiDynamic, .aiChat, .editor — not the v0.27 .outline/.canvas/etc.) |

Total v1.32 = **3 files**, **1 new + 2 modified**, **0 production code logic changes** (= pure refactor = move struct to own file).

## What this ticket ships

**Real fix** (= per Q34 5.4 + Q173 ponytail + Q186 + Q57 + Q112):
- **WorkspaceView.swift = 2139 → 1749 lines** (= drop of 390 lines = 18% reduction)
- **ZoneModuleView.swift = new file with 398 lines** (= extracted struct)
- **ZoneModuleViewTests.swift = path-independent** (= uses #filePath = works in any worktree)
- **6/6 ZoneModuleView tests pass** (= all green)
- **No regression** (= 36/36 tests pass across ForeshadowingView + PlaceholderView + MinimaxConnector)

## Why this split is safe

| # | Property | Value |
|---|---|---|
| 1 | ZoneModuleView is `public` (= accessible from `WenshuApp` module) | ✓ |
| 2 | ZoneModuleView's dependencies (= AppState, BookStore, ZoneSlot) are all in the same module | ✓ |
| 3 | ZoneModuleViewTests existed BEFORE this split (= v0.93 ticket 002) | ✓ (= independent test file) |
| 4 | WorkspaceView still instantiates ZoneModuleView (= `ZoneModuleView(zoneSlot: .aiDynamic)` at line 596) | ✓ (= same module = works) |
| 5 | Swift's `import` resolution treats all files in the same target as one module | ✓ (= no new import needed) |

Per Q34 5.2 + Q173 ponytail + Q186: split is mechanically safe (= pure file move + test path update).

## Empirical validation (= per Q34 5.4)

| # | Metric | Value |
|---|---|---|
| 1 | `swift build --target WenshuAppTests` | **BUILD COMPLETE in 9.29s** |
| 2 | `swift test --filter "ZoneModuleView"` | **6/6 tests pass in 0.001s** |
| 3 | Regression check: `swift test --filter "ForeshadowingView\|PlaceholderView\|MinimaxConnector"` | **36/36 tests pass** |
| 4 | WorkspaceView.swift line count | 2139 → 1749 (= -390) |
| 5 | ZoneModuleView.swift line count (= new file) | 398 (= 28 header + 370 struct) |

## What did NOT change

| # | Property | Status |
|---|---|---|
| 1 | WorkspaceView's 30 dependents | Unchanged (= still import from `WenshuApp` module) |
| 2 | ZoneModuleView's public API | Unchanged (= same struct name + init + body) |
| 3 | ZoneModuleView's bindings (= @Binding var) | Unchanged (= same type signatures) |
| 4 | Test assertions (= the 6 source-level tests) | Updated to match current ZoneSlot enum values |

## Cross-references

- `Sources/WenshuApp/Views/Workspace/ZoneModuleView.swift` (this ticket's primary target = new file)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (= modified: removed 390 lines)
- `Tests/WenshuAppTests/Views/Workspace/ZoneModuleViewTests.swift` (= updated path + ZoneSlot case names)
- repowise `get_health` (2026-09-14 15:39 UTC) — WorkspaceView = top hotspot

## What was the v0.93 ZoneModuleView test problem?

The v0.93 test file (= `ZoneModuleViewTests.swift`) had a hardcoded
absolute path: `"/Volumes/ANAN/Engineering/wenshu/Sources/.../WorkspaceView.swift"`.
This meant:
- (= -) Tests only worked when the worktree was at the main checkout
- (= -) Moving the struct (= v1.32) would have broken the test even if the path was updated (= the new file is in a worktree)
- (= +) v1.32 rewrote the test to use `#filePath` (= relative path; = works in any worktree)

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Notes |
|---|---|---|
| 1 | **Continue splitting WorkspaceView** (= EditorPlaceholder = ~411 LOC, EditorPaperCanvas = ~437 LOC) | Future tickets per Q112 |
| 2 | **Split NavigationSplitShell** (= 1564 NLOC, top #2) | Future ticket |
| 3 | **Split PaneNSController** (= 1587 NLOC, top #4) | Future ticket |
| 4 | **Split PreviewPane** (= 1472 NLOC, top #3) | Future ticket |

**Per Q34 5.2 + Q173 ponytail + Q186 + Q112**: each subsequent
extraction = 1 ticket per file (= 1-3 file changes per ticket
depending on whether the extracted view has an existing test file
that needs path updates).

## Acceptance criteria

### Ticket 001 — Extract ZoneModuleView from WorkspaceView

- ✓ swift build --target WenshuAppTests = **BUILD COMPLETE in 9.29s**
- ✓ swift test --filter "ZoneModuleView" = **6/6 pass in 0.001s**
- ✓ No regression (= 36/36 tests across ForeshadowingView + PlaceholderView + MinimaxConnector)
- ✓ WorkspaceView.swift reduced 2139 → 1749 lines (-390)
- ✓ ZoneModuleView.swift created (= 398 lines = 28 header + 370 struct)
- ✓ ZoneModuleViewTests.swift path-independent (= uses #filePath)
- ✓ ZoneModuleView's public API unchanged (= same struct + init + body)
- ✓ 0 production code logic changes (= pure file move)