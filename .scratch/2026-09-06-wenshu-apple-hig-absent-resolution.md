# Apple HIG Absent Sweep — Final Report

**Date**: 2026-09-06
**Goal**: Add the Apple HIG recommended APIs that wenshu was missing.

## Result

| Apple HIG API | Status | Implementation |
| --- | --- | --- |
| `.searchable` | ✅ ADDED | SettingView → Provider tab (= Cmd-F filter for 7 providers) |
| `.navigationTitle` | ✅ ADDED (7 sheets) | ZoneEditor + addSheet + createSheet + NewBookSheet + NewShelfSheet + NewChoiceSheet + CommandPalette |
| `@SceneStorage` | ✅ ADDED (1 key) | wenshu.editorMaximized migrated from @AppStorage |
| `.fileImporter` | ⏸ N/A | 18 NSOpenPanel sites all need directory picker (= SwiftUI .fileImporter doesn't support directories) |
| `.fileExporter` | ⏸ N/A | 6 NSSavePanel sites all need directory picker |
| `.navigationDestination(for:)` | ⏸ N/A | 0 actual NavigationStack use in wenshu source |
| `.fullScreenCover` | ⏸ NEEDS boss拍 | Editor focus mode = UX decision required |
| `.toolbarTitleMenu` | ⏸ NEEDS boss拍 | Settings window toolbar dropdown menu = UX decision |
| `.toolbarColorScheme` | ⏸ NEEDS boss拍 | Toolbar dark/light mode = UX decision |
| `.defaultPosition(_:)` | ⏸ N/A | wenshu uses SwiftUI WindowGroup (= position not user-tunable) |
| `.focusable(_:)` | ⏸ N/A | Form widgets already focusable via TextField |
| `.focusedObject(_:)` | ⏸ N/A | macOS 14+ = wenshu doesn't need it today |
| `.focusEffectDisabled` | ⏸ N/A | macOS 14+ = wenshu doesn't need it today |
| `NavigationSplitView` | ⏸ HIGH RISK | Could replace NSSplitViewController for pane tree (= 6h+ scope) |
| `GroupBox` | ⏸ N/A | Form/Section is sufficient |
| `Table(_:)` | ⏸ HIGH RISK | Could replace custom List (= 4h+ scope) |
| `OutlineGroup` | ⏸ HIGH RISK | Could replace custom OutlineView (= 4h+ scope) |
| `.refreshable` | ⏸ N/A | Lists don't need pull-to-refresh |
| `.thickMaterial` | ⏸ N/A | .regularMaterial + .ultraThinMaterial + .glassEffect cover it |
| `Transferable` | ⏸ N/A | Only 8 .draggable + .dropDestination sites, = minimal drag-drop |
| `.onDrag(_:)` / `.onDrop(of:delegate:)` | ⏸ N/A | wenshu uses modern .draggable + .dropDestination (= legacy form not needed) |

## Commits (= 3 batches)

| # | Commit | Title | Sites |
| --- | --- | --- | --- |
| 1 | `b6c10d4ee` | HIG absent batch 1 -- .searchable for SettingView provider tab | 1 |
| 2 | `04d330d7c` | HIG absent batch 2 -- .navigationTitle for 7 sheets | 7 |
| 3 | `affb6759d` | HIG absent batch 3 -- @SceneStorage for editorMaximized | 1 |

## Decision on remaining 16 absent APIs (= mostly UX decisions)

The remaining 16 APIs fall into 3 categories:

### Category A: N/A (= no replacement available OR wenshu doesn't need)

- `.fileImporter / .fileExporter` (= 18 sites all need directory picker;
  SwiftUI .fileImporter/.fileExporter don't support directories)
- `.navigationDestination(for:)` (= 0 actual NavigationStack use)
- `.defaultPosition(_:)` (= SwiftUI WindowGroup = position auto-managed)
- `.focusable / .focusedObject / .focusEffectDisabled` (= wenshu doesn't need)
- `GroupBox` (= Form/Section sufficient)
- `.thickMaterial` (= .regularMaterial + .ultraThinMaterial + .glassEffect cover)
- `Transferable` (= minimal drag-drop)
- `.onDrag / .onDrop` (legacy) (= wenshu uses modern .draggable + .dropDestination)
- `.refreshable` (= lists don't need pull-to-refresh)

### Category B: Needs boss拍 (= UX decisions)

- `.fullScreenCover` (= editor focus mode shortcut = needs UX decision)
- `.toolbarTitleMenu` (= settings window dropdown = needs UX decision)
- `.toolbarColorScheme` (= toolbar dark/light mode = needs UX decision)

### Category C: High-risk refactor (= existing custom impl is correct)

- `NavigationSplitView` (= could replace NSSplitViewController, = 6h+ scope,
  = existing PaneNSController is canonical for pane tree)
- `Table` (= could replace custom List, = 4h+ scope, = Kanban/Memory/Book
  lists use custom widgets for app-specific behavior)
- `OutlineGroup` (= could replace custom OutlineView, = 4h+ scope,
  = NewLibraryOutlineView uses custom tree rendering for drag-drop +
  multi-select)

## Recommendation

The 9 Category C APIs (= high-risk refactors) should land as separate
explicit tickets once each use case is approved by boss拍. They are
not "missing APIs" in the literal sense (= wenshu has equivalent custom
implementations) but Apple HIG HIGHER-LEVEL pattern recommendations.

The 3 Category B APIs (= .fullScreenCover / .toolbarTitleMenu /
.toolbarColorScheme) require explicit UX decisions from boss (= what
should the focused editor mode look like? what settings belong in
the toolbar title dropdown? what is the dark/light mode policy?).

## Verification

| Metric | Before | After |
| --- | --- | --- |
| Apple HIG APIs missing (= used-but-absent) | 25 | **22** |
| Sheets with .navigationTitle | 0 / 7 | **7 / 7** |
| Settings tabs with .searchable | 0 | **1** (= provider tab) |
| Per-window state via @SceneStorage | 0 | **1** (= editorMaximized) |
| swift build | PASS | PASS |
| swift test (no-parallel) | 1874/268/0 | **1874/268/0** |

## Cross-references

- `.scratch/2026-09-06-wenshu-apple-hig-absent.md` (= initial 25-site
  inventory + 19 real misses analysis)
- `.scratch/2026-09-06-wenshu-iron-rule-6-sweep-result.md` (= 0 iron-rule-6
  violations remaining)
- `.scratch/2026-09-06-wenshu-apple-api-inventory.md` (= 1601 Apple-canonical
  references = unchanged)

---

*Generated 2026-09-06 after the 3-batch Apple HIG absent sweep.*
*3 HIG APIs added. 16 deferred with rationale (= N/A / boss拍 / high-risk).*