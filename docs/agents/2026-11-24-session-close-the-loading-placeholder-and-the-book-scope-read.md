# Session close — the project's one loading placeholder, and the book scope's read out of the tab switch's frame

Date: 2026-11-24 (Asia/Shanghai). Tree this record was written against: `main` at
`1a2327f795` — an ancestry SNAPSHOT, not a tip claim. Read your own current tip with
`git rev-parse --short main`; the ancestry test is the check, never the tip. The gate
readings in section 6 are measured on the SCOPE'S OWN WINDOW, `26ef07472d..37a8f04bf2`,
because a figure measured against a moving `main` is broken by the very commit that
carries this record:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git merge-base --is-ancestor 37a8f04bf2 main && echo 'the scope is in main ancestry'
git log --oneline main -- Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift | head -3
```

Every gate below was run on the MERGED tree, not inherited from a branch, and every
number carries the command that prints it.

## 1. The two requests this scope answers

1. The chat zone's tab switch stuttered. The cause named by the request was not the chat
   zone itself: the related columns (the material column, the inspector) load together
   with the tab, so switching to the chat tab paid for another zone's work. The request was
   that the chat zone's own motion must not be affected by the other zones' loads.
2. The waiting state must be one project-wide mechanism, not a patch on the right column:
   while a region is loading it reserves the space its real content will occupy, and the
   real content replaces it in place, so nothing jumps. Implemented with Apple's own
   SwiftUI primitives; no longer or extra animation was used to hide a blocked main thread.

## 2. Root cause (two, independent)

**2.1 The tab switch's frame carried another scope's disk read.** The chat tab's pick
moves the directory tree's selection (`ChatZoneTabBar.swift:220-221` writes
`workspaceUI.currentSidebarPart` and `workspaceUI.sidebarSelection`), the material
column's scope is that selection (`AssetsPane.swift:185` calls
`previewScope(for: workspaceUI.sidebarSelection)`, and `previewScope(for:)` maps a book
row to `.bookScope`), so switching tabs changes the material column's scope inside the same
frame the chat zone animates in. That scope walked the book's documents on the main thread.
It walked the same book twice per pass: once for the pane's own body, once for the chrome's
card count.

The app's own probe measures this on the tree it runs on, and it prints the commit it
measured. It runs in any checkout of the tree:

```bash
cd /Volumes/ANAN/Engineering/wenshu
swift Tools/wenshu-devtool/probes/card_surfaces_load_cost.swift
```

The three readings below are STRUCTURAL facts (= the walk count, the byte count and
where the read happens), so they read the same on every tree where this scope's code
stands; the timings the probe also prints are not published here, because they move with
the machine and the load. The tree these were measured on is `37a8f04bf2`, the scope's
tip:

| reading (the probe's own `A2` rows) | before (the old door) | after (the new door) |
| --- | --- | --- |
| disk walks of the book per body pass | 2 | 0 |
| bytes read inside the body pass | 123854 | 0 |
| where the read happens | the tab switch's frame, on the main thread | one background read per book, published into the view |

The probe prints `source_fragments: 9/9 match` before any number, so a number that cannot
be tied to the source it measures is not printed at all.

## 3. The fix as it stands on `main`

| file | role |
| --- | --- |
| `Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift` | the one placeholder. One component, three shapes (`rows`, `cards`, `groups`) so each zone reserves the shape its real content takes. Honours Reduce Motion (the cycle is empty when it is on). |
| `Sources/WenshuApp/Features/Editor/View/PreviewPaneBookDocuments.swift` | the book scope's documents read ONCE per book, off the main thread, behind a generation counter so a stale read cannot write over a newer one. |
| the zones that wait | the material column's scopes, the library list, the kanban board and the sidebar draw the shared placeholder; the chat transcript is the named exclusion, with the reason in the test (its own streaming lane is the waiting state there). |
| `Sources/WenshuApp/Shared/UI/ComponentDocs/ComponentIndex.md` | registers the component in the part table, so a reader finds it by concern. |

## 4. What landed — ancestry, not tips

Seven commits, twenty files touched, 2649 lines added and 484 removed (measured with
`git show --numstat` over the seven, summed):

```bash
cd /Volumes/ANAN/Engineering/wenshu
git show --numstat --format= f0b4c889a7 a4cfc41a62 d34741da44 1c13915934 988c12eb5d 6a8941d389 37a8f04bf2 \
  | awk 'NF==3{a+=$1;d+=$2;f[$3]=1}END{printf "unique-files=%d insertions=%d deletions=%d\n",length(f),a,d}'
```

| commit | subject | the card that reviewed it | that card's verdict |
| --- | --- | --- | --- |
| `f0b4c889a7` | feat: the project's one loading placeholder, and the zones that wait draw it | `t_498766b6` | approved at `a4cfc41a62` (its parent) |
| `a4cfc41a62` | perf: the material column's book scope reads its documents once, off the main thread | `t_498766b6` | approved at `a4cfc41a62` |
| `d34741da44` | fix: the review's notes, and the citations that did not reproduce | `t_e353de04` | changes requested at `d34741da44` |
| `1c13915934` | fix: the comment scaffold's runaway, the number family, and the evidence | `t_5eabcfdc` | changes requested at `1c13915934` |
| `988c12eb5d` | fix: the runaway probe's dead arm, and the four records that were over-claiming | `t_db1d3d81` | approved at `988c12eb5d` |
| `6a8941d389` | fix: the three open findings from the first audit, measured against the landed tree | `t_ecbf4bc8` | approved at `6a8941d389` |
| `37a8f04bf2` | fix: the loading mechanism's own three loose ends, measured against the landed tree | `t_77e63bf6` | approved at `37a8f04bf2` |

Two of the seven carry a changes-requested verdict, and that is the record of what those two
cards found; the finding each one raised was closed by the next commit in the list. Every
verdict above is read back with the project's own gate:

```bash
cd /Volumes/ANAN/Engineering/wenshu
for c in t_498766b6 t_e353de04 t_5eabcfdc t_db1d3d81 t_ecbf4bc8 t_77e63bf6; do
  python3 Tools/wenshu-devtool/review_gate.py --card $c 2>&1 | tail -1 || true
done
```

The gate exits 0 on `approved` and 3 on `changes_requested`, so the loop keeps going.

`t_6765a05c` approved `06cbbf1a4d6c`, the same change as `37a8f04bf2` before it was
rebased: the two commits are byte-identical over this scope's three files
(`git diff 06cbbf1a4d6c 37a8f04bf2 -- <those files>` prints nothing), and `37a8f04bf2` is
the copy on `main`. The pre-rebase sha `06cbbf1a4d6c` is parked under
`refs/keep/skeleton-06cbbf1a4d` so the card's citation still resolves; `37a8f04bf2` needs
no parking because `main` already holds it. `git for-each-ref refs/keep` lists what is
parked.

## 5. Measured before and after

Section 2's table is this scope's measurement; the probe prints it on the tree it runs on,
and section 6 names that tree (`37a8f04bf2`) so the figure is one the reader can reproduce.

The mechanism's shape test bites four ways. The arms and their readings are the REVIEW
CARDS' own record, not a measurement this closeout re-ran, and the card that holds them is
named here so the reader can go to the owner: the four arms are attached to `t_6765a05c`
and re-run at `t_77e63bf6`, where they read = = dropping a shape that is in use, 2 issues;
adding a fourth shape that no zone asks for, 3 issues; ignoring Reduce Motion, 1 issue; and
drawing the placeholder in the excluded chat file, the exclusion test goes red. Reverting
every arm returns the suite to green. This closeout re-ran the suite those arms bite (87
tests in 8 suites, section 6) and did NOT re-run the arms themselves.

## 6. The gates, re-run on the scope's own window

Rounds 1 through 7 each ran the whole gate set at their own tip and posted the readings in
the card bodies on the board (`hermes kanban show <card>`). This closeout re-ran them
instead of inheriting them, because main had moved under the branch.

**⇒ ⇒ ⇒ AND EVERY GATE BELOW IS MEASURED ON THE SCOPE'S OWN WINDOW, = = THE FIXED
SHA PAIR `26ef07472d..37a8f04bf2`.** A gate whose head is the live `main` measures a
different set every time another lane lands, and a number that moves with the tree is a
number the reader cannot check. ⇒ ⇒ ⇒ So the readings below are the ones the tools print
in a checkout of the scope's tip, and the commands are the tools' own, run there:

```bash
SKIP: this block creates a worktree, = = so it must not run on every verification.
# The scope's own tip, in a checkout of its own. Every command in the table below
# is run from THAT directory, = = so each one measures 26ef07472d..37a8f04bf2:
cd /Volumes/ANAN/Engineering/wenshu
git worktree add --detach /tmp/wenshu-scope-tip 37a8f04bf2
cd /tmp/wenshu-scope-tip
```


Every command in the table below is run from `/tmp/wenshu-scope-tip` (= = the checkout the
block above makes), and each one is the project's own tool, unchanged.

| gate | command | reading at `37a8f04bf2` |
| --- | --- | --- |
| build | `swift build -c debug` | exit 0 |
| the scope's own suites | `swift test --filter 'LoadingPlaceholderTests\|BookDocumentTests'` | exit 0, 28 tests in 2 suites passed |
| the scope's eight suites | `swift test --filter 'LoadingPlaceholderTests\|BookDocumentTests\|AppleSidebarMVVMSplitTests\|InspectorCardTests\|InspectorRightColumnPushTests\|InspectorCardLazinessTests\|KanbanViewTests\|EmptyStateViewTests'` | exit 0, 87 tests in 8 suites passed |
| the change gate | `for c in formatting pollution loc-cap markdown-newline; do python3 Tools/wenshu-devtool/ci_change_gate.py --base 26ef07472d --check $c; done` (the tool takes ONE check name per call, = = it rejects a pipe-separated list) | `the change adds no unformatted line (70 changed Swift file(s) checked)`, `the change adds no forbidden vocabulary`, `every changed Swift file is within the 600-LOC cap (70 file(s) checked)`, `the change drops no .md's trailing newline (5 changed .md file(s) checked)` |
| comment lineage | `python3 Tools/wenshu-devtool/comment_lineage.py --base 26ef07472d --head 37a8f04bf2` | 1634 added comment lines, `offending: 0 rows / 0 files (P0=0, P1=0)` |
| the design sweep | `bash Tools/wenshu-devtool/design-sweep.sh $(git show --numstat --format= f0b4c889a7 a4cfc41a62 d34741da44 1c13915934 988c12eb5d 6a8941d389 37a8f04bf2 \| awk 'NF==3{f[$3]=1}END{for(k in f) print k}' \| grep '\.swift$')` | `design sweep on 16 file(s)` = = `design sweep clean` |
| the registry | `python3 Tools/wenshu-devtool/nfi-loc-check.py --base 26ef07472d` | 20 rows checked: 11 the change added, 9 whose named file the change rewrote |
| dead code | `python3 Tools/wenshu-devtool/verify-dead.py Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift Sources/WenshuApp/Features/Editor/View/PreviewPaneBookDocuments.swift` | `ALIVE: 2 / PARTIAL: 0 / DEAD: 0` |

The scope's own two suites are the gate this scope answers with; the eight-suite row is the
wider set the same two suites belong to, and it is the number the record published before.

**⇒ ⇒ ⇒ AND THE SWEEP'S FILE LIST IS NAMED BESIDE EVERY COUNT, = = BECAUSE THE
COUNTS DIFFER BY ARM.** The scope's own paths are the union of the seven commits' own
paths: 20 paths, of which 16 end in `.swift` and 16 sit under `Sources/` or `Tests/` (= =
the two sets overlap in 15, because `ComponentIndex.md` is a `Sources/` path that is not
Swift, and the `Tools/` probe is Swift but not under `Sources/`). Swept over the 16
`.swift` ones the tool reads `design sweep clean`. Swept over all 20 it prints five hits,
and every one is the scope's own DOCUMENTATION quoting the rule it teaches: three naked
glyphs and one magic spacing inside
`Sources/WenshuApp/Shared/UI/ComponentDocs/ComponentIndex.md` (lines 237, 472, 516 and 492)
and one inside `docs/agents/nfi.md` (line 223). A prose line that shows the rule is not a
violation of it.

The cumulative diff over the same range is a different arm and carries other lanes' work:
76 paths in all, 70 of them under `Sources/` or `Tests/`, against the scope's own 20 and 16
(= = 56 and 54 paths that this scope never wrote). Swept over the cumulative arm the tool
reports one more hit, and it belongs to another scope: a naked
`Image(systemName: Self.statusIconName(for: toolUse.status))` at
`Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift:58`, a file no commit in
this scope touches (its `statusIconName` returns `hourglass` / `checkmark` / `xmark`). It is
recorded here as a finding against that lane, not silently fixed here and not counted against
this scope.

The pollution gate reads the changed lines only, so it cannot tell who introduced a
character: a CJK or curly-quote hit in a diff must be checked against the parent file with
`git show <sha>^:<path>` before anyone calls it a violation.

### The full suite's failure set, and the one difference

`swift test` exits 0 and its last line reads `208 tests in 24 suites passed`, but the log
carries a failing middle target. The project's own comparator reads both summary shapes and
prints the SET:

```bash
cd /Volumes/ANAN/Engineering/wenshu
E=/Volumes/ANAN/.hermes/evidence/wenshu
python3 Tools/wenshu-devtool/swift_test_compare.py \
  $E/2026-11-24-fullsuite-base-26ef07472d.log \
  $E/2026-11-24-fullsuite-tip-8f607d8ff9.log \
  --base-label '26ef07472d (the scope base, same directory family)' \
  --tip-label '8f607d8ff9 (the merged tree)' || true
```

The comparator exits 1 when the tip carries a failure the base does not, which is what
this pair does; the `|| true` keeps the block's own exit code at 0 so the reader can see
the printed difference. The two logs are the runs' own output, kept outside the repo's
scratch (which is pruned) and identifiable by their sha256.

The base run sat in a throwaway detached worktree of `26ef07472d` in the same directory
family as the tip run, so the comparison is not a path artifact. The base's set is 10
failure sites; the merged tree's set is those same 10 plus one, and the one is a
load-sensitive assertion that is green when its suite runs alone at both trees
(`swift test --filter EditorPersistenceTests` → `11 tests in 1 suite passed` at each).
No file of this scope's twenty is in either set.

## 7. The change that was NOT kept

The card `book-scope-param-2026-11-24` proposed threading `folderName` down to
`PreviewPaneBookDocuments` because `PreviewPane.swift:400`'s `case let .bookScope(bookId,
folderName: folderName)` binding is unused at that site. Two facts, both measured:

- the binding is not dead where it is written — `PreviewPane.swift:401` passes it to
  `PreviewPaneScopeViews.bookScopeView(bookId:folderName:)`, whose body reads it at
  `PreviewPaneScopeViews.swift:146` (the title key), `:167` (the comparison) and `:178-179`
  (the scope's folder); and `PreviewPane.swift:404` calls
  `bookDocuments.loadNow(..., folderName:)` (the argument at `:408`);
- the tool that reported it is `swiftformat`'s `unusedArguments` rule, and that rule does not
  see argument uses inside a `@ViewBuilder` result-builder branch.

The edit was reverted before any commit (`git status --porcelain` empty, build green). The durable lesson is in the `comment-lineage-comment-rewrite` skill as Pitfall 4: an
`unusedArguments` report is a false-positive source on this tree, because the rule cannot see an
argument used inside a `@ViewBuilder` result-builder branch. The rule to apply before deleting a
binding: find its uses with a repo-wide grep over every call site, not with the linter's verdict.

## 8. The pre-rebase line that was not landed

The pre-rebase line's tip is the sha `ff2ea717b6` (an older amend state; its branch
`wt/skeleton-loading-2026-11-23` has since been replayed onto the landed line and now names
`6a8941d389`, which IS in main's ancestry). `ff2ea717b6` itself is NOT in main's ancestry,
and it is parked under `refs/keep/skeleton-ff2ea717b6` so the cards that cite it resolve.

Measured against its merge-base with main (`26ef07472d`) it carries eighteen files, 1657
added and 191 removed lines; measured against `1a2327f795` = = the tree this record's header
names = = it reads 99 files, 7414 insertions and 1710 deletions, and its
`LoadingPlaceholder.swift` is 268 lines against that tree's 424 = = the pre-rebase ancestor
line, plus a revert of the landed soft-cites sweep. Do not land it:

```bash
cd /Volumes/ANAN/Engineering/wenshu
git diff --shortstat ff2ea717b6 1a2327f795   # the direction of the difference, read not assumed
```

**⇒ ⇒ ⇒ AND EVERY NUMBER IN THIS RECORD IS KEYED TO A NAMED SHA, NEVER TO A
MOVING TIP.** A number measured against `main` is broken by the very commit that
carries the record: this record's own added lines move the difference it reports, so
every re-measurement of the same sentence reads a different figure. ⇒ ⇒ A
published figure therefore names the tree it was measured on, and a reader who wants a
different tree measures it again on that tree.

## 9. The tests this scope owns

| suite | what it holds | LOC at `37a8f04bf2` |
| --- | --- | --- |
| `Tests/WenshuAppTests/UI/DesignSystem/LoadingPlaceholderTests.swift` | the shape census (declared set against the set asked for at the call sites), the reserved-space invariant, Reduce Motion, the chat exclusion | 417 |
| `Tests/WenshuAppTests/Editor/View/BookDocumentTests.swift` | the one read per book, the generation counter dropping a stale write, the card showing the same content while waiting | 344 |

The eight suites this scope's two belong to — `LoadingPlaceholderTests`,
`BookDocumentTests`, `AppleSidebarMVVMSplitTests`, `InspectorCardTests`,
`InspectorRightColumnPushTests`, `InspectorCardLazinessTests`, `KanbanViewTests`,
`EmptyStateViewTests` — hold 87 tests in 8 suites, and the command that prints that number
is in section 6. The first two re-run green in the scope's own checkout at this closeout.

## 10. Independent verdicts

| card | tier | the sha it cleared | its verdict |
| --- | --- | --- | --- |
| `t_498766b6` | T3 | `a4cfc41a62` (the read moved off the main thread) | approved |
| `t_e353de04` | T3 | `d34741da44` | changes requested |
| `t_5eabcfdc` | T3 | `1c13915934` | changes requested |
| `t_db1d3d81` | T3 | `988c12eb5d` | approved |
| `t_ecbf4bc8` | T3 | `6a8941d389` (the first audit's three findings) | approved |
| `t_77e63bf6` | T3 | `37a8f04bf2` (the mechanism's three loose ends) | approved |
| `t_6765a05c` | T3 | `06cbbf1a4d6c` (the same change before its rebase) | approved |
| `t_e984b7ae` | T2 | this record | changes requested, and this record is its rework |

## 11. OPEN ITEMS

1. The look check (gate 7.7) — the isolated copy of this tree is
   `/Volumes/ANAN/Engineering/wenshu/build/MergedLook1124.app`, bundle id
   `com.wenshu.app.look1124`, executable `MergedLook1124`, ad-hoc signed, built from
   `8f607d8ff9` out of the merged checkout's `.build/debug`. Its data store is its own copy
   (`build/wenshu-look.ws`), reached through a bookmark written into its own preference
   domain, so it cannot collide with the shipped app's instance. It is launched with a plain
   `open` on the absolute path, and the instance is alive and answering:

```bash
open /Volumes/ANAN/Engineering/wenshu/build/MergedLook1124.app
pgrep -fl MergedLook1124
osascript -e 'tell application id "com.wenshu.app.look1124" to get name'
```

   At this closeout's last reading the instance answered `MergedLook1124` and its windows
   were a 1400x980 window and one 78x21 window (measured with `CGWindowListCopyWindowInfo`;
   the `osascript` route above is the reader's own liveness check, because the accessibility
   route to a window count is refused on this machine). The byte proof that the bundle
   carries this scope's code is the
   symbol table of its executable against the base tree's binary, with a positive control in
   both so a zero cannot mean "the tool selected nothing":

```bash
NEW=/Volumes/ANAN/Engineering/wenshu/build/MergedLook1124.app/Contents/MacOS/MergedLook1124
OLD=/Volumes/ANAN/.hermes/evidence/wenshu/2026-11-24-base-26ef07472d-WenshuApp.bin
nm -a "$NEW" | grep -ci LoadingPlaceholder   # the scope's own symbol
nm -a "$OLD" | grep -ci LoadingPlaceholder   # the same command on the base tree
nm -a "$NEW" | grep -ci PreviewPane           # the positive control, nonzero in both
nm -a "$OLD" | grep -ci PreviewPane
```

   The scope's symbol reads 1366 in the bundle and 0 in the base tree's binary; the control
   reads 1532 against 1290, so the tool reads symbols in both. The acceptance is the human
   look at the tab switch and at each zone's waiting state, not the numbers in section 2.
2. The board's open columns at this closeout's last sweep (2026-11-24, before this
   record's own review card was opened) held ONE card, and it is this scope's own review
   card (`t_d4924260`, running). Everything else on the board was `done` (977) or
   `archived` (140). These counts move as other lanes land; read the live board with the
   board's own query, not from this sentence:

   ```bash
   sqlite3 -readonly /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db \
     "select status, count(*) from tasks where status not in ('done','archived') group by status;"
   ```
3. The `design-sweep` hit named in section 6 belongs to the chat lane's file and is open
   there.
4. Worktree registrations are live on disk, and this session's own two are removed by this
   closeout (the base-control rehearsal and the reverted parameter rehearsal, both with no
   commit of their own); the rest belong to other lanes and other sessions, and are not this
   session's to delete. Two of those lanes still carry commits that have not landed as of
   this closeout's sweep (`wt/citation-guard-widen-2026-11-24` with 17 commits and
   `wt/apple-api-2026-11-22` with 7, each measured with
   `git rev-list --count main..<branch>`, = = a count that moves as those lanes land) —
   recorded here so the next reader knows they exist, not claimed as this scope's work.
5. The p95 of the tab switch's frame was NOT re-measured at this closeout, on any tree.
   Section 2's after-row is the probe's walks and bytes, = = which is what the fix claims,
   and the probe's timings are not published here because they move with the machine and
   the load. A fresh timing run on the scope's own tree is still open.

## 12. What this record does not claim

It does not claim the whole board is empty, that the other sessions' lanes landed, or that the
chat tab switch is now measurably hitch-free — the load moved out of the frame and the
counters prove the walk count and the bytes, nothing more. It names the commits that are not
this scope's, and it publishes no count of itself. And it publishes every figure against a
NAMED tree: a figure measured against a moving `main` is broken by the very commit that
carries this record, so the tree is named beside the number and the reader measures it again
on that tree.
