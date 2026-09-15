# v0.92 LiquidGlassPolishTests fix · Spec

**Branch**: `wt/v0.92-liquid-glass-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

`LiquidGlassPolishTests.testAllFivePolishSurfacesWired()` (= 5 issues)
expected 6 files to contain `.glassEffect(.regular)`. Per boss 2026-09-07
real-device testing and subsequent code evolution, several of these
files no longer match the test's snapshot expectations.

Per boss OOB "A": fix the test (= the production code evolved
according to boss's real-device decisions; = per Q57: 3rd-party
verdict ≠ authority; = update the test to match the current architecture).

## Scope (= 1 ticket, 1 test file 1 commit per Q112)

| # | Ticket | File(s) | Status |
|---|---|---|---|
| 1 | `001-liquid-glass-test-update` | `Tests/WenshuAppTests/UI/Polish/LiquidGlassPolishTests.swift` | ✅ done |

Total v0.92 = **1 file changed**, **~20 lines modified**, **0 prod code
changes**.

## Files removed from the test's expected list (= per boss real-device decisions)

| File | Status | Why removed |
|---|---|---|
| `Sources/WenshuApp/UI/RegionTabBar.swift` | Doesn't exist (= replaced by `PaneTabBar.swift`) | Refactor moved the canonical tab bar |
| `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` | Uses Apple native `.listStyle(.sidebar)` | Apple owns the styling per HIG (= no custom view body to apply .background to) |
| `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Uses `.background(Color.white)` / `.ultraThinMaterial` / `Color.clear` | Boss 2026-09-07 real-device decisions |
| `Sources/WenshuApp/Core/LinkGraph/BacklinksPanel.swift` | Uses `.background { Color.clear }` | Boss 2026-09-07 real-device test removed `.glassEffect(.regular)` (= per the existing comment at line 116) |

## Files kept in the test's expected list (= production code already wired)

| File | Status | Why kept |
|---|---|---|
| `Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift` | `.background { Color.clear.glassEffect(.regular) }` at line 194 | Boss 2026-09-07 decision kept this surface |
| `Sources/WenshuApp/Views/Library/BookEditorSheet.swift` | `.background { Color.clear.glassEffect(.regular) }` at line 157 | Boss 2026-09-07 decision kept this surface |

## Per-ticket acceptance criteria

### Ticket 001 — test update

- `swift test --filter "LiquidGlassPolishTests"` = 2/2 pass
  (= previously 5 fail)
- `swift build` = BUILD COMPLETE (= test file only)
- No production code changes (= test-only)

## Cross-references

- `Tests/WenshuAppTests/UI/Polish/LiquidGlassPolishTests.swift` (= this
  branch)
- `Sources/WenshuApp/UI/PaneTabBar.swift` (= the renamed tab bar; =
  already has `.glassEffect` per grep)
- `.scratch/v0.91-pre-existing-flakes/spec.md` (= the upstream flake
  analysis that flagged this as out-of-scope for v0.91)

## Validation (= per Q34 step 4)

1. `swift test --filter "LiquidGlassPolishTests"` = **2/2 pass**
2. `swift build` = BUILD COMPLETE
3. Test name changed from "All 5 polish surfaces" to retain the
   documented boss 2026-09-07 decisions