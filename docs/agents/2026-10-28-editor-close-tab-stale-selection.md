# 2026-10-28 Editor close tab — the stale active-tab id and the stale segment index

Status: merged to main (= commits `392f38accc` (the fix) + `c22676a27c` (its
suite) = the rebased form of the reviewed `e91b3c424e` + `c40fa2f6e8`),
pushed to `origin` and `old-origin`. A rebase rewrites every sha, so the
REVIEWED shas are not on `main` (= `git cat-file -e c40fa2f6e8` finds the
object; = `git merge-base --is-ancestor c40fa2f6e8 main` says no) and only
the rebased pair is.
Worktree: `project/t_3abaf01a-t2-closing-the-open-document-leaves-a-st`
(= cleaned up post-merge).
Tests: `swift test --filter AppStateCloseTabTests` = 13, `LabelSegmentedControlSelectionTests`
= 7, `EditorTabStripTests` = 10, `EditorTabStripSelectedLabelTests` = 2,
`LabelSegmentedControlIconConfigurationTests` = 1, `ChapterFocusLockTests` = 2,
`EditorViewTests` = 24 — all green on the rebased tree.
Build: clean (= `swift build` exits 0; = the reviewer measured 0 new warnings
against current main).
Review: approved by `wenshu-review` (= round 2, execution lens; = the
independent verdict is on the card `t_3abaf01a`).

## Boss intent (= the only spec that matters)

> Closing the document that is currently open leaves the editor zone in a
> state that the tab strip cannot render.

Closing the open document left the editor zone in a state the tab strip
could not draw: the strip kept a segment index that no longer existed, and
the active-tab id pointed at a document that was gone. Close the last
document and the editor zone either drew a stale segment or drew nothing.

## Root cause (= two separate state invariants)

**(1) The active-tab id survived the close.** `AppState.closeTab(id:bookStore:)`
removed the tab from `openTabs` and, when the closed tab was the active
one, picked a neighbour — but the "no tabs left" branch left `activeTabId`
alone, and its own comment said so ("the `activeTabId` is left untouched
(= it's a stale UUID pointing at the closed tab)"). `activeTabId` is a
non-optional `UUID`, so "left alone" meant "the id of a document that is no
longer open". It is also persisted, so the stale id survived a relaunch.

It matters beyond tidiness: the id decides which VIEW the editor column
renders. A stale id makes `activeTab` resolve to nil (= the empty-state
branch), and the empty state is a DIFFERENT view with a DIFFERENT
intrinsic size. The close of the last document therefore changed the
column's size in the same layout pass that the tab strip's segment count
dropped (= the strip's control collapses to a 0x0 intrinsic size when its
count reaches zero). Two size collapses in one pass is what the
narrow-window crash is made of.

**(2) The segment index survived the segment count.** `LabelSegmentedControl.configure`
shrinks the control's `segmentCount` when the caller's label list shrinks,
and the selection sync that follows only wrote a segment when the bound
value WAS in the label list:

```swift
if let index = labels.firstIndex(of: selection.wrappedValue),
   control.selectedSegment != index {
    control.selectedSegment = index
}
```

So when the bound value named no segment (= the tab strip's own
`noSelectionSentinel`, = the "no tabs left" case) the sync wrote nothing
and the control kept the index it had: the drawn selection named a
DIFFERENT value than the bound one.

## Fix

1. `AppState.swift` — the close path. The active-tab id is REWRITTEN to a
   fresh UUID (= a value that names no open document, = the same "no
   match" idiom the `focusedChapterPath` setter already uses) when the last
   document closes, so the id never names a closed document and the
   persisted value cannot resurrect one after a relaunch.
2. `LabelSegmentedControl.swift` — the segment index. A new pure
   `selectedSegmentIndex(for:in:)` returns **-1** (= AppKit's own "no
   segment is selected") when the bound value names no segment, and
   `configure` writes that result unconditionally. The drawn selection can
   therefore never name a different value than the bound one.

Nothing else moved: the tab strip's public shape and its
`noSelectionSentinel`, `EditorView`'s wiring, the split view's layout code,
the `EditorLayoutMode` values, the two UserDefaults literals, and
`WenshuDefaultsKey.allCases.count` (= 15) are byte-identical, and no new
string was added.

## Tests

`Tests/WenshuAppTests/UI/DesignSystem/LabelSegmentedControlSelectionTests.swift`
(new, 7 tests) drives the CONTROL, not just the index, and
`AppStateCloseTabTests.swift` gained the close-path assertions. The
reviewer re-tested the guard by MEASURING it rather than trusting it:
reverting the production write in `configure` to its pre-card form fails 2
of the 7 selection tests (= a stale `selectedSegment` of 1 and of 0); with
the fix, 7/7 pass.

## Measured

- Set difference against the merge base `b855bfc6ac` over the 8 owning
  suites: **57 pass / 7 suites -> 67 pass / 8 suites**, = +10 tests, 0
  removed, 0 regressions.
- 3 neighbour suites: 39/39 on both sides.
- `FrameMagicSweepTests` fails identically on the baseline (= pre-existing,
  = untouched files).
- Merged with current main: 0 new warnings, 67 + 39 tests green.
- AppKit facts re-derived by the reviewer with a headless probe: a
  count-shrink clamps `selectedSegment` to -1; writing -1 is accepted; an
  out-of-range write throws `NSRangeException` (= the out-of-range
  guarantee is load-bearing).
- The reopen acceptance item was proven by driving the REAL production path
  (= `closeTab` -> `CardOpenOps.openTab` -> `LabelSegmentedControl.configure`
  on a real `NSSegmentedControl`): the strip selects the reopened document.

## Open items

1. The card's own reopen test asserts its own setup rather than driving
   the reopen path. The reviewer drove the real path in its own probe, so
   the behaviour is proven; the TEST does not yet prove it.
2. The label control now writes `-1` when the bound value names no
   segment, so a caller that relied on the control keeping a stale
   selection would see the change. No such caller exists in the tree
   (= the tab strip is the only one, and its sentinel case is the one
   this card fixes).
