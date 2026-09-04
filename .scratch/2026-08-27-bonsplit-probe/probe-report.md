# Bonsplit Probe Report — 2026-08-27

> Wenshu v0.27 third-party library probe (= AGENTS.md §11.1 verdict).
> Probe target: `almonk/bonsplit` 1.1.1 (commit `77b9cce` 2026-05-19).
> Purpose: write a real SwiftUI app that uses the full bonsplit API surface,
> build it, run it, observe behavior, write a verdict for the boss.

## 1. Library snapshot (from GitHub API + read of vendored source)

| field | value | §11.1 gate |
|---|---|---|
| stars | **459** | ≥100 ✓ |
| forks | 101 | — |
| license | MIT | ✓ |
| last commit | **2026-05-19** (~3 months ago) | ≤ 12 months ✓ |
| archived | false | ✓ |
| merged PRs in last 12m | 3 (May×2, Jan×1) | ✓ active |
| open issues | 2 (drag-to-split, AppKit cursor blocking) | — |
| macOS-first | **yes** (entire README is macOS) | ✓ |
| platforms required | macOS 14.0+, Swift 5.9+ | OK on wenshu macOS 27 |
| public LOC | 1,132 (10 files under Sources/Bonsplit/Public/) | — |
| internal dirs | `Internal/Controllers/`, `Internal/Models/`, `Internal/Styling/`, `Internal/Views/` — pure SwiftUI, no AppKit/NSView | ✓ |

All four §11.1 conditions satisfied.

## 2. What bonsplit actually is

> **bonsplit = tab bar + split panes.** Not a pure splitter.

It packages a Chrome-like tab bar with an arbitrary binary tree of horizontal/vertical split panes underneath. Both pieces are coupled:

- `BonsplitView(controller:)` renders a tree where leaves are *panes* and
  internal nodes are *splits*. Every pane hosts a `Tab` array + a selected tab.
- The split tree is fully dynamic: `controller.splitPane(orientation:)`
  splits the focused pane in two; `controller.closePane(...)` collapses.
- Tab UX (close, drag-reorder, drag-to-other-pane, dirty marker, save prompt
  via delegate) is built-in.
- Splitter UX (drag to resize, programmatic `setDividerPosition`,
  `layoutSnapshot()` callback) is built-in.
- `SplitOrientation.horizontal` = side-by-side (left | right);
  `SplitOrientation.vertical` = stacked (top / bottom).
  (Naming note: opposite of v0.27 `NativeSplitter.Orientation`.)

Public API surface (`Sources/Bonsplit/Public/`):

| file | role |
|---|---|
| `BonsplitView.swift` | the root SwiftUI view, takes a controller + content/emptyPane builders |
| `BonsplitController.swift` | `@MainActor @Observable` state holder — all mutation flows here |
| `BonsplitConfiguration.swift` | behavior + appearance (allowSplits, allowCloseTabs, contentViewLifecycle, tab bar height, split buttons...) |
| `BonsplitDelegate.swift` | 14-method nonisolated protocol — every lifecycle event |
| `Types/TabID.swift`, `PaneID.swift` | opaque UUID wrappers (uuid is `internal` — you cannot read the raw UUID) |
| `Types/Tab.swift` | read-only tab metadata |
| `Types/SplitOrientation.swift`, `NavigationDirection.swift` | enums |
| `Types/LayoutSnapshot.swift` | Codable snapshot of pane frames + tree |

Geometry API (the "why we want it" half):

```swift
controller.layoutSnapshot() -> LayoutSnapshot   // flat list of pane pixel rects + selected tab
controller.treeSnapshot()   -> ExternalTreeNode  // recursive Codable tree
controller.findSplit(UUID)  -> Bool             // lookup by id
controller.setDividerPosition(_, forSplit: UUID, fromExternal: true)
                                                // programmatic resize, loop-safe
```

## 3. The probe

Path: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-27-bonsplit-probe/BonsplitProbe/`
(independent SPM package, **does not touch main `Package.swift`**).

Contents:

```
BonsplitProbe/
  Package.swift                     # swift-tools 5.9, macOS 14
  Sources/
    BonsplitLib/                    # vendored bonsplit 1.1.1 (25 files)
    BonsplitProbe/
      ProbeApp.swift                # WindowGroup + BonsplitView + Commands
      ProbeAppState.swift           # @Observable state, delegate conformance
```

Vendor strategy: copied `Sources/Bonsplit/` into `Sources/BonsplitLib/` instead
of network fetch. This bypasses the v0.27 027-31 "network died mid-fetch,
Package.resolved never generated, build broke" failure mode — if the probe
builds, it builds because the code is literally on disk.

What the probe exercises:

| capability | how |
|---|---|
| Window opens with one pane + one tab | `BonsplitController` + `newTab()` in `init` |
| Create tab | `⌘T` → `controller.createTab(title:icon:)` |
| Close tab | `⌘W` → `controller.closeTab(tabId)` (reads focused tab via `@FocusedValue`) |
| Split right | `⌘\` → `controller.splitPane(orientation: .horizontal)` |
| Split down | `⌘⇧\` → `controller.splitPane(orientation: .vertical)` |
| Focus neighbor pane | `⌘⌥←→↑↓` → `controller.navigateFocus(direction:)` |
| Zoom | `⌘⇧Z` → `controller.toggleZoom()` |
| Drag tab reorder + cross-pane move | drag tabs in the bar |
| Print geometry | `⌘⇧P` → `controller.layoutSnapshot()` + `treeSnapshot()` to stdout |
| TextEditor per tab with `isDirty` | tab text editor + `controller.updateTab(tabId, isDirty: true)` on first edit |
| Auto-create tab in new pane | `didSplitPane` delegate callback → `newTab(inPane: newPane)` |
| Window title follows active tab | `didSelectTab` delegate callback |

## 4. Build + run results

| step | result |
|---|---|
| `swift build` | **exit 0**, 0 errors, 4 warnings (one cosmetic `#NoUsage` on `MainActor.assumeIsolated` return value — non-fatal) |
| `swift run BonsplitProbe` for 8 s, then SIGTERM | **returncode -15 (SIGTERM, expected)**, **0 fatals** during the run |

This proves bonsplit 1.1.1 builds against the same Swift 6.4 / macOS 27
toolchain wenshu uses, links into a SwiftUI app, and renders a tab+split UI
without crashing.

## 5. Issues found during the probe

1. **`BonsplitDelegate` is `nonisolated` but `BonsplitController` is `@MainActor`.** Every conforming method must be `nonisolated`, then wrap `@MainActor` state access in `MainActor.assumeIsolated { ... }`. This is the one non-trivial integration cost — if you forget `MainActor.assumeIsolated`, you get `ConformanceIsolation` errors under Swift 6 mode (warnings even under Swift 5 mode).

2. **`TabID.id` and `PaneID.id` are `internal` UUIDs.** You cannot read the raw UUID from outside the library — only compare `TabID` values for equality. This is fine for most use cases but blocks any "show me the tab id" UI affordance.

3. **No `ObservableObject` support.** `@FocusedObject` (the SwiftUI property wrapper that reads the focused scene's `@StateObject`) does not work — it requires the `ObservableObject` protocol. bonsplit's controller is `@Observable` (the new Observation framework). Workaround: use `@FocusedValue(\.sceneObject)` with a `FocusedValueKey`. Probe uses this pattern.

4. **Split tree is dynamic; wenshu's 6-zone layout is fixed.** bonsplit's tree is user-rearrangeable (drag to split, drag to merge, drag tabs across panes). wenshu's 6-zone layout (ADR-0007) is fixed: HStack+VStack with 6 hand-written `NativeSplitter` views in known positions. bonsplit's dynamic tree would replace ADR-0007 wholesale — it is not a drop-in replacement for `NativeSplitter` while keeping ADR-0007.

5. **Tree layout vs `HStack+NStack` does not compose.** If wenshu wanted "bonsplit under the hood" while keeping the upper-band / lower-band 4+2 zone shape, it would either need to (a) make bonsplit render exactly the desired tree and force-disable user splits, or (b) keep `NativeSplitter` and only borrow bonsplit's geometry/divider API. Neither is clean.

## 6. Verdict

**bonsplit 1.1.1 is technically excellent and structurally wrong for wenshu.**

| dimension | verdict |
|---|---|
| maintenance | active (3 merged PRs in 12 months, last commit 2026-05-19) |
| license + macOS-first | matches §11.1 ✓ |
| build on wenshu toolchain | ✓ (Swift 6.4 / macOS 27 SDK, zero errors) |
| runtime stability | ✓ (8 s test run, no fatals) |
| replaces `NativeSplitter`? | ❌ — different paradigm (dynamic tree vs fixed 6-zone) |
| complements `NativeSplitter`? | ⚠️ — only the geometry/divider API is reusable, and ADR-0007 already solved that |
| replaces `NSView` overlay for splitter? | ✅ — bonsplit uses pure SwiftUI drag (cursor + hover + drag) — same wins we got from `NativeSplitter` |
| cost if we adopt | large: 6-zone ADR-0007 must change OR bonsplit must be wrapped in a "fixed 6-zone facade" |

### Recommendation

**Do not adopt bonsplit as the splitter for wenshu 6-zone layout.** The
fixed 6-zone shape is the product (Xcode-like, Apple HIG, ADR-0007); bonsplit's
dynamic split tree is a different product.

**Keep `NativeSplitter` (ADR-0007).** It already solves the splitter problem
in the shape wenshu actually has.

**Hold bonsplit in the third-party inventory** for future features where the
shape IS a dynamic split tree (e.g., the per-book editor if we ever wanted
"chapter A on the left, character notes on the right, world outline below,
user-draggable"). That is a future-iteration decision; for now, do not pull
it in.

## 7. Files for boss review

- Package + sources: `.scratch/2026-08-27-bonsplit-probe/BonsplitProbe/`
- Vendored bonsplit: `.scratch/2026-08-27-bonsplit-probe/Sources/Bonsplit/`
  (also mirrored under `BonsplitProbe/Sources/BonsplitLib/`)
- Build cache: `BonsplitProbe/.build-probe/` (~10 MB; safe to delete)

To re-run the probe:

```sh
cd /Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-27-bonsplit-probe/BonsplitProbe
swift build --build-path .build-probe
swift run  --build-path .build-probe BonsplitProbe
```

## 8. Boss decisions pending

1. Approve `bonsplit` for future use as the splitter for *editor zones* (per-book
   editor area only — not the global shell)?
2. Approve promoting bonsplit to the official §11.1 third-party exception list?
3. Leave `NativeSplitter` as is, or revisit ADR-0007 if bonsplit does land
   somewhere?
4. Keep `.scratch/2026-08-27-bonsplit-probe/` for posterity, or revert/clean?