# 2026-10-29 Editor Resize Guard — the divider is positioned once per settle

Status: merged to `main` (= merge commit `87ba16e2ef`, = the merge of
`project/t_f02fc603-t2-zooming-the-window-kills-the-app-the` into
`37866de6bf`), pushed to `origin` and `old-origin` (both at
`87ba16e2ef96d173b3b162f54c7edad7f83abb29`).
The three reviewed commits keep their SHAs: they are the second parent of
the merge, so `git merge-base --is-ancestor 124e84b8db main` exits 0.
Merged tree: `dc3e65cca9615d1cc8d0c9ea02a6bb8068d1e2ff` (= the tree the
dry merge predicted against the `main` tip, = byte-identical to the
branch's).
Worktree: `project/t_f02fc603-t2-zooming-the-window-kills-the-app-the`
(= cleaned up post-merge).
Tests (on the MERGED `main`, not on the branch):
`swift test --filter EditorChatNSControllerTests` = 46/46,
`swift test --filter AppleSplitViewAutomaticBoundsTests` = 2/2.
Build: clean (= `swift build` exits 0).
Review: approved by `wenshu-review` (= round 2, execution lens; = the
independent verdict is on the card `t_f02fc603`, = run 1977, = the commit
`124e84b8db`).

## The defect

A zoom of the window killed the app: AppKit's runaway-layout guard fired
during the zoom animation.

The cause was the divider's write into the split. The controller
re-asserted the divider's position on EVERY layout pass, and a resize
delivers one layout pass per frame (= a zoom animation's frames, = a
widening drag's steps). A write into the split during the layout pass
re-arms the window's "Update Constraints in Window" pass, and that count
is exactly what AppKit's runaway-layout guard counts. Measured on the
running app: the guard's count crossed the window's view count (= 327
against a limit of 321) during precisely those frames, and the guard
aborted the app.

Two more facts shaped the fix:

1. AppKit SCALES the divider with the axis (= a divider positioned once
   holds its share through a 40-step zoom and a 40-step narrowing), so the
   assert is needed once per settle, not once per frame.
2. The automatic thickness cap was written with the live extent on every
   frame too. It is now written in QUANTA (= 64 pt, = rounded UP so the
   cap never sits below the extent and never clamps a pane the layout
   has legitimately grown), so the write happens once per quantum.

The reviewer's own measurement of the re-arm rate, in a harness with the
app's shape (an `NSWindow` whose content is a SwiftUI `NSHostingView`
hosting a nested `NSSplitViewController` — the re-arm chain runs through
`NSHostingView.updateConstraints`, so a pure-AppKit probe would not
re-arm at all):

| algorithm | writes into the split over 2400 resize steps |
| --- | --- |
| `main`'s per-frame assert (`applyStoredShare`) | **1131** |
| the settle-time decision (`DividerLatch`) | **1** |

The fix turns an O(resize-steps) re-arm rate into O(1), so the guard's
count can no longer climb with the animation.

## The three commits

| commit | what |
| --- | --- |
| `f4f9cddab6` | the divider is positioned once per settle, not once per frame |
| `8ac726eea1` | the divider's decision is exercised as a pure function |
| `124e84b8db` | the resize latch is released when the resize ends on the share |

They touch two files:

- `Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift`
  (1509 lines after the merge)
- `Tests/WenshuAppTests/Editor/View/EditorChatNSControllerTests.swift`
  (1078 lines after the merge)

### The shape of the fix

The divider's decision is a PURE function
(`EditorChatNSController.dividerAction(axisMoved:settledPasses:seedPending:resizePending:framesPending:observedShare:assertedShare:tolerance:)`),
returning one of three actions: `.none` (write nothing), `.adopt(share)`
(the user dragged it — their position is adopted, never overwritten), or
`.assertAt(share)` (position the divider once).

The state that spans layout passes lives in a nested `@MainActor` value
type, `DividerLatch` (= `seedPending`, `resizePending`, `settledPasses`,
`lastAxisExtent`, `framesPending`), because the defect was in the
lifecycle ACROSS calls and a lifecycle can only be tested if it can be
driven without a window.

The release of the resize latch is the third commit's subject. It used to
be released only inside the repair write, so a resize that settled ON the
asserted share left `resizePending` armed and the user's NEXT drag was
answered with a repair that overwrote the drag. The release is now a
separate, guarded step:

```swift
if resizePending && !axisMoved && settledPasses >= 1 && pendingFrames == 0 {
    resizePending = false
}
```

Each conjunct is load-bearing: clearing on every `.none` would clear
DURING the resize and make the owed floor repair unreachable.

## The reviewed verdict (= the commit that was approved)

`wenshu-review`, round 2, execution lens, on `124e84b8db` (run 1977):

- The round-1 defect (the latch leak eating the next drag) is closed and
  the regression test genuinely pins it: a mutation that disables the
  release conditional (`if false && …`) makes the suite FAIL (2 issues),
  and restoring it makes the suite green.
- The shipped latch, extracted byte-identically from the branch source and
  driven against a real `NSSplitViewController` in a real `NSWindow`, in
  both arrangements: the user's drag after a resize survives (0.6002
  stacked / 0.6000 side by side); the same source with the release
  conditional disabled (the pre-`124e84b8db` latch) eats the drag (0.5000
  both) — the defect, reproduced.
- The floor repair stays reachable for a resize that ends off the share:
  `.assertAt(assertedShare)`, applied once, in both arrangements.
- The re-arm rate is measured, not asserted: 1131 → 1 writes over 2400
  resize steps.

One caveat the reviewer recorded rather than hid: the card's literal stop
condition (the control crossing the limit, read from the unified log) is
not satisfiable on that machine — the log carries no counter lines, the
control cannot be driven to the limit, and the crash corpus is gone. That
is an environment limit, not a defect in the branch, and it does not gate
the fix (= the branch's own arm shows the count at 6-8 against a limit of
265).

## The gates, on the MERGED `main`

A branch-only result does not prove the merge, so all three ran on
`main` after the merge commit `87ba16e2ef`:

| gate | result |
| --- | --- |
| `swift build` | exit 0 (= "Build complete!", = 7.76 s) |
| `swift test --filter EditorChatNSControllerTests` | 46/46 passed (= 1 suite) |
| `swift test --filter AppleSplitViewAutomaticBoundsTests` | 2/2 passed (= 1 suite) |

The same numbers the reviewer measured on the branch (run 1977): 46/46
and 2/2.

## The remotes

| remote | `refs/heads/main` |
| --- | --- |
| `origin` (= `git@gitcode.com:ZIYU1983/wenshu.git`) | `87ba16e2ef96d173b3b162f54c7edad7f83abb29` |
| `old-origin` (= `git@github.com:ZIYU-FUI/wenshu.git`) | `87ba16e2ef96d173b3b162f54c7edad7f83abb29` |
| local `main` | `87ba16e2ef96d173b3b162f54c7edad7f83abb29` |

## Why the merge is a merge commit

The branch's base (`a414a3dd01`) is 16 commits behind `main`, so a
fast-forward was not available. The merge is therefore `--no-ff`, the
branch's three commits keep their SHAs (= the verdict names `124e84b8db`,
and the merged files are byte-identical to the branch's), and the merged
tree is exactly `dc3e65cca961` — the tree the dry merge predicted
against the `main` tip, = no conflict, = no drift.

## Open items

None carried by this landing. The fix, its tests, and the reviewed
verdict are on `main`; the branch and its worktree carried nothing that
the merge does not, so they were deleted after it.
