# Session close — the editor's tab strip has no double-click close (2026-11-19)

## 1. What was asked

The owner's ruling, given while the first round of this scope was already in
review: a double-click close on the editor's tab strip is not wanted at all.
Not "make it agree with the other close paths" — delete the path. The strip
closes a tab from the segment's own X (the selected tab) and from the
right-click menu (the tab the pointer names); a third path only duplicated
those two.

This supersedes the wording of the earlier scope card `t_8d594cc2`, which
listed the double-click as part of the required behaviour.

## 2. What the tree shipped before

`LabelSegmentedControl` (the shared AppKit control the editor's strip hosts)
attached an `NSClickGestureRecognizer` with `numberOfClicksRequired = 2` and a
gesture delegate whose only job was to refuse the gesture when the pointer was
over the X. `EditorTabStrip` wired the resulting `onDoubleClickSegment`
callback to its own close. Nothing else in `Sources` consumed that callback,
and the count is printed per pattern because a bare "nothing else" is not
re-derivable: on the pre-change tree `31b5c3929a`,
`git grep -c onDoubleClickSegment 31b5c3929a -- Sources` = 8 hits in 2 files
(`LabelSegmentedControl.swift` 7, `EditorTabStrip.swift` 1), and
`NSClickGestureRecognizer` = 7 hits in `LabelSegmentedControl.swift` alone.

## 3. Why it came back once (the rework's real subject)

Round one was reviewed at `ccf4443fa522ae89d53476e7daf25a6f652a5757` and came
back `changes_requested` (card `t_014a4e3f`, run 4576). The reviewer's own
words: "the CODE is right and I proved it, not read it". What failed was the
record, not the change:

- **R1** — `EditorView.swift:102-103` still described the strip as keeping
  "its own close path (= a double click on a segment)". One production comment
  still taught the deleted behaviour.
- **R2** — the card published a gate number the machine would not reprint. The
  four-suite filter was published as `53 tests in 4 suites passed`; on both the
  tip and the base it reads `53 tests in 4 suites failed with 12 issues`. The
  published run had been real (measured two hours earlier on the same commit) —
  the suite is load-sensitive, so the published gate was a coin flip.
- **R3** — the whole-suite claim "6 failures in the base and 6 in the tip, the
  same six" counted `recorded an issue` LINES, not distinct sites.

All three closed in `c58db7b06ada568008dac6abcfb34ee017f71052`, which round two
approved (card `t_f5f901e0`, run 4584 = **1309 s = 21.8 min**, claimed 14:29:32
and completed 14:51:21 local). An earlier draft of this record said "approved in
nine minutes"; the board's `task_runs` row does not print that, and it is off by
2.4x. It is corrected here rather than left, because publishing a number from
memory instead of from the machine is the same defect class as R2 below.

## 4. What the change does

| File | Change |
| --- | --- |
| `Sources/WenshuApp/Shared/UI/LabelSegmentedControl.swift` | the `onDoubleClickSegment` callback, the `NSClickGestureRecognizer`, and the gesture delegate are removed; `Coordinator` is a plain `NSObject` again |
| `Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` | the callback that closed the tab is removed |
| `Sources/WenshuApp/Features/Editor/View/EditorView.swift` | the docblock names the two paths that remain instead of the deleted one |
| `Tests/WenshuAppTests/Shared/UI/PaneTabStripCloseTests.swift` | the delegate test is replaced by one absence guard holding five `#expect` (lines 916, 925, 926, 927, 935), two of which the mutation bites |
| `Tests/WenshuAppTests/Workspace/EditorViewIconMigrationTests.swift` | a stale comment corrected |
| `docs/agents/nfi.md` | the registry's LOC value for the test file |

The guard asserts an ABSENCE, because the requirement is an absence: the
control the REAL strip hosts (`hostedStrip(tabCount: 3, columnWidth: 240)`, so
the production `makeNSView` path, not a hand-made control) carries no gesture
recognizer, and neither production file names the deleted path any more.

## 5. Measured before and after

Every number names the tree it was printed on. Units are stated because a bare
count died on re-measurement once already (R3).

- `LabelSegmentedControl.swift`: 670 lines before, **590 lines** after
  (`wc -l`, the file ends with a newline).
- Owning suite: `swift test --filter 'PaneTabStripCloseTests'` = **29 tests in
  1 suite passed** (4.510 s on `c58db7b06a`; 2.031 s on the merged tree
  `124ce32757`; 1.833 s inside `pre_review_gate.py`).
- Guard bites: one line put back into `makeNSView`
  (`control.addGestureRecognizer(NSClickGestureRecognizer())`) = **29 tests in
  1 suite failed with 2 issues** at `PaneTabStripCloseTests.swift:916` and
  `:925`. Measured by the author before the card, and re-measured independently
  by both review runs.
- Deletion is complete: `grep -rn "onDoubleClickSegment\|NSClickGestureRecognizer"
  Sources` = 0 hits; in `Tests` the only hits are the guard's own assertions.
- No close-path sentence survives: `grep -rniE "double.?click" Sources |
  grep -iE "clos"` plus the CJK verb for "close" (kept out of this doc, which
  must stay zero-CJK) = 1 hit, and that hit is the word `closure` in
  `PreviewPaneCard.swift:42`'s `onDoubleClick closure` (= the card's OPEN path).
  The broader tab/strip grep returns 3 hits, all of them double-click to OPEN a
  tab from a pane (`AssetsPane.swift:211`, `CardOpenOps.swift:353`,
  `PreviewPaneCard+Body.swift:265`) — a different, still-live feature.

## 6. Gates on the MERGED tree

Run after the rebase onto `b0ba0e0e2b`, in the shared checkout at
`124ce3275727955162a896fa4d90657c334c3375` (the reviewed sha `c58db7b06a` and
the landed sha differ only by that clean rebase, which resolved nothing, so the
verdict still covers the change):

Every base below is a SHA, not a moving ref: `main` has since been pushed two
sibling commits past this scope, so `--base main~1` and the pruned branch name
`wt/dblclick-2026-11-19` no longer measure this change (`nfi-loc-check.py --base
main~1` now prints "the change adds no registry row; nothing to check", and
`merge-preflight.sh wt/dblclick-2026-11-19` prints "no such branch"). With the
sha-named bases every published string reprints.

- `review_gate.py --card t_f5f901e0` = `approved` rc 0 (this one reprints by
  card id, so it survives the branch's deletion; the preflight run that printed
  `CLEAN` before the fast-forward does not).
- At `--base b0ba0e0e2b` (= the code commit's own parent):
  `ci_change_gate.py --check formatting` = ok, `5 changed Swift file(s)`;
  `--check pollution` = ok; `--check markdown-newline` = ok,
  `1 changed .md file(s)`.
- `pre_review_gate.py --base b0ba0e0e2b --card <the card body>` = every gate
  measured on this tree and green (build exit 0, the filter exit 0 with `29
  tests in 1 suite passed`, CJK audit exit 0 over 58 added lines, `verify-dead`
  exit 0 with 0 dead declarations, the registry's round-trip exit 0).
- At `--base 1699b71bc5~1` (= this record's own commit): `nfi-loc-check.py` =
  `every rewritten file's row carries its own count (1 row(s) checked)`;
  `ci_change_gate.py --check markdown-newline` = `2 changed .md file(s)
  checked`; `nfi-split.py --check` = `PASS`; `python3
  Scripts/merge-nfi-registry.py 1699b71bc5~1 docs/agents/nfi.md
  docs/agents/nfi.md` = rc 0 (a merge driver, so `python3` and three paths).
- Re-run on the tip `main` had moved to when this record closed (`1fbeb0cf96`,
  two sibling sidebar commits later), in the shared checkout: `swift build
  --build-tests` rc 0; `swift test --filter 'PaneTabStripCloseTests'` = `Test
  run with 29 tests in 1 suite passed after 5.597 seconds`; `verify-dead.py`
  rc 0; `nfi-split.py --check` PASS; `nfi-loc-check.py --base 1699b71bc5~1`
  rc 0; the registry round-trip rc 0; `ci_change_gate.py --base 124ce32757~1
  --check formatting` rc 0 and `--check markdown-newline` rc 0. The change
  still holds on a tree that moved under it.
- `python3 Tools/wenshu-devtool/pollution_watchdog.py <repo>` = **rc 1, on this
  checkout and on every clean one**, and it is not this scope's account: the
  watchdog scans all tracked text files (1626 under its own
  `.md/.swift/.txt/.json/.yaml/.yml` filter) as well as the changed ones, and
  the repo's rule file `.swiftlint.yml:62` carries the forbidden-vocab list
  literally inside its `regex:` line, so the detector reports its own
  definition. Present since `780d7cb5f4` (2026-10-26), unchanged at
  `124ce32757` and at `1fbeb0cf96`. The gate that blocks landing is
  `ci_change_gate.py --check pollution` (added lines only) = rc 0. Listed in
  §11 item 8. One trap worth keeping: piped, its status is invisible
  (`pollution_watchdog.py . | tail -3; echo $?` printed 0 where the direct
  `> log; echo $?` printed 1).

The CJK audit is comment-shaped AND Swift-shaped: `pre_review_gate.py:356`
diffs `{base} HEAD -- '*.swift'`, so a markdown-only commit gives it nothing to
read and it still exits 0 (`no new CJK comment line (0 added line(s) scanned)`
was printed for this doc's commit). A tracked .md's zero-CJK rule is therefore
proved by the direct Han-range scan of the file itself, which this record's
commit carries: 0 occurrences in the range U+4E00-U+9FFF, in the file and in
its added lines, over `wc -l` = 395 lines. That gap is a gate defect in
its own right (= nothing in CI enforces rule 1.1 on markdown, and widening the
check to all tracked text files WITHOUT dropping the `'*.swift'` pathspec would
close nothing) and is listed in §11 item 7.

One correction to what §11 item 7 claimed: the Han characters a draft of this
record carried were a WORKING-COPY state and never a commit. `git show` on all
three of this doc's commits (`2041ea23f`, `e878310927`, `1699b71bc5`) prints 14
Han each — 2 in the commit header's author name and 12 in a pre-existing
`nfi.md` context row — so no object in the store carries the "2 versus 0"
discriminator that draft asserted. The file-level and added-line scans above
are the ones that hold.

## 7. Attribution of the tree's red — an A/B, not a whole-suite run

The tree carries a family of timing-dependent suites. One filter over the seven
of them:

```
swift test --filter 'EditorTabStripOverflowTests|EditorTabTitleTests|PaneTabStripTitleTests|EditorPersistenceTests|AsyncDelegationRegistryTests|SidebarTreeReloadTests|ChatViewHistoryShortcutTests'
```

printed, back to back on `b0ba0e0e2b` (before the merge) and on `124ce32757`
(after it), the same counts — `Test run with 59 tests in 7 suites failed after
23.477 seconds with 17 issues` on the base and the same line `after 26.084
seconds` on the tip (the elapsed field is machine load, not evidence; the counts
and the sites are) — at the identical ten sites with the identical
multiplicities, 17 `recorded an issue` lines in each log:
`EditorTabStripOverflowTests:532` x5, `:582` x4, `:403`/`:435`/`:499` x1 each,
`EditorTabTitleTests:60`, `PaneTabStripTitleTests:476`,
`SidebarTreeReloadTests:189`, `ChatViewHistoryShortcutTests:35`,
`AsyncDelegationRegistryTests:104`. **This change moved zero test outcomes.**

Two whole-suite runs (`swift test --skip CSSearchableIndexSearchTests`) on the
same trees printed 19 issue lines at 12 sites and 7 issue lines at 4 sites, and
NEITHER printed a summary for the bundle that failed — a bundle that aborts
mid-run (a `swiftpm-testing-helper` signal 11 was recorded in an earlier
review's run) emits its issues and never its summary line. A whole-suite run on
this machine is therefore evidence of nothing about attribution; the same-filter
A/B minutes apart is.

## 8. The shipped binary carries it, and the owner's look is PENDING

The preview bundle is the one the owner looks at for a UI-touching ticket
(AGENTS.md 7.7). The recipe was never written down, which is why this section
records it end to end:

1. `bash Scripts/build-app.sh` from the merged checkout = `BUILD_RC=0`,
   `build/Wenshu.app/Contents/MacOS/WenshuApp`, 15:40 local.
2. `cp -R build/Wenshu.app build/MergedCheck.app`; rename the executable to
   `MergedCheck`; `plutil -replace CFBundleExecutable -string MergedCheck`,
   `CFBundleIdentifier -string com.wenshu.app.look`,
   `CFBundleName -string MergedCheck`.
3. `codesign --force --deep --sign - build/MergedCheck.app` = adhoc,
   `Identifier=com.wenshu.app.look`.
4. Its data copy stays `build/wenshu-look.ws`. The independent bundle id, the
   independent executable and the independent data copy are required: a second
   instance of `com.wenshu.app` restores the same saved window geometry and
   AppKit's update-constraints guard aborts BOTH processes.

Byte-level proof that this binary is the changed tree, with the pre-change
binary kept as the positive control so a zero cannot mean "the tool selects
nothing". The counting command is printed, because the control column only
discriminates under the case-INSENSITIVE reading:

```
NEW=/Volumes/ANAN/Engineering/wenshu/build/MergedCheck.app/Contents/MacOS/MergedCheck
OLD=/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/MergedCheck-1118-control.bin
nm -a "$NEW" | grep -ci onDoubleClickSegment     # then handleDoubleClick, closeSegment
nm -a "$OLD" | grep -ci onDoubleClickSegment     # same three
nm -a "$NEW" | grep -c  closeSegment             # the case-SENSITIVE control
```

| binary | `onDoubleClickSegment` | `handleDoubleClick` | control `closeSegment`, `grep -ci` | same control, `grep -c` |
| --- | --- | --- | --- | --- |
| `OLD` = the preview built 2026-11-18 (tree HAD the path) | 20 | 4 | 46 | 30 |
| `NEW` = the preview built from `124ce32757` | **0** | **0** | **62** | 30 |

Read case-sensitively the control column is 30 in BOTH binaries and discriminates
nothing (`-ci` reads 62 = 30 `closeSegment` + 32 `CloseSegment`, and 46 = 30 +
16). The first two columns reprint under either reading.

- Which build: `/Volumes/ANAN/Engineering/wenshu/build/MergedCheck.app`, from
  `124ce32757`, adhoc-signed. The path is ABSOLUTE on purpose: the bundle exists
  only in the shared checkout, and a relative `build/MergedCheck.app` read from
  any worktree resolves to nothing — `nm` prints no lines and all three counts
  read 0, which is a false proof of absence, the one thing the control column
  exists to prevent.
- Owner's verdict on the running build: **NOT YET GIVEN**. The last look the
  owner took was at the build that still had the double-click.
- App left running: **no**. No instance of `com.wenshu.app.look` was alive when
  this bundle was rebuilt; the pre-change binary is preserved at
  `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/MergedCheck-1118-control.bin`
  (= a scratch file, so it can be pruned; it is re-creatable by building
  `31b5c3929a` with the same recipe).
- The one command that completes it: `open
  /Volumes/ANAN/Engineering/wenshu/build/MergedCheck.app`, then close a tab
  twice as fast as possible — nothing should close on the second click, while
  the X and the right-click menu still close the tab they name.
- A sibling session's instance (`pid 83611`, from
  `.worktrees/wt-cover-menu-2026-11-19/build/Wenshu.app`) was running
  throughout; it is not this session's to touch.

## 9. What this scope cost on the board

The scope is a comment-and-deletion change, and it still cost 11 reviewer runs.
Both totals are printed with the query that produces them, because "five runs"
and "about two hours" are true only under one definition and this record's first
draft used that definition without naming it:

```
sqlite3 <board>/kanban.db "SELECT id,outcome,(ended_at-started_at)
  FROM task_runs WHERE task_id IN ('t_014a4e3f','t_f5f901e0') ORDER BY id"
```

- ALL of this scope's runs: **11 runs, 14223 s = 3.95 h** (10 on `t_014a4e3f`,
  1 on `t_f5f901e0`).
- The runs that actually got a reviewer process (the other six died inside a
  minute, on admission): 4523 + 4528 + 4569 + 4576 + 4584 = **8124 s = 2.26 h**.

The ledger, one row per run, as the board prints it:

| run | card | outcome | minutes |
| --- | --- | --- | --- |
| 4523 | `t_014a4e3f` | `crashed` — "managed worker lost: EOFError", the machine rebooted | 42.5 |
| 4528 | `t_014a4e3f` | `crashed` — the same message | 33.0 |
| 4534 | `t_014a4e3f` | `rate_limited`, exit 75 | 10.5 |
| 4538 | `t_014a4e3f` | `rate_limited`, exit 75 — 5227 s, killed inside a review that needed more | 87.1 |
| 4552 / 4556 / 4560 / 4564 | `t_014a4e3f` | `rate_limited`, exit 75 | 1.0 each |
| 4569 | `t_014a4e3f` | `crashed` — the terminal provider death: `gave_up` at 13:23:19 carrying `{failures: 3, effective_limit: 5, limit_source: task}` and "pid 26764 exited on a terminal provider error (exit 78)", the worker's last output a 429 for the account's token-plan cap (code 2067), whose own text is Chinese and is therefore not reproduced here | 18.3 |
| 4576 | `t_014a4e3f` | `completed` — round one's `changes_requested`, 13:45:38 to 14:05:18 | 19.7 |
| 4584 | `t_f5f901e0` | `completed` — round two's `approved`, 14:29:32 to 14:51:21, 1309 s | 21.8 |

- A `rate_limited` outcome does not count toward the failure budget, so the card
  looped; the three consecutive provider deaths blocked it, and the review lane
  unblocked it at 13:45:35 after re-probing the provider.
- The card was created at the tier's 90-minute floor (runs 4523-4538 carry
  `max_runtime_seconds` 5400), which is why run 4538 died at 87.1 minutes. The
  fix for the next one: a review card gets `--max-runtime 10800` at creation,
  because a requeue is a fresh session that re-reads the tree from zero.
  `t_f5f901e0` was created with 10800.
- Both cards were first subscribed with `--platform desktop`, which the gateway
  does not serve (= a dead row). They were re-subscribed with `--platform local`
  and the dead rows deleted.
- An earlier draft of this section mis-cited four things, all corrected above
  against `task_runs`: run 4528 as `rate_limited` (it `crashed`); runs
  4540/4541, which belong to sibling cards `t_7c1ab8af` and `t_db37c4cb` and not
  to this scope; run 4538 as the exit-78 death (that is 4569, and 4538 is
  `rate_limited` with exit 75); and "61 API calls deep", a number no board row
  prints and no log in this session's evidence names.

## 10. Scope's commits, and the ones that are not

- `31b5c3929a` — the previous scope's landed work (the X, the conditional
  collapse, the right-click menu). Not this ticket's change; it is this
  ticket's base.
- `ccf4443fa5` → `c58db7b06a` → landed `124ce32757` — **this scope**: one
  ticket, one commit, rebased clean onto `b0ba0e0e2b`.
- `b0ba0e0e2b` — a sibling session's sidebar work (card `t_803f54f2`). It was
  already on local `main`; pushing it to the remotes with this scope's commit
  was maintenance of the shared server state, not authorship.
- `1699b71bc5` — this record's own commit, with its registry row in the same
  commit, and the correction commit that follows it (whose sha this text cannot
  contain, because writing it would change it).

Read the current tip with `git rev-parse main`; a doc cannot name the tip its own
commit creates. Server truth is read per remote AND by ancestry, not by tip,
because siblings keep moving the tip: at the time of writing `git ls-remote
origin refs/heads/main` and `git ls-remote old-origin refs/heads/main` both read
`1fbeb0cf96b66698cef7e878c4493f312b12310d` (= two sibling sidebar commits past
this scope), and `git merge-base --is-ancestor <sha> <remote>/main` returns rc 0
for BOTH `124ce32757` and `1699b71bc5` against BOTH remotes.

## 11. Open items left behind

1. **The owner's look at the double-click-free build is PENDING** (§8). Nothing
   else blocks it; the bundle is built and proved.
2. **The timing-dependent suite family** (§7): ten sites that flip with machine
   load, red on the tree itself, and NOT filed as a card, because the board
   spawns exactly one profile (`kanban.dispatch_profiles: [wenshu-review]`) so a
   diagnostic card assigned to the developer lands in `skipped_nonspawnable`. It
   needs either an owner order or in-session work. Until then no card should use
   those suites as a gate.
3. **The landing gate's branch-name claim** (`Scripts/merge-preflight.sh`): when
   the card the BRANCH NAME claims answers `contract_error`, the script read
   `UNREVIEWED` instead of falling through to the sha carrying the approving
   verdict. This item is now a record of movement, not an open question. Another
   session under the same developer profile claimed `t_a43d3e2f` (the dispatcher
   had logged `skipped_nonspawnable` for it an hour earlier, because only
   `wenshu-review` is dispatchable), ruled **option 3 = fix the gate, not the
   branch name**, and implemented it at `f00e9e1168` on
   `project/t_a43d3e2f-gate-fallthrough` (pushed to origin, not landed). Its
   review card `t_4861a2fb` returned `changes_requested`: the claim-versus-sha
   check was added only on the APPROVING path (`merge-preflight.sh:168-185`), so
   the refusal path (`:186-222`, two-literal whitelist at `:214`) still lets a
   claim whose verdict belongs to a DIFFERENT commit veto the branch — measured
   live on the same tip `31b5c3929a`, where two branches differ only in NAME and
   read rc 3 versus rc 0. The rework is that session's, not this scope's, and
   this record does not touch that branch.
4. **The 600-line cap** on the strip's two files stays sibling scope (AGENTS.md
   6.6 is DEFERRED per ADR-0025).
5. **`scratch/lib/verdict.md`** is an untracked file in the shared checkout from
   another session's card. Left in place; it is not this session's residue.
6. **The board still holds ~312 `desktop`-platform subscription rows** from
   before the mechanism was measured. Not this session's to rewrite.
7. **The zero-CJK rule (AGENTS.md 1.1) has no gate on markdown.** The audit
   diffs `{base} HEAD -- '*.swift'` (`pre_review_gate.py:356`), so a
   markdown-only commit passes it with exit 0 whatever the file contains (36
   tracked files under `docs/` already carry Han that no CI check reads). The
   fix is a check over the added lines of every tracked text file, AND it must
   drop the `'*.swift'` pathspec — widening the wording while keeping the
   pathspec closes nothing. This record caught itself doing exactly that: a
   draft of §5 quoted a Chinese search term inside a grep example. That was a
   working-copy state, never a commit (§6 prints the measurement that shows
   why), and the term belongs in the closed card's command, not in an artifact
   the rule covers.
8. **`pollution_watchdog.py` is red on every clean checkout** (§6): it scans all
   tracked text files and so reports the forbidden-vocab list written inside
   `.swiftlint.yml:62`, which is its own rule definition, and exits 1. No
   landing gate consumes it today (`ci_change_gate.py --check pollution` does,
   and reads rc 0), so nothing is blocked — but it cannot become a gate until it
   excludes the file that defines the vocabulary. It pre-dates this scope by 24
   days (`780d7cb5f4`, 2026-10-26).

## 12. This record's own rounds

- Round 1 (card `t_a4a6794f`, run 4594, 47 min): all six acceptance claims were
  re-derived by the reviewer with its own commands and PASSED — including claim
  4's A/B, re-run sequentially in two detached worktrees (`b0ba0e0e2b` and
  `1699b71bc5`, both `59 tests in 7 suites failed ... with 17 issues` at the
  same ten sites with the same multiplicities), and claim 5's byte counts. The
  verdict was still `changes_requested`, for five doc-only findings, every one
  of them a number the machine does not reprint — this record's own R2 class:
  §8's control column needed its counting command and its case-sensitivity
  stated (F1); §8's bundle path had to be absolute, because the bundle exists
  only in the shared checkout and a relative path reads 0/0/0 from a worktree
  (F2); §9's run ledger mis-cited four runs and carried one number no board row
  prints (F3); "approved in nine minutes" was 1309 s = 21.8 min, stated twice
  (F4); and §6/§10 named a moving ref and a pruned branch, so the published
  commands no longer measured this change (F5). This commit is the fix.
  `1699b71bc5` was already pushed, so the fix is a NEW commit and the pushed
  sha was not amended.
- The reviewer's evidence lives in that profile's scratch, not this session's:
  `/Volumes/ANAN/.hermes/profiles/wenshu-review/cache/scratch/ab-2026-11-19/`.
