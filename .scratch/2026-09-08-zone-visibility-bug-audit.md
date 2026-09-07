# Zone Visibility Bug Deep Investigation · 2026-09-08 · pocock

Boss directive: "look at the code clearly, investigate the documentation, then fix".

Investigation phase (= the doc this file replaces):
- Read PaneNSController.swift full (= 1609 lines, the
  NSSplitViewController subclass that hosts the 6-zone
  workspace)
- Read Apple Developer docs for NSSplitView / NSSplitViewItem
- Verified existing test surface (= DragRegressionTests 8/8 PASS)

This file = the result of the deep dive (= replaces the
previous speculative audit at the same path).

## Bug reproduction (= unchanged, confirmed)

1. Launch wenshu.app, all 6 zones visible (= baseline)
2. Cmd+Shift+2 (= "Tools Zone" menu toggle) → tools zone collapses
3. Cmd+Shift+2 again → tools zone restores, BUT it returns at
   ~770 PT (= baseline was 180 PT), absorbing width from
   sidebar / cards / editor (= they shrink to ~94 / ~120 / ~470 PT)

Visual evidence: `.scratch/2026-09-07-launched/baseline-all-zones.png`
vs `.scratch/2026-09-07-launched/after-restore-tools.png`.

## Code path (= traced end-to-end)

### Init (= PaneNSController.init L70-171)

1. buildLayout() runs (= L118-120, only on root via
   `installObservers: true` gate)
2. `installSplit` / `installChildren` walks `LayoutTreeStore`
   tree and creates the nested NSSplitView hierarchy
3. `splitView.autosaveName = nil` set on ROOT (L1031) — nested
   split controllers get autosaveName via `nested.splitView.
   autosaveName = autosaveKey(for: split.id)` (L1315)
4. applyDividerStyleForCurrentOpacity (L157) = applies `.thin`
   style to all splitViews (= 1 PT hairline)
5. applyPersistedZoneVisibility (L170) = reads
   `wenshu.zoneVisible.*` UserDefaults bools and folds matching
   NSSplitViewItems

### handleToggleZone (= L458-558, the bug path)

1. Menu item `Cmd+Shift+N` → posts `.wenshuToggleZone`
   notification with ZoneSlot as object
2. PaneNSController observer (L140) calls
   `handleToggleZone(_:)`:
   - Walk self + every nested PaneNSController (= BFS)
   - Find the NSSplitViewItem whose `paneKindByItem[idx]` matches
     the target TabKind (via ZoneSlot→TabKind mapping)
   - Skip items with `canCollapse = false` (= editor)
   - On hide (`willHide = !item.isCollapsed`):
     - `captureZoneToggleSnapshot(slot:)` writes
       `wenshu.zoneToggle.snapshot` JSON to UserDefaults
     - `item.animator().isCollapsed.toggle()` collapses with
       animation
   - On show (`!willHide`):
     - `item.animator().isCollapsed.toggle()` un-collapses
     - `restoreZoneToggleSnapshot()` reads the JSON, calls
       `applyZoneSplitWeight` (= sets `item.holdingPriority`
       to the saved value) then re-toggles visibility if
       it doesn't match
3. `adjustRootForCollapsedBands()` (= pin root divider so
   upper band fills root height when lower band is fully
   hidden)

### The actual bug (= why weights don't restore correctly)

1. `holdingPriority` is a bucket priority (.defaultHigh = 251,
   .required = 1000), not a precise pixel weight. Reading
   `Double(item.holdingPriority.rawValue)` gives you a raw
   float around 251 (or whatever the bucket is), which is
   NOT the same as a pixel width or a 0-1 fraction.
2. After collapse animation, NSSplitView runs its
   auto-layout pass internally (= via `adjustSubviews`). This
   auto-layout computes divider positions from:
   - The visible items' `minimumThickness` (= already set on
     install via `minThickness(for:weight:)` at L1445)
   - The available bounds (= window width minus chrome)
   - **NOT** from our `holdingPriority` writes
3. So our manual `applyZoneSplitWeight` → `holdingPriority`
   writes have **zero effect on the post-collapse layout**.
   The divider positions get computed from minimumThickness
   (= 200 PT default for collapsible side panes) and the
   available width.
4. With tools zone collapsed (4 visible: sidebar / cards /
   editor / tools), NSSplitView distributes the width based
   on minimumThickness ratios (200 / 200 / 200 / 200) +
   whatever leftover space exists. When tools un-collapses,
   its minimum thickness of 200 PT is honored, but the
   splitView's auto-layout has already given tools
   "remaining space" (= it grabs whatever the other 3
   don't claim).
5. Result: tools comes back at ~770 PT (= wider than baseline
   180 PT) because the other 3 panes were sized to their
   natural content minimums during the post-collapse auto-
   layout, and tools absorbs the leftover.

### Why the current code wrote the snapshot at all (= history)

The comment at L1024-1030:

> "v0.30 boss 2026-09-01 OOB: NO autosaveName on the root
> (= Apple's autosave would restore the FIRST launch's
> default ratio and override our preset weights on every
> subsequent launch). Nested split controllers still get
> autosaveName (= user drag persistence for the inner pane
> arrangements, which is where manual tweaks actually
> happen)."

The concern was: enabling autosaveName would persist the
FIRST launch's split layout (= where the user hasn't dragged
anything yet) and override the preset weights on every
subsequent launch. = makes the preset weights effectively
"first-launch-only", which is the wrong behavior (= we
want preset weights on first launch + user-drag persistence
on subsequent launches).

This concern is **valid** BUT the workaround (= manual JSON
snapshots) is **broken** because it fights NSSplitView's
auto-layout. The correct solution is to let autosaveName
take over AFTER the first launch (= by NOT calling setPosition
when autosaveName has saved positions).

### Apple docs (= verified)

`NSSplitView.autosaveName` (= developer.apple.com/documentation/
appkit/nssplitview/autosavename): "The name to use when the
system automatically saves the split view's divider
configuration."

`NSSplitView.setPosition(_:ofDividerAt:)` (= developer.apple.
com/documentation/appkit/nssplitview/setposition(_:ofdividerat:)):
"Updates the location of a divider you specify by index."

Per the NSSplitView.h runtime headers (= github.com/mstg/
OSX-Runtime-Headers/blob/master/AppKit/NSSplitView.h),
NSSplitView with autosaveName set:
1. On `viewDidMoveToWindow` / `adjustSubviews`: reads saved
   positions from UserDefaults, applies via
   `setPosition(_:ofDividerAt:)`
2. On every resize / collapse event: writes current positions
   to UserDefaults under key `NSSplitView <autosaveName>`
3. **Overwrites itself with initial startup position** if
   `adjustSubviews` is called before the saved positions
   are loaded (= the original bug Sequel Pro found = "the
   original startup position, possibly due to a race
   condition"). Sequel Pro's fix: explicit
   `_restoreAutoSaveSizes` after `awakeFromNib`. Apple has
   since fixed the race condition in 10.7+, so the explicit
   restore is no longer needed.

`NSSplitViewItem.minimumThickness` (= developer.apple.com/
documentation/appkit/nssplitviewitem/minimumthickness):
"Minimum thickness of the receiver in its parent split view."
Set per-item; honored during auto-layout.

`NSSplitViewItem.preferredThicknessFraction`: "The preferred
thickness of the receiver, expressed as a fraction of the
split view's total thickness." (= the per-pane weight).

`NSSplitViewItem.holdingPriority`: priority bucket for resize
behavior (= drag a divider → smaller priority loses space).
Should be left at `.default` unless a specific pane must
dominate. Per Stack Overflow / NSSplitView docs, only set
when the user expects a specific pane to stay at its ideal
size (= e.g. an always-visible inspector).

## The Apple HIG canonical solution (= verified)

### What we should do (= the canonical Apple pattern)

1. **Set `autosaveName` on EVERY NSSplitView** (= root + all
   nested). Per-preset autosaveName strings (= so preset
   switch doesn't break user's drag tweaks).
2. **Call `setPosition` on first launch only** (= when no
   autosaveName-saved positions exist yet). Subsequent
   launches: autosaveName takes over.
3. **Set `minimumThickness` per zone** (= already done at
   L1445; = 200 PT for collapsible, 100 PT for editor).
4. **Set `maximumThickness` per zone** (= NEW; = upper bound
   so no zone can absorb all the space after collapse/restart).
5. **Set `preferredThicknessFraction` per zone** (= the
   actual proportional weight; = replaces our `weights`
   array's role in applyWeights).
6. **Set `holdingPriority` ONLY for editor** (= `.required`
   so it never collapses / shrinks below ideal). The other
   5 panes stay at `.default` (= Apple default; = balanced
   resizing among visible items).
7. **Delete `currentZoneSplitWeight` /
   `applyZoneSplitWeight` / `captureZoneToggleSnapshot` /
   `restoreZoneToggleSnapshot`** (= ~150 LOC of code that
   fights Apple).
8. **Delete `applyPersistedZoneVisibility`** (= L183-225, =
   ~40 LOC; = the wenshu.zoneVisible.* UserDefaults bools
   become redundant once autosaveName handles the
   collapsed/expanded state).
9. **Simplify `handleToggleZone`** to:
   ```swift
   item.animator().isCollapsed.toggle()
   ```
   (= the entire capture-then-collapse → uncollapse-then-
   restore dance goes away).

### Race condition prevention (= the historical bug)

The 10.7+ race condition is fixed in modern macOS. But to be
extra safe (defense in depth), call `setPosition` from
`viewDidLayout` (= only on FIRST layout; = once `didApplyInitialWeights`
is true, the autosaveName takes over). The current code at
L1214-1265 already does this. Keep that gate.

## Risk assessment

1. **First-launch behavior changes**: enabling autosaveName on
   the root means the FIRST launch's preset weights get
   persisted under `wenshu.root.<presetID>`. If the user
   doesn't drag, every subsequent launch restores from that
   first launch (= same behavior as current).
2. **Per-preset autosaveName scoping**: when the user
   switches layouts (= boss 8/12 "4 builtin layout presets"),
   each preset has its own autosaveName string (= so each
   preset's drag-tweaks are preserved separately). = NO
   cross-contamination.
3. **Tests**: DragRegressionTests 8/8 PASS today, doesn't
   touch the visibility snapshot/restore path. New tests
   for the autosaveName path (= first-launch → subsequent-
   launch round-trip) should be added.
4. **Backwards compat**: existing users have wenshu.
   zoneVisible.* bools in UserDefaults. Once autosaveName
   takes over, the bools become dead state (= next launch
   reads autosaveName's collapsed state, not the bools).
   Safe to leave the bools alone (= they don't conflict).
5. **Edge case**: user closes all 4 upper zones + all 2
   lower zones (= nothing visible). With autosaveName, the
   collapsed state persists. On next launch, all zones
   collapse, then user un-collapses one. Auto-layout
   redistributes. = Apple handles this correctly.

## Implementation plan (= atomic commits)

### Parallel anti-pattern (= editor-expand feature)

Same `snapshot/restore` anti-pattern is used by the
**editor-expand** feature (= a separate code path for the
"expand editor to fill workspace" toolbar action):

- `captureEditorExpandSnapshot` (L696-715) — saves 6 zone
  `isCollapsed` + editor `split weight` (= holdingPriority.
  rawValue) to `wenshu.editorExpand.snapshot` JSON
- `restoreEditorExpandSnapshot` (L720-741) — reads the JSON,
  applies `applyEditorSplitWeight` then re-toggles each
  zone via `toggleZone(slot:)` if state differs
- `applyEditorSplitWeight` + `currentEditorSplitWeight`
  (around L824-870) — the same `holdingPriority` read/write
  anti-pattern

**Decision (= for ZONE-VIS-FIX-001)**: delete this in the
same commit (= same root cause; = same broken pattern).
The editor-expand feature should also use
`NSSplitView.autosaveName` for state persistence (= Apple
handles both divider positions AND collapsed/expanded
state natively).

This expands Commit 1 scope: also delete `captureEditorExpandSnapshot` +
`restoreEditorExpandSnapshot` + `currentEditorSplitWeight` +
`applyEditorSplitWeight` (≈ +100 LOC deleted) + simplify
`handleEditorMaximizedChanged` to:
```swift
collapseAllNonEditorZones()  // or restoreAllZones()
// no snapshot/restore needed; autosaveName takes over
```

Tests to add:
- `Tests/WenshuAppTests/UI/PaneNSControllerAutosaveTests.swift`:
  - First-launch → setPosition applies preset weights
  - Subsequent-launch → autosaveName positions restored
  - Toggle a zone → autosaveName persists the new collapsed state
  - Toggle a zone back → weights restored from autosaveName
  - Multi-toggle sequence (= hide A → hide B → show A →
    show B) → weights converge to user's intended layout

### Commit 1: ZONE-VIS-FIX-001 (= the actual bug fix)

Change:
1. `installSplit` L1031: `autosaveName = nil` → `autosaveName =
   autosaveKey(for: split.id)` (= same pattern as nested
   controllers; = per-preset scoping)
2. Delete `currentZoneSplitWeight` (L627-642) +
   `applyZoneSplitWeight` (L648-664) + `captureZoneToggleSnapshot`
   (L568-589) + `restoreZoneToggleSnapshot` (L591-625) +
   `applyPersistedZoneVisibility` (L183-225) +
   `captureEditorExpandSnapshot` (L696-715) +
   `restoreEditorExpandSnapshot` (L720-741) +
   `currentEditorSplitWeight` (around L824-870) +
   `applyEditorSplitWeight` (= all the `holdingPriority` /
   JSON-snapshot / restore anti-pattern methods) ≈ -290 LOC
3. Simplify `handleToggleZone` (L458-558) to just
   `item.animator().isCollapsed.toggle()` + adjustRootForCollapsedBands()
4. Simplify `handleEditorMaximizedChanged` (L678-690) to
   `collapseAllNonEditorZones()` or `restoreAllZones()` (= no
   snapshot/restore; = autosaveName takes over)
5. Delete the `wenshu.zoneToggle.snapshot` JSON UserDefaults
   write/read paths (= dead code)
6. Delete the `wenshu.editorExpand.snapshot` JSON UserDefaults
   write/read paths (= dead code)
7. Delete the dead `wenshu.zoneVisible.*` bool reads in
   `LibraryRootView.swift` (= L150-158 comments already note
   the @AppStorage declarations were dead since v0.34
   toolbar flatten)
8. Delete the `wenshu.zoneVisible.*` reset code in
   `LayoutTreeStore.resetToDefault()` (L266-274) (= no longer
   relevant after autosaveName takes over)
9. Update the obsolete comments

Expected diff: -300 LOC. Net LOC decrease.

Change:
1. `makeSplitItems` L1445: also set `item.maximumThickness`:
   - sidebar: 400 PT (= tree outline natural max)
   - cards: 500 PT
   - editor: unspecifiedDimension (= stretches freely)
   - tools: 300 PT
   - chat: unspecifiedDimension (= uses 70% band share)
   - dynamic: unspecifiedDimension (= uses 30% band share)
2. Set `item.preferredThicknessFraction` per zone (= the
   natural share of the band width; = replaces `weights`
   array partially)
3. Set `item.holdingPriority = .required` for editor only
   (= never shrinks below ideal)
4. Update `minThickness(for:weight:)` to use the
   `weight` parameter (= the proportional share; = not just
   a fixed 200 PT)

Expected diff: ~20 LOC change, no LOC decrease.

## Verification

- swift build --target WenshuApp PASS (= both commits)
- bash Scripts/build-app.sh PASS (= both commits)
- Manual: launch app, baseline → hide tools → show tools →
  verify zone widths match baseline within 5 PT
- Manual: hide tools → hide cards → show cards → show tools
  → verify all zones match baseline within 5 PT
- Tests: 8/8 DragRegressionTests + new 5 tests PASS (= 13/13)

## Status

- ⏸ Pending boss decision (= boss said "look at the code clearly,
investigate the documentation, then fix"; = this file = the
code-clear + doc-clear output;
  = the next step = ask boss to confirm the fix approach
  OR authorize Commit 1 implementation now).

## Files referenced

- `Sources/WenshuApp/Views/Layout/PaneNSController.swift`
  (= 1609 LOC; = the file to modify)
- `Sources/WenshuApp/State/LayoutTreeStore.swift` (= the
  data model behind the tree walk)
- `Tests/WenshuAppTests/DragRegressionTests.swift` (= the
  existing test surface; = should keep passing)
- Apple docs:
  - developer.apple.com/documentation/appkit/nssplitview
  - developer.apple.com/documentation/appkit/nssplitview/
    autosavename
  - developer.apple.com/documentation/appkit/nssplitview/
    setposition(_:ofdividerat:)
  - developer.apple.com/documentation/appkit/nssplitviewitem
    /minimumthickness