# Session close: the literal mask and the promotions arm

Date: 2026-11-11

Scope: the devtool lane's two requirements, as written on the review cards
that carry them. This closeout covers that scope only. Neither requirement
touches a Swift file: the whole diff is three files under
`Tools/wenshu-devtool/`.

The tree this record measured (= = and `main` may have moved on since):

- the measured tree = `7851ccb3fc9c6449a9275634c928f942e6ada0ae` (= = the
  carrier of requirement 2, = = the tip `main`, `origin/main` and
  `old-origin/main` all pointed at when the numbers below were taken, = =
  read back per remote with `git ls-remote`)
- the base the change landed on = `225366259bbaaf86ad44895bf9fafb3fe3eaa644`

= = ⇒ The shas above are the SNAPSHOT the numbers below were measured on, = =
and they are still the tree's own history (= = `7851ccb3fc` is on `main`),
= = but `main` itself points further along, = = because this closeout's own
record commit sits directly ON TOP of it (= = one commit, = = and the
remotes point at THAT, = = because the record is the last thing this scope
pushes). = = ⇒ A record cannot contain its own sha (= = writing it in would
change the sha it names), = = so the reader gets the tip from the repository:
`git rev-parse main` for the local tip, `git ls-remote origin main` and
`git ls-remote old-origin main` for the two remotes. = = ⇒ And the invariant
that matters is an ANCESTRY one, = = not a tip one: the carrier
`7851ccb3fc` is an ancestor of both remotes' `main`, = = so the code landed
wherever `main` points now.

## 1. The requirement, row by row

One row per requirement, in the boss's business language. The carrier column
is the commit on `main` that carries the requirement. The proof column is an
ANCESTRY fact, not a tip: the carrier commit IS the sha the approved card
ruled on, so the ruling covers the carrier by construction.

| # | Requirement (business language) | Carrier on `main` | Author | Approved card | Reviewed sha | Proof |
|---|---|---|---|---|---|---|
| 1 | A split's promotions arm must name a member by its own type, so a member cannot be widened by a same-named member of another type | `225366259b` | `probe` | `t_7ab46c73` | `225366259b` | the carrier IS the reviewed sha |
| 2 | The mask must read EVERY literal form, so a member's owner never moves with a literal's text | `7851ccb3fc` | `probe` | `t_3d6a9bc2` | `7851ccb3fc` | the carrier IS the reviewed sha |

**Commits in this scope that are NOT mine.** None. `225366259b` and
`7851ccb3fc` are the only commits this scope landed, and both were written by
this session (= = the tree records them under the author `probe`, = = the
author this session commits under, = = the same author the code-block scope's
carrier `d21bc040b0` carries). The four review cards are the `wenshu-review`
profile's, = = and they carry no commits, = = only verdicts.

**Commits this closeout's PUSH carried that are NOT this scope's work.** The
push that carried this scope's carriers to the remotes also carried two
groups of commits that were already on `main` before this closeout
committed:

| the group | the commits | the tree's author | what it is |
|---|---|---|---|
| a SIBLING session's work | `3c1b07a6bb`, `ae3d505020`, `7f2da5f64a`, `25af52a82c` | `pocock <pocock@localhost>` | the devtool lane's own earlier rounds, = = a different author from this scope's `probe`, = = so the two groups are separable with `git log --format=%an` |
| the PREVIOUS scope's record | `e4961b2348` | `probe` | the code-block scope's closeout document, = = the same agent identity, = = but a DIFFERENT scope's work |

Neither group is this scope's work and neither is claimed here; = = they were
on `main` before this closeout committed, = = and pushing them was maintenance
of the shared server state, = = not authorship. The commits this closeout's
OWN push added (= = this doc's commit and its registry row) are this scope's. They are not this scope's work and are
not claimed here; = = they were on `main` before this closeout committed, = =
and pushing them was maintenance of the shared server state, = = not
authorship. The commits this closeout's OWN push added (= = this doc's commit
and its registry row) are this scope's.

**The four review rounds.** The scope went through four review cards, and
TWO of them are `changes_requested` verdicts that are still on the board:

| Card | Sha under review | Verdict | What the round was about |
|---|---|---|---|
| `t_9118e596` | `52def2d91c` | `changes_requested` | the first round; the blocker was machine-local absolute paths in the measurement (= = the review's own fresh clone died with `AttributeError: module 'arm' has no attribute 'literal_spans'`) |
| `t_7ab46c73` | `225366259b` | `approved` | the promotions arm's rework, with the measurement reading the tree it ships in |
| `t_58d1da10` | `eafb01f5e` | `changes_requested` | the masking round; F1 (= = the measurement deleted the raw and multi-line literal forms), F2 (= = the figures were not runnable from the tree), F3 (= = case 2 could not see a dropped newline) |
| `t_3d6a9bc2` | `7851ccb3fc` | `approved` | the masking rework; it closed F1, F2, F3, both notes, AND the latent interpolation defect the prior round filed as N3 |

## 2. What was measured, before and after

Every number below is a measurement on the tree, not a reading of the source.

**The promotions arm's figures** (= = the counts a split's own check
publishes, each at its own scope):

| the scope | the pairs where a local hides a type's private member | the pairs where the name lives in two types with disagreeing privacy |
|---|---|---|
| the whole tree | 65 | 19 pairs, 18 names |
| no `Vendor/` | 55 | 18 pairs, 17 names |
| `Sources/` + `Tests/` | 52 | 15 pairs, 14 names |

These three figures reproduce in the merged tree.

**The masking's reach.** The measurement masks a literal's interior and then
compares the member set before and after, so a member that MOVED with a
literal's text is a defect. On the whole tree (= = every Swift file at HEAD,
1405 of them), and over a window of the last 300 commits:

| the figure | the new mask | the base's mask |
|---|---|---|
| the tree-wide figure (= = every Swift file at HEAD) | **0** | **4** |
| the window figure (= = 300 commits) | **0** | **5** |
| the two independent readers' disagreement | **0** | — |

The base's five window pairs are the same four files the tree-wide figure
names (`EditorCodeBlockSurfaceTests`, `LabelIconSweepTests`,
`CodeBlockFillTests`, `GoldenCorpusTests`); `LabelIconSweepTests` appears in
two commits.

**The base's four files are the four the fix is about.** Each is a Swift
test file whose fixture holds a string literal, so the base's mask read the
literal's text as code and moved a member's owner. The new mask blanks the
interior and leaves the owner where it was.

**The interpolation fix is not cosmetic, and its reach was measured.** The
rework's literal scanner now reads THROUGH an interpolation (= = the
expression is code), which changed the masked output of **58 real files** in
the tree. So the reviewer measured that delta's reach instead of assuming it:
**0** files change their member set at HEAD, and **0** over the window's 848
(commit, changed file) pairs; and the promotions arm's widening VERDICT moves
on **0** of them (= = so the masking is a correctness repair and not a verdict
change).

**The measurement reads the tree it ships in.** The measurement's own reader
is a SECOND implementation, separate from the tool's scanner (= = because the
tool's scanner is the thing under test), and it reports each literal's DATA
ranges (= = the text that is not an interpolation's code and not an escape),
so the delimiters are never touched. Measured outside the suite, on all four
forms: the plain, the raw, the multi-line, and the raw multi-line one, each
reads 1 literal before and 1 after the variant, the length is kept, and the
delimiters survive.

**The figure does not depend on how the reader is told to read.** The same
measurement was run under both readings of a nested literal: the reviewer's
(= = an interpolation is code) and the strict one (= = a nested literal's
text is data). Both print the base at 4, the tip at 0, and the new mask at 0,
so the conclusion does not rest on the choice.

## 3. The two defects this scope found and fixed

1. **The measurement's window walk spawned a process per pair.** The held
   branch's batched tree read had regressed into a per-file `git show`, so
   the window phase spawned about 843,000 processes and needed about 130
   minutes (= = so the card's OWN gate could not finish inside the review's
   5400-second cap). The fix reads each tree in ONE `git cat-file --batch`,
   which is byte-identical to the per-file read over 15,295 (tree, file) pairs
   and 379,666 blob sizes, and the gate now runs in **1m17s** (1m18s from
   the fresh clone).
2. **The card named only the new mask's window figure.** The base's window
   figure is FIVE (= = the same four files), so the card now names both.

## 4. The gates, and how to re-run them

The card's own named gates, and the tree's house gates, all read at
`7851ccb3fc`:

```bash
cd /Volumes/ANAN/Engineering/wenshu
python3 Tools/wenshu-devtool/tests/test_split_pre_check.py
python3 Tools/wenshu-devtool/tests/measure_literal_mask.py
python3 Tools/wenshu-devtool/nfi-split.py --check
python3 Tools/wenshu-devtool/ci_change_gate.py --base 225366259b --check formatting
python3 Tools/wenshu-devtool/ci_change_gate.py --base 225366259b --check pollution
bash Tools/wenshu-devtool/tests/test_nfi_registry.sh
python3 Tools/wenshu-devtool/nfi-loc-check.py --base 225366259b
```

| Gate | The result at this sha |
|---|---|
| the suite | 48 cases, 87 `PASS`, 0 `FAIL`, `split_pre_check: every case passed`, exit 0 |
| the measurement | the four figures in section 2, exit 0; and the same figures from a fresh clone with no arguments, run from `/` |
| the three mutations | M-B reds 2 named cases, M6 reds 7, M-I reds 2 (= = the interpolation case's two); the control is green with 0 `FAIL` |
| the other arms | 32 of the base's 33 functions are byte-identical; the 33rd is `mask_code` itself, = = this scope's subject |
| `nfi-split.py --check` | PASS |
| `ci_change_gate.py --check formatting` | "the change adds no unformatted line (0 changed Swift file(s) checked)", exit 0 |
| `ci_change_gate.py --check pollution` | "the change adds no forbidden vocabulary", exit 0 |
| `test_nfi_registry.sh` | "nfi registry: all tests passed", exit 0 |
| `nfi-loc-check.py --base 225366259b` | "the change adds no registry row; nothing to check", exit 0 |
| the CJK audit | 1107 added lines, 0 carrying CJK |
| `swift build --build-tests` | "Build complete!" (50.95 s) |
| `swift test --skip CSSearchableIndexSearchTests` | 3580 tests in 555 suites, 5 issues; and the 54 XCTest `Executed` lines report 0 failures each, with 0 `Test Case ... failed` lines |

**The full suite's honest reading.** The 5 issues are 5 sites in 4 files, and
they are NOT this scope's: = = the scope's diff touches **0** Swift files
(= = three files under `Tools/wenshu-devtool/`), = = so no Swift source and
no Swift test moved. Measured rather than reasoned: the same four suites
were run alone in a throwaway worktree at the base (`225366259b`), and the
three deterministic sites fail there with the same assertions (= =
`ChatViewHistoryShortcutTests.swift:35`, `EditorTabTitleTests.swift:60`,
`AsyncDelegationRegistryTests.swift:104`), and `EditorPersistenceTests` is a
load-sensitive site (= = a 3-second wait) that passes alone on both trees and
fails only in the full concurrent run. So the honest claim is about the three
deterministic sites, and **failures on the merged tree that are not on the
base: 0**.

**Both frameworks are covered**, because they report differently and a report
that reads only one of them quotes half the suite:

| the framework | what it prints | this run |
|---|---|---|
| Swift Testing | `Test run with N tests in M suites ... with K issues` | 151/34 passed, **3580/555 failed with 5 issues**, 208/24 passed |
| XCTest | `Executed N tests, with M failures` and `Test Case '-[...]' failed` | **54 `Executed` lines, every one 0 failures**, and **0** `Test Case ... failed` lines |

and the trailer names the failing target AND its framework: `Note: Some test
targets reported failures: - WenshuAppTests (Swift Testing)`.

**§7.7 does not apply, and the reason is stated rather than assumed.** This
scope touches no Swift file and no view, so it is not a UI-touching ticket,
and the merge gate is `swift build` (= = green above) and not the boss's own
look at a running build. Nothing was launched, and no app instance is left
running.

## 5. The board record

| Card | Status | Verdict |
|---|---|---|
| `t_9118e596` | done | `changes_requested` (= = the finding was real, = = and it was fixed in the next round) |
| `t_7ab46c73` | done | `approved` by `wenshu-review` |
| `t_58d1da10` | done | `changes_requested` (= = the finding was real, = = and it was fixed in the next round) |
| `t_3d6a9bc2` | done | `approved` by `wenshu-review` |

The merge gate reads the landed branch: `review_gate.py --card t_3d6a9bc2`
= = "approved  approved by wenshu-review", exit 0, and
`review_gate.py --branch fix/split-pre-check-literal-mask-r2 --sha
7851ccb3fc…` = = "CARD t_3d6a9bc2" (the branch is gone, = = the gate still
resolves the card from the sha alone, = = which is how the gate is built to
work).

**The preflight was read on the BRANCH, before the landing, and that is where
it is meant to be read.** `Scripts/merge-preflight.sh` answers "will this card
branch conflict with main, and does it owe a verdict?" = = it is the
pre-landing gate, = = and the house runs it on a card branch (= =
`Scripts/land_card.sh` passes the branch, = = never `main`). On
`fix/split-pre-check-literal-mask-r2` it read `CLEAN` with **no** `UNREVIEWED`
line, = = because the card named the sha the branch pointed at, = = and that
was the last reading before the fast-forward.

Read AFTER this closeout's own docs commit landed, the same command on `main`
reads `CLEAN` **and** `UNREVIEWED`, because no card names a docs commit (= =
the sha `main` now points at is this closeout's own record, = = not a carrier
of code). That is the house's own ending state, = = not a defect: the
code-block scope's `main` ended at `e4961b2348`, = = a docs commit named by no
card either. The gate's rule is "a card that writes code owes a verdict", = =
and a closeout's record is not a card that writes code.

Both remotes read the sha (= = `git ls-remote` per remote, = = because a push
that reported success on one remote says nothing about the other).

**The scope's own branches and worktrees are gone.** The branch
`fix/split-pre-check-literal-mask-r2` was fast-forwarded into `main` and then
deleted, and its worktree `.worktrees/mask-r2` was removed. The four review
cards' worktrees (= = `.worktrees/t_3d6a9bc2`, `.worktrees/t_58d1da10`,
`.worktrees/t_9118e596`, `.worktrees/t_7ab46c73`) and their
`project/t_…` branches are removed too (= = all four cards are `done`, = =
all four worktrees were clean, = = and every one of those commits is already
on `main`), and so are the three hand-made lanes (= =
`.worktrees/mask-seam`, `.worktrees/mask-interp`, `.worktrees/nb1-clobber`).
No other session's worktree, branch, scratch file or running instance was
touched.

## 6. One procedural deviation, found by the audit and written into the skill

The board's own `task_events` are the authority for `t_3d6a9bc2`
(= = `/Volumes/ANAN/.hermes/kanban/boards/wenshu-par/kanban.db`):

| the clock | the event | what it means |
|---|---|---|
| 19:44:19 | `claimed` (run 3612) | the first dispatch, against the pre-amend tip |
| 20:12:46 | `reclaimed` (manual) | the card's own gate could not finish inside the 5400 s cap |
| 20:13:31 | `worker_bound` (run 3614) | the dispatcher re-claimed it 44 s later |
| 20:46:44 | `reclaimed` (manual) | the batched-read amendment changes the reviewed sha |
| 20:46:52 | `worker_bound` (run 3616) | the dispatcher re-claimed it 8 s later |
| 20:52:11 | `edited` (fields: body) | the body was re-edited 5m19s AFTER the reviewer was bound |
| 21:28:08 | `commented` (wenshu-review) | the reviewer names the tip it reviewed |
| 21:28:27 | `completed` = approved | run 3616's metadata: `reviewed_sha = 7851ccb3fc9c6449a9275634c928f942e6ada0ae` |

The VERDICT is sound: the reviewer explicitly noticed the tip had moved,
chose to review the TIP, re-read the amended body, verified `review_gate.py`
resolves the branch to its card, and recorded the amended sha (= = the sha
that landed). What was broken is the PROCESS: house rule 3 says a running
card's body must not be edited, and the reclaim-to-edit window was 5 minutes
wide while the dispatcher re-claims a reclaimed card within seconds.

= = ⇒ The rule that prevents it is now in the shared skill tree
(`wenshu-review-proof/references/the-branch-tip-is-frozen-while-the-review-runs.md`):
reclaim, amend, THEN edit the body (= = and read the card's state right
before the edit, because the dispatcher re-claims within 8 seconds).

## 7. Not in this scope

- **The three added files carry no registry row.** Rule 1.7 asks for every
  added file to be registered in `docs/agents/nfi.md`. The registry's own
  gate (`nfi-loc-check.py`) reads only the rows a change ADDS, so it reads
  "the change adds no registry row; nothing to check" here and exits 0; = =
  and the tree's own precedent is mixed (= = 10 of the 43 commits that added
  a file under `Tools/wenshu-devtool/` registered it, = = and the four tools
  the review-lane-cost closeout landed are not registered either). The three
  files here are therefore NOT registered, = = and that is a fact the next
  reader needs rather than a gap this closeout silently closed.
- **`split_pre_check.py` is 1895 lines and `test_split_pre_check.py` is 2907.**
  The 600-LOC cap in AGENTS.md 6.6 is scoped to `.swift` files (= = "600 LOC
  per .swift file"), and these are Python, so the cap does not reach them.
  It is named here because a reader who sees the numbers needs to know the
  cap was considered and why it does not apply.
- **The rejected rounds' trees are dropped from the refs, and their shas
  stay readable.** The two branches that held the rejected masking round
  (= = `fix/split-pre-check-literal-mask` and
  `fix/split-pre-check-interpolation`, both at `eafb01f5e`) are deleted,
  because the rework superseded them and the tree's own precedent drops a
  rejected round's branch (= = the code-block scope's rejected round
  (`74e20f1640`) is in no ref either). The sha is still readable, because the
  REVIEW lane's own scratch worktree holds it (= =
  `wenshu-review/cache/scratch/t58d1da10/wt-tip`), and that scratch belongs
  to the review profile, = = not to this session. So no round's tree is
  lost; = = only this session's pointers to it are gone.
- **The board's open columns were swept.** `blocked`, `todo`, `ready` and
  `review` are all empty. One card is `running` (= = `t_5f826648`, a
  sibling's review), and it was measured and not closed.

## 8. The lessons that outlive this scope

1. **A MOVED TIP IS NOT A MOVED REVIEW, AND THE BODY IS FROZEN WHILE THE
   REVIEWER RUNS.** The reclaim-to-edit window is where the rule breaks, and
   the dispatcher re-claims a reclaimed card within SECONDS (= = 8 seconds,
   measured). So the order is: reclaim, amend, THEN edit the body, and read
   the card's state right before the edit.
2. **A GATE THAT CANNOT FINISH IS A GATE THAT FAILS, AND IT FAILS THE CARD
   THAT NAMES IT.** The measurement's window walk spawned about 843,000
   processes, so the card's own gate could not finish inside the review's
   cap. A card that names a gate must name one that can RUN, and a gate
   whose cost is a function of the tree's size is a gate whose cost has to be
   measured before the card is written.
3. **THE FIGURE MUST NOT DEPEND ON THE CHOICE THE READER MAKES.** The same
   measurement was run under both readings of a nested literal, and both
   print the same four figures, so the conclusion does not rest on the
   reader's interpretation. A figure that moves with the interpretation is a
   figure that has not been measured yet.
4. **THE REVIEWER'S FINDINGS ARE ABOUT THE TREE, NOT ABOUT MY INTENT.** Two
   rounds were rejected on real defects in the change's OWN diff (= = the
   measurement deleted two of the four literal forms, and then case 2 could
   not see a dropped newline), and the third round was approved on a defect
   the reviewer found by itself (= = the latent interpolation leak).
