# Session closeout: the mark a revealed row of the tree draws

= = = 2026-11-27. = = = ONE carrier: a row of the left tree that the app
opened by itself drew TWO disclosure marks in the same slot (= one in the
closed state, overlapping the open one), = = and the ask was to delete one
of them. = = This is the record of what was measured, = = what was changed,
= = what the gates read, = = and what is still open.

## 1. The symptom, the root cause, the fix

= = = THE ASK (= the boss's own words, = rendered in the committed
language): = = in the directory tree, a book row's expand/collapse mark was
painted a second time in the CLOSED state, = = overlapping the real one, =
= and one of the two had to go.

= = = THE SYMPTOM MEASURED: = = on the row the app opens without being
asked (= the launch reveal, = or the conversation's page pick, = which open
the rows ABOVE the row a selection names), = = the row's children were on
screen (= so the row IS open), = = and its disclosure control reported
CLOSED. = = ⇒ ⇒ ⇒ The app's state and the control's own state disagreed, =
= and both marks were painted: = = the mark the control was built with (=
closed), = = and the mark the row's content drew around it.

= = = THE ROOT CAUSE: = = the app owns the set of open rows (=
`WorkspaceUIState.expandedSidebarRows`), = = and Apple's disclosure control
draws its mark from the value IT is handed. = = When the reveal opened a
row the user never clicked, only the binding's value moved: = = the control
kept the identity (= and the drawn mark) it was first built with, = = and
nothing rebuilt it. = = ⇒ ⇒ ⇒ The row's drawing identity named only its
SUBTREE's content (= `drawIdentity`), = = never its OWN open/closed state.

= = = THE FIX: = = the control's identity now names the state the app holds
the row in. = = The rule lives beside the rule that owns the set (=
`WorkspaceUIState.rowExpansionSuffix(for:) = "o" | "c" | "" (= no mark at
all for a row with no children)`), = = and it is applied to the
`DisclosureGroup` inside `SidebarTreeRow` (= not to the row, = not to the
tree). = = ⇒ ⇒ ⇒ A row whose state changed rebuilds its control and carries
ONE mark (= the one it actually has); = = a row whose state did not change
keeps everything it had (= its identity, = its chrome, = its subtree).

= = = WHAT IS NOT THE FIX (= the two dead ends, = so nobody re-walks them):

= = = 1.1 DELETING A CONTROL. = = A census of the running app's
accessibility tree read FOUR disclosure controls for FOUR container rows in
BOTH builds (= 15x34, = one `AXPress` each, = values flipping on press). =
= The second mark was never a control, = = so there was nothing to delete:
= = the defect lives in what a control paints, = = not in how many controls
exist.

= = = 1.2 THE GUARD THAT WAS WRONGLY BLAMED. = = The first version of this
fix put the state in the ROW's identity (= `.id(drawIdentity + suffix)`).
= = The existing guard "The selection does not rebuild the tree" (=
`SidebarTreeReloadTests`) went red under it, = = and that read as a
verdict on the placement. = = ⇒ ⇒ ⇒ IT WAS NOT A VERDICT: = = THE GUARD IS
FLAKY ON MAIN. = = Repeated runs of the same binary: = = at `ba2415ab86`
(= the base, = = without this change) 4 of 6 runs red; = = at this
branch's sha 6 of 8 runs red; = = and with the selection line DELETED from
the test (= a probe, = = never committed, = = reverted) the counted-reads
assertion at line 190 still failed in 4 of 6 runs. = = ⇒ ⇒ ⇒ THE READ COUNT
GROWS WITH NO SELECTION AT ALL: = = the test captures its baseline after a
fixed 500 ms sleep (= `settle`, = = line 142) = = while the view's own
first load is still draining (= `AppleSidebarView`'s `.task`, = = line
250), = = so the number the claim is measured against is taken mid-flight.
= = The row-identity placement was therefore never shown guilty. = = The
shipped placement was kept on other grounds: = = it rebuilds the CONTROL, =
= not the row, = = not the tree, = = which is the smaller change to what
the user sees, = = and the fix itself rests on the pixels and the
accessibility state (= §2), = = not on that guard. = = ⇒ ⇒ ⇒ THE FLAKY
GUARD IS ITS OWN TICKET (= §5.1): = = until it is repaired, = = no sidebar
change can be judged by it.

## 2. The measured before and after

= = = Same row (= the book row the reveal opened), = = same window (=
1400x977, = at 260,69), = = same 2x pixels, = = same crop (= the mark's
column, = x 48..76), = = two builds (= the committed build of `main` at
`ba2415ab86`, = and this branch).

| what was read | before | after |
| --- | --- | --- |
| the control's own disclosure state, while its children are on screen | CLOSED (value 0) | OPEN (value 1) |
| the row's children drawn | yes | yes (= unchanged) |
| ink height in the mark's column | 16 px (= two marks, tip to tip) | 10 px (= one mark) |
| the shape in that column | a down mark with a closed mark under it | one down mark (= the state the row is in) |
| the title's text box (= the same capture) | x=50.0, w=172.9 (= the extra mark merged into it) | x=116.6, w=106.4 (= clean) |
| press the mark: close, then open | 0, then 1 | 0, then 1 (= unchanged) |
| the mark after the user closes the row | (= not separable before) | one right-pointing mark, = arms opening left (= a closed mark's own height is 16 px) |
| a row with no children | (= no suffix) | (= no suffix: = its identity never moves) |

= = = The pixel readings are reproducible with the tools written for this
(= the ink-cluster reader groups a column's ink rows and prints each
cluster's height; = = the frame captures came from the app's own window, =
= not from a screen grab of a shared desktop).

## 3. The gates on this tree

= = = `swift test --filter SidebarTree` = = **23 tests / 3 suites**. = =
The two suites that carry this change's claims (=
`SidebarTreeExpansionTests`, = which now includes *"A row's drawing
identity follows the row's own open/closed state"*, = and
`SidebarTreeRowIdentityTests`) = = read GREEN in every run taken here. = =
The third member, = `SidebarTreeReloadTests`' "The selection does not
rebuild the tree", = = read green in 2 of 8 runs on this sha and 2 of 6
runs at the base (= §1.2: = = a baseline-capture race, = = not this
change), = = so it is not evidence about anything until §5.1 is done.

= = = `python3 Tools/wenshu-devtool/comment_lineage.py --base ba2415ab86
--head <this sha>` = = **31 added comment lines, offending 0 rows / 0
files (P0=0, P1=0)**.

= = = `python3 Tools/wenshu-devtool/nfi-loc-check.py --base ba2415ab86` =
= **clean** (= 3 rows checked: = 1 the change added, = 2 whose named file
the change rewrote).

= = = `bash Tools/wenshu-devtool/tests/test_nfi_registry.sh` = =
**PASS=*** FAIL=0**.

= = = `Tools/wenshu-devtool/design-sweep.sh` on the two changed sources:
= = **clean** (= no naked `Image(systemName:)`, = no `.cornerRadius`, = no
`.font(.system(size:))`, = = no new magic literal).

= = = The commit hook ran `commit_filter.py` (= the pollution vocabulary
filter) = = and `nfi_lock.py check --staged`; = = `docs/agents/nfi.md` was
reserved with `nfi_lock.py acquire` before its row was written.

= = = Gates quoted here are measured on THIS branch. = = The landing
re-runs them on the merged tree (= `review_gate.py --card <id>` then
`Scripts/merge-preflight.sh <branch>`), = = which is a different tree.

## 4. The boss's own look (= the 7.7 gate)

= = = The build put up for the eye: = = an ISOLATED copy of the app bundle
(= `com.wenshu.app.diag28`, = = ad-hoc re-signed, = = launched with the
boss's own preferences, = = so it restores the exact state that showed the
double mark), = = because a second instance under `com.wenshu.app` kills the
one already running (= and that one is his).

= = = STATUS: = = the pixels and the accessibility state above are
evidence, = = not the verdict. = = §7.7's gate is his own look at a running
build, = = and it has not been given yet.

## 5. The open items

= = = 1. **THE FLAKY GUARD** (= §1.2). = = "The selection does not rebuild
the tree" must be repaired before it can be used to judge any sidebar
change. = = The defect is the baseline capture: = = `afterFirstLoad` is
read after a fixed 500 ms sleep while the view's first load is still
running, = = so the counted reads grow with or without a selection. = = The
shape of the repair: = = let the load QUIESCE before capturing the
baseline (= poll the counter until two consecutive reads agree, = over a
bounded window), = = then move the selection, = = then assert the count has
not moved. = = ⇒ ⇒ ⇒ A probe with the selection line deleted fails the same
assertion 4 times in 6 runs, = = which is the measurement that proves the
guard's red says nothing about a change.

= = = 2. THE DEAD-CODE ITEM IS VOID, = = AND THE SENTENCE THAT STOOD HERE
WAS WRONG. = = It named `AppleSidebarView.expansionProvider` as a member with
no reader. = = That member does not exist and never did: = = `git grep -n
'expansionProvider' -- Sources Tests` prints nothing, = = and `git log --all
--oneline -S'expansionProvider' -- '*.swift'` prints nothing either. = = The
tree's own verifier agrees (= every one of the sidebar's five files is ALIVE, =
0 PARTIAL, = 0 DEAD): = = `python3 Tools/wenshu-devtool/verify-dead.py
Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift
Sources/WenshuApp/Features/Library/View/AppleSidebarView+Nodes.swift
Sources/WenshuApp/Features/Library/View/SidebarTreeView.swift
Sources/WenshuApp/Features/Library/View/SidebarNode.swift
Sources/WenshuApp/Features/Library/View/SidebarRowView.swift`. = = So there is
no dead provider to delete = = and no ticket follows from this item. = = What
the sentence was reaching for is the inverse of dead code: = = the app owns its
expansion set (`WorkspaceUIState.expandedSidebarRows`, = = read through
`SidebarTreeView.expansionBinding`) = = and never consults the framework's own
copy, = = which is the design this fix relies on, = = not residue.

= = = 3. The shared checkout carries unrelated staged work (= re-take it with
`git status --short | wc -l`, = because that number moves with every other
lane and a count written here is stale by the next landing). =
= Untouched by this change, = = which lives in its own worktree on
`fix/sidebar-single-disclosure`.

= = = 4. The review card for this sha has to be created by a session that
may write to the board (= a delegated child's `kanban create` is refused by
the delegate guard); = = the create line is handed over with the sha, = =
and it must name §5.1, = = because the reviewer's run will otherwise read
that guard's red as a verdict on this commit.
