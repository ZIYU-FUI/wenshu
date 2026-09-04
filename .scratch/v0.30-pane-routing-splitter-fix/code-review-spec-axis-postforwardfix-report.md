# Spec-axis code-review — v0.30 pane-routing-splitter-fix (POST applyWeights fix)

> **Loop gate**: Q5.4 / post-forward-fix spec-axis verification after the applyWeights fix landed in `113e918db`.
> **Prior state**: Spec FINAL = PASS (at `10dc16964`, pre-fix).
> **Branch**: `wt/multi-agent-dispatch` @ HEAD = `a68adeb57` (H-3 forward-fix v2, sits on top of `113e918db`).
> **Scope**: Verify the applyWeights fix (a) correctly pairs every SplitNode with the matching NSSplitViewController, (b) defers apply via `DispatchQueue.main.async` until AFTER `buildLayout` completes, (c) produces 6 setPosition calls per the commit claim (= root 1 + upperBand 3 + lowerBand 2) **but actually 5 calls per the captured log** (root 1 + upperBand 3 + lowerBand 1; see evidence below), and (d) preserves all boss-required functionality.
> **Method**: read full PaneNSController.swift at HEAD (= `a68adeb57`) and at `113e918db` to verify the applyWeights fix is intact and unmodified; trace `installSplit` + `collectPendingWeights` tree walk step-by-step against the FCP `builtinDefaultPreset`; parse `/tmp/wenshu-applyweights.log`; `swift build` at HEAD with stashed working-tree (other agent's uncommitted LiquidGlass-opacity changes); grep for functional-preservation symbols.

---

## Verdict (4 tickets)

| Ticket | Title | Verdict |
|---|---|---|
| (a) | `collectPendingWeights` correctly pairs every SplitNode with matching NSSplitViewController (root + upperBand + lowerBand for FCP layout) | **PASS** |
| (b) | `DispatchQueue.main.async` fires AFTER `buildLayout` completes (= `pendingWeights` fully populated before `applyWeights` runs) | **PASS** |
| (c) | The 6 setPosition calls (root 1 + upperBand 3 + lowerBand 2 — per task description) actually take effect (= verified via `/tmp/wenshu-applyweights.log`) | **PASS** (with correction: actual count is **5**, not 6 — see ticket (c) analysis below) |
| (d) | No regression in functional preservation (4 builtin presets, LayoutPicker, AppState, Zone views, PaneFrame schema, wenshuResetLayout notification all still work) | **PASS** |

**Overall verdict: PASS.** The applyWeights fix in `113e918db` correctly distributes preset weights to all 3 NSSplitViewControllers in the FCP tree (= root + upperBand + lowerBand), defers the apply via async until after buildLayout completes, and preserves all boss-required functionality. The task description's "6 setPosition calls" claim is off-by-one: `lowerBand` has `weights: [7, 3]` (= 2 weight entries = 1 divider), not 2 dividers. Actual = 1 + 3 + 1 = **5 setPosition calls**, all with non-zero positions matching the cumulative-weight formula.

---

## Build verification

```
$ git stash                                              # stash concurrent agent's uncommitted LiquidGlass-opacity work
Saved working directory and index state WIP on wt/multi-agent-dispatch: a68adeb57
$ swift build
… Build complete! (11.56秒)
EXIT=0
$ git stash pop
… Dropped refs/stash@{0}
```

- **Build at HEAD with applyWeights fix (no dirty working tree)**: exit 0, zero errors.
- **Build with working tree's dirty changes** (concurrent agent's LiquidGlass-opacity additions): fails with `PaneNSController.swift:121:65: error: type 'NSSplitView.DividerStyle' has no member 'none'` — that error is in **uncommitted, post-113e918db work** (the divider-opacity feature added ~51 lines after the applyWeights fix landed). Not a regression of the applyWeights fix itself.
- All warnings are pre-existing in `PaneNSController.swift` (the `nonisolated override func splitView(...)` actor-isolation warnings at L194/211/218 and the immutable-`child` warning at L304 carried from prior reviews; see Spec RE-VERIFY 1 + Spec FINAL).

---

## Ticket (a) — `collectPendingWeights` correctly pairs SplitNode ↔ NSSplitViewController

### Tree shape (FCP `builtinDefaultPreset` per `WorkspaceStore.swift` L424-515)

```
root = split(.column, weights=[1,1], children=[upperBand, lowerBand])
  upperBand = split(.row, weights=[1,2,6,1], children=[4 groups])
  lowerBand = split(.row, weights=[7,3], children=[2 groups])
```

### `installSplit` walk (= what builds the controller hierarchy)

`buildLayout()` (L267-293) calls `installSplit(split, parent: self, parentOrientation: .column)` for the root. Because root.orientation (`.column`) == parentOrientation (`.column`), the **SAME-orientation branch** (L508-521) fires:

```
installChildren(root.children, weights=[1,1], into: self)
```

For each child of root:
- `upperBand` (.row) — DIFFERENT from parent's .column → **DIFFERENT branch** (L528-537):
  1. `nestedA = NSSplitViewController()` (L528)
  2. `nestedA.splitView.isVertical = true` (L529)
  3. `installChildren(upperBand.children, weights=[1,2,6,1], into: nestedA)` (L531) → all 4 groups become NSSplitViewItems on `nestedA.splitView`
  4. `self.addChild(nestedA)` (L532) → `self.children` now has 1 child
  5. `pendingWeights.append((nestedA, [1,2,6,1]))` (L537)

- `lowerBand` (.row) — DIFFERENT from parent's .column → same DIFFERENT branch:
  1. `nestedB = NSSplitViewController()`
  2. `nestedB.splitView.isVertical = true`
  3. `installChildren(lowerBand.children, weights=[7,3], into: nestedB)` → 2 groups
  4. `self.addChild(nestedB)` → `self.children` now has 2 children
  5. `pendingWeights.append((nestedB, [7,3]))`

**Important**: root weights `[1,1]` are **NOT** appended during `installSplit` (the SAME-orientation branch returns at L520 without touching `pendingWeights`). After `installSplit` returns:

```
pendingWeights = [(nestedA, [1,2,6,1]), (nestedB, [7,3])]
self.children = [nestedA, nestedB]
```

### `collectPendingWeights` post-walk (= what populates the final pendingWeights)

`buildLayout()` then overwrites `pendingWeights` with the result of `collectPendingWeights()` (L288):

```
collectPendingWeights() →
    result.append((self, root.weights=[1,1]))                           // L315
    for child in root.children:
        collectPendingWeightsHelper(for: child, into: &result)         // L323
```

For each root child:
- `upperBand` (.split) — L360-377:
  - `countSplitNodesBefore(upperBand)` = number of `.split` nodes before index 0 in `root.children` = **0**
  - `nestedControllers = self.children.compactMap { $0 as? NSSplitViewController }` = `[nestedA, nestedB]`
  - `nested = nestedControllers[0]` = `nestedA` ✓
  - `result.append((nestedA, [1,2,6,1]))` (L372)
  - `collectNestedHelper(nestedA, upperBand, result)` — `upperBand.children` are all `.group` → no nested entries added
- `lowerBand` (.split) — L360-377:
  - `countSplitNodesBefore(lowerBand)` = number of `.split` nodes before index 1 in `root.children` = **1** (upperBand is `.split`)
  - `nested = nestedControllers[1]` = `nestedB` ✓
  - `result.append((nestedB, [7,3]))`
  - `collectNestedHelper(nestedB, lowerBand, result)` — `lowerBand.children` are all `.group` → no nested entries

### Final result (verified by Python simulator mirroring the algorithm)

```
[(self, [1, 1]), (nestedA, [1, 2, 6, 1]), (nestedB, [7, 3])]
```

- **3 entries**: root + upperBand + lowerBand ✓
- **Each entry is the correct (NSSplitViewController, [Double]) pair** ✓
- **Weights match the FCP preset** (column [1,1], row [1,2,6,1], row [7,3]) ✓

### Algorithm also handles the other 3 builtin presets correctly

| Preset | Tree shape | Expected `pendingWeights` count | Verification |
|---|---|---|---|
| `builtinDefaultPreset` (FCP) | root column [1,1] → upperBand row [1,2,6,1] + lowerBand row [7,3] | 3 (root + upperBand + lowerBand) | ✓ |
| `builtinFocusPreset` | root row [1,4.6] → 2 groups (no nested) | 1 (just root) | ✓ |
| `builtinTerminalDeckPreset` | root column [3,1] → topRow row [1,3.2,1.2] + 1 group | 2 (root + topRow) | ✓ |
| `builtinQuadPreset` | root column [3,1] → topRow row [1,3] + bottomRow row [1.4,1] | 3 (root + topRow + bottomRow) | ✓ |

The post-walk is **not FCP-specific** — it correctly walks any depth-N tree by structural-index pairing.

**Verdict for (a): PASS.**

---

## Ticket (b) — `DispatchQueue.main.async` fires AFTER `buildLayout` completes

### Timing trace

1. **`init()`** (L70-97) calls `buildLayout()` **synchronously** at L81. `init()` does NOT return until `buildLayout()` returns.
2. **`buildLayout()`** (L251-294) calls `installSplit(...)` (sync), then `pendingWeights = collectPendingWeights()` at L288 (sync). `buildLayout()` does NOT return until `collectPendingWeights()` completes and `pendingWeights` is fully populated with all 3 entries.
3. **SwiftUI representable** wraps `PaneNSController` in `NSViewControllerRepresentable.makeNSViewController(context:)` and returns it. The view is added to the window hierarchy only AFTER this.
4. **`viewDidLayout()`** (L432-473) is **called by AppKit AFTER the view is in a window** (= after `init` has long returned, after `pendingWeights` is fully populated). It dispatches the apply via `DispatchQueue.main.async { ... }` at L459.
5. **The async block** runs at the end of the current runloop cycle (= after `viewDidLayout` returns). It guards:
   - `!self.didApplyInitialWeights` (L461) — prevents re-entry
   - `!self.pendingWeights.isEmpty` (L462) — ensures weights were populated
   - `self.splitView.bounds.width > 0 && self.splitView.bounds.height > 0` (L466) — ensures bounds are non-zero (= ready for `setPosition`)
6. **`for (controller, weights) in self.pendingWeights`** iterates and calls `self.applyWeights(weights, on: controller)` for each of the 3 entries.
7. **`self.didApplyInitialWeights = true`** (L471) prevents future re-application.

### Concurrency analysis

- `@MainActor` (L41) on `PaneNSController` means all state mutation runs on the main actor.
- `DispatchQueue.main.async` (L459) targets the same main thread.
- **No race condition** between `init` populating `pendingWeights` and `viewDidLayout` reading it — both happen on the main thread, and the async dispatch in `viewDidLayout` ensures the apply runs in a fresh runloop tick.

### The bug that was fixed (= the symptom of the prior bug)

Without `DispatchQueue.main.async`, `viewDidLayout` fired **synchronously the moment `addChild` returned**, while `buildLayout` was still inside `installSplit` adding more nested controllers. At that instant, `pendingWeights` only had the root entry (because the post-walk hadn't run yet). The apply loop only had 1 entry to iterate → nested controllers never received their preset weights.

With the async dispatch, `viewDidLayout`'s apply block is **deferred until the current runloop tick ends**, by which time `buildLayout` (called from `init`) has returned and `pendingWeights = collectPendingWeights()` at L288 has fully populated the 3 entries.

### Why `pendingWeights` cannot be empty when the async block fires

`init` → `buildLayout` → `collectPendingWeights()` runs **synchronously** at L288. The only way `pendingWeights` could be empty when the async block fires is if `init` returned BEFORE L288, which is impossible because L288 is inside `buildLayout` which is called synchronously from `init` at L81.

The guard `!self.pendingWeights.isEmpty` (L462) is defensive — a safety net for any future re-entrancy — but in practice it cannot trip on the normal first-launch flow.

**Verdict for (b): PASS.**

---

## Ticket (c) — setPosition calls actually take effect

### `/tmp/wenshu-applyweights.log` evidence

```
[wenshu.NS] ROOT pendingWeights count=3
[wenshu.NS] ctrl=ObjectIdentifier(0x0000007703074900) div=0 w=1.0/total=2.0 prop=0.5 span=897.0 pos=448.5 success=()
[wenshu.NS] ctrl=ObjectIdentifier(0x0000007702aaeac0) div=0 w=1.0/total=10.0 prop=0.1 span=1452.0 pos=145.2 success=()
[wenshu.NS] ctrl=ObjectIdentifier(0x0000007702aaeac0) div=1 w=2.0/total=10.0 prop=0.3 span=1452.0 pos=435.6 success=()
[wenshu.NS] ctrl=ObjectIdentifier(0x0000007702aaeac0) div=2 w=6.0/total=10.0 prop=0.9 span=1452.0 pos=1306.8 success=()
[wenshu.NS] ctrl=ObjectIdentifier(0x0000007702aaee80) div=0 w=7.0/total=10.0 prop=0.7 span=1452.0 pos=1016.4 success=()
```

### Parsed call distribution

| Controller | ObjectIdentifier | Weight prop | Total | Dividers fired | Expected |
|---|---|---|---|---|---|
| Root (column) | `0x7703074900` | 1.0 | 2.0 | 1 (div=0) | 1 (column [1,1]) ✓ |
| UpperBand (row) | `0x7702aaeac0` | 1.0, 2.0, 6.0 | 10.0 | 3 (div=0,1,2) | 3 (row [1,2,6,1]) ✓ |
| LowerBand (row) | `0x7702aaee80` | 7.0 | 10.0 | 1 (div=0) | 1 (row [7,3]) ✓ |
| **Total** | 3 distinct controllers | | | **5** | **5** |

### Count correction

The task description says "**6** setPosition calls (root 1 + upperBand 3 + lowerBand 2)". The lowerBand actually has `weights: [7, 3]` — 2 weight entries ⇒ **1 divider** (N-1 dividers for N items). The correct sum is **5** (= 1 + 3 + 1). The commit body in `113e918db` has the same off-by-one: it says "all 6 setPosition calls firing once pendingWeights contained 3 entries" but `lowerBand`'s `weights` array has 2 entries, not 3.

The `/tmp/wenshu-applyweights.log` is the ground truth and confirms **5 calls, all 3 distinct controllers**.

### Position math verification (= positions are non-zero, correct, and span-aligned)

| Controller | Divider | prop = cumulative/total | span | expected position | actual position | ✓ |
|---|---|---|---|---|---|---|
| Root | 0 | 1/2 = 0.5 | 897 | 448.5 | 448.5 | ✓ |
| UpperBand | 0 | 1/10 = 0.1 | 1452 | 145.2 | 145.2 | ✓ |
| UpperBand | 1 | 3/10 = 0.3 | 1452 | 435.6 | 435.6 | ✓ |
| UpperBand | 2 | 9/10 = 0.9 | 1452 | 1306.8 | 1306.8 | ✓ |
| LowerBand | 0 | 7/10 = 0.7 | 1452 | 1016.4 | 1016.4 | ✓ |

All positions are mathematically correct (= `span × cumulative_proportion`) and **non-zero**, which is the success criterion (= `setPosition` against a 0-wide canvas would be a no-op).

### `success=()` field

The log entries each end with `success=()` — `setPosition(ofDividerAt:)` in `applyWeights` (L580) returns `Void` so the trailing `()` is the empty tuple return value. The commit body says "all setPosition fired non-zero" — verified by all 5 positions being non-zero and matching the formula.

### Source-of-truth confirmation

The `applyWeights` implementation (L554-582):

```swift
for dividerIndex in 0..<dividerCount {
    cumulative += weights[dividerIndex]
    let proportion = cumulative / CGFloat(total)
    let totalSpan: CGFloat = isVertical ? splitView.bounds.width : splitView.bounds.height
    let position = totalSpan * proportion
    splitView.setPosition(position, ofDividerAt: dividerIndex)
}
```

This is exactly the algorithm the log entries reflect. Each call to `setPosition(_:ofDividerAt:)` writes the divider position into Apple's NSSplitView model; AppKit then re-renders the split view with the divider at that pixel position on the next layout pass.

**Verdict for (c): PASS.** All 3 NSSplitViewControllers received their preset weights via `setPosition` (= 5 divider calls total — root 1 + upperBand 3 + lowerBand 1). Task description's "lowerBand 2" is an off-by-one; the actual `weights: [7, 3]` array has 2 entries but only 1 divider position gets set.

---

## Ticket (d) — Functional preservation (= no regression)

### Spec §"What MUST be preserved" (re-checked at HEAD)

| Item | Status | Evidence |
|---|---|---|
| All 4 builtin presets | ✅ | `WorkspaceStore.swift:417-420` lists `builtinDefaultPreset(), builtinFocusPreset(), builtinTerminalDeckPreset(), builtinQuadPreset()`; all 4 constructors defined (L424, L517, L559, L603). `WorkspaceStore.swift` last touched at `f380a2cd4` (PR 4 of 4 wire-up), **before** the applyWeights fix. |
| `LayoutPicker` + `LayoutEditBar` | ✅ | Files at `Sources/WenshuApp/Views/Workspace/LayoutPicker/{LayoutPicker,LayoutEditBar}.swift`. Last commits: `48d09bb6a` (LayoutPicker, ticket 028-009) and `00d4391ef` (LayoutEditBar, v0.28 followup). Both **before** `113e918db`. |
| Display menu items (Show/Hide Tools zone etc.) | ✅ | `App.swift:596-611` posts `.wenshuToggleZone(ZoneSlot)` for sidebar/preview/tools/chat/dynamic. `PaneNSController.swift:91-96` observes the notification and flips `NSSplitViewItem.isCollapsed` in `handleToggleZone(_:)` at L105-128. End-to-end wiring intact. |
| `AppState` @Observable | ✅ | `AppState.swift:42` declares `@Observable` class. Last commit `9d1f9bf82` (Q34 gap A+B fix), **before** `113e918db`. |
| All Zone content views | ✅ | `PreviewPane.swift` last touched by `113e918db` (the `twoColumnBreakpoint` change at L260 from 280→130 — explicitly part of this fix per commit body item 5). Other views (`NewLibraryOutlineView`, `ChatView`, `ForeshadowingView`, `GraphView`, `ZoneContentView`) all last touched in earlier v0.28-v0.30 commits, **not** by `113e918db`. |
| `PaneFrame.minWidth / idealWidth / flex` schema | ✅ | `WorkspaceState.swift:46-52` still declares all 3 fields. Last touched at `f380a2cd4` (PR 4 of 4), **before** `113e918db`. |
| `wenshuResetLayout` notification + reset action | ✅ | `App.swift:107` declares the notification name; `App.swift:616` and `:1395-1396` post it from menu items. The post does not require any code change in the applyWeights fix. |

### Diff of `113e918db` (= what changed)

```
…/WenshuApp/Views/Layout/PaneNSController.swift  | 235 ++++++++++++++++++---
…/WenshuApp/Views/Workspace/PreviewPane.swift    |  11 +-
2 files changed, 215 insertions(+), 31 deletions(-)
```

- **`PaneNSController.swift`**: the applyWeights fix (215 insertions, 31 deletions). Internal refactor: `pendingRootWeights` → `pendingWeights: [(NSSplitViewController, [Double])]`; added `collectPendingWeights` / `collectPendingWeightsHelper` / `collectNestedHelper` / `countSplitNodesBefore`; deferred `viewDidLayout` apply via `DispatchQueue.main.async`; removed debug NSLog + FileHandle writes.
- **`PreviewPane.swift`**: 11 lines changed — `twoColumnBreakpoint` constant lowered from 280 to 130 (L260). Necessary because the actual delivered preview pane width at the new ratio is ~109-134 PT, not the previously-expected 290 PT.

### What did NOT change in `113e918db`

- `WorkspaceStore.swift` — `makeBuiltinPresets`, `PaneFrame` references, `resetLayout` action: **untouched**
- `App.swift` — display menu posts, `wenshuResetLayout` declaration: **untouched**
- `LayoutPicker/` — preset picker UI: **untouched**
- `AppState.swift`, `WorkspaceState.swift`, `LayoutParser` (if exists), all Zone content views (except PreviewPane.swift's 11-line constant change): **untouched**

### Functional preservation summary

The fix is **surgical**: it changes how weights are distributed across NSSplitViewControllers (root + nested) and timing of the apply (deferred via async), plus one downstream PreviewPane threshold tweak. **Nothing in the spec's "must be preserved" list was modified.**

**Verdict for (d): PASS.**

---

## AC traceability — final cross-reference

| Ticket | AC # | Prior verdict (Spec FINAL @ `10dc16964`) | Post-forward-fix verdict | Evidence |
|---|---|---|---|---|
| (a) | collectPendingWeights tree-walk correctness | n/a (fix not yet applied) | **PASS** | 3 entries verified by Python simulator; structural-index pairing correct; algorithm generalizes to other 3 presets |
| (b) | async dispatch timing | n/a | **PASS** | init() synchronous chain guarantees `pendingWeights` populated before `viewDidLayout` can fire; async deferred block runs after viewDidLayout returns |
| (c) | setPosition actually takes effect | n/a | **PASS** | `/tmp/wenshu-applyweights.log` shows 5 non-zero setPosition calls (task description says 6 — off-by-one: `lowerBand` has 1 divider, not 2) |
| (d) | No functional regression | n/a | **PASS** | All 7 boss-preservation items confirmed at HEAD; diff of `113e918db` is surgical (only 2 files, 11 lines in PreviewPane) |

---

## Observations (non-blocking, advisory only)

1. **Off-by-one in commit body + task description**: `113e918db` commit body and the current task both say "6 setPosition calls (root 1 + upperBand 3 + lowerBand 2)". Actual = 5 (lowerBand has 1 divider, not 2). Both source and task description propagate the same error. The log file is correct.
2. **Concurrent agent's uncommitted work**: At time of this review, the working tree has uncommitted changes to `PaneNSController.swift` + 3 other files (LiquidGlass opacity feature). These are **NOT part of the applyWeights fix** and were stashed during the build verification. The uncommitted changes themselves don't compile (introduce `NSSplitView.DividerStyle.none` reference that doesn't exist in macOS 27 SDK). This is a separate concern, not a regression of the applyWeights fix — the applyWeights fix itself (at HEAD with stash) compiles cleanly.
3. **No `pendingWeights = []` reset on rebuild**: `collectPendingWeights` always overwrites `pendingWeights` (L288), so this is fine; just noting that `pendingWeights.append((nested, split.weights))` at L537 (legacy incremental path inside `installSplit`) is **dead code** now that `collectPendingWeights` always re-populates from scratch after `buildLayout` completes. The append happens, then is immediately overwritten on L288. Harmless but redundant.

---

## Final verdict

**Spec-axis Q5.4 post-forward-fix loop gate: PASS.**

- **(a) `collectPendingWeights` correctly pairs SplitNode ↔ NSSplitViewController = PASS** — produces exactly 3 entries for the FCP layout `(root, [1,1])`, `(upperBand, [1,2,6,1])`, `(lowerBand, [7,3])`; algorithm generalizes to all 4 builtin presets.
- **(b) `DispatchQueue.main.async` fires AFTER `buildLayout` completes = PASS** — `init` synchronously calls `buildLayout` which synchronously populates `pendingWeights` at L288; `viewDidLayout` can only fire after `init` returns; async block runs in a later tick after `viewDidLayout` returns. Concurrency-safe (`@MainActor`).
- **(c) setPosition calls actually take effect = PASS** — `/tmp/wenshu-applyweights.log` shows 5 non-zero setPosition calls (= task description's "6" is off-by-one for lowerBand). All 3 controllers receive their preset weights. Position math correct for all 5 calls.
- **(d) No functional regression = PASS** — diff of `113e918db` is surgical (2 files, 11 lines in PreviewPane); all 7 boss-preservation items verified intact at HEAD.

**Recommend closing the Spec-axis gate** — the applyWeights fix is correctly implemented per the spec, the captured log proves all 3 NSSplitViewControllers in the FCP tree receive their preset weights, and no boss-preservation requirement regressed.