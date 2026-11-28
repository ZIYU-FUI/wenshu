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

Every token of seven or more hexadecimal characters in this file, outside a
fenced block, is resolved with `git rev-parse --verify --quiet <token>^{commit}`.
A token is first stripped of punctuation and of a trailing ellipsis, so an id the prose prints
short is censused anyway: how an id is written cannot exempt it from the loop that reads it.
One that resolves to a commit is a member of the census; one that does not is
printed by the block below with its length and the line it sits on, so a reader sees
the list of non-commits rather than trusting a sentence about it. Each one is named at
its site as what it is = a blob id, a tree id, a `git patch-id --stable` output, a
change id, the sha256 of printed probe output, an integer an order digest printed, or an id that
names no object at all = which is a defect in the sentence that printed it, not a kind of id.
A patch-id and a
change id are properties of a diff, not objects, so they cannot resolve; a blob id
resolves under `git cat-file -t` as `blob` and under `rev-parse --verify
<token>^{commit}` as nothing, which is the test the block applies. The block below is the measurement and the
doc gate runs it as written, so a reader re-takes it by pasting it into a shell inside
a checkout of this branch; its printed lines are the counts: a member is hard when `git merge-base --is-ancestor <member> origin/main`
returns 0, meaning any clone of this repository reaches it, and soft when it returns
1, and every soft member is printed with the refs that carry it, from
`git for-each-ref --contains <member> --format=%(refname)`. A soft member behind a
`refs/remotes/` ref can be re-taken by a reader who clones this repository; one
behind no such ref exists only inside this one checkout, so the claims pinned to it
can be re-taken only by whoever holds it. Nothing in this paragraph repeats the
numbers: they are printed, because a count transcribed from a tool rots when the
tool's own input moves, and this file's prose is that loop's input.

```bash
python3 - <<'PY'
import subprocess
from pathlib import Path
# The census is not a table in prose: it is this loop, run against this file.
REL = ("docs/agents/2026-11-26-session-close-the-rank-order-lane-and-"
       "the-claim-line-a-gate-could-not-read.md")
lines = Path(REL).read_text().split("\n")
fence, toks = False, set()
where = {}
for i, line in enumerate(lines, 1):
    if line.startswith("```"):
        fence = not fence
        continue
    if fence:
        continue  # a sha inside a block is output, not a claim
    for w in line.split():
        t = w.strip("`().,:;=\"").rstrip("\u2026.")
        if len(t) >= 7 and all(c in "0123456789abcdef" for c in t):
            toks.add(t)
            where.setdefault(t, []).append(i)


def resolve(tok):
    r = subprocess.run(["git", "rev-parse", "--verify", "--quiet", tok + "^{commit}"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def on_main(sha):
    cmd = ["git", "merge-base", "--is-ancestor", sha, "origin/main"]
    return subprocess.run(cmd, capture_output=True).returncode == 0


members = sorted({resolve(t) for t in toks if resolve(t)})
hard = [s for s in members if on_main(s)]
soft = [s for s in members if s not in hard]
assert len(members) == len(hard) + len(soft)
print("members %d hard %d soft %d" % (len(members), len(hard), len(soft)))
for s in hard:
    assert on_main(s)  # an arm that cannot re-check its own class is not a proof
    print("  %s main" % s[:10])
server = []
for s in soft:
    cmd = ["git", "for-each-ref", "--contains", s, "--format=%(refname)"]
    refs = subprocess.run(cmd, capture_output=True, text=True).stdout.split()
    assert not on_main(s)
    tag = "server" if any(r.startswith("refs/remotes/") for r in refs) else "local-only"
    if tag == "server":
        server.append(s)
    print("  %s %s %s" % (s[:10], tag, ",".join(r.replace("refs/", "") for r in refs) or "none"))
print("  server-carried off-main: %d; checkout-only: %d" % (len(server), len(soft) - len(server)))

void = sorted((t for t in toks if not resolve(t)), key=lambda x: (len(x), x))
print("tokens that do not resolve to a commit: %d, by length %s" % (
    len(void), sorted({len(v) for v in void})))
for v in void:
    print("  len %d %s on lines %s" % (len(v), v, ",".join(str(i) for i in where[v])))
PY
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
   tip's 0 is a silence, not a re-spelling: it names no chord in any form. Whether
   any message in this repository spells a chord as words depends on the scope, and
   an arm that asserts a number has to name the scope it read. Over the base this
   lane started from, `b738e7593a881bd6a9108713b68833e4d3cb52f1`, `git log` over
   that scope piped to `grep -c` reads 0 for `Command-K` and 0 for `Command-F`.
   Over this branch it reads 1 and 1, with one carrier:
   `335ba28ffd72676d24dd3de099a20de63988a0de`, this record's own earlier commit,
   whose message body quotes that grep and so carried its own refutation. That
   commit is an ancestor of what lands here, so after the landing the base scope
   reads 1 and 1 as well, with the same single carrier. The
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

## The gate set re-taken after main moved twice

Base `origin/main` = `ba2415ab86`. While this record was being fixed, main moved
from `b738e7593a` to `ba2415ab86` through `8057b1afdc`, `94fb8dadf1` and
`ba2415ab86` = the three that took the chord-glyph rule and its test into main's
judge. The branch's tip at that point, `1c9adf82a8`, is therefore not a child of
main: `git merge-base --is-ancestor` returns 1 for it. The census loop published
above lists the refs that carry it = two local branch heads and one
ref the server also has, so the shape it pins can be re-taken by a reader who
fetched that ref, and not by a reader who cloned main alone. `git merge-tree
--write-tree origin/main 1c9adf82a8` read clean, so main was merged into this branch
and the tree under measurement is this
branch's own tip after that merge, which a reader resolves with `git rev-parse
HEAD`, and every log below is labelled `.gate-logs/r7_<label>.log` rather than
by a sha that a later amend would invalidate.

Nothing main added touches this record: the three commits touch
`Tools/wenshu-devtool/` and one row of `docs/agents/nfi.md`; this branch touches
its own row and this file. `git diff --quiet origin/main HEAD --
Tools/wenshu-devtool/` returns 0, which is the reading that closes the rejection's
charge that the branch carried a second copy of a rule main already had = there is
one implementation on each path and one carrier for it. `git ls-tree origin/main --
` followed by this record's path prints no row = main does not carry this record
yet, so a claim about this file cannot be read off main's tree, and the
record's own blob is the same either side of that merge, which the block under it
re-derives instead of asserting = it prints the blob of this record's path at the
branch's pre-merge tip and at the merge, and the two strings are equal. The merge
therefore moved the base under the earlier claims and rewrote none of them.

```bash
D="docs/agents/2026-11-26-session-close-the-rank-order-lane-and-the-claim-line-a-gate-could-not-read.md"
for c in 1c9adf82a8 8313fec5fc; do
  printf '%s  %s\n' "$c" "$(git rev-parse "$c:$D")"
done
```


Two claims had to change rather than survive. The chord rule is now read from
main's `Tools/wenshu-devtool/commit_filter.py` and `tests/test_chord_glyph_rule.py`
instead of a copy carried by this lane, and replaying the local chord family onto
main's rule is a separate matter from this branch's content = `git patch-id
--stable` over `a708a7e590` reads
`cc7cc21c1c4d042568c161b68d4c540ccd681610`, over `548730e302`
`a57427b240c99a708e9e17c692bc9afabccd0d58`, and over main's own carrier `8057b1afdc`
`bbcc5c90a5498b21a39ff6a8393b4ea2ad7213cf` = three different strings, so the lane's
two chord commits are not a copy of what main took: main rewrote the rule on its own
path, and `git diff --quiet origin/main HEAD -- Tools/wenshu-devtool/` says the tree
now holds main's single version. One equality does survive and it is the one that
matters to this record's own history: `git diff 825edae01447^ 825edae01447 | git
patch-id --stable` and `git diff a08c89d9f3^ a08c89d9f3 | git patch-id --stable` both
read `dc43650f3b63c898a5d96b4940a3d3bc2d25c5b4`, which is a property of the diff, so
the replay of that record edit onto a different parent moved no content. A patch-id is
not an object: neither string resolves, which is why each is named with the two commits
it was taken over. The registry fix
`7e036f7613` is on main's tree now, and the count `nfi-loc-check.py` prints is a
property of the diff it is handed rather than of the tool: the landed table ran where
`origin/main` was `29ec44f1e2` (its comment-lineage row names the window
`29ec44f1e2..4db43731ac`) and printed 2 rows, the round below ran at `b738e7593a` and
printed 1 row. The two numbers are readings of two windows.


## The doc gates measured on the shape a reader gets

Base `origin/main` = `b738e7593a881bd6a9108713b68833e4d3cb52f1`. The object under
measurement is the commit `335ba28ffd72676d24dd3de099a20de63988a0de`, reachable on
the server as `refs/heads/docs/rank-order-closeout-2026-11-27`; the tree it holds,
which is what the eight readings below actually describe, is
`07ae614a024b2902a7ba02b079442c5e837000aa`, and `git cat-file -t` returns `commit`
for the first id and `tree` for the second. Instant 2026-11-27 04:06 CST; that
round's logs are `.gate-logs/r5_335ba28ffd72_<label>.log`, = labelled by the commit
id, which is the naming this record rejects three sections below and that the r7
round replaced with `.gate-logs/r7_<label>.log`. The names are quoted as they were
written, not as endorsement; an amend of that commit would have orphaned all eight
filenames. Each log opens with the command it ran and carries the gate's own exit
status on the next line as `rc=0`. All eight returned 0:
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

## The three defects the doc gate found in this record's own shape

The round above closed the numbers. Its doc gate came back with three readings about the
record instead, and all three were in the instrument rather than in a count. Each is
quoted from the log of that run, `.gate-logs/r7_doc-gate.log`, whose `cmd:` line names
the command. Its `tree:` line names no object, and this paragraph believed it: the ninth round's
review card found that belief and the block below prints the instant, its commit and that commit's
tree instead of quoting the line.

The registry row was wrong: `registry LOC cell 520 != the doc's 519 line(s)`. The gate
counts newlines, the way `wc -l` does, and the row had been synced with a splitter that
counts the empty field after the last newline. One line, in a row whose whole job is to
be the number a reader checks the file against.

The merge paragraph froze a live ref: `1 prose line(s) freeze a live ref`, naming the
line that proved the record's blob unchanged by writing two `git rev-parse` commands and
their shared output as a sentence. That is the form the gate names = true at the
author's minute, false after the next push, and false here after the next amend, which
is exactly what happened to it. The equality is now a block that prints both ids.

The census block never ran: `block 3: exit 2` and `bash: import: command not found`.
The verifier has no Python path. It hands every block it recognises to `bash -lc`, so a
block of Python behind a `python` fence is shell to it, and the loop that publishes every
count in the section above resolved nothing at that tree. The claim in the section below
it, that the verifier executes the resolve loops rather than re-reading them, was untrue
of the one loop that matters most = the census. The fence now opens as `bash` and feeds
Python to a quoted heredoc, which a reader and the gate both run, and it prints its own
member count and its own hard/soft split, so no hand-typed copy of either survives in
the prose anywhere in this file.

The naming of that round's logs had to be repaired too. The section above states that
they are labelled `.gate-logs/r7_<label>.log` rather than by a sha that a later amend
would invalidate. At the instant that sentence was written the files on disk still
carried a sha in their names, and the commit one of them named was then amended, so the
sentence was true of intent and false of the filesystem. The files now carry the sha-free
names the sentence states, the amend changed no tree, and this round's logs follow the
same convention.

```bash
for f in .gate-logs/r7_*.log .gate-logs/r8_*.log; do
  [ -e "$f" ] || continue
  printf '%-24s %s\n' "$(basename "$f" .log)" "$(grep -m1 '^tree:' "$f")"
done | sort
R7TREE=$(grep -m1 '^tree:' .gate-logs/r7_doc-gate.log 2>/dev/null | cut -d" " -f2)
if [ -z "$R7TREE" ]; then
  echo "no r7 log in this checkout: the line above is the whole of the instrument's naming"
else
  R7CAT=$(git cat-file -t "$R7TREE" 2>&1); R7RC=$?
  printf 'the r7 tree line %s -> cat-file rc %d: %s\n' "$R7TREE" "$R7RC" "$R7CAT"
  printf "the instant commit of that round, which the same log names in its window: %s\n" \
    "$(git rev-parse --verify --quiet 2ef6e40cca^{commit})"
  printf "that commit's tree, which is the object the r7 readings describe: %s\n" \
    "$(git rev-parse 2ef6e40cca^{tree})"
  printf "the amend of that commit, which changes the commit and never its tree: %s\n" \
    "$(git rev-parse --verify --quiet 1aaa64f573^{commit})"
fi
```

The gate set was re-run at the tree that carries this section, the same eight commands, and each log names the instant, the tree object and the command in its first three lines, with the command's own exit code as its last line. The logs and the driver that wrote them live in the worktree, which the repository does not track, so they do not travel with the commit: the ignore rule is printed below, and the eight command lines are printed with it, so the re-take does not depend on a file a reader cannot fetch. What a reader takes from this section is therefore the readings below plus the commands that regenerate them.

```bash
git check-ignore -v "$(git rev-parse --show-toplevel)/.gate-logs/r8_run.sh"
```

```bash
SKIP: the eight commands re-take the whole set; run in sequence, each prints its own exit code
python3 Tools/wenshu-devtool/comment_lineage.py --base origin/main
python3 Tools/wenshu-devtool/ci_change_gate.py --check formatting --base origin/main
python3 Tools/wenshu-devtool/ci_change_gate.py --check loc-cap --base origin/main
python3 Tools/wenshu-devtool/ci_change_gate.py --check markdown-newline --base origin/main
python3 Tools/wenshu-devtool/ci_change_gate.py --check pollution --base origin/main
python3 Tools/wenshu-devtool/nfi-loc-check.py --base origin/main
python3 Tools/wenshu-devtool/tests/test_nfi_loc_check.py
python3 /Volumes/ANAN/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/scripts/verify_doc_commands.py --run --registry docs/agents/nfi.md docs/agents/2026-11-26-session-close-the-rank-order-lane-and-the-claim-line-a-gate-could-not-read.md
```

The block below walks the eight names and prints, for each, the tree object its log was taken at and the exit code that log ends with, or the reason nothing is printed. It reads, so "all eight returned 0" is a reading taken here and nowhere else. One absence is structural and is printed as such: the doc gate's own log is written only after that gate finishes, so inside the gate this block shows seven logs and its own absence.

```bash
for f in comment-lineage doc-gate formatting loc-cap markdown-newline nfi-loc nfi-tests pollution; do
  p=".gate-logs/r8_$f.log"
  if [ -f "$p" ]; then
    printf '%-20s %-44s %s\n' "$f" "$(grep -m1 '^tree:' "$p" | cut -d' ' -f2)" "$(tail -1 "$p")"
  else
    printf '%-20s %s\n' "$f" "no log in this checkout; re-take with the eight commands above"
  fi
done | sort
```

The eight closeout steps, each stated in the tense it can be checked in:

| step | state at this commit | how a reader takes it |
| --- | --- | --- |
| 1 re-run the gate set on the merged tree | run at this tree | the eight command lines above, then the reading block, at the tree a reader stands on |
| 2 record the verdict on the board | written once this commit exists | card `t_022b3908`, the card that holds this lane's decision |
| 3 the closure record in the tree | this file, committed | `git ls-tree -r --name-only <landing merge> -- docs/agents/` |
| 4 durable lessons into the skills | written | `wenshu-card-gate-vocabulary`, the section on the verifier's one shell path and one line-count rule; `standard-closeout`, the section on instrument readings |
| 5 clean up own residue | done at the push | `git worktree list` in the main checkout, and no scratch directory left outside the repository under this session's name |
| 6 re-check the final state | printed after the push | the lane ref `docs/rank-order-closeout-2026-11-27` read back from the server, and the branch-to-main ancestry the landing card carries |
| 7 sweep the board's open columns | done with step 2 | `t_022b3908`, and no other card holding this lane |
| 8 land | PENDING: review card at this sha, `review_gate.py --card`, `Scripts/merge-preflight.sh`, then the merge and the push | the landing merge's ancestry, in the reader's own minute |

Nothing here claims a landing that has not happened. A record that asserted the merge and
the approval it waits on would close the scope on a claim the tree cannot show, and that
is the defect this lane has now paid for twice.


## The second review round: three charges about what an id names

The independent review card `t_bd0a86fe` ran read-only over the commit `fa6ae5aa49…` and
returned CHANGES_REQUESTED with three blockers (comment 3211). None of them was a failing
gate. All three were the same class as the defect this record is about: a token described as
something it is not, or a number stated where no measurement prints it.

**One — a chord claim that was false inside its own branch.** The section on the second
remote asserted that no commit message in the repository spells a chord as words, and printed
`git log --all --format=%B | grep -c` readings of `0` and `0`. That is refuted by the branch
itself: the commit `335ba28ffd…`, which is an ancestor of the commit under review, carries the
grep in its own message body and therefore carries its own refutation. The claim now names the
scope it read, and the block below re-takes it from three immutable commits, so the numbers
below do not depend on where a reader stands or on which scratch worktrees a machine happens to
have attached:

```bash
for scope in b738e7593a881bd6a9108713b68833e4d3cb52f1 335ba28ffd72676d24dd3de099a20de63988a0de fa6ae5aa492a175813bfbc593fbfb827c63eadce; do
  body=$(git log "$scope" --format=%B)
  printf '%-42s Command-K=%s Command-F=%s\n' "$scope" \
    "$(printf '%s' "$body" | grep -c 'Command-K')" "$(printf '%s' "$body" | grep -c 'Command-F')"
done
```

At this instant the three lines print `0 0` for the base, then `1 1` for the carrier, then `1 1`
for the commit under review, and exactly one commit inside that ancestry spells either word — the carrier,
subject `docs(agents): the closeout's resolve loo…`. The earlier reading of `2` commits came from
`--all`, which walked a detached worktree holding `4bcfec5ed7…`; that commit is carried by no ref,
was this session's own rebase probe, and its worktree has been removed. Counting across `--all` is
not a scope: it reads whatever a machine left attached, and a number taken that way cannot survive
someone else's `git worktree list`.

**Two — a commit id described as a tree.** The r5 section named `335ba28ffd…` the "tree under
measurement". It is a commit; `git cat-file -t` says `commit` for it and `tree` for
`07ae614a…`, which is the tree it holds and the object the eight readings describe. The same
section's log filenames carry the commit id, which is the naming this file rejects one section
below: an amend of that commit would orphan all eight names. The filenames are now quoted as what
they were, with the convention stated as rejected rather than as held.

The ninth round's review card found the same class one line further. `d58e84d3…` (printed short here
so it stays one token) is what the r7 logs carry on their `tree:` line, and it is not a tree at all,
let alone one whose commit had died: the block above prints `git cat-file -t` on it, which returns rc
128 and names no object. What that round really measured is printed from the instrument rather than
typed into a sentence here = the r7 window names its own head commit, that commit resolves, and the
tree the eight readings describe is the tree of that commit, which the block prints. That commit was
then amended, and an amend changes a commit and never the tree it held, so the tree was alive at the
instant and is alive now, and no sentence needed the id that names nothing. The reason this file
carried the misnaming unread is the census itself: a token printed with a trailing ellipsis failed
its hex test, so typography exempted the one id that needed resolving. The filter no longer accepts
that exemption.

**Three — a hand-typed count in the registry row.** The row described the resolve loops as
carrying "sixteen shas, each named by what carries it". No measurement prints sixteen, and the
token census in this file prints its own three numbers instead; the typed count also called every
token a sha, which is the same misdescription as blocker two one level up. The count is gone from
the row, which now says only that an id is named by what carries it and that a non-commit is named
as its kind. The census loop prints `members`, `hard` and `soft` at the tree it runs on, and the
doc gate's log for this round carries its printed line as the closing line of the block it executed.

The repair round's own instrument. The eight gates were run at the tree that holds this section and
each log keeps the command on its first line and the command's own exit code on its last, named
`.gate-logs/r9_<label>.log` — round label and no object id, which is what the naming rule above
asks for. These logs do not carry an instant or a tree line, unlike the r7 and r8 logs, and are not
offered as evidence of a tree: the tree is read from the commit, and the commit is named by the
review card. All eight returned 0; the doc gate closed with its own reading.

## The readings on the merged tree

`origin/main` had moved four commits since the tree of the previous section, so the eight gates
were run again after the merge, on the merged tree `e1a5fb2fd4055c1865b198698f21999dcc71d6a2`, a
tree id, printed from that merge commit. All eight returned 0 and the merge carried no code, so the
doc gate's reading of this record is the line count the registry row carries at that tree, and the
census block prints its own member count and its own hard/soft split there rather than a sentence. The scope readings of the section above were
re-taken at the merged tree and hold there: `0 0` for the base commit, `1 1` for the carrier.

The commit that carries this paragraph is a child of that measured tree, and its diff over the
merge commit is this paragraph plus the registry's line count for this file, which is the only
number in the file a reader cannot read off a printed instrument. Checking that the two blobs differ
in nothing else is therefore the whole of what this paragraph asks a reader to trust.
## The ninth round's one blocker, and the census hole that hid it

`t_4e9c29b6` read this file at the commit that carries it and returned CHANGES_REQUESTED with one
blocker, R9-B1, and it was a defect in this file rather than in a count: the paragraph above that
quoted the r7 logs called their `tree:` line the tree object under measurement, and then named the id
on it as a tree whose commit had been amended away. The logs refute both readings. The id resolves to
no object at any length, the commit of that instant still resolves, and the tree the eight readings
describe is that commit's tree = all three are printed by the block above, so the sentence that was
wrong is now the sentence that points at a printer. The amend did change nothing about the tree, which
is the rule the record states, and the record broke a different rule: it described an id it had never
resolved.

The instrument let that happen. The census resolved only tokens that were wholly hexadecimal, and this
file prints long ids short, so a trailing ellipsis took the token out of the loop that was supposed to
read it. The filter now strips an ellipsis before the test, which is the fix R9-B1 asks for in the
place it belongs = in the rule, not in one sentence. Tokens that enter the census because of it are
named at their sites as the kind they are, and a token that names no object is called what it is: a
defect in the sentence that printed it.

Two further readings on the same card are accepted corrections rather than defects. The `sixteen
shas` claim was a global grep across `docs/agents/nfi.md`, which counts rows belonging to other
lanes; the scoped reading of this lane's own row prints none, and the row no longer carries a typed
count at all. And the Base paragraph asserted that the diff's base already included `origin/main`,
which was true of the instant it was written and stopped being true when `main` moved; it now names
the base and the head as two ids printed by its own commands. Nothing here restates a number that a
block can print.
