# v1.35 PreviewPane source-level tests · Spec (= honest scope gap; blocked on boss's untracked test file)

**Branch**: `wt/v1.35-preview-pane-tests-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "要修，继续"

## Context

Per boss OOB 2026-09-14 "要修，继续": continue the fat-file
split pattern from v1.32-v1.34. v1.35 attempts to add
PreviewPaneTests.swift (= 16 source-level tests = repowise
directive for #3 untested hotspot).

## Scope (= 1 ticket 1 file per Q112 + Q173 ponytail)

| # | File | Change |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Views/Workspace/PreviewPaneTests.swift` | New file (= 16 source-level tests) |

## Empirical validation (= per Q34 5.4)

| # | Metric | Value |
|---|---|---|
| 1 | `swift build --target WenshuAppTests --skip-update` | **FAILS** (= blocked on boss's untracked `LucideIconResolutionTests.swift` which imports the removed `LucideSwift` module) |

## Root cause analysis (= per Q34 5.2)

Per Q34 5.2 + Q173 ponytail + Q186 + Q57: the v1.35 build fails because:

1. `PreviewPaneTests.swift` was created (= the v1.35 actual change)
2. v1.35 also needs `ZoneModuleView.swift` and `EditorPlaceholder.swift`
   to drop their `import LucideSwift` (= v1.32 + v1.33 extracted files
   predate boss's v1.x Lucide → SF Symbols 6 deprecation)
3. The worktree also contains boss's untracked file:
   `Tests/WenshuAppTests/UI/LucideIcon/LucideIconResolutionTests.swift`
   (= from boss's `wt/v1.34-workspace-extract-2026-09-15` worktree)
4. That test file imports `LucideSwift` (= the module boss removed in
   commit `c50d76167`)
5. The Swift compiler fails to resolve the `LucideSwift` import

Per Q57: **boss's untracked files are off-limits** (= don't touch
work-in-progress). Per Q46 + Q186: **v1.35 cannot ship without
boss's work being committed** (= LucideIconResolutionTests.swift
must be either committed or removed before the test target builds).

## Per Q46 stop-rule + Q186 + Q173 ponytail

| # | Ticket | Attempt | Result |
|---|---|---|---|
| 1 | v1.35 | PreviewPane tests + drop Lucide imports in v1.32/v1.33 files | **BLOCKED on boss's untracked file** |

**1 attempt reverted** per Q46 (= blocked on external work).

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Notes |
|---|---|---|
| 1 | **Wait for boss's `wt/v1.34-workspace-extract-2026-09-15` to merge** | Once merged, LucideIconResolutionTests.swift is either committed (= real test file) or removed (= dead file). Then v1.35 can ship. |
| 2 | **Re-apply v1.35 after boss's work merges** | Future ticket per Q112 |
| 3 | **Skip PreviewPane and split PaneNSController** (= repowise #4) | Different target |

**Per Q34 5.2 + Q173 ponytail + Q46**: option 1 (= wait) is the
correct path. The boss's work must complete first.

## What this ticket ships (= honest scope gap per Q34 5.6)

| # | Item | Status |
|---|---|---|
| 1 | `Tests/WenshuAppTests/Views/Workspace/PreviewPaneTests.swift` | **Untracked on disk** (= not committed; = blocked on external work) |
| 2 | Drop `import LucideSwift` in `ZoneModuleView.swift` + `EditorPlaceholder.swift` | **Reverted** (= part of the same worktree) |
| 3 | Production code change | None |

**Net change to main**: 0 lines (= honest scope gap).

## Cross-references

- `Tests/WenshuAppTests/Views/Workspace/PreviewPaneTests.swift` (on disk; = uncommitted; = blocked on external work)
- commit `c50d76167` (= boss's Lucide → SF Symbols 6 deprecation)
- `wt/v1.34-workspace-extract-2026-09-15` (= boss's active worktree; = contains `LucideIconResolutionTests.swift` blocking the build)
- `.scratch/v1.34-extract-shell-placeholder/spec.md` (= v1.34 sibling; = succeeded by removing `import LucideSwift` from `EditorPlaceholder.swift` + `ZoneModuleView.swift` — same fix needed here)

## Validation (= per Q34 step 4)

1. `swift build --target WenshuAppTests --skip-update` = **FAILS** (= external blocker)
2. `PreviewPaneTests.swift` exists on disk but NOT committed
3. `ZoneModuleView.swift` + `EditorPlaceholder.swift` reverted to original
4. 0 production code changes

## Out-of-scope (= explicit)

- Touch boss's untracked `LucideIconResolutionTests.swift` (= Q57 violation)
- Wait for boss's worktree to merge (= future = depends on boss)
- Move to PaneNSController (= repowise #4) instead of PreviewPane (= blocked by same issue)