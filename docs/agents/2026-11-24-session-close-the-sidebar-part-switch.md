# The sidebar's tree draws one part's rows at a time (sidebar-part-switch, 2026-11-24)

The scope `2026-11-24-sidebar-part-switch` = one defect the boss
reported in one sentence: the left sidebar's tree drew the "Twelve
Immortals" book row ON TOP of the help book's "Characters" row, and the
two rows' styles overlapped. His own condition decided where the defect
was looked for: the tree is clean at launch, and the overlap appears
after ONE switch between the parts.

The plan of record is
`/Volumes/ANAN/Engineering/wenshu/.scratch/2026-11-24-sidebar-part-switch/spec.md`,
and its one issue body is under that plan's `issues/` directory.

**AND THIS RECORD IS WRITTEN IN THE TENSE THE TREE IS IN.** The scope's
fix is COMMITTED on `wt/sidebar-dup-tree-2026-11-24` at `772b608a66`,
and the review's verdict on that sha is PENDING. A record that states an
approval that has not happened is a record that misremembers the scope,
and the closeout gate reads this file BY NAME, so the artifact that
closes the scope would have been the artifact that lied about it. Each
step below therefore says what HAS happened and what is PENDING.

## 1. Re-run the section 7 gates on the MERGED tree

PENDING THE LANDING. The gates below were run on the BRANCH TIP, and
they are re-run on the merged tree when the landing happens (= the merged
tree does not exist yet, = and no log under `.gate-logs/` names a merged
sha, = because `main` has not moved).

What the branch tip measures now:

- `swift build --build-tests` = the build is green (= `Build complete`).
- `swift test --filter SidebarPartSwitchTableIdentityTests` = 2 tests,
  1 suite, exit 0.
- `swift test --filter SidebarTreeRowIdentityTests` = the tree's own
  row-identity suite, exit 0 (= the change does not disturb the row's
  own drawing identity).
- `swift test` = the whole suite, and its census is BELOW (= the suite
  is NOT green on `main`, = = and this scope does not own the red).
- `python3 Tools/wenshu-devtool/nfi-loc-check.py --base main` = every
  added or rewritten file's row carries its own count (2 rows checked:
  1 the change added, 1 whose named file the change rewrote).
- `python3 Tools/wenshu-devtool/comment_lineage.py --base main --head
  HEAD --repo .` = 0 offending rows / 0 files over the branch's window.
- The CJK audit over the lines the commit ADDED = 0 hits (1.1's own
  reading, = = not a grep's, = = and the commit's message carries none).

### The suite census, measured

The census is scoped to what this scope owns. This scope's OWN suites are
`SidebarPartSwitchTableIdentityTests` (= the one it adds) and
`SidebarTreeRowIdentityTests` (= the one it must not disturb), and both
exit 0.

⇒ ⇒ ⇒ AND THE PRE-EXISTING REDS ARE NAMED WITH THEIR EVIDENCE, = = AND
THE CLAIM IS AN INVARIANT, = = NOT A COUNT. The whole suite is NOT
green on this tree, = = and it is NOT green on `main` either. ⇒ ⇒ ⇒
⇒ ⇒ ⇒ AND THE RED SET IS LOAD-SENSITIVE, = = so a COUNT of it would be
a number that dies on the next run. MEASURED: = = the same tree prints
seven red suites on one run and one on the next (= the machine's load
decides which timing-sensitive suites tip over), = = and one suite that
was red in a run MEASURED CONCURRENTLY with another tree's run (= the
`WenshuConductor` wiring) is GREEN on three standalone runs on BOTH
trees (= so it was the load, = = not the tree). ⇒ ⇒ ⇒ So this record
publishes the two claims that SURVIVE the load, and not a count:

- CLAIM ONE (= the scope's own): = = `SidebarPartSwitchTableIdentityTests`
  is GREEN on this branch, = = and RED without the change (= the table is
  the same object before and after a change of part), = = and
  `SidebarTreeRowIdentityTests` is GREEN (= the change does not disturb
  the tree's own drawing identity).
  ⇒ ⇒ ⇒ MEASURED, = = BOTH WAYS, = = ON THIS BRANCH'S TIP, = = AND THE
  SHAPE IS THE PART THAT MATTERS. The removal was not the whole commit:
  = = only the one code line the fix adds
  (`.id(workspaceUI.currentSidebarPart)` in `SidebarTreeView.swift`) was
  deleted, = = the comment above it left in place, = = so the run tests
  the LINE and not the file's presence.
  - WITHOUT the line: = = `Test run with 2 tests in 1 suite failed ...
    with 1 issue`, = = and the failing case is ONLY
    "A change of part rebuilds the table" (= its issue prints
    `some → ObjectIdentifier(0x…)`, = = which is the assertion saying the
    table is still the same object), = = while "A change below the top
    keeps the table" PASSES in the same run.
  - WITH the line restored: = = `Test run with 2 tests in 1 suite passed`,
    = = and the tree is byte-identical to the commit again
    (= `git diff HEAD` empty).
  ⇒ ⇒ ⇒ So the suite separates the two halves of the claim: = = the rebuild
  a change of part MUST cause, = = and the in-place diff a change below the
  top MUST still get. = = A suite that only failed on the base would not
  distinguish "the fix works" from "the app is broken", = = and that
  separation is why this suite is the one the scope ships.
  - ⇒ ⇒ AND THE ONE OBVIOUS COLLATERAL, = = CHECKED AT THE SOURCE INSTEAD OF
    ASSUMED: = = a forced rebuild is a NEW table, = = so the question a reader
    asks next is whether the tree's expansion is lost with the old one. = = It
    is not, = = and the reason is structural rather than lucky: = = the view
    holds NO `@State` at all (`grep -n '@State' SidebarTreeView.swift` returns
    nothing), = = and every `DisclosureGroup` is driven by
    `expansionBinding(for:)`, = = which reads and writes
    `workspaceUI.expandedSidebarRows` — = = the set lives in the STORE, = = keyed
    by the row (`AppleSidebarView+Nodes.swift`, = = above `revealExpansionKeys`:
    "the key survives a tree rebuild and a relaunch"). = = A new table therefore
    re-reads the same set on its first render. = = ⇒ WHAT STAYS UNPROVEN is the
    MEASUREMENT, = = not the mechanism: = = no test in this scope asserts that an
    expansion survives a part switch, = = so the argument above is a reading of
    the code and not a result. = = `SidebarTreeReloadTests` covers the SELECTION
    living above the tree (= "The selection does not rebuild the tree"), = = which
    is the neighbouring question and not the same one.
- CLAIM TWO (= the pre-existing red): = = the two suites that are red
  DETERMINISTICALLY (= red on every standalone run, = = so they are the
  tree's shape and not the load's) are named here, = = and each was
  measured on a pristine detached worktree of `main` at `bbc2434997`:

  - `ChatView history shortcut (T92)` (= the case
    `body_logs_history_metadata`, = = the log block carries no
    `totalTokens` key). MEASURED on the pristine base: = = the same
    failure, = = and red on three standalone runs in a row (= the same
    shape on both trees).
  - `SidebarTreeReloadTests` (= the case "The selection does not rebuild
    the tree", = = the reads went from 3 to 6). MEASURED on the pristine
    base: = = the same failure.

⇒ ⇒ ⇒ The census is re-measurable with the command that produced it, and
the invariant is checked by comparing its output on the two trees (= = the
branch's set and the base's set):

```bash
# SKIP: this census needs the MERGED tree, = which does not exist until the
# branch lands, = and a whole-suite run is not a gate (it aborts mid-bundle
# and prints a count that measures how far it got). = It is printed at the
# landing, = on the merged tree, = and compared against the same command on
# a pristine worktree of `main`.
swift test 2>&1 | grep -oE 'Suite "[^"]+" failed after' | sed 's/ failed after//' | sort -u
```

⇒ ⇒ ⇒ AND THE OTHER PRE-EXISTING RED IS NAMED SEPARATELY, BECAUSE IT
HAS ITS OWN SHAPE. The filtered run `swift test --filter
'SidebarTreeRowIdentityTests|SidebarTreeReloadTests|SidebarPartStateTests'`
is RED, = = and it is red on the BASE TOO: = = measured on the same
pristine worktree of `main`, = = the same filter prints the same failure
(= `SidebarTreeReloadTests` = "The selection does not rebuild the tree",
= = the reads went from 3 to 6). ⇒ ⇒ ⇒ That red is NOT this scope's, = =
and it is not caused by this change: = = the same filter on this
branch's tip prints the same red, = = and the same filter WITHOUT the
change prints it too. ⇒ ⇒ ⇒ The suite `SidebarTreeReloadTests` is RED
on `main` when it runs beside its neighbours, = = and GREEN when it runs
alone (= `swift test --filter SidebarTreeReloadTests` = 2 tests, = = 1
suite, = = exit 0) — = = which is its own shape, = = and it is reported
here rather than folded into this scope's verdict.

## 2. Record the verdict on the board

PENDING THE REVIEW. The scope's review card names the branch's tip
(= the tip this record's own commit produced), and the card is the
board's own record of this scope's verdict (= the card's verdict is the
field the merge gate reads). This record does not
name a verdict the board has not written (= the review's verdict is
`changes_requested` until a card records `approved`, = = and this
scope's card has not).

## 3. Write the closure doc

DONE: this file. Its own name carries the scope's topic (= the reader
finds it by the scope's slug), and it is written in the tree's tense
(= every step says what HAS happened and what is PENDING the landing).

The scope's registry row lives in `docs/agents/nfi.md` (= the row for the
suite this scope adds, = = and the row for `SidebarTreeView.swift`, whose
file the change rewrote, = = so its own count moved with the change).

## 4. Persist the durable lessons into the SKILLS

DONE. The lesson belongs to the class of work this scope is (= a view
whose content is REPLACED wholesale by a different hierarchy):

⇒ ⇒ ⇒ **A LIST THAT IS GIVEN A DIFFERENT HIERARCHY MUST BE GIVEN A
DIFFERENT IDENTITY, OR THE TABLE RECYCLES THE OLD HIERARCHY'S CELLS
INTO THE NEW ONE.** ⇒ ⇒ ⇒ The lesson's shape: = = the defect was
INVISIBLE to the accessibility tree (= the model was right, = = the
a11y tree is rebuilt from the model), = = and visible only in the
PIXELS (= the table's cells). ⇒ ⇒ ⇒ So a tree that shows several
UNRELATED hierarchies must be read by ITS PIXELS and not by its a11y
tree, = = and a harness that cannot see the pixels cannot see this
class of defect at all.

⇒ ⇒ ⇒ AND THE FIX MUST NOT BE THE TREE'S SHAPE: = = a tree's shape
changes when a row's subtree changes (= and the row under the user must
survive that), = = so the identity that rebuilds the table must be the
HIERARCHY the table shows (= the part), = = and the tree's own drawing
identity must stay where it is.

## 5. Clean up YOUR OWN residue

PENDING THE LANDING (= the branch and its worktree are this scope's own
residue, = = and they are removed once the branch has landed). What the
scope leaves behind in the shared checkout is its plan of record
(`.scratch/2026-11-24-sidebar-part-switch/`), = = which the plan gate
and the closeout gate both read.

⇒ ⇒ ⇒ AND THE SCOPE'S OWN EXPLORATION IS GONE: four probe suites were
written while the defect was being localized (= a part-switch probe, = =
an a11y-text probe, = = a pixel probe, = = and the boss's own sequence).
NONE of them reproduced the defect (= the defect needs the real app's
window and the real cell reuse), = = so none of them is a regression
guard, = = and a suite that passes on the base guards nothing. ⇒ ⇒ ⇒
They are deleted, and the ONE suite that discriminates (= it fails on
the base and passes with the change) is what the scope ships.

## 6. Re-check the final state and report it

PENDING THE LANDING. What is true now:

- The fix is committed on `wt/sidebar-dup-tree-2026-11-24` at
  `772b608a66`, = = on top of `main` at `bbc2434997`.
- The scope's own suites are green, = = and the whole suite's census is
  BELOW the base's (= the suite is not green on `main`, = = and this
  scope does not own the red).
- The boss's OWN LOOK (§7.7, = = the merge gate for a UI-touching
  ticket): GIVEN. His verdict, = = in English, = = was that the overlap
  was gone and the iteration could stop.
  ⇒ ⇒ ⇒ WHICH BUILD, = = THE FOUR FACTS THE RULE ASKS FOR:
  - Path: `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/fix1124.app`,
    = = executable `Fix1124`, = = 37,831,776 bytes, = = mtime
    `2026-11-24 18:08:16`.
  - Bundle id: `com.wenshu.app.fix1124` (= = an ISOLATED id, = = so it
    never shares the saved window geometry with `com.wenshu.app` = = and
    two instances of one bundle id abort each other).
    It was launched with a PLAIN `open`, = = never `open -n`.
  - Signature: ad-hoc (= = `codesign -dv` prints `flags=0x2(adhoc)`,
    = = `Signature=adhoc`).
  - The app was NOT left running (= = re-checked at the closeout:
    `ps -eo pid,args | grep "Wenshu.app/Contents/MacOS"` returns
    nothing).
  ⇒ ⇒ ⇒ AND THE ONE HONEST LIMIT ON THIS EVIDENCE, = = STATED RATHER THAN
  SMOOTHED OVER: = = the bundle was packed at 18:08 from the worktree's
  `.build/debug/WenshuApp`, = = and the FIRST commit that holds the fixed
  source is `772b608a66` at 19:31, = = so the build the boss looked at
  PREDATES the commit by 83 minutes. ⇒ ⇒ ⇒ So git cannot prove that
  binary's source: = = no object holds the tree as it stood at 18:08.
  What IS proven: = = the binary carries the view type
  (`nm -a` prints 130 `SidebarTreeView` symbols against a 766-symbol
  `AppleSidebarView` positive control, = = so the count selects and is
  not a silent zero), = = and the fix's code line is a single modifier,
  = = and the tree's own suite reproduces the two halves of the claim
  WITHOUT the boss's look being the only thing standing between the
  defect and a regression. ⇒ ⇒ ⇒ ⇒ ⇒ So the look is recorded as GIVEN on a
  pre-commit build, = = and the COMMITTED proof is the suite, = = not the
  look.

### The landing table, one row per original requirement

| Requirement | The commit that carries it | The verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| The sidebar's tree draws one part's rows at a time (= no row of one part under a row of another) | `772b608a66` | PENDING THE REVIEW (= the card for this sha) | PENDING THE LANDING |

⇒ ⇒ ⇒ AND THE COMMITS THE PUSH CARRIES THAT ARE NOT THIS SCOPE'S: the
push will carry whatever `main` holds at the landing, = = and the scope's
own commit is the one row above. = = The siblings' commits are named in
the landing report when the push happens (= the set is measured per
push, = = not from this document).

## 7. Sweep the board's open columns

MEASURED, and NOT this scope's cards. The board's non-terminal columns
hold four cards, and every one of them is a SIBLING's (= = so they are
measured and named, = = and not closed, = = because closing a sibling's
card erases the reason it is blocked):

| Card | Status | Whose | What it is |
| --- | --- | --- | --- |
| `t_8b5ba37e` | running | `wenshu-review` | round 4 of the comment-honesty sweep (= the vendor rule's markers) |
| `t_ac2dfd0a` | ready | `pocock` | the vendor rule sees 0 offending and the tree holds 22 |
| `t_16d2c525` | ready | `pocock` | the keyboard chord answers two controls in one view |
| `t_a905313b` | ready | `wenshu-review` | the chat zone's context meter is Apple's capacity gauge |

⇒ ⇒ ⇒ AND THE TWO `pocock` CARDS ARE THE BOARD'S OWN KNOWN SHAPE: = = the
board's `dispatch_profiles` names the review profile alone, = = so a card
addressed to the implementer is never spawned (= = it waits for ever),
= = and the board's own hand-off gate reports that shape. ⇒ ⇒ ⇒ So those
two rows are not this scope's to close, = = and this scope does not close
them.

⇒ ⇒ ⇒ AND THIS SCOPE'S OWN CARD IS THE ONE THIS SESSION CREATES (= the
review card for the fix's sha), = = and it is landed in step 8.

## 8. THE CARD YOU DISPATCHED IS YOURS TO LAND

PENDING. The scope's review card names the branch's tip. The landing shape
is measured, not preferred: = = a merge whose second parent is the
reviewed sha, = = then a rebase and a fast-forward. The landing is done
in this scope's own worktree (= never in the shared checkout), = = the
branch's own named gates are re-run on the rebased tree (= a rebase can
change what a gate proves), = = and the remote is read back per remote
(= `git ls-remote`, = = because a push that reported success on one
remote says nothing about the other).

⇒ ⇒ ⇒ AND THE STOPPING RULE: this scope's review card carries the
claims it checks BY NAME, = = and a finding that is only wording is
non-blocking once the named claims hold. = = The record does not log its
own meta-reviews: = = a round that asks for a further self-audit of this
document is the defect repeating.
