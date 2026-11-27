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

= = = 1.2 PUTTING THE STATE IN THE ROW'S IDENTITY. = = The first version of
this fix did exactly that (= `.id(drawIdentity + suffix)` on both `ForEach`
levels). = = It removed the double mark (= measured, = same as below), = =
and it broke a guard that was already in the tree: = = the existing test
"The selection does not rebuild the tree" counts how many times the sidebar
reads the library (= `SidebarTreeReloadTests`), = = and a row identity that
names the expansion set makes the LIST depend on that set, = = so every
expansion change re-read the library. = = That suite went RED (= 1 issue, =
rc=1) = = and stayed red until the state moved off the row and onto the
control. = = ⇒ ⇒ ⇒ THE LESSON: = = the fix belongs on the smallest view that
holds the wrong paint, = = because anything wider re-opens the read path the
tree is explicitly guarded against.

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

= = = `swift test --filter SidebarTree` = = **23 tests / 3 suites / 0
failures** (= `SidebarTreeExpansionTests`, = `SidebarTreeRowIdentityTests`,
= = `SidebarTreeReloadTests`), = = including the new guard this change
carries: = = *"A row's drawing identity follows the row's own open/closed
state"* (= it drives the reveal the way the app does, = and reads the
suffix for the shelf, = the book, = and a leaf).

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

= = = 1. `AppleSidebarView.expansionProvider` still has no reader (= dead
code = the framework's own expansion, = which the app replaced with its
own set). = = Its own ticket, = = not smuggled into this one.

= = = 2. The shared checkout carries unrelated staged work (= 68 files). =
= Untouched by this change, = = which lives in its own worktree on
`fix/sidebar-single-disclosure`.

= = = 3. The review card for this sha has to be created by a session that
may write to the board (= a delegated child's `kanban create` is refused by
the delegate guard); = = the create line is handed over with the sha.
