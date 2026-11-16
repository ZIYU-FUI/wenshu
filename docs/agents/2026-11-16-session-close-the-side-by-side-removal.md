# Session closeout: the editor and the chat's side-by-side arrangement is removed

## 1. The trace table (= one row per line the boss gave)

| # | The requirement | The commit that carries it | The independent verdict | The proof |
| --- | --- | --- | --- | --- |
| 1 | the feature that made the editor and the chat stand side by side once the window grew wide enough introduced a pile of bugs, and it is to be deleted | `78e9bf20c` + `de3f287f4` | `t_f2ecfedf` = changes requested (prose only, no Swift source change) -> `t_15bfa0d1` = **approved** | 67 targeted tests + the whole suite (151 + 208 tests) green; the arrangement probe reads `3/3`; `git grep` finds 0 hits in `Sources/` for the arrangement enum, the width floors, the second autosave name, the View menu's radio group and the persisted key |
| 2 | dragging the left edge down to the minimum width crashes the app | the removal does NOT claim this crash (= the crash keeps its own card `t_b74ba50e`); the arithmetic behind the non-claim was corrected in `25e61e17e` | `t_15bfa0d1` = **approved** (= the correction is re-derived independently, and the non-claim stands) | the crash's own window was 1032 PT wide, so its detail column was 1032 - 710 = 322 PT, far below the 875 PT floor (= 595 + 280): the arrangement was already the top-bottom one when the app aborted |
| 3 | narrowing the window moves the editor's and the chat's top tab bars downward | `78e9bf20c` + `de3f287f4` | `t_15bfa0d1` = **approved** | `viewDidLayout` reaches the split's structure nowhere; the split's two items are added once in `viewDidLoad` and never moved; 0 hits for `removeSplitViewItem` / `insertSplitViewItem` / `applyPaneOrder` in `Sources/`. The symptom itself was NOT observed in a drag (= no drag ran, = see section 2) |
| 4 | the tab bars already split infinitely, so the left-right interaction is not needed | `de3f287f4` (the rule, the floors, the arrangement enum, the menu, the persisted key, 68 lines of localized strings) | `t_15bfa0d1` = **approved** | the View menu's radio group is gone and `menu.view.editor_layout` has 0 hits; the persisted key `wenshu.editor.layoutMode` has 0 reads in `Sources/`; the typed-key count is 14 |

## 2. What was NOT measured, and the claim that does not rest on it

**The drag arm measured NOTHING, so there is no crash rate to quote.** The
arm is blocked by macOS's consent, not by the code: the app's library
root is `LibraryRoot.ensureDefault()` (= a path under `~/Documents`),
and an ad-hoc-signed trial bundle has no consent for that folder. The
block is silent (= the app is alive, there is no window, there is no
crash report, and the process sits in `open()` inside
`readDataFromFile`). Five runs, each one a change to the seed or to the
paths, are recorded in the card comment on `t_f2ecfedf`. The user's
`~/Documents` was restored in the same run.

**⇒ ⇒ ⇒ SO THE REMOVAL CLAIMS NO CRASH, AND THAT CLAIM DOES NOT REST ON
THE ARM.** The crash's own report carries the window frame
`{{84, 66}, {1032, 984}}`, so its detail column was 322 PT, far below
the 875 PT floor: the arrangement was already the top-bottom one when
the app aborted. That is arithmetic on the report, not a measurement of
the fix.

**⇒ ⇒ ⇒ AND A BATCH THAT ABORTED ON `NO_WINDOW` IS NEVER QUOTABLE AS "DID
NOT CRASH."** The absence of a measured crash rate is not evidence for
this change, and not evidence against it.

## 3. The gates, = = re-run on the branch at the landing

| Gate | What it says |
| --- | --- |
| `swift build` | PASS (= "Build complete!") |
| `swift test --filter "EditorChatNSControllerTests\|UserDefaultsStoreTests"` | PASS (= 67 tests in 2 suites) |
| `swift test` (= the whole suite) | PASS (= 151 + 208 tests) on the landing's own run. The base's run of the same command is RED (= a timing-sensitive suite; = and the reviewer's own base run measured the IDENTICAL failures at the base and at the tip), so 0 failures are attributable to this change |
| the design sweep (= the greps over the changed Swift files) | PASS (= "design sweep on 9 file(s) / design sweep clean"). NOTE: the sweep's DEFAULT file selection is the Mobile client's paths (`Mobile/Sources/**`), which this repository does not have, so the default invocation is VACUOUS (= "no changed Swift files") and the changed files must be named |
| the pollution gate | PASS (= "the change adds no forbidden vocabulary") |
| the formatting gate | PASS (= "the change adds no unformatted line (11 changed Swift file(s) checked)") |
| `verify-dead.py --ui-components --verbose` over the five changed `EditorChat*` files | PASS (= "every component in scope is reachable"). The repo-wide run names ONE candidate (`WindowOpenButton`), = = and that candidate is PRE-EXISTING on `main` (= the same command on `main` reports it) |
| the NFI gates (`nfi-split.py --check`, `nfi-loc-check.py --base main`) | PASS |
| the probe index's own test | PASS (= 5/5) |
| the arrangement probe (`--source-only`) | PASS (= "source_fragments: 3/3 match") |
| the merge preflight | CLEAN (= no conflict; = and the approving verdict on the record) |

## 4. The two review rounds

The first review (`t_f2ecfedf`, 50 min) returned **changes requested** on
four prose findings and **no Swift source change**: the removal's own
justification named the outer columns' minimum widths (200 + 240 + 270)
and called their sum 810, then added 1190 to 810 and called the result
2001. The rework (`25e61e17e` + `4627e9410`) states the widths it uses
and lets the sum follow, withdraws the claim that the rule could never
resolve to side by side (= at the outer columns' minimum widths a 1920
PT window leaves 1210 PT of detail, and 1210 x 0.5 = 605 >= 595, = so
the rule COULD reach it there), fixes the file header of
`+Layout.swift`, re-tags the registry's two rows, and re-records the
probe index's measurement.

**⇒ ⇒ ⇒ AND THE CORRECTION MAKES THE REMOVAL'S JUSTIFICATION STRONGER,
NOT WEAKER:** the rule's reach moved with a quantity it never read, = =
which is the defect class the boss named.

The second review (`t_15bfa0d1`, 60 min) closed all four findings and
**approved** the tip. The landing (`Scripts/land_card.sh`) then rebased,
re-ran the gate set, fast-forwarded `main`, pushed, and read the remote
back (= `RESULT: LANDED (t_15bfa0d1) sha=4627e9410`).

## 5. The incident, = = and the lesson

At 18:30-18:32 the whole repository directory was deleted (= the source
tree, the `.git` directory, every worktree checkout, = = and the
session's own uncommitted work). It came back from a mirror clone and
from the Hermes checkpoint stores' file snapshot. The full account, the
measured restore state, and the mechanism that was NOT identified are in
`2026-11-16-session-the-repo-was-deleted-mid-session-and-how-it-came-back.md`.

**⇒ ⇒ ⇒ THE LESSON: work that is not committed is not work, and a
worktree is a place a delete can reach.** The second round of this
change was committed in four steps, so each step was in the object store
before the next began.

## 6. Out of scope, = = reported and not fixed

- `EditorChatNSController.toggleChatZone()` has no production caller. It
  was ALREADY caller-less on `main` (= the View menu's Show/Hide Chat
  Zone toggle writes `workspaceUI.chatVisible`, = = not this), and this
  change does not touch it.
- The mechanism that deleted the repository is not identified. The
  checkpoint pruner only deletes snapshots inside its own store, and the
  worktree sweep only reads `<repo>/.worktrees`, so neither explains the
  deletion, and the prune burst that coincides with it is a
  correlation, not a mechanism.
- The design sweep's default file selection points at the Mobile client's
  paths, which this repository does not have. It is therefore vacuous
  here unless the changed files are named. That is a gate that reports
  PASS while checking nothing.
