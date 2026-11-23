# Session close — the AI-reply chain's five lanes, and the landing that carried them (2026-11-24)

This document closes one scope: the Hermes Desktop's **AI reply side** — what
the reader sees while the assistant answers, and after it finishes. Five lanes
were built and reviewed; this record names each one, the review that cleared
it, the shape the landing takes, and the gates that read green on the branch.

**Nothing here claims the landing has happened.** The branch is published and
reviewed; the fast-forward into `main` and the push are the landing card's own
steps, and their result is recorded on that card, not here. The two remotes'
`main` are the proof of a landing, and this document does not assert what they
carry.

## 1. The requirements and where each one lives

| # | What was asked | Where it went | Verdict trail |
| --- | --- | --- | --- |
| 1 | The reply is drawn while it streams (= = the parts appear on the row as they arrive, = = not a pulse row) | `f635f261b5`, on `main` | `t_022108d0` APPROVED at `f635f261b5` (shipping tip, round 3) |
| 2 | The tool card settles its own call (= = the result merges into the call, = = a failed call settles as an error, = = an orphan result stays its own part) | `22277b9032` + `c3202a5144`, on `main` | `t_ea0a890b` (round 1), `t_6cf31ac5` (round 2), `t_8fda5fe0` (round 3, CHANGES_REQUESTED), `t_419a320b` (round 4) APPROVED at `c9d5b0c69f` |
| 3 | The reasoning trace reads inside a bounded rectangle | `603442485f` (= = a cherry-pick of `78c1b09fc1`) | `t_1702fd97` APPROVED at `78c1b09fc1` (round 6) |
| 4 | The transcript knows where the reader is, and offers the way back (= = the arriving reply does not drag a reader who scrolled up back to the bottom) | `c3f59ea158` (= = a cherry-pick of `81e2da0760`) | `t_05f39c04` APPROVED at `81e2da0760` (round 5) |
| 5 | The sub-agent card says what the agent just did | `a0865c4fa1` (= = a cherry-pick of `19c6d1c264`) | `t_a9b7f4b7` APPROVED at `19c6d1c264` (round 3) |

Two of the five are on `main` already, carried by other sessions' landings; the
other three are the commits this branch carries. Each of the three carries a
`(cherry picked from commit …)` trailer naming its lane's approved sha.

## 2. The landing shape, and why it is this shape

The five lanes were reviewed **separately**, each on its own branch, each
approved by a card that is not its implementer. The landing was therefore not
"push five branches": the review gate resolves a card by **the sha the branch
points at**, so a branch whose sha no card names carries NO verdict.

The shape that was measured, not chosen:

- **One integration branch**, `wt/chat-ai-reply-batch-2026-11-23`, carrying one
  commit per lane.
- **The registry is the only thing that conflicts.** `docs/agents/nfi.md` is a
  table of rows; the row-wise driver (`Scripts/merge-nfi-registry.py`) merges
  it at the key level, and every count cell a lane touched was then
  **re-measured in the merged tree** (= = the merged file is neither side's
  file). `nfi-loc-check` reads "14 row(s) checked: = 11 the change added, = 3
  whose named file the change rewrote and did not add" = = exit 0.
- **The branch's base is `main`**, so the landing is a **fast-forward**:
  `git merge-tree --write-tree 37a8f04bf2 79ec0f390a` = = rc 0 (= = no conflict at
  all), and `main`'s content is carried by ancestry rather than by a merge.
- **The registry's own parentheticals were re-published with it.** Eight rows
  describe `ChatViewModel.swift` with the label "(now ChatViewModel.swift, N
  LOC, under cap)"; the file is 351 lines in this tree, and the label read
  252 (= = the count of the tree the rows were written in). The label is a
  claim about a file, so it was re-published to the file the tree actually has.

## 3. What the lane commits changed

`git diff --shortstat 37a8f04bf2..c3f59ea158` = = "23 files changed, 2660
insertions(+), 151 deletions(-)": 16 `Sources/` files, 6 `Tests/` files, and
the registry. Ten files are new (= = `SubAgentActivityLine.swift`,
`SubAgentRunner+Storage.swift`, `ChatScrollToBottomButton.swift`,
`ChatTranscriptBottom.swift`, `ChatView+Transcript.swift`, and five test
files); the rest are rewrites.

Both ends of that range are fixed shas (= = the `main` the branch was cut
from, and the commit that carries the three lane commits), so the figure does
not move when this record's own commits sit on top of it, and it reads the
same after the landing (= = a range that named `main` would print nothing
once `main` IS this branch).

## 4. The gates, as they read at this tip

| gate | the tool's own line | rc |
| --- | --- | --- |
| `swift build` | `Build complete!` | 0 |
| the six lane suites | `Test run with 44 tests in 6 suites passed` | 0 |
| `comment_lineage.py --base main --repo <worktree>` | `added comment lines: 996` / `offending: 0 rows / 0 files (P0=0, P1=0)` | 0 |
| `ci_change_gate.py --base main --check formatting` | `the change adds no unformatted line (21 changed Swift file(s) checked)` | 0 |
| `--check loc-cap` | `every changed Swift file is within the 600-LOC cap (21 file(s) checked)` | 0 |
| `--check pollution` | `the change adds no forbidden vocabulary (main...HEAD)` | 0 |
| `--check markdown-newline` | `the change drops no .md's trailing newline (2 changed .md file(s) checked)` | 0 |
| `nfi-loc-check.py --base main` | `14 row(s) checked: = 11 the change added, = 3 whose named file the change rewrote` | 0 |
| `git merge-tree --write-tree 37a8f04bf2 79ec0f390a` | wrote a tree, no conflict output | 0 |

The reviewer re-ran the gates in the card's own worktree, with the worktree
clean before and after and its `HEAD` = = the named sha, and wrote no file in
it. It also re-derived the registry independently of its gate, with the
registry driver's own ruler (= = the key it extracts from each row): 499 keys
at `main` = = 510 keys at the tip, 11 added, 0 lost. and checked the lane carry **by blob and by line**:
20 of the 23 lane-touched files byte-identical to their lane's copy, and in
the three exceptions (`nfi.md`, `ChatViewModel.swift`,
`Localizable.xcstrings`) no lane-authored code or test line is absent at the
tip (= = the differences are additions).

## 5. What this closeout does NOT claim

- **The rendered look is the boss's to see.** No screenshot was taken and none
  is claimed (= = rule 7.7); a live-app proof would need the boss to launch
  the app.
- **The landing is asserted here, with its own measurement.** The branch
  `wt/chat-ai-reply-batch-2026-11-23` was landed into `main` by fast-forward
  (= = `git merge --ff-only`, one parent, no merge commit), and both remotes
  carry it: the push line read `37a8f04bf2..79ec0f390a  main -> main` on each
  of them, and each server's read-back printed
  `79ec0f390a44297548d5fa87d7b5a1ecf11bc4e5  refs/heads/main` (read on
  2026-11-24, without a pipe into `tail`/`head`, because a pipe reports its
  own rc and hides a remote failure).
- **The turn-outcome feature is not part of this scope.** It has no lane, no
  card and no branch anywhere on the board (= = the six-number scope this
  session inherited named five features with lanes; the sixth never became a
  card).
- **A complete `swift test` over the merged tree was not run** (= = the six
  lane suites were, plus the build; the tree's other suites are their own
  scope's business).
- The registry rows this scope added carry the counts of the tree they were
  written in; the header says so, and a later change that rewrites one of
  these files must re-publish its count.

## 6. The records the scope leaves behind

- The branch: `wt/chat-ai-reply-batch-2026-11-23`, published on `origin`.
- The registry: this document's own row, appended at the END of the table, and
  the three lane rows the driver resolved.
- The board: the landing card (`t_c56d6f30`) carries the review verdict, the
  push line and the dated read-back of both remotes' `main`.
- The two remotes' `main`: `3c52985d7b8a337a742703cc299a0541518a78ab` = = the
  commit this record's own tree is on (= = the branch's fast-forward, plus this
  record's own landing commit).

## 7. The trace, one row per requirement

Every requirement this scope inherited, the commit that carries it, the
independent verdict that cleared it, and the server-side proof that it is on
`main` (= = read back from the remote, not from the local clone).

| # | requirement | the commit that carries it | the independent verdict | the server's proof |
| --- | --- | --- | --- | --- |
| 1 | the reply is drawn while it streams | `f635f261b5` | `t_022108d0` APPROVED at `f635f261b5` | on `origin/main` = = `git merge-base --is-ancestor f635f261b5 origin/main` = = rc 0 |
| 2 | the tool card settles its own call | `22277b9032` + `c3202a5144` | `t_419a320b` APPROVED at `c9d5b0c69f` (= = after `t_ea0a890b`, `t_6cf31ac5`, `t_8fda5fe0`) | on `origin/main` = = rc 0 for both |
| 3 | the reasoning trace reads inside a bounded rectangle | `603442485f` (= = a cherry-pick of `78c1b09fc1`) | `t_1702fd97` APPROVED at `78c1b09fc1` | on `origin/main` = = rc 0 |
| 4 | the transcript knows where the reader is, and offers the way back | `c3f59ea158` (= = a cherry-pick of `81e2da0760`) | `t_05f39c04` APPROVED at `81e2da0760` | on `origin/main` = = rc 0 |
| 5 | the sub-agent card says what the agent just did | `a0865c4fa1` (= = a cherry-pick of `19c6d1c264`) | `t_a9b7f4b7` APPROVED at `19c6d1c264` | on `origin/main` = = rc 0 |
| — | the five lanes as ONE branch, and this record | `79ec0f390a` | `t_f0b926e4` APPROVED at `74a33187ac`, then `t_e4b56df9` APPROVED at `79ec0f390a` | `origin/main` = = `3c52985d7b`, which has `79ec0f390a` as an ancestor = = rc 0 |
| — | the landing itself (= = the fast-forward, the two pushes, the read-backs) | `3c52985d7b` | the landing card `t_c56d6f30` (this card's own scope; a landing writes docs and refs, so it owes no lane verdict) | `origin/main` = = `old-origin/main` = = local `main` = = `3c52985d7b8a337a742703cc299a0541518a78ab` (read 2026-11-24 03:10:43 CST, no pipe) |

**What is NOT in this table.** The turn-outcome feature (= = the sixth item of
the scope this session inherited) has no lane, no card and no commit: it was
never built, so no row can claim it.
