# session close: the rank-order lane, and the claim line a landing gate could not read

Landed scope: the library ranking returned a different order in different
processes, because it walked a `Set` directly. The fix is two lines in
`Sources/WenshuApp/Features/Library/Service/SearchRanking.swift`; the cost of
this scope was almost entirely in the record around it, not in the fix.

Every tip in this file is an instant, read at the stated moment, not a standing
fact. `main` moved four times while this lane was open. The commands that
re-derive each number are printed next to it.

## The traceability table

| original requirement | carrier commit | independent verdict | server proof |
| --- | --- | --- | --- |
| the score's accumulation does not depend on the process's hash seed (= the order the tokens are visited in is fixed) | `ecec033726` (the two-line fix: `Set(queryTokens).sorted()`, then iterate that) | `t_cd5419f9`, `approved by wenshu-review` at `8415d6220073f52d5e52db2e80992baf7ad12d91` | the landed tip `4db43731ac` is an ancestor of `origin/main` and of `old-origin/main` (`merge-base --is-ancestor`, rc 0), read 2026-11-26 22:54 CST |
| a test that measures the ranking under two different hash seeds (or in two processes) asserts the SAME order, and it is red before the change and green after | `4db43731ac` (`Tests/WenshuAppTests/Library/Search/SearchRankingOrderStabilityTests.swift`, blob `eeaaf4f944d2`) | same card, same verdict | same ancestry, rc 0; the suite blob `eeaaf4f944d2` is the same object at `4db43731ac` and at `825edae014` |
| the retrieval fixture's measured floor does not regress (= the numbers the closed card measured stay true) | `64212762cb` is where the floor was measured; it is a backup ref, not this branch's history (`refs/backup/retrieval-rank-order-64212762cb`), and it is carried to `4db43731ac` by three blob identities: scorer `813e7876b1ee`, corpus `c92b81985c7a`, floor `771f957f210d`, the same objects at `64212762cb`, `4db43731ac` and `825edae014` | `t_9c54532c` comment 2935, "Criterion 3 - MET, measured at the tip", 2026-11-26 08:00:43: library row `0.75 0.92 1.00 0.67 1.00` against the floor constants `9.0/12.0`, `10.0/12.0`, `11.0/12.0` at `RetrievalQualityRankers.swift:65-67` | re-taken at the tip 2026-11-26 22:48 CST: `swift test --filter RetrievalQualityTests` rc 0, 17 tests in 1 suite, library row `0.75 0.92 1.00 0.67 1.00` (log `/tmp/floor_retake_tip2.log`, a scratch path the tree does not carry); the three blobs are the same objects at `4db43731ac`, `825edae014` and `origin/main` |
| the registry must teach the mechanism, not a myth about it (= a review-round requirement, `t_9c54532c` B2) | `4db43731ac` (`docs/agents/nfi.md`, the `SearchRanking.swift` row) | raised as `BLOCKER B2 - the mechanism sentence in landed artifacts is wrong` in `t_9c54532c` comment 2935, and cleared by `t_cd5419f9` comment 3071, "Check 2 - the registry no longer teaches the wrong mechanism" | same ancestry, rc 0 |

## What the lane got wrong before it landed

**1. Three rounds spent a rejection on an arm that could not fail.** The first
fixture gave its tied documents the SAME terms, so both sides accumulated the
same values in the same relative order: the scores tied exactly, no layout
change moved a slot, and the order-level arms were green against a reverted
scorer. They only went red when a sibling bit-pattern arm ran beside them in the
same process. A suite that is green on the defect is not a regression test, and
rounds 1 and 2 carried `changes_requested` for exactly that.

**2. The measurements taken between 15:32 and 18:39 were voided by an
environment fault, not by a bad method.** Two executors held
`.worktrees/retrieval-rank-order-2026-11-26` at once: the card's own worker, and
a delegated session dispatched over the top of it. Two reflog events 558 seconds
apart ended that overlap, and only one of them is still readable in a file.
`git reflog show wt/retrieval-rank-order-2026-11-26` (the BRANCH reflog, which
the worktree's removal did not touch) prints `2026-11-26 18:39:03 rebase
(finish)` onto `7e036f7613`. The other, `2026-11-26 18:29:45 reset: moving to
HEAD`, survives only as a verbatim quotation in `t_891a6235` comment 3059,
because the worktree that held that log has since been removed with the lane's
own residue. The throwaway driver's own
bracket is on disk as two files: `/var/tmp/r4/por_start.txt` (mtime `18:30:42`)
and `/var/tmp/r4/por_end.txt` (mtime `18:37:58`), 436 seconds. The line the
driver captured inside that bracket, `/var/tmp/r4/line186.txt`, carries mtime
`18:35:44`. The landing rebase rewrote the lane worktree's own copy of
`Sources/.../SearchRanking.swift` at `19:17:03`; that worktree is gone, and the
two surviving copies read `11-24 13:59:05` (the shared checkout) and `11-26
19:32:32` (this record's worktree) as of 2026-11-26 22:54 CST, read with
`stat -f '%Sm' -t '%m-%d %H:%M:%S'`. Any arm whose window
crossed `18:29:45` may have measured a reverted scorer that no longer existed.
The rule recorded on `t_891a6235` comment 3059 and repeated on the review card:
re-take, do not cite. The delegation was dispatched at `15:32` and stopped at
`18:39:05` (comment 3059's own endpoints); its product was already in the tree
from the card's worker.

**3. The root cause of that waste was dispatch, not the model.** A card
assigned to a profile runs by itself on this board, so filing a card AND
dispatching a child for the same scope buys two executors in one worktree. One
worktree, one executor; before a child is opened on a scope that already has a
live card, the check that works today is the board's own rows, not
`board_liveness.py`: that tool takes `--board`, `--fresh` and `--grace`, has no
`--card` or `--scope` flag, and never prints a workspace path, so it cannot
answer the question this rule asks. The query that does is `select id, status,
assignee, workspace_path from tasks where status in ('running','ready','review')
and workspace_path is not null`, read with `sqlite3 -readonly` against
`~/.hermes/kanban/boards/wenshu-par/kanban.db`. What it catches is the
collision class this rule exists to prevent: two open cards naming the SAME
workspace path, one of them the shared checkout. At 2026-11-26 22:54 CST four
open cards named a workspace, and the four paths they named were
`.worktrees/t_a500b73d` (`t_07e2a022`),
`.worktrees/vendor-parity-on-main-2026-11-26` (`t_f9a65c7e`),
`/Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/workspaces/t_a6580791`
(`t_a6580791`) and `.worktrees/nfi-census-block-2026-11-26` (`t_982f92db`) -
four distinct paths, no collision - and the card that had claimed the shared
checkout, `t_6d24acce`, had already gone to `done`, so a rule written on it
would have found nothing to stop. The census is blind by construction to cards
opened after that instant (this card, `t_f20c7f89`, was created at 22:59:45).
A `--card`/`--scope` flag on `board_liveness.py` is the tool-side half of the
fix and is carried as an open item.

**4. A published number was written with a placeholder and shipped anyway.**
The landing comment first read `measured | 2026-11-26 19:3x CST`. That is a
guess in a table's formatting. `t_891a6235` comment 3077 retracts it with the
real readings (gate log mtimes `19:17:49` to `19:19:02`, read-back at
`19:28:05`, and the landed commit's author date `17:44:06 +0800` = = whose
committer date is `19:17:03 +0800`, the landing rebase). A `19:3x` is not a
measurement, and
the fix is to run `date`, not to format the row.

## The defect the landing found in the record's shape

The approval was on the board and the landing gate still refused, because the
refusal was about typography:

```
SKIP: a transcript of two separate runs, prompt prefixes included; each line is
      verbatim, and neither command is safe to re-run after the landing.
$ bash Scripts/merge-preflight.sh wt/retrieval-rank-order-2026-11-26
UNREVIEWED wt/retrieval-rank-order-2026-11-26
         no review card names the sha this branch points at          # rc 3
$ python3 Tools/wenshu-devtool/review_gate.py --card t_cd5419f9 --main origin/main
gate: approved        reason: approved by wenshu-review               # rc 0
```

The two answers differ because they take different paths. `--card` reads the
verdict from the card's run metadata. The landing lookup finds the governing
card by the sha in its body, through `review_gate.reviewed_sha()` and
`_claim_tokens()`, and that scan takes the hex token **from the line that
carries the claim label**. The card wrapped its paragraph, so the label line
ended with the word for the identifier and the identifier itself sat on the next
line:

```
SKIP: this block is the quoted body shape the section is about, not a command.
Round-2 review of the rank-order lane. Under review: sha
`8415d6220073f52d5e52db2e80992baf7ad12d91`, branch `wt/...`, base ...
```

Measured on that stored body: `rg._claim_tokens(body)` returned the empty list,
and `rg.reviewed_sha(body, rg.branch_tip_history(branch), branch)` returned
`None` even though `branch_tip_history` held `8415d62200`. So the gate printed
`REVIEW CARD UNREADABLE` over a real approval, and its own message named the
remedy it could not apply (`read it with --card <id> before re-reviewing the
branch`).

The record-side repair, in `t_cd5419f9` comment 3074: put the claim and its
token on one line under a `## WHAT TO BUILD` heading, and correct the base label
(the body called `0f9c784db6` `origin/main`; `origin/main` moved to
`29ec44f1e2` at 2026-11-26 19:07:18 CST, and every reading `t_cd5419f9`
published was taken 19:09:16-19:09:41 CST, after that move, so `7e036f7613`
covered only the first 2m29s of that card's 19:04:49-19:11:26 run; the landing
measured `29ec44f1e2`). With the edit in
place and the branch tip still `8415d62200` = = the branch's reflog shows the
rebase onto `29ec44f1e2` at `19:17:03` = = `review_gate.py --branch
wt/retrieval-rank-order-2026-11-26 --main origin/main` answered `CARD
t_cd5419f9 / matched by sha`, rc 0, and the preflight answered `CLEAN`, rc 0.
Those two readings do not reproduce now, and the reason is the rebase: the
branch points at `4db43731ac`, which no card names, so the same two commands
read rc 3 and `UNREVIEWED`. The forms that still reproduce the approval are
`review_gate.py --card t_cd5419f9 --main origin/main`, rc 0, and
`review_gate.py --branch wt/retrieval-rank-order-2026-11-26 --sha
8415d6220073f52d5e52db2e80992baf7ad12d91 --main origin/main`, rc 0, `matched by
sha` (both measured). Editing a finished review card's body did not touch its
verdict:
the verdict lives in the run's metadata and the reviewed commit is byte-identical.

**The rule this leaves behind: a card's claim token and its claim label share a
line.** A gate that reads a record line by line is reading a contract, and a
wrapped contract is an unreadable one. The tool-side question (should
`_claim_tokens` fall back to the paragraph when the label line carries no token,
or should it keep failing closed) is carried as an open item below, not settled
here.

## Measurements, and what a reader can re-take

The tree carries the suite and its own probe; the driver that looped the arms
does not. Every figure below is dated, and every one that came from a throwaway
driver names the file it was read from and the interval it was read in. The
figures taken from the 15:32-18:39 window this record voids are not published
here at all: the rows below carry post-fault readings instead.

| claim | value | re-take |
| --- | --- | --- |
| the suite passes at the tip | 5 tests in 1 suite (the four order arms plus the tree's own probe), rc 0, 0 issues, re-taken 2026-11-26 22:44 CST (`/tmp/orderstability_retake_tip.log`, a scratch path the tree does not carry) | `swift test --filter SearchRankingOrderStabilityTests` (tree-carried) |
| the ranking's order is the same in every process | three launches of the tree's OWN probe at the tip printed one identical order (the three `RANKORDER` lines are byte-identical, sha256 `18c084d11a64ea97adb5887091f973447fdecca8e972598640c5fc5af186d165`), rc 0 each, 2026-11-26 22:49 CST; the throwaway probe's words for the same claim are `order-digest 10009171863505857283`, `flipped-pairs []`, `rotated-digests 1 distinct of 21` (`/var/tmp/cp1.log` 17:31:26, `cp2.log` 17:31:29, `cp3.log` 17:31:33 - read inside the two-writer interval of section 2 above, so the tree-carried re-take is the one that carries the claim) | `WENSHU_RANK_ORDER_PROBE=1 swift test --filter rankOrderProbe`, three launches, compare the printed order lines; the tie-break arm's pair scale is `pairCount = 24` (test file line 56) and it is green at the tip |
| the negative arm bites, arms run alone | post-fault readings (the set spans 18:59:54-19:00:47), every one of them after the 18:39:03 rebase and after the 18:57:15 shipping amend: tie-break arm alone rc 1, 1 issue, flipped pairs `[1, 2, 8, 14, 15, 21, 23]` of the fixture's `pairCount = 24` (`/var/tmp/r7/rev_a1.log`, 19:00:47); arrival-order arm alone rc 1, 1 issue, drifted 19 of 144 arrival orders (`/var/tmp/r7/rev_a2.log`, 19:00:38); the approving reviewer took the same arm alone on the reverted scorer at 19:09:16-19:09:41 and read 86 of 144 (`t_cd5419f9` comment 3071) | same recipe, marked SKIP for cost; each figure above names the artifact and the interval it was read in, and no figure here is quoted from the voided 15:32-18:39 window |
| the negative arm bites without a shared process | `--no-parallel` rc 1, 751 issues, with the score arm, the tie-break arm, the arrival-order arm and the second-process arm all red in the same run (`/var/tmp/r7/rev_np.log`, 19:00:43); the approving reviewer's own `--no-parallel` run read rc 1, 525 issues at 19:09 (`t_cd5419f9` comment 3071) | same recipe, plus `--no-parallel` |
| a suite that cannot run does not read as green | `WENSHU_RANK_ORDER_NO_RUNNER=1` gives rc 1 with 1 issue | tree-carried: the skip arm asserts its own refusal |

```
SKIP: costs a full `swift build --build-tests` per launch, and mutates a
checkout. Run it in a throwaway worktree, never in a lane another card holds.
The arms below are the ones the table publishes, one launch each.
git worktree add --detach /tmp/rank-order-revert-probe 4db43731ac
cd /tmp/rank-order-revert-probe
python3 - <<'PY'
import pathlib
p = pathlib.Path("Sources/WenshuApp/Features/Library/Service/SearchRanking.swift")
t = p.read_text()
assert t.count("Set(queryTokens).sorted()") == 1
p.write_text(t.replace("Set(queryTokens).sorted()", "Set(queryTokens)"))
PY
swift test --filter SearchRankingOrderStabilityTests.tiedPairsAreOrderedByTheTieBreak; echo "tie-break rc=$?"
swift test --filter SearchRankingOrderStabilityTests.tiedPairsStayOrderedWhenTheTermsArriveInAnotherOrder; echo "arrival-order rc=$?"
swift test --no-parallel --filter SearchRankingOrderStabilityTests; echo "no-parallel rc=$?"
git worktree remove --force /tmp/rank-order-revert-probe
```

A reverted scorer that leaves every arm rc 0 is a reject of the suite, not a
pass: the fixture would once again be unable to move, which is the defect rounds
1 and 2 were rejected for.

The cheap check a reader can run: every commit this record cites by name is a
member of one of the two loops below. The first loop holds the five shas that are
on `main`: it FAILS if one of them does not resolve, and it prints only the sha
and its type - no ref, because `main` is the ref. The second loop holds the other
eleven, prints for each the
refs in the checkout that carry it, and prints `not in this clone` where none
does, without failing. Of those eleven: three sit on a server ref, so a clone
that fetches `docs/rank-order-closeout-2026-11-26` or `wt/cmd-shift-k-2026-11-25`
re-takes them - `825edae01447537b1fb3144675c89e17aadd1b26`, and
`799a0dcf5e54866331c398fc07d129fdfdcc357a` with its parent
`e53e8441e9dc29bdc8b8e0731a4f0cad1625c06c`; four are carried only by refs this
checkout made for itself - a backup ref and three parked superseded tips; three
are carried only by local lane branches; and one, `a08c89d9f30d06d81630c286651f998444eba9ea`,
is this record's own third commit after two rebases, named here only for its
patch-id. `825edae01447` is that same commit as it was pushed: `git patch-id
--stable` reads `dc43650f3b63c898a5d96b4940a3d3bc2d25c5b4` for both, so the blob
identities cited at `825edae01447` are taken at a pushed shape and not at a
moving tip.

```
for s in ecec033726 4db43731ac 29ec44f1e2 7e036f7613 0f9c784db6; do
  git cat-file -e "$s" || exit 1
  printf "%s %s
" "$s" "$(git cat-file -t "$s")"
done
for s in 825edae01447537b1fb3144675c89e17aadd1b26 \
         8415d6220073f52d5e52db2e80992baf7ad12d91 \
         64212762cb \
         a708a7e5900857a3eaf613fba82dd6dc9e79a01d \
         548730e3021a5d17db829499730970bfff750a04 \
         799a0dcf5e54866331c398fc07d129fdfdcc357a \
         e53e8441e9dc29bdc8b8e0731a4f0cad1625c06c \
         a08c89d9f30d06d81630c286651f998444eba9ea \
         3d67d7270d3244eec49a0a23cc3c4947938a0cbc \
         c5d54473162aa909dee87ba57cf83ef9d8a2557d \
         913b5239b38e21daf47e35fa1fa441692f95eb8f; do
  if git cat-file -e "$s" 2>/dev/null; then
    printf "%s %s %s\n" "$s" "$(git cat-file -t "$s")" \
      "$(git for-each-ref --contains "$s" --format='%(refname)' | tr '\n' ' ')"
  else
    printf "%s not in this clone\n" "$s"
  fi
done
```

## Gate set, at the landed tree

Run in the card's own worktree after the rebase, pointed at the shared checkout's
log directory so the closeout gate can read the proof from the tree that holds
the work:

```
SKIP: this is the author's recorded run, kept verbatim because the label logs
      below are its output; re-running it costs a full build plus the suite.
Run it from the repository root.
LOGDIR="$PWD/.gate-logs" PER_CMD_TIMEOUT=780 bash Scripts/gate_run.sh \
  .worktrees/retrieval-rank-order-2026-11-26 rankorder-land-4db43731ac \
  'git rev-parse HEAD' \
  'python3 Tools/wenshu-devtool/pre_review_gate.py --base origin/main --filter SearchRankingOrderStabilityTests' \
  'python3 Tools/wenshu-devtool/nfi-loc-check.py --base origin/main' \
  'python3 Tools/wenshu-devtool/comment_lineage.py --base origin/main'
```

Driver rc 0. Four label logs, `.gate-logs/rankorder-land-4db43731ac_1.log`
through `_4.log` (mtimes `19:17:49` to `19:19:02`), each with `grep -c FAIL`
equal to 0, and `_1.log` prints the sha it proves
(`4db43731ac686716b37e476de8d03b39abf9666b`).

| gate | reading |
| --- | --- |
| `git rev-parse HEAD` | the landed tip, printed into the log so the run names its own tree |
| `pre_review_gate.py --base origin/main --filter SearchRankingOrderStabilityTests` | every gate was measured on this tree and is green |
| `nfi-loc-check.py --base origin/main` | every added or rewritten file's row carries its own count, 2 rows checked |
| `comment_lineage.py --base origin/main` | window `29ec44f1e2..4db43731ac`, added comment lines 87, offending 0 rows / 0 files, P0 0, P1 0 |
| `bash Tools/wenshu-devtool/tests/run-suites.sh` at the landed tree | `suites=46 red=0 known-red=0`, rc 0; the log is `/tmp/battery-landed.log`, mtime `19:29:21`, a scratch path the tree does not carry |

Two earlier battery readings read `suites=46 red=1`, with the red named
`test_ticket_tier`: `/tmp/suites_tip.log` (mtime `17:27:51`) and
`/tmp/suites_base.log` (mtime `17:32:07`), whose contents are byte-identical.
Both instants PRECEDE the landed commits' committer time (`19:17:03`, the
same for `4db43731ac` and `ecec033726`), so neither log is a reading of the
landed tree. Their author times differ (`17:44:06` and `06:56:53`), so the
author-time reading this sentence used to carry did not hold for the second of
them. The suite's redness is board-dependent by
construction: the failing case asks the tier tool about a fixture card, the
tool consults the LIVE board, and the failure message in `/tmp/tt_tip.log`
names the collision and the card it collided with (`the live card t_b8b24959
(status ready) also writes`). What the artifacts do NOT support is the cause
this record used to assert: `t_b8b24959` ran `15:38:15`-`17:09:05` and
`17:44:42`-`18:40:02`, so the two red readings fall in the gap when it was
not running, while three of the four green ones (`/tmp/battery_tip.log`
`17:57:02`, `/tmp/battery_rebased.log` `18:28:13`, `/tmp/battery_quiet2.log`
`18:36:18`) fall INSIDE its live window, and the fourth
(`/tmp/battery-landed.log` `19:29:21`) falls after it completed. Green while
it was live, red while it was dead: "the card finished, so the suite went
green" is therefore backwards, and the cause is not claimed here. The red was never added to `known-red.txt`
(`grep -c ticket_tier Tools/wenshu-devtool/tests/known-red.txt` = 0), because
masking a board-dependent red is how a gate stops meaning anything.

## Two facts about the landing that a later reader will otherwise misread

**The landing was a rebase, so the approved sha is not an ancestor of `main`.**
`git merge-base --is-ancestor 8415d6220073f52d5e52db2e80992baf7ad12d91
4db43731ac686716b37e476de8d03b39abf9666b` says no, and so does the same
question asked of `origin/main`, which now carries the landed tip. The verdict
still governs because the gate matches the CHANGE, and a change identity is a
function of its base, so the base is part of the claim:
`review_gate.change_id('4db43731ac686716b37e476de8d03b39abf9666b',
'29ec44f1e25be02ea3ab7bd825d4a2f1d7df4185')` and
`review_gate.change_id('8415d6220073f52d5e52db2e80992baf7ad12d91',
'29ec44f1e25be02ea3ab7bd825d4a2f1d7df4185')` both read
`c0f70cb4cbced6e30c50dbc2056c55b202ce7e4d56d4521ed828ec91e0c2f083` = = measured
before the branch moved, the second half only where the parked commit exists.
With `origin/main` as the base the replayed half reads `None`, and that is by
definition rather than by failure: the landed tip is now an ancestor of main,
so the diff `main..4db43731ac` is empty and `change_id` returns `None` for an
empty change. That is why the reading had to be taken before the push:

```
python3 -c "import sys;sys.path.insert(0,'Tools/wenshu-devtool');import review_gate as rg;b='29ec44f1e25be02ea3ab7bd825d4a2f1d7df4185';print('replayed vs 29ec44f1e2',rg.change_id('4db43731ac686716b37e476de8d03b39abf9666b',b));print('replayed vs origin/main',rg.change_id('4db43731ac686716b37e476de8d03b39abf9666b','origin/main'))"
```

The reviewed commit is parked at `refs/keep/rank-order-r3`, and `refs/keep/` is
local: `git ls-remote origin | grep -c 'refs/keep/'` prints `0`.

**Local `main` was left behind on purpose.** The shared checkout held staged
files belonging to the `t_b1dbd63e` lane, among them `docs/agents/nfi.md`, so a
`merge --ff-only` there would have rewritten a sibling's staged registry rows.
The push went branch-to-`main` instead (`git push origin
wt/retrieval-rank-order-2026-11-26:main`), which is a fast-forward on the server
and touches no local index. That count is an instant and it moves: the ruler
`git -C /Volumes/ANAN/Engineering/wenshu diff --cached --name-only | wc -l` read
25 when the landing was measured and reads 28 at `2026-11-26 20:18 CST`. At the
read-back, local `main` was `29ec44f1e2` and
`origin/main` was `4db43731ac`. `nfi_lock.py status` read
`docs/agents/nfi.md is free (nobody)` before the push.

## Open items, carried

1. **The reverted-scorer driver is not an instrument the tree carries.** The
   per-launch flips and drifts came from `/var/tmp/r3`, `/var/tmp/r4` and
   `/var/tmp/r7`. They belong in `Tools/wenshu-devtool/probes/` with a row in
   `probe-index.md`, an entry in `Tools/wenshu-devtool/README.md`, a row in
   `docs/agents/nfi.md`, and `python3 Tools/wenshu-devtool/tests/test_probe_index.py`
   keeping the deposit from going missing. Until then the numbers in the table
   above are a report, not a reading.
2. **`_claim_tokens` reads a claim line by line.** Whether it should fall back to
   the paragraph, or keep failing closed with a message that routes the reader to
   `--card`, is a tool decision this record does not make. Nothing on the board
   owns it as of the instant this file was written; check `sqlite3 -readonly
   ~/.hermes/kanban/boards/wenshu-par/kanban.db "select id, status from tasks
   where body like '%claim token%'"` before filing a card for it.
3. **Four lanes of this wave are not landed**, and the verdict is on each lane's
   REVIEW card, not on the rework card the rejection spawned: vendor parity
   `t_bb1e6d16` (`CHANGES_REQUESTED at 3d67d7270d3244eec49a0a23cc3c4947938a0cbc`,
   rework `t_f9a65c7e`), the chord record `t_f0902b46` (`changes_requested at
   548730e3021a5d17db829499730970bfff750a04`, rework `t_e5f90adb`), the fade-in
   lane `t_16ff9709` (`changes_requested at c5d54473162aa909dee87ba57cf83ef9d8a2557d`,
   rework `t_2c076ee3`). The loc gate lane is the odd one: `t_1c7f0b43` carries
   no `review_outcome` at all, and its lane-mate `t_66e8c311` reads `approved at
   913b5239b38e21daf47e35fa1fa441692f95eb8f` = = a sha that is NOT on `main`
   (`git merge-base --is-ancestor 913b5239b38e21daf47e35fa1fa441692f95eb8f
   origin/main` rc 1), so this record cannot claim that lane landed either. Its
   card `t_6d24acce` is the census fix that approval did not cover; it is
   `done`, and its one run (5259, `completed`, started and ended 2026-11-26
   22:40:22 CST) carries no `review_outcome` in its metadata. The four rework
   cards are read the same way, with `sqlite3 -readonly
   ~/.hermes/kanban/boards/wenshu-par/kanban.db "select t.id, t.status,
   (select count(*) from task_runs r where r.task_id = t.id) as runs from tasks
   t where t.id in ('t_f9a65c7e','t_e5f90adb','t_2c076ee3','t_6d24acce')"`:
   at 2026-11-27 00:07 CST that returns `t_f9a65c7e` `ready` 0 runs,
   `t_e5f90adb` `done` 1 run (5265, `completed`, 2026-11-26 23:24:10 CST),
   `t_2c076ee3` `ready` 0 runs, `t_6d24acce` `done` 1 run (5259). Neither run
   carries a `review_outcome`, so none of the four cards carries a verdict of
   its own.
4. **One chord item was decided, and the decision is on the card.**
   `t_fbb810a3` reached the rejection cap on a committed message whose chord
   glyphs contradict the tree; the card is `blocked`, single run 5083
   `blocked`, read 2026-11-27 00:07 CST. The owner chose the reviewer's first
   option: comment 2820 on that card, 2026-11-25 18:11:02 CST, "option 1 -
   order the amend", and comment 2828, 2026-11-25 20:15:42 CST, records the
   rework at tip `799a0dcf5e54866331c398fc07d129fdfdcc357a`, which supersedes
   the tip the rejection was about. The counts belong to that superseded
   message: counted by codepoint over `git log -1 --format=%B
   a708a7e5900857a3eaf613fba82dd6dc9e79a01d`, it carries `U+2318` ten times and
   `U+21E7` four times, and six of the mentions are bare `U+2318`+letter with
   no `U+21E7` at all (`U+2318`+`K` three times, `U+2318`+`F` three times), so
   the defect is a DROPPED `U+21E7`, not a claimed `U+23EB`; `U+23EB` appears
   in no commit message in this repo and in no comment on `t_fbb810a3`. That
   superseded tip is carried by `refs/keep/chord-glyph-round-3` and by no server
   ref, so a clone cannot re-take the counts from it. What a clone can re-take is
   the tip that branch carries now, `799a0dcf5e54866331c398fc07d129fdfdcc357a`,
   and its parent `e53e8441e9dc29bdc8b8e0731a4f0cad1625c06c`, both on
   `refs/heads/wt/cmd-shift-k-2026-11-25` and on the same-named server ref. By the
   same codepoint method the tip's message counts 0 `U+2318` and 0 `U+21E7` and
   the parent's counts 3 `U+2318`, 3 `U+21E7` and 0 bare `U+2318`+letter. The
   tip's 0 is a silence, not a re-spelling: it names no chord in any form, and no
   message in this repository spells a chord as words - `git log --all
   --format=%B | grep -c` reads 0 for `Command-K` and 0 for `Command-F`. The
   repaired message is the parent's, and it carries the same patch as the
   superseded tip (`git patch-id --stable` reads
   `cc7cc21c1c4d042568c161b68d4c540ccd681610` for both): the amend rewrote the
   message and left the diff alone. The tree facts the rejection charged hold at
   the tip and are re-takeable there: the
   code block's chord is `U+2318`+`U+21E7`+`F`
   (`ChatView+KeyboardShortcuts.swift:353` = `.keyboardShortcut("f", modifiers:
   [.command, .shift])`), focus input's chord is `U+2318`+`K` (`:25` =
   `.keyboardShortcut("k", modifiers: [.command])`), and the roster line at
   `:233` names both (`U+2318` 14 times, `U+21E7` 8 times on that line).
5. **This record is reviewed as any change is.** The card that reviews this
   record names the sha this file was committed as, and the verdict on that card
   is not written back into this file: the
   round that would record an approval of this record is itself a new commit, so
   a finding here that only asks for another such sentence is the defect
   repeating, and should be rejected as one.

## The doc gates measured on the shape a reader gets

Base `origin/main` = `b738e7593a881bd6a9108713b68833e4d3cb52f1`, tree under
measurement `335ba28ffd72676d24dd3de099a20de63988a0de` (reachable on the server as
`refs/heads/docs/rank-order-closeout-2026-11-27`), instant 2026-11-27 04:06 CST,
logs `.gate-logs/r5_335ba28ffd72_<label>.log`, each exit code read from the gate
command's own status and printed as the log's first line. All eight returned 0:
`Tools/wenshu-devtool/tests/test_nfi_loc_check.py` (the file's own suite),
`verify_doc_commands.py --run --registry docs/agents/nfi.md`,
`nfi-loc-check.py --base origin/main`, `comment_lineage.py --base origin/main`,
and `ci_change_gate.py --check` for `markdown-newline`, `formatting`,
`pollution`, `loc-cap`. Three of those readings must not be over-read. The
verifier's closing line is `PASS (6 block(s) seen, 2 executed)`: the two executed
blocks ARE the two resolve loops above, so they were run and not just re-read, and
the other four blocks were skipped by their own `SKIP` markers.
`comment_lineage.py` printed that no added comment line exists in this window, so
nothing was measured there and rc 0 is NOT a pass on that rule. `nfi-loc-check.py`
printed `1 row(s) checked` at this base, which is a different window from the
two-row reading in the landed-run table above; this record's row is the one in
scope here. The commit that carries this sentence is a child of the measured tip,
and its diff over that parent is exactly this block plus the line count in
`docs/agents/nfi.md`, so the reading can be carried forward by checking that the
two blobs differ in nothing else.
