# Session: remove the editor and chat's side-by-side arrangement

## 1. What the boss asked

The boss named three defects that arrived with the window-width rule that
flips the editor and the chat between a left-right and a top-bottom
arrangement:

1. Dragging the window's left edge narrower, down to the window's
   minimum width, crashes the app.
2. Dragging the window's left edge narrower moves the editor's and the
   chat's top tab bars downward.
3. The tab bars already split infinitely, so the window's width is no
   longer their reason; the left-right arrangement is not needed.

The boss ruled: delete the automatic rule and the side-by-side
arrangement, keep only the top-bottom arrangement. "It introduced a pile
of bugs. Better off without it."

## 2. Why the arrangement's reach depended on the wrong quantity

The rule that chose the arrangement lived in
`EditorChatNSController.arrangement(forCompetingWidth:editorShare:mode:)`:
it took the detail column's width and asked whether an even split of it
gave both panes their floor (595 PT for the editor, 280 PT for the chat).
Side by side therefore needed a detail column of 1190 PT.

The detail column is the window's width minus the OUTER COLUMNS, and the
outer columns have a MINIMUM and an IDEAL width each:

| Outer column | Minimum | Ideal | Source |
| --- | --- | --- | --- |
| the sidebar | 200 PT | 240 PT | `LibraryRootView.swift`'s `navigationSplitViewColumnWidth` |
| the materials column | 240 PT | 300 PT | the same |
| the inspector | 270 PT | 270 PT | macOS's own inspector column width (= the app sets no width of its own) |
| **the sum** | **710 PT** | **810 PT** | 200 + 240 + 270 = 710; 240 + 300 + 270 = 810 |

So side by side needed a window of 710 + 1190 = **1900 PT** when the outer
columns stood at their minimum, and 810 + 1190 = **2000 PT** when they stood
at their ideal.

**⇒ ⇒ ⇒ SO ON THE BOSS'S 1920 PT DISPLAY THE RULE COULD REACH SIDE BY
SIDE, OR NOT, DEPENDING ON HOW WIDE THE OUTER COLUMNS HAPPENED TO BE.**
At their minimum widths the detail column is 1920 - 710 = 1210 PT, and
`holdsChrome(1210, 0.5)` holds (= 1210 x 0.5 = 605 >= 595). At their ideal
widths the detail column is 1920 - 810 = 1110 PT, and `holdsChrome(1110,
0.5)` does NOT (= 555 < 595). The same window, the same rule, two different
answers, = = and the answer depends on a quantity the rule never reads.

That is the defect class the boss named: a rule that measures the wrong
quantity, whose reach moves with something else. The arrangement was
therefore NOT unreachable on this machine, = = it was reachable or
unreachable according to a condition the rule did not own, = = and every
crossing of that condition ran the structural change inside a layout
callback.

## 3. What the removal changes

The editor and the chat are now always one above the other. The editor
takes the whole width of the detail column and the chat takes the whole
width below it, and the divider runs across, exactly as the app behaved
before the arrangement rule arrived.

Three things go with it:

- The width rule, and with it the floors it compared (595 PT, 280 PT,
  1190 PT, and the chrome widths 116 PT and 254 PT).
- The transition machinery: the deferred re-order of the split's two
  items, the second autosave name for the side-by-side layout, and the
  fifty-fifty reset that a transition owed.
- The setting itself: the View menu's editor-layout radio group, the
  `EditorLayoutMode` enum, the persisted key, and its four labels.

What stays is the work the arrangement never owned: the divider's
persisted position, the fifty-fifty reset on the first launch, the
thickness bounds, and the `sizeThatFits` fix that stops the editor's
host from reporting the whole document's height.

## 4. What the removal is measured against

The three defects are measured, not asserted:

1. The crash. Dragging the window's left edge down to its minimum width
   must not produce a crash report that carries this build's binary UUID.
2. The tab bars. During the same drag the editor's and the chat's top
   bars must not move.
3. The arrangement. The chat must sit below the editor at every width,
   and the app must carry no code that selects between two
   arrangements.

## 5. The gates

- The unit tests, with the arrangement rule's tests replaced by the
  arrangement's absence.
- The build, and the crash oracle over the left-edge drag.
- The reviewer reads the commit and runs the gates named in the card.

## 6. What this session does NOT claim

The crash the boss hit on 2026-11-16 at 09:45:55 is the AppKit
runaway-layout guard: the window was marked as needing another
Update Constraints in Window pass more times than it has views (436
passes against a limit of 430), and the process aborted. The report
holds no application frame beyond `WenshuApp.$main()`.

The window in that report was 1032 PT wide. Its detail column was
therefore 1032 - 710 = 322 PT (= the outer columns at their minimum),
far below the 875 PT that side by side needs at its floor (= 595 PT for
the editor + 280 PT for the chat). At the moment of the abort the
arrangement was already the top-bottom one. So this removal is NOT
measured to fix that crash, and the removal must not be reported as the
fix for it.

What this removal does remove is the machine that could re-arm the
window's constraint passes while the window is being narrowed: the
per-pass re-measure of the panes' thickness bounds against the window's
width, and the deferred re-order of the split's items that rebuilds the
editor's and the chat's hosts when the arrangement flips. Whether the
crash is gone is measured, not claimed here.

The crash itself also has a pre-existing card, `t_b74ba50e`, which was
archived. This session does not reopen it; it only removes the
arrangement, and reports the measurement.
