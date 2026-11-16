# Session closeout: the editor and the chat's side-by-side arrangement is removed

## 1. The scope

The boss named three defects that arrived with the window-width rule that
flips the editor and the chat between a left-right and a top-bottom
arrangement, and one ruling that the feature was no longer needed (= the tab
bars already split infinitely, = = so the window's width was no longer their
reason, = = and the left-right arrangement had nothing left to buy):

1. Dragging the window's left edge narrower, down to the window's minimum
   width, crashes the app.
2. Dragging the window's left edge narrower moves the editor's and the chat's
   top tab bars downward.
3. The left-right arrangement is not needed.

The boss ruled: delete the automatic rule and the side-by-side arrangement,
keep only the top-bottom one. "It introduced a pile of bugs. Better off
without it."

**⇒ ⇒ ⇒ AND EACH OF THE SCOPE'S COMMITS IS AN ANCESTOR OF `main` ON BOTH
REMOTES** (= = the durable fact, = = not a tip, = = because a tip is stale
within minutes):

| # | The commit |
| --- | --- |
| 1 | `78e9bf20c` (= the split has ONE arrangement) |
| 2 | `de3f287f4` (= the side-by-side arrangement is removed) |
| 3 | `9639ff9d6` (= the divider's latch is never reset) |
| 4 | `5de82e37d` (= the arrangement's absence reads the way the gate wants) |
| 5 | `6a494e2e2` (= the repo was deleted mid-session, = = and how it came back) |
| 6 | `25e61e17e` (= the removal's own arithmetic adds up) |
| 7 | `4627e9410` (= the probe's recorded run names the tree it measured) |
| 8 | this scope's closure doc (= = its own commits, = = whose shas this doc cannot name, = = because a doc that names its own sha changes it) |

**⇒ ⇒ ⇒ AND THE COUNT IS ANCHORED TO THE SCOPE, = = NOT TO `main`.** A
range that ends at `main` carries every lane's commits (= = a sibling
scope's, = = so its answer is a moving number and its authors are two), = =
so the scope's own commits are counted at the scope's own sha:
`git rev-list --count 58dd224bb..253734934` = = the eight commits the table
above names. **⇒ ⇒ ⇒ AND THIS DOC'S OWN COMMITS ARE COUNTED BY PATH** (= =
= = the only commits that are this doc's), = = so the scope's total is those
two numbers added.

## 2. The trace table (= one row per line the boss gave)

| # | The requirement | The commit that carries it | The independent verdict | The proof |
| --- | --- | --- | --- | --- |
| 1 | the feature that made the editor and the chat stand side by side once the window grew wide enough introduced a pile of bugs, and it is to be deleted | `78e9bf20c` + `de3f287f4` + `9639ff9d6` | `t_f2ecfedf` = changes requested (prose only, = = no Swift source change) -> `t_15bfa0d1` = **approved** | 67 targeted tests + the whole suite (= 151 + 208 tests) green; the arrangement probe reads `3/3`; `git grep` finds 0 hits in `Sources/` for the arrangement enum, the five width floors, the second autosave name, the View menu's radio group and the persisted key |
| 2 | dragging the left edge down to the minimum width crashes the app | the removal does NOT claim this crash (= the crash keeps its own card `t_b74ba50e`); the arithmetic behind the non-claim was corrected in `25e61e17e` | `t_15bfa0d1` = **approved** (= the correction is re-derived independently, = = and the non-claim stands) | the crash's own window was 1032 PT wide, so its detail column was 1032 - 710 = 322 PT, far below the 875 PT floor (= 595 + 280): the arrangement was already the top-bottom one when the app aborted |
| 3 | narrowing the window moves the editor's and the chat's top tab bars downward | `78e9bf20c` + `de3f287f4` | `t_15bfa0d1` = **approved** | `viewDidLayout` reaches the split's structure nowhere; the split's two items are added once in `viewDidLoad` and never moved; 0 hits for `removeSplitViewItem` / `insertSplitViewItem` / `applyPaneOrder` in `Sources/`. The symptom itself was NOT observed in a drag (= see section 3) |
| 4 | the tab bars already split infinitely, so the left-right interaction is not needed | `de3f287f4` (the rule, the floors, the arrangement enum, the menu, the persisted key, 68 lines of localized strings) | `t_15bfa0d1` = **approved** | the View menu's radio group is gone and `menu.view.editor_layout` has 0 hits; the persisted key `wenshu.editor.layoutMode` has 0 reads in `Sources/`; the typed-key count is 14 |

## 3. What was NOT measured, and the claim that does not rest on it

**The drag arm measured NOTHING, so there is no crash rate to quote.** The
arm is blocked by macOS's consent, not by the code: the app's library root is
`LibraryRoot.ensureDefault()` (= a path under `~/Documents`), and an
ad-hoc-signed trial bundle has no consent for that folder. The block is
silent (= the app is alive, there is no window, there is no crash report, and
the process sits in `open()` inside `readDataFromFile`). Five runs, each one a
change to the seed or to the paths, are recorded in the card comment on
`t_f2ecfedf`. The user's `~/Documents` was restored in the same run.

**⇒ ⇒ ⇒ SO THE REMOVAL CLAIMS NO CRASH, AND THAT CLAIM DOES NOT REST ON
THE ARM.** The crash's own report carries the window frame
`{{84, 66}, {1032, 984}}`, so its detail column was 322 PT, far below the
875 PT floor: the arrangement was already the top-bottom one when the app
aborted. That is arithmetic on the report, not a measurement of the fix.

**⇒ ⇒ ⇒ AND A BATCH THAT ABORTED ON `NO_WINDOW` IS NEVER QUOTABLE AS "DID
NOT CRASH."** The absence of a measured crash rate is not evidence for this
change, and not evidence against it.

## 4. The §7 gates, = = RE-RUN ON THE MERGED TREE

The merged tree = `main` after the fast-forward (= the tree this scope's
commits landed on, = = plus this scope's closure doc). The gates were run
there, not on the branch that was measured before the merge.

| Gate | The result |
| --- | --- |
| `swift build` | PASS (= "Build complete!") |
| `swift test --filter "EditorChatNSControllerTests\|UserDefaultsStoreTests"` | PASS (= 67 tests in 2 suites) |
| `swift test` (= the whole suite) | PASS (= 151 tests in 34 suites, = = and 208 tests in 24 suites). The base's run of the same command is RED (= a timing-sensitive suite). The approving review (`t_15bfa0d1`) measured the attribution on this tree: **11 failing sites at the base, 7 at the tip, the tip a strict subset of the base, and 0 sites the tip fails that the base does not** (= = so 0 failures are attributable to this change). The word "identical" belongs to the FIRST review (`t_f2ecfedf`), which measured a different tip (= `6a494e2e2`) and a different failure set; = = and the whole suite's failing set FLOATS on the same tree, = = so no base/tip pair has a stable identical set |
| the design sweep (= the greps over the changed Swift files) | PASS (= "design sweep clean"). NOTE: the sweep's DEFAULT file selection is the Mobile client's paths (`Mobile/Sources/**`), which this repository does not have, so the default invocation is VACUOUS (= "no changed Swift files") and the changed files must be named |
| the pollution gate | PASS (= "the change adds no forbidden vocabulary") |
| the formatting gate | PASS (= "the change adds no unformatted line (11 changed Swift file(s) checked)") |
| `verify-dead.py --ui-components --verbose` over the five changed PRODUCTION `EditorChat*` files (the sixth changed `EditorChat*` file is a test file) | PASS (= "every component in scope is reachable"). The repo-wide run names ONE candidate (`WindowOpenButton`), = = and that candidate is PRE-EXISTING on `main` (= the same command on `main` reports it) |
| the NFI gates (`nfi-split.py --check`, `nfi-loc-check.py`) | PASS |
| the probe index's own test | PASS (= 5/5) |
| the arrangement probe (`--source-only`) | PASS (= "source_commit: 253734934111", = = "source_fragments: 3/3 match") |
| the merge preflight | CLEAN (= no conflict; = = and the approving verdict on the record) |

## 5. §7.7 = = THE BOSS'S OWN LOOK IS A VERDICT THIS DOC RECORDS (= = AND IT IS PENDING)

This scope is UI-touching (= the View menu's radio group is gone, = = and the
arrangement is fixed), = = so the merge gate includes the boss looking at the
running build. **The four facts:**

1. **Which build**: `/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app`,
   rebuilt from `main` @ `253734934111ad3e8e6b6e49f55f101be918dd29`,
   ad-hoc signed (= `Signature=adhoc`, `Identifier=com.wenshu.app`), binary
   uuid `A5784ACC-AE7D-39C9-8E09-83599817AFD3`.
2. **The bundle's OWN BYTES carry the change** (= measured with `nm -a` on
   the bundle's binary): ABSENT = `EditorArrangement`, `applyLayoutMode`,
   `holdsChrome`, `sideAutosaveName`, `EditorLayoutMode` (= 0 hits each);
   PRESENT = `updateAutomaticThicknessBounds` and `storedShare` (= 2 hits
   each) = = the control, = = because a tool that selects nothing and a tree
   that lacks the thing both print 0.
3. **The boss's verdict = NOT YET GIVEN** (= never "approved").
4. **The app was left running = no.** This session launched nothing.

**⇒ ⇒ ⇒ AND THE LOOK WAS NOT TAKEN, AND THE REASON IS RECORDED RATHER THAN
THE LOOK.** The bundle id `com.wenshu.app` is HELD by a live instance (= pid
3574, = = started 13:19, = = still executing the pre-deletion image, = = whose
OWN executable was deleted when the repository was deleted under it, = = while
the path now holds the REBUILT bundle (= = a different inode)). A second
instance of the same bundle id restores the same saved window geometry, and
AppKit's update-constraints guard then fires and BOTH processes abort (= the
measured `open -n` failure mode), = = so launching this scope's build would
have DESTROYED A LIVE INSTANCE. **⇒ ⇒ ⇒ AND THAT INSTANCE IS NOT TOUCHED**
(= it is not this session's residue), = = it is left running and named, = = and
the look is the boss's to schedule once the bundle id is free.

**⇒ ⇒ ⇒ ⇒ AND THE DOC CARRIES THE ONE COMMAND THAT COMPLETES IT:**

```bash
open /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
```

(a PLAIN `open`, = = never `open -n`; = = and first stop the instance that
holds the bundle id). **⇒ ⇒ ⇒ ⇒ ⇒ AND WHAT TO LOOK AT** (= = the two things
that must now hold):

- the editor is ABOVE the chat at every width, = = and the window narrows
  without the panes changing places;
- the View menu carries NO editor-layout choice, = = and its Show/Hide Chat
  Zone toggle still works.

## 6. The server-side proof, = = and what the push carried

`Scripts/land_card.sh` pushes ONE remote (= `origin`), = = so the closeout
pushed the other.

**⇒ ⇒ ⇒ AND THE PROOF IS ANCESTRY, = = NOT A TIP** (= = a tip is stale
within minutes, = = and this doc's own commits move it). Each of the scope's
commits is an ancestor of `main` on BOTH remotes:

```bash
git merge-base --is-ancestor <sha> refs/remotes/origin/main
git merge-base --is-ancestor <sha> refs/remotes/old-origin/main
```

**⇒ ⇒ ⇒ AND THE READ-BACK AT THIS CLOSEOUT'S MOMENT** (= = a snapshot, = =
and the reader re-reads it, = = because the server's answer moves):

| Where | The sha |
| --- | --- |
| `git ls-remote origin main` (= gitcode) | `253734934111ad3e8e6b6e49f55f101be918dd29` |
| `git ls-remote old-origin main` (= github) | `253734934111ad3e8e6b6e49f55f101be918dd29` |

(= = both remotes read the SAME sha, = = which is the fact the proof turns
on; = = the sha itself is the snapshot.)

**⇒ ⇒ ⇒ AND THE PUSH CARRIED NO SIBLING'S COMMITS.** Every commit in
`58dd224bb..253734934` is this scope's (= section 1), = = so the push was
authorship, = = not maintenance of the shared server state.

## 7. The board's open columns (= the sweep)

| Card | State | What it is | Who owns it |
| --- | --- | --- | --- |
| `t_f2ecfedf` | done | this scope's first review (= changes requested on four prose findings) | this scope |
| `t_15bfa0d1` | done | this scope's second review (= **approved**), = = the verdict that covers the branch | this scope |
| `t_c82584bb` | **unblocked for one honest retry** (= was blocked) | the App Store editorial-card scope's closeout. Its three runs all ended `timed_out` at 5430 s, 5438 s and 5443 s = = each within 43 s of its 5400 s cap, = = so the blocker was a CLOCK, not the work. The cap was raised to 7200 s, the card was unblocked, and the dispatcher picked the retry up. Its work (= three commits on `wt/appstore-card-correct`) is NOT on `main` | the review lane, = = a sibling's scope, = = not closed here |
| `t_79f3723d` | **done** | the App Store card's figures. Its own comment recorded it as SUPERSEDED, = = and the three cards that replaced it (`t_940ad123`, = = `t_51b7dddd`, = = `t_b997467d`) were done or running at this closeout, = = so the reason it was blocked had cleared | a sibling's scope, = = closed on its own stated intent |

**⇒ ⇒ ⇒ AND NOTHING OF THE SIBLING'S WAS TOUCHED**: = = not its worktree,
= = not its branch, = = not its three commits. = = The two cards were
MEASURED, and only the one whose blocker had cleared was closed.

## 8. The two review rounds

The first review (`t_f2ecfedf`, 50 min) returned **changes requested** on four
prose findings and **no Swift source change**: the removal's own justification
named the outer columns' minimum widths (200 + 240 + 270) and called their sum
810, then added 1190 to 810 and called the result 2001. The rework
(`25e61e17e` + `4627e9410`) states the widths it uses and lets the sum follow,
withdraws the claim that the rule could never resolve to side by side (= at
the outer columns' minimum widths a 1920 PT window leaves 1210 PT of detail,
and 1210 x 0.5 = 605 >= 595, = = so the rule COULD reach it there), fixes the
file header of `+Layout.swift`, re-tags the registry's two rows, and
re-records the probe index's measurement.

**⇒ ⇒ ⇒ AND THE CORRECTION MAKES THE REMOVAL'S JUSTIFICATION STRONGER, NOT
WEAKER:** the rule's reach moved with a quantity it never read, = = which is
the defect class the boss named.

The second review (`t_15bfa0d1`, 60 min) closed all four findings and
**approved**. The landing (`Scripts/land_card.sh`) then rebased, re-ran the
gate set, fast-forwarded `main`, pushed, and read the remote back (= `RESULT:
LANDED (t_15bfa0d1) sha=4627e9410`).

## 9. The incident, = = and the lesson

At 18:30-18:32 the whole repository directory was deleted (= the source tree,
the `.git` directory, every worktree checkout, = = and the session's own
uncommitted work). It came back from a mirror clone and from the Hermes
checkpoint stores' file snapshot. The full account, the measured restore
state, and the mechanism that was NOT identified are in
`2026-11-16-session-the-repo-was-deleted-mid-session-and-how-it-came-back.md`.

**⇒ ⇒ ⇒ THE LESSON: work that is not committed is not work, and a worktree
is a place a delete can reach.** The second round of this change was committed
in four steps, so each step was in the object store before the next began.

## 10. Out of scope, = = reported and not fixed

- `EditorChatNSController.toggleChatZone()` has no production caller. It was
  ALREADY caller-less on `main` (= the View menu's Show/Hide Chat Zone toggle
  writes `workspaceUI.chatVisible`, = = not this), and this change does not
  touch it.
- The mechanism that deleted the repository is not identified. The checkpoint
  pruner only deletes snapshots inside its own store, and the worktree sweep
  only reads `<repo>/.worktrees`, so neither explains the deletion, and the
  prune burst that coincides with it is a correlation, not a mechanism.
- The design sweep's default file selection points at the Mobile client's
  paths, which this repository does not have. It is therefore vacuous here
  unless the changed files are named. That is a gate that reports PASS while
  checking nothing.
- `Scripts/land_card.sh` pushes ONE remote. A scope that lands through it
  reaches github only when the closeout pushes the second remote.
- The live instance that holds the bundle id (= pid 3574) still executes the
  pre-deletion image, whose own executable was deleted (= = the path now
  holds the rebuilt bundle, = = a different inode). It is left running and
  named; the boss's look waits on it.
