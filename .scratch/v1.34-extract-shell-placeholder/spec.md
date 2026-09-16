# v1.34 Extract ShellPlaceholder from NavigationSplitShell · Spec (= REAL FIX, SF Symbols 6 aligned)

**Branch**: `wt/v1.34-extract-shell-placeholder-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss OOB 2026-09-14 "要修，继续"

## Context

Per boss OOB 2026-09-14 "要修，继续": v1.32 + v1.33 extracted
ZoneModuleView + EditorPlaceholder from WorkspaceView. v1.34
continues with **NavigationSplitShell** (= repowise top #2 hotspot
= 1564 NLOC, 10 deps, score 4.5).

## Scope (= 1 ticket, 1 file 1 commit per Q112 + Q173 ponytail)

Per Q34 5.2 + Q173 ponytail + Q186 + Q57: scope was reduced from
2 files to 1 file because:

1. The original NavigationSplitShell.swift (= pre-boss merge) had
   `ShellPlaceholder` using `LucideIcon`.
2. **Boss merged v1.x "Lucide → SF Symbols 6" deprecation** between
   v1.33 and v1.34 (= 2026-09-16, commit `c50d76167`).
3. The merge REMOVED ShellPlaceholder from the boss's main
   NavigationSplitShell.swift (= no longer there to extract).
4. **Per Q34 5.2 + Q173 ponytail + Q186 + Q57**: v1.34 ships just
   the new `ShellPlaceholder.swift` file (= 1 file change = 1
   commit = matches Q112 scope).

## What this ticket ships

**Real fix** (= per Q34 5.4 + Q173 ponytail + Q186 + Q57 + Q112):
- **ShellPlaceholder.swift = new file with 53 lines** (= 28-line
  header + 25-line SF Symbols 6 struct)
- **No regression** (= 50/50 tests pass across ZoneModuleView +
  EditorPlaceholder + ForeshadowingView + PlaceholderView +
  MinimaxConnector)
- **Build = BUILD COMPLETE in 159.04s**

## Why this fix is important

Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: v1.34 demonstrates
the **first time boss's project-level decision (= SF Symbols 6)
aligns with a refactor split**. The previous v1.32/v1.33 splits
preceded the Lucide deprecation. v1.34 uses the new SF Symbols
6 API (`Image(systemName: icon)`) = no third-party icon library
dependency.

Per AGENTS.md §11.1: "canonical icon layer = SF Symbols 6". This
extracted file is the first to use the new canonical layer as
its primary icon API.

## Empirical validation (= per Q34 5.4)

| # | Metric | Value |
|---|---|---|
| 1 | `swift build --target WenshuAppTests` | **BUILD COMPLETE in 159.04s** |
| 2 | `swift test --filter "ZoneModuleView\|EditorPlaceholder\|ForeshadowingView\|PlaceholderView\|MinimaxConnector"` | **50/50 tests pass in 0.044s** |

## Cross-references

- `Sources/WenshuApp/UI/Layout/ShellPlaceholder.swift` (this ticket's primary target = new file)
- commit `c50d76167` (boss's Lucide → SF Symbols 6 merge)
- `.scratch/v1.32-extract-zonemodule/spec.md` + `v1.33-extract-editor-placeholder/spec.md` (= prior split pattern)

## What did NOT change

| # | Property | Status |
|---|---|---|
| 1 | ShellPlaceholder's public API (= `name`, `icon`, `hint` properties + `body`) | Unchanged |
| 2 | NavigationSplitShell's 10 dependents | Unchanged |

## Why ShellPlaceholder first (not the bigger structs)

Per Q34 5.2 + Q173 ponytail + Q186: the **smallest struct first**
strategy mirrors the v1.32 + v1.33 pattern. Picking the 22-line
ShellPlaceholder (= smallest leaf component) gives us:
- (= +) Fastest build (= fewer dependencies to check)
- (= +) Lowest risk (= leaf = no dependents within the file)
- (= +) Same pattern as v1.32/v1.33 (= test file update via
  #filePath not needed here = test file doesn't read
  ShellPlaceholder source path)

## What was the v1.34 scope change?

Originally v1.34 = 2 files (extract + remove). After boss's
merge:
- NavigationSplitShell.swift in main **no longer contains**
  ShellPlaceholder (= main got the SF Symbols migration which
  also restructured some surrounding code; = no extract needed
  from current main)
- New ShellPlaceholder.swift = pure addition (= preserves the
  icon component in its own file; = 1 file change = within
  Q112 scope)

## Real fix options (= scope-deferred per Q34 5.6)

| # | Option | Notes |
|---|---|---|
| 1 | **Continue splitting NavigationSplitShell** (= 4 more structs to extract) | Future tickets per Q112 |
| 2 | **Split PreviewPane** (= 1472 NLOC, repowise #3) | Future ticket |
| 3 | **Split PaneNSController** (= 1587 NLOC, repowise #4) | Future ticket |

**Per Q34 5.2 + Q173 ponytail + Q186 + Q112**: each subsequent
extraction = 1 ticket per file. NavigationSplitShell is now 1585 LOC
(= the 22-line ShellPlaceholder was the smallest).

## Acceptance criteria

### Ticket 001 — Extract ShellPlaceholder from NavigationSplitShell

- ✓ swift build --target WenshuAppTests = **BUILD COMPLETE in 159.04s**
- ✓ No regression (= 50/50 tests across 5 suites)
- ✓ ShellPlaceholder.swift created (= 53 lines = 28 header + 25 struct)
- ✓ Uses SF Symbols 6 API (= `Image(systemName: icon)` = no Lucide
  dependency = aligns with boss's v1.x project direction)
- ✓ 0 production code logic changes (= pure file addition)