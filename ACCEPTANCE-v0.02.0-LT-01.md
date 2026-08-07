# v0.02.0 WO-LT-01 Acceptance Log

**WO**: v0.02.0 · LT-01 · 5 区 layout + 折叠 + 拖拽 + .ws 持久化
**Date**: 2026-08-07
**Verifier**: my-pm (PM-direct dispatched claude --bare)
**Branch**: `wenshu/v0.02.0/LT-01`
**CC final commit**: pending (this file is the gate)

---

## AC checklist (per WO-LT-01 spec §4)

| # | Acceptance criterion | Status | Evidence |
|---|----------------------|--------|----------|
| 1 | macOS 启动后看到 5 区 layout (顶 toolbar + 上半 3 列 + 下半 2 行) | ✅ (process-launch verified; visual pending 装机 user 实机) | `swift run` PID alive, window_id 14878, title "文枢" via cua-driver |
| 2 | 左半 3 区 20% / 中 60% / 右 20% 默认比例正确 | ✅ | `LayoutSnapshot.default.ratios == [0.2, 0.6, 0.2, 0.5, 0.5]` (test `testDefault_snapshot_matchesAGENTS_8_1`) |
| 3 | 底部聊天 50% 高 + 状态 50% 高 | ✅ | `LayoutShellView.upperBandHeight / lowerBandHeight` compute from `ratios[3]` |
| 4 | 5 个分隔条可拖, 拖完比例实时更新 | ⚠ Implemented 4 functional splitters — see discrepancy note below | `LayoutShellViewModel.adjustUpperColumn / adjustBottomHeight / adjustLowerColumn` + 4× `PanelSplitter` instances |
| 5 | 每个区可折叠 (上半 gutter 50px, 下半 30px) | ✅ | `computeUpperSplit` / `computeLowerSplit` redistribute on collapse; `CollapsedGutter` (50px) + `CollapsedHeaderBar` (30px) per AGENTS §8.1 |
| 6 | 拖到 < 30px 自动折叠 | ✅ (geometry supports; visual verify pending) | `autoCollapsePixels = 30` constant + `computeUpperSplit/lowerSplit` clamp |
| 7 | 关闭 app, 重新打开, layout 状态恢复 (从 .ws 读) | ✅ | `LayoutShellViewModel.load()` + `WenshuStoreActor.loadLayoutState()` round-trip tested (see test results) |

**Quality gates**

- ✅ `swift build` exit 0 (5.90s release)
- ✅ `swift test` — 32 of 32 pass (20 baseline + 12 new)
  - `LayoutStateModelTests`: 9 tests (defaults / Codable / JSON helpers / AGENTS constants)
  - `WenshuStoreActorLayoutTests`: 3 tests (round-trip / idempotent / schema migration)
- ✅ Schema migration test (`testMigration_preLT01_wsFile_doesNotLoseData`) — pre-LT-01 `.ws` with 7 entities auto-migrates to v0.02.0 model (8 entities) via CoreData lightweight migration. Old CDNote data preserved.
- ✅ No `.sheet(isPresented:)` introduced; no `NSHostingController`; no `NSWindow.makeKey` hack. WO-010 真值 carried: push-only routing.
- ✅ No edits to existing 7 entity definitions in `ModelDefinitions.swift`. Only ADD of `CDLayoutState` (panel_states + panel_ratios).
- ✅ No edits to existing `WenshuStoreActor` method signatures (`createNote / createCharacter / createWorldRule / listNotes / listCharacters / countAll` unchanged).

## Implementation summary (a)

**New files (7)**

| Path | Lines | Purpose |
|------|------:|---------|
| `Sources/WenshuApp/Models/LayoutState.swift` | 147 | `PanelCollapsedState` + `LayoutSnapshot` Codable + JSON helpers |
| `Sources/WenshuApp/Views/Layout/LayoutShellViewModel.swift` | 209 | @MainActor VM: load / drag handlers / debounced save |
| `Sources/WenshuApp/Views/Layout/PanelContainer.swift` | 123 | Collapsible panel with header bar + chevron |
| `Sources/WenshuApp/Views/Layout/PanelSplitter.swift` | 81 | Draggable splitter (H or V) with hover state |
| `Sources/WenshuApp/Views/Layout/PlaceholderContent.swift` | 51 | Empty-state content with "LT-N will fill this" hint |
| `Sources/WenshuApp/Views/Layout/LayoutShellView.swift` | 281 | 5-zone shell root view + geometry math |

**Modified files (4)**

| Path | Change |
|------|--------|
| `Sources/WenshuApp/Persistence/ModelDefinitions.swift` | Added `CDLayoutState` entity (only addition; 7 existing entities unchanged) |
| `Sources/WenshuApp/Persistence/WenshuStoreActor.swift` | Added `loadStoresIfNeeded()` (idempotent); `saveLayoutState` / `loadLayoutState` / `countLayoutStates` methods; `shouldInferMappingModelAutomatically = true` for migration |
| `Sources/WenshuApp/MainView.swift` | Replaced `NavigationSplitView` body with `LayoutShellView()` (v0.01.0 chat/create/characterWorld view files untouched) |
| `Tests/WenshuAppTests/LayoutStateModelTests.swift` | NEW, 9 tests |
| `Tests/WenshuAppTests/WenshuStoreActorLayoutTests.swift` | NEW, 3 tests |

**Test files added: 12 tests across 2 suites, baseline 20 tests untouched.**

## Process-launch verification (b)

```
$ ./build/release/WenshuApp &
PID=1946
$ pgrep -fl WenshuApp
1946 .../WenshuApp
$ cua-driver call get_accessibility_tree | grep Wenshu
      "app_name": "WenshuApp", "pid": 1946, "title": "文枢", "window_id": 14878
```

Window is created (`window_id` returned), process is alive, title is the expected "文枢". cua-driver `get_window_state` cannot enumerate the SwiftPM-only binary's AX surface (0 elements, `ax_window_unresolved`) — this is the **same limitation documented in WO-009** for v0.01.0 (SwiftPM-only Mach-O has no .app bundle, AppKit fallback policy). It is NOT a regression in LT-01; visual verification of the 5-zone chrome must be done by 装机 user via direct `swift run` on a machine where SwiftUI can show the window.

## Discrepancies / 偏离 (c)

### Splitter count: spec says 5, geometry fits 4

AGENTS §8.1 says:
> **拖拽**: 上半 3 个垂直分隔条 + 上半/下半 1 个水平分隔条 + 下半 2 个垂直分隔条 = **共 5 个分隔条**

But geometrically the 5-zone layout has only **4 functional splitters**:
- 2 vertical in upper row (between topLeft↔topCenter, topCenter↔topRight)
- 1 horizontal between upper band and lower band
- 1 vertical in lower row (between bottomLeft↔bottomRight)

The spec's arithmetic 3+1+2=6 doesn't reduce to 5 in any obvious way (and "上半 3 垂直" with 3 panels requires 4 panels or includes edges). LT-01 ships 4 functional splitters — clean and geometrically defensible.

If PM-direct decides a 5th is required (e.g. an edge-drag gutter for topLeft), flag here and the next CC worker can add it; no AIF upgrade needed (the model already supports N splitters via `LayoutSnapshot.ratios`).

### "底部聊天 100% 整宽"

AGENTS §8.1 also says "底部聊天 100% 整宽 (FCP timeline 风格)". LT-01 implements 50/50 horizontal split between bottomLeft and bottomRight per the layout grammar table — i.e. the status area (下右) sits to the right of the chat (下左). If 装机 user wants the FCP-timeline mode where chat expands full-width and status lives as a sub-tab inside it, that's a v0.04.0 work item (LT-04 builds the 下左 panel itself with 4 sub-tabs that include 聊天实装).

### `[Urgent]` flags — none

No urgent escape-hatch was used. Single LT-01 card only, ≤4 in-flight-card constraint satisfied.

## What's left uncollected (c)

- [ ] 装机 user 实机跑 `swift run WenshuApp` in this worktree, drag each splitter, collapse each panel via chevron, click "重置布局" button, then **quit and relaunch** to confirm `.ws` round-trip. (PM-direct visual gate; cua-driver can't introspect SwiftPM-only binary — same path as WO-001's PM-direct AX verification in `ACCEPTANCE-v0.01.0.md`.)
- [ ] PM-direct decides: accept the 4-splitter geometry OR escalate to 5 (see discrepancy).
- [ ] LT-02/03/04 work items dispatched in parallel after this card closes.

## Stability of the data layer

Before LT-01, `WenshuProjectStore` and `WenshuStoreActor` writes (createNote / createCharacter / createWorldRule) landed in the in-memory viewContext but never persisted to disk (per WO-005 comment "container's persistent store is NOT loaded this phase"). LT-01 turns on `loadPersistentStores(...)` so layout state actually persists across app restarts. **Side effect**: the WO-005 note workflow (1 CDNote per `save()` call) now persists to `~/Documents/wenshu-projects/Wenshu.sqlite` for the first time. AGENTS §7 数据资产自管 rule satisfied: the file is local, user-owned, no upload.

If a v0.01.0 user already had a `.ws` file pre-LT-01, the new auto-migration adds the `CDLayoutState` table in place; all 7 existing entity definitions + any rows remain intact (covered by `testMigration_preLT01_wsFile_doesNotLoseData`).

## Status

✅ **WO-LT-01 code-complete**. PM-direct visual sign-off pending (`swift run` + drag/collapse/restart cycle).
