# 12: Zone-toggle full-state snapshot (= B-12)

## Boss OOB context

Boss 2026-09-02 (= this session, OOB during Q34 step 1 review): '各区显示隐藏也存在同样的 bug, 就是因为只记录显隐不也记录其他, 导致显隐多次后, 视图完全混乱' = same bug as the editor-expand path (= Q33/Q38): only recording visibility flags, not full state, so multi-toggle leaves the layout in an inconsistent state.

Reference: v0.34 ticket 02 (= EditorExpandShrinkTrailingButton fix) captured full 6-zone state + editor split weight in UserDefaults JSON BEFORE collapsing, then restored from snapshot on shrink. Zone-toggle needs the same pattern.

## What to build

Patch `PaneNSController.handleToggleZone(_:)` so the 5 toolbar toggle buttons (= sidebar / preview / tools / chat / dynamic — = boss 8/29 OOB) capture + restore full state (= same shape as handleEditorMaximizedChanged from ticket 02):

  - Before hiding a zone: capture 6-zone isCollapsed state + per-zone split weight (= holdingPriority) to UserDefaults JSON under key `wenshu.zoneToggle.snapshot`.
  - After hiding a zone: nothing extra (= existing toggle behavior preserved).
  - Before showing a zone (= restoring from collapsed state): read snapshot JSON, restore the per-zone weight first, then the visibility.

Snapshot payload shape (= mirrors ticket 02 = single source of truth for snapshot format):
```json
{
  "zoneVisible": { "projectSidebar": true, ... },
  "weights":     { "projectSidebar": 0.498, "editor": 0.498, ... }
}
```

## Blocked by

None (= independent of ticket 11 = Q34 chain closed; this is B-12 follow-up).

## Status

ready-for-agent

## Acceptance criteria

- [ ] `handleToggleZone` snapshots full 6-zone state before collapse (= uses existing `allZoneSlots()` + `currentZoneSplitWeight` helpers from ticket 02 if extractable; otherwise duplicates per ticket 02 spec)
- [ ] Snapshot JSON written to `wenshu.zoneToggle.snapshot` (= separate key from `wenshu.editorExpand.snapshot` = no interference with the editor-expand path)
- [ ] `handleToggleZone` reads snapshot before expanding, restores per-zone weight first then visibility
- [ ] Build exit 0
- [ ] No regressions in `handleEditorMaximizedChanged` (= ticket 02 path uses separate snapshot key + helper)
- [ ] Zero `forbidden vocab` in commit body (AGENTS.md hard rule)

## Iron rules applied

- Rule 11: UserDefaults standard storage (= JSON-encoded dict, = ticket 02 pattern)
- Rule 6: NSLayoutConstraint.Priority(.rawValue) for weight (= no custom serialization)
- wenshu-apple-api-first: reuse existing `toggleZone(_:)` / `paneKindByItem` / `splitViewItems` from ticket 02
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

## Double-axis review (= Q37 streak rule)

- [ ] Standards axis: AGENTS.md hard rules + 11 iron rules
- [ ] Spec axis: snapshot shape matches ticket 02 (= single source of truth for snapshot pattern)
