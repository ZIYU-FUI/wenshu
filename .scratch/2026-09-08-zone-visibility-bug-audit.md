# Zone Visibility Bug Audit · 2026-09-08 · pocock

Boss directive: "排查各区域显隐的代码。看 apple API 全套的解决方案
我们是不是没有用全，现在一个区域隐藏后，再显示会重新分配错误。
变得很窄"

## Bug reproduction (= confirmed)

1. Launch wenshu.app (= commit 3bec5a840, build Sep 8 00:04)
2. Baseline widths (= `.scratch/2026-09-07-launched/baseline-all-zones.png`):
   - sidebar ~230 PT
   - cards ~315 PT
   - editor ~545 PT
   - tools ~180 PT (合计 ~1270 PT inner width)
3. Cmd+Shift+2 (= menu bar toggle "工具区" = .specializedTools)
   → `.scratch/2026-09-07-launched/after-hide-tools.png`
   → tools zone collapses correctly (= NSSplitViewItem.isCollapsed
   toggled → the 3 remaining zones auto-expand to fill)
4. Cmd+Shift+2 again (= restore tools zone)
   → `.scratch/2026-09-07-launched/after-restore-tools.png`
   → **tools zone returns at ~770 PT width (= much wider than baseline 180)**
   → sidebar / cards / editor all squeezed to ~94 / ~120 / ~470 PT
   → **the weights did NOT restore correctly**

## Root cause (= the manual snapshot/restore fights Apple)

The current code at
`Sources/WenshuApp/Views/Layout/PaneNSController.swift`:

1. `installSplit` line 1031: `self.splitView.autosaveName = nil`
   (= disables Apple's built-in divider persistence on the ROOT
   splitView; nested splits still get autosaveName per line 1315).
2. `handleToggleZone` line 499-558:
   - find matching NSSplitViewItem by TabKind (= walks self +
     children controllers)
   - on hide → `captureZoneToggleSnapshot(slot:)` → reads
     `holdingPriority.rawValue` of all 6 zones into UserDefaults
     JSON under `wenshu.zoneToggle.snapshot`
   - on show → `restoreZoneToggleSnapshot()` → reads JSON, applies
     weights back via `applyZoneSplitWeight` then `toggleZone` for
     visibility flip
3. `currentZoneSplitWeight` line 627: `Double(item.holdingPriority.rawValue)`
   (= reading rawValue of NSLayoutConstraint.Priority; = priority
   bucket not a percentage; = defaultPriority.rawValue = 251 ≈ 0.4
   in normalized)

### Why it breaks after multi-toggle

- `holdingPriority` is a **bucket priority** (= .defaultLow=150,
  .defaultHigh=251, .required=1000), not a precise pixel weight.
- The first toggle captures `251` (= defaultHigh = the Apple
  default for split items). Subsequent restore applies 251 back.
- But `NSSplitView` itself **also maintains its own divider
  positions internally** based on its auto-layout pass after the
  collapse animation. When `item.animator().isCollapsed.toggle()`
  toggles from `false → true`, the splitView auto-resizes
  remaining items to fill. When `false → true → false`, the
  un-collapsed item appears but the splitView's auto-layout may
  have **already recalculated** the divider positions based on
  the visible items. = **the manual `holdingPriority` write
  loses the race against the splitView's auto-layout**.
- `NSSplitViewItem.holdingPriority` only influences resize
  behavior on user drag (= not on the initial post-collapse
  layout). So our `applyZoneSplitWeight` doesn't actually
  constrain the restored width.

### Why the bug shows as "very narrow" zones

When 5 zones are visible after restoring tools (= 4 in upper band
+ 1 in lower band), the splitView's auto-layout re-allocates
divider positions based on the natural content min/ideal sizes of
each pane. Since most panes have no explicit min size set, they
shrink to their natural minimum (= sidebar = outline with no
min width = ~50 PT; = cards = LazyVGrid min cell size = ~80 PT;
= editor = TextEditor with intrinsic size = ~120 PT; = tools =
NSToolbar min height/width = ~100 PT). Without autosaveName
persistence, the divider positions get re-computed from these
natural minimums = the "very narrow" symptom.

## Apple HIG canonical solution

For multi-zone macOS layouts (= 6 zones in wenshu), the canonical
Apple solution is `NSSplitView` + `NSSplitViewController` with:

1. **`NSSplitView.autosaveName` set on EVERY splitView** (=
   the root + every nested). NSSplitView's built-in state
   restoration persists divider positions + collapsed/expanded
   state of `canCollapse` items to UserDefaults under the
   autosaveName. = **no manual JSON snapshots needed**.

2. **`NSSplitViewItem.canCollapse = true`** on items that
   should be hideable (currently 5 of 6; editor = always
   visible per boss 8/12 OOB "editor must never be hidden").

3. **No manual `holdingPriority` write**. The Apple default
   priority is correct for the most common case (= equal
   resizing among visible panes). Only override priority when
   a specific zone must dominate (= e.g. editor = .required
   so it never shrinks below ideal).

4. **Minimum/maximum widths via `NSSplitViewItem.preferredThicknessHorizontalRange`**:
   - sidebar: min=180, max=400 (= tree outline natural)
   - cards: min=200, max=500
   - editor: min=400, ideal=stretch, max=nil
   - tools: min=120, max=300

5. **Visibility toggle**: `item.animator().isCollapsed.toggle()`
   only (= let autosaveName handle state persistence).
   Remove the `captureZoneToggleSnapshot` /
   `restoreZoneToggleSnapshot` methods (= dead code once
   autosaveName takes over).

6. **Apply presets on install (= first launch only)** via
   `NSSplitView.setPosition(_:ofDividerAt:)` after the
   controller's view has laid out. Subsequent launches let
   autosaveName restore the user's last divider positions.
   = **the preset weights stay as the default for first
   launch; autosaveName takes over for subsequent launches**.

7. **For multi-band layouts (= upper + lower band)**:
   - root = `.column` (= vertical split between upper + lower)
   - upper band = `.row` (= horizontal split between 4 zones)
   - lower band = `.row` (= horizontal split between chat + dynamic)
   - each nested `NSSplitView` gets its own autosaveName
   (= per-band divider persistence; = user can drag a band's
   dividers without affecting the other band's positions).

## What needs to change (= the actual fix)

1. `installSplit` line 1031: change `self.splitView.autosaveName = nil`
   → `self.splitView.autosaveName = "wenshu.root.<layoutPresetID>"`
   (= per-preset so preset switch doesn't break user's drag tweaks).
   Remove the comment that justifies disabling autosaveName
   (= the comment was correct in v0.30 but the issue was elsewhere).

2. `currentZoneSplitWeight` / `applyZoneSplitWeight` /
   `captureZoneToggleSnapshot` / `restoreZoneToggleSnapshot`:
   **DELETE** (= ~150 LOC). They're fighting Apple's built-in
   persistence.

3. `handleToggleZone`: simplify to:
   ```swift
   item.animator().isCollapsed.toggle()
   // nothing else — let NSSplitView.autosaveName handle persistence
   ```
   = ~50 LOC removed.

4. `installSplit`: add min/max width constraints via
   `NSSplitViewItem.preferredThicknessHorizontalRange` (= the
   natural content min sizes become the divider position
   floor; = zones never shrink below their natural min).

5. `applyPersistedZoneVisibility` (line 169 area): this is the
   startup state restore. **Move to use autosaveName's
   built-in collapse state**, not the `wenshu.zoneVisible.*`
   UserDefaults bools. The bools were a workaround for the
   broken snapshot/restore path; once autosaveName is correct,
   the bools become redundant.

## Risk

- **Bigger drag UX diff than usual** (= the fix changes the
  core persistence layer of the 6-zone workspace).
- **Per-layout-preset autosaveName**: each preset
  (= default / writing / review / ?) needs its own autosaveName
  string (= otherwise switching presets would re-use the old
  preset's divider positions).
- **Test impact**: 8/8 DragRegressionTests should still pass
  (= they don't test divider position restoration; = low risk
  for those).

## Recommendation

Split into 2 commits (= 2 atomic units so each can be reverted
independently if needed):

**Commit A** (= "trust autosaveName"): add autosaveName to the
root splitView, remove the manual snapshot/restore methods
(= hold the visibility toggle API stable). This is the **fix**
that solves the bug boss reported.

**Commit B** (= "preferredThicknessHorizontalRange"): add the
min/max width constraints so the natural content min sizes
define the divider floor (= no zone can shrink below its
natural min even after drag).

Or as one commit (= smaller, more atomic; but more risky if
something goes wrong mid-test).

## Status

- ⏸ Pending boss拍 (= boss said "排查各区域显隐的代码"
  = investigate; = the question is open whether to fix in
  this turn or just report).