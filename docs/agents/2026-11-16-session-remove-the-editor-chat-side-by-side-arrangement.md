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

## 2. Why the arrangement was measured to be unreachable on this machine

The rule that chose the arrangement lived in
`EditorChatNSController.arrangement(forCompetingWidth:editorShare:mode:)`:
it took the detail column's width and asked whether an even split of it
gave both panes their floor (595 PT for the editor, 280 PT for the chat).
Side by side therefore needed a detail column of 1190 PT.

The detail column is the window's width minus the sidebar (200 PT), the
materials column (240 PT), and the inspector (270 PT): 810 PT of outer
columns. So side by side needed a window of 2001 PT, and on the boss's
1920 PT display the rule could never resolve to side by side at all.

The rule was, on this machine, a rule that ran on every layout pass and
could never resolve to the arrangement it existed to select.

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

The window in that report was 1032 PT wide, which is far below the
2001 PT that side by side needed: at the moment of the abort the
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
