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
| equal-weight query terms must not resolve in per-process order | `ecec033726` (the two-line fix: `Set(queryTokens).sorted()`, then iterate that) | `t_cd5419f9`, `approved by wenshu-review` at `8415d6220073f52d5e52db2e80992baf7ad12d91` | `origin` and `old-origin` both read `4db43731ac686716b37e476de8d03b39abf9666b` at 19:28:05 CST |
| a suite that proves it, and fails when it is broken | `4db43731ac` (`Tests/WenshuAppTests/Library/Search/SearchRankingOrderStabilityTests.swift`) | same card, same verdict | same read-back |
| the registry must teach the mechanism, not a myth about it | `4db43731ac` (`docs/agents/nfi.md`, the `SearchRanking.swift` row) | the reviewer's criterion 3: the registry row teaches the measured mechanism | same read-back |

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
a delegated session dispatched over the top of it. The worktree reflog records
`2026-11-26 18:29:45 reset: moving to HEAD` and `2026-11-26 18:39:03 rebase
(finish)`; `Sources/.../SearchRanking.swift` carried mtime `18:35:44`, inside a
469-second launch loop that another session was running. Any arm whose window
crossed `18:29:45` may have measured a reverted scorer that no longer existed.
The rule recorded on `t_891a6235` comment 3059 and repeated on the review card:
re-take, do not cite. The delegation was stopped at `18:39:05` after
`11220.12` seconds; its product was already in the tree from the card's worker.

**3. The root cause of that waste was dispatch, not the model.** A card
assigned to a profile runs by itself on this board, so filing a card AND
dispatching a child for the same scope buys two executors in one worktree. One
worktree, one executor; the check is `python3
Tools/wenshu-devtool/board_liveness.py --card t_891a6235` before a child is opened on
a scope that already has a live card.

**4. A published number was written with a placeholder and shipped anyway.**
The landing comment first read `measured | 2026-11-26 19:3x CST`. That is a
guess in a table's formatting. `t_891a6235` comment 3077 retracts it with the
real readings (gate log mtimes `19:17:49` to `19:19:02`, read-back at
`19:28:05`, commit date `17:44:06 +0800`). A `19:3x` is not a measurement, and
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
(the body called `0f9c784db6` `origin/main`; `origin/main` was `7e036f7613` while
the review ran and `29ec44f1e2` when the landing measured). After the edit,
`review_gate.py --branch wt/retrieval-rank-order-2026-11-26 --main origin/main`
answers `CARD t_cd5419f9 / matched by sha`, rc 0, and the preflight answers
`CLEAN`, rc 0. Editing a finished review card's body did not touch its verdict:
the verdict lives in the run's metadata and the reviewed commit is byte-identical.

**The rule this leaves behind: a card's claim token and its claim label share a
line.** A gate that reads a record line by line is reading a contract, and a
wrapped contract is an unreadable one. The tool-side question (should
`_claim_tokens` fall back to the paragraph when the label line carries no token,
or should it keep failing closed) is carried as an open item below, not settled
here.

## Measurements, and what a reader can re-take

The tree carries the suite; the driver that looped it five times does not. The
re-takable claim is the arm's own result, and the numbers below that came from a
throwaway driver are labelled as such.

| claim | value | re-take |
| --- | --- | --- |
| the suite passes at the landed tip | 4 arms, 5 launches, rc 0, 0 issues | `swift test --filter SearchRankingOrderStabilityTests` (tree-carried) |
| process-to-process stability | 3 launches at the tip produced 1 distinct ranking md5, 0 of 24 tied pairs flipped | throwaway driver, `/var/tmp/r7/results.tsv`; not tree-carried |
| the negative arm bites, arms run alone | tie-break rc 1 flipped 1, 7, 5, 5 and 11 of 24 pairs; arrival-order rc 1 drifted 16, 16, 132, 48 and 96 of 144 rotations; process-order rc 1 split 6/4, 6/4, 3/9, 8/6, 8/2 | throwaway driver over a reverted `SearchRanking.swift`; recipe below, marked SKIP for cost |
| the negative arm bites without a shared process | `--no-parallel` rc 1 on three launches, 691, 234 and 522 issues, at least one issue on each of the three order arms | same recipe, plus `--no-parallel` |
| a suite that cannot run does not read as green | `WENSHU_RANK_ORDER_NO_RUNNER=1` gives rc 1 with 1 issue | tree-carried: the skip arm asserts its own refusal |

```
SKIP: costs a full `swift build --build-tests` plus five launches, and mutates a
checkout. Run it in a throwaway worktree, never in a lane another card holds.
git worktree add --detach /tmp/revert-probe 4db43731ac
cd /tmp/revert-probe
python3 - <<'PY'
import pathlib
p = pathlib.Path("Sources/WenshuApp/Features/Library/Service/SearchRanking.swift")
t = p.read_text()
assert t.count("Set(queryTokens).sorted()") == 1
p.write_text(t.replace("Set(queryTokens).sorted()", "Set(queryTokens)"))
PY
for i in 1 2 3 4 5; do swift test --filter SearchRankingOrderStabilityTests >/dev/null 2>&1; echo "launch $i rc=$?"; done
git worktree remove --force /tmp/revert-probe
```

A reverted scorer that leaves every arm rc 0 is a reject of the suite, not a
pass: the fixture would once again be unable to move, which is the defect rounds
1 and 2 were rejected for.

The cheap check a reader can run in any clone: every commit this record cites
resolves.

```
for s in ecec033726 4db43731ac 8415d62200 29ec44f1e2 7e036f7613; do
  printf "%s %s\n" "$s" "$(git cat-file -t "$s")"
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
| `bash Tools/wenshu-devtool/tests/run-suites.sh` at the landed tree | `suites=46 red=0 known-red=0`, rc 0, log written `19:29:21` |

The same battery read `suites=46 red=1` earlier the same evening, with the red
named `test_ticket_tier`. That suite is board-dependent: one of its fixtures
sealed a path held by live card `t_b8b24959`, which has since finished. It was
never added to `known-red.txt`, because masking a board-dependent red is how a
gate stops meaning anything.

## Two facts about the landing that a later reader will otherwise misread

**The landing was a rebase, so the approved sha is not an ancestor of `main`.**
`git merge-base --is-ancestor 8415d6220073f52d5e52db2e80992baf7ad12d91
4db43731ac686716b37e476de8d03b39abf9666b` says no. The verdict still governs
because the gate matches the change, measured before the branch moved:
`review_gate.change_id` is `c0f70cb4cbced6e30c50dbc2056c55b202ce7e4d56d4521ed828ec91e0c2f083`
for both the reviewed tip and the replayed tip. The reviewed commit is parked at
`refs/keep/rank-order-r3`, and `refs/keep/` is local: `git ls-remote origin |
grep -c 'refs/keep/'` prints `0`.

**Local `main` was left behind on purpose.** The shared checkout holds 25 staged
files belonging to the `t_b1dbd63e` lane, among them `docs/agents/nfi.md`, so a
`merge --ff-only` there would have rewritten a sibling's staged registry rows.
The push went branch-to-`main` instead (`git push origin
wt/retrieval-rank-order-2026-11-26:main`), which is a fast-forward on the server
and touches no local index. At the read-back, local `main` was `29ec44f1e2` and
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
3. **Four lanes of this wave are not landed**, because none carries an approving
   verdict: vendor parity (`t_f9a65c7e`), the loc gate record (`t_6d24acce`), the
   chord record (`t_e5f90adb`), the fade-in lane (`t_2c076ee3`). Their verdicts
   were `changes_requested` and each rejection shipped its own rework card.
4. **One chord item needs a human, not a round.** `t_fbb810a3` reached the
   rejection cap on a committed message whose chord glyphs contradict the tree
   (`U+23EB` claimed, `U+2318` written). The reviewer offered amend, waive, or a
   generator-side check; the author cannot pick one of those.
5. **This record is reviewed as any change is.** Its closure card names this
   sha, and the verdict on that card is not written back into this file: the
   round that would record an approval of this record is itself a new commit, so
   a finding here that only asks for another such sentence is the defect
   repeating, and should be rejected as one.
