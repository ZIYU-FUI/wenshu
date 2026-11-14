# Handoff: the pane tab strip's band regression (= the drawn cells can exceed the column)

Date: 2026-11-14
Written by: the pocock session that landed the scope (= the commit below)
Read with: `git log --oneline -3 main` and `git status`

## WHY THIS DOCUMENT EXISTS

The scope (= the pane tab strips, the title rule, the chat page's reverse
link, and the whole library's assets) is LANDED, REVIEWED and APPROVED.
Its closeout document is
`docs/agents/2026-11-14-session-close-the-pane-tab-strips-and-the-chat-page.md`.

But the dual-axis audit that the closeout ran (= the spec axis, = = a
read-only audit of the merged tree, = = run as a separate read-only
child) found ONE REAL REGRESSION that the review rounds and the closeout
gates did not see. = ⇒ So the landed tree carries a defect, = and this
document is the hand-off for the next session, which takes it as a NEW
REQUIREMENT (= not as a continuation of the landed scope).

⇒ ⇒ ⇒ **The regression is on `main` right now.** = The next session's
first act is to fix it, = and the fix is a new commit on top.

## THE DEFECT, MEASURED

**The drawn strip can exceed the column it was given, in a narrow band,
and this scope introduced it.**

⇒ ⇒ ⇒ The MEASUREMENT (= the repository's OWN instrument: =
`EditorTabStripOverflowTests` hosts the REAL strip in an `NSHostingView`
and reads the drawn track from the layer tree, = = which is real pixels
and not an Accessibility frame):

| tabs | column | share | the BASE's drawn track | the LANDED tree's drawn track |
| --- | --- | --- | --- | --- |
| 23 | 454.5 PT | 19.76 PT | **454.50 PT** (= exact) | **460.00 PT** (= 5.5 PT over) |
| 12 | 222.0 PT | 18.50 PT | **222.00 PT** (= exact) | **240.00 PT** (= 18 PT over) |
| 10 | 190.0 PT | 19.00 PT | **190.00 PT** (= exact) | **200.00 PT** (= 10 PT over) |
| 12 | 200.0 PT | 16.67 PT | 200.00 PT | 200.00 PT (= exact) |
| 30 | 200.0 PT | 6.67 PT | 200.00 PT | 200.00 PT (= exact) |

⇒ ⇒⇒ ⇒ **⇒⇒⇒ SO THE BAND IS THE SHARE RANGE [≈18.2 PT, ≈19.9 PT].**
= ⇒ Outside it the division is exact on both trees.

⇒ ⇒⇒ ⇒ **⇒⇒⇒ AND WHY:** = AppKit gives a cell whose LABEL is only
whitespace (= a zero width space is trimmed away) = its own minimum
segment width (= MEASURED: 20.5 PT at the `.small` control size), = so
the strip overflows. = ⇒ The scope's title rule writes exactly such a
label (`PaneTabStripTitle.nothingMarker`) into every cell too narrow for
a prefix plus an ellipsis, = so the scope turned the band's overflow ON.

⇒ ⇒⇒ ⇒ **⇒⇒⇒ AND THE USER-VISIBLE EFFECT:** = the control's own frame
is still pinned to the column, = but the cells inside are laid out at
20 PT each, = so the track runs past the column and the LAST CELL IS
CLIPPED at the column edge; = the cells are no longer equal shares. = No
ink escapes onto the neighbouring column (= the horizontal scroll view's
clip view cuts at the column), = and in the band the cells hold no
text, = so what the user sees is a cut-off last cell and an unequal
division.

⇒ ⇒⇒ ⇒ **⇒⇒⇒ AND WHY THE REPO'S OWN GUARD MISSED IT:** =
`EditorTabStripOverflowTests.swift:404` asserts the right thing
(`drawnTrackWidth <= columnWidth + 1`), = but its grid (= tab counts 3,
5, 9, 12, 20, 30 × columns 200 and 454.5) = lands ENTIRELY OUTSIDE
the band, = so all twelve points measure exactly on the region. = ⇒ A
band point (= 23 tabs in a 454.5 PT column, = = or 12 in 222) = would
make the existing assertion fail. = ⇒ **The next session's guard must
add a band point.**

## THE MECHANISM, MEASURED (so the next session does not re-derive it)

1. **AppKit clamps an explicit segment width to its own minimum**
   (= 20.5 PT at `.small`). = ⇒ A cell can NEVER be narrower than that
   through `setWidth(_:forSegment:)`. = ⇒ ⇒ The landed code's narrow
   branch called `setWidth(0, forSegment:)` (= to clear a previous,
   wider region's width), = and AppKit answered with its minimum = ⇒ the
   band overflow.
2. **`.fillEqually` alone divides the control's own frame exactly**, = at
   every geometry measured (= the base has no explicit widths and is
   exact everywhere, = including the band). = ⇒ ⇒ Its requirement is
   that no label is wider than the cell it lands in, = and AppKit then
   clips the label.
3. **A label of only whitespace reads as EMPTY**, = and an empty cell
   gets the minimum segment width. = ⇒ ⇒ ⇒ A zero width space is
   trimmed away (= so it reads as empty), = and that is what turned the
   band on. = ⇒ ⇒ ⇒ A label that carries a real SPACE is not trimmed,
   = so the cell is divided to its share, = and a space paints nothing.
4. **A label that is too wide for the cell is NOT clipped by AppKit**
   when no explicit width is set (= MEASURED: 3 tabs in a 200 PT region
   with the scope's fitted titles drew a 239 PT track). = ⇒ ⇒ ⇒ So a
   fix that removes the explicit widths MUST also make the app fit
   every title to the share MINUS the segment's insets, = otherwise the
   WIDE case overflows instead.

⇒ ⇒ ⇒ ⇒ **⇒⇒⇒ AND THE PARTIAL FIX, = MEASURED, = IS NOT SHIPpable
AS IT STANDS:** = removing the explicit widths + making the marker
`U+200B + " "` (a zero width space plus a space) = ⇒ **the band
becomes exact** (454.50 / 222.00 / 190.00 = = = the base's numbers) = =
**and the wide case breaks** (3 tabs in 200 PT = = = 239 PT). = ⇒ ⇒ ⇒
So the third step (= fit the title to the share minus the insets) is
what is missing. = ⇒ The patch is saved at
`/Users/anbaiqiang/.hermes/profiles/pocock/cache/scratch/partial-fix-band.patch`
(= = the two source files' diff) = and the measuring instrument is
`/Users/anbaiqiang/.hermes/profiles/pocock/cache/scratch/BandStripProbeTests.swift`
(= = a test that hosts the REAL strip and prints the drawn track and the
cell steps at six geometries). = ⇒ **COPY BOTH INTO THE NEXT
SESSION'S WORKTREE BEFORE MEASURING ANYTHING**, = = and do not commit
the partial fix without the third step.

## THE NEXT SESSION'S WORK (= = the order that works)

1. Read this document, = then `git log --oneline -3 main` and
   `git status`.
2. Copy the two saved files into the worktree, = apply the patch, = and
   add the third step (= fit the title to the share minus the insets).
3. Measure with the band probe (= the six geometries) and require: = the
   drawn track equals the column at EVERY geometry, = including the
   band and the wide case; = and the narrow cell still paints no ink
   (= the boss's rule: = at the extreme, = nothing shows at all, = not
   even a lone ellipsis).
4. Add a band point to `EditorTabStripOverflowTests` (= 23 tabs in
   454.5 PT, = = and 12 in 222) = so the repo's own guard can see the
   band. = ⇒ And check that the existing twelve points still pass.
5. Run the scope's own ten suites (= 71 tests) and the §7 gates on the
   merged tree, = then take a review card for the fix (= = a new sha = =
   a new verdict = = per rule 1.14), = = and land it (= = a new commit =
   = the landed shas are never rewritten).
6. Append this round to the closeout document as a NEW commit (= the
   document is pushed, = so its own sha cannot change), = and update the
   registry row's LOC last (= the row's number must equal the file's
   line count).

## WHAT IS LANDED, AND WHERE IT LIVES

- The scope's own commit: `ca741631e` (= on `main`, = = and it is the
  commit that carries the band regression).
- The closeout document's commits: `aa65bfb0e9` and `00a0fdb456`.
- Both remotes read back the same sha (= `origin` = gitcode, =
  `old-origin` = github): = `git ls-remote origin main` and
  `git ls-remote old-origin main`.
- The review card: `t_3112a59b` (= approved, = and its body names the
  tree that landed).
- The branch `wt/applemode` holds the rounds' history (= the shas the
  earlier verdicts name, = so they stay resolvable). = Its worktree is
  at the branch tip and is CLEAN.

## THE THINGS THAT ARE NOT MINE (do not touch them)

- The shared checkout sits on another session's branch
  (`wt/session-closeout-2026-11-13`). = ⇒ `git merge --ff-only` in that
  checkout lands into THAT branch; = ⇒ move `main` with
  `git update-ref refs/heads/main <sha> <old-sha>` instead.
- Another session's instance of the same bundle id was on screen (a
  stale build whose sidebar still carries the old label), = and a system
  permission dialog belonging to it covered the middle of the screen. =
  ⇒ It is not this session's residue; = ⇒ leave it, and do not answer
  another session's permission dialog.
- The review lane's own scratch holds its worktrees (= = the round-4
  card's worker was live in one of them).

## THE TWO THINGS THE AUDIT LEFT OPEN (recorded, not built)

1. **The scope's added comments carry 111 CJK characters** (= the
   boss's own words, quoted for traceability). = ⇒ Rule 1.1 says English
   only, = and the tree's baseline already carries 4989 CJK characters
   in 756 comment lines across 107 files. = ⇒ Rewriting them would
   change the diff, = = which changes the change id, = = which voids
   the verdict the boss accepted; = ⇒ it wants its own card.
2. **The assets pane's instance route (`AssetsPane.previewScope()`) has
   no guard** (= the review lane named it as non-blocking: = it is
   pre-existing in kind, = and this scope narrowed it).

## THE LESSONS THAT ARE ALREADY IN THE SKILLS

= `~/.hermes/shared/wenshu-skills/wenshu-parallel-dev/references/the-guard-drives-the-door.md`
carries the guard lessons (= the door drives the guard, = the body's own
layer is held at the behaviour level, = a link has two directions, = a
source read has decoys, = a private mapping is a door, = a fixture that
makes an equality vacuous is a trap, = a hosted tree's text is not an
observable, = and the card must name the tree that lands). = ⇒ **THE
BAND LESSON BELONGS THERE TOO** (= an explicit width is clamped, = = so
the fix for a division problem is the LABEL, = = not the width) = = and
the next session should add it.
