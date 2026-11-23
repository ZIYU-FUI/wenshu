# Session close — the AI-reply chain's five lanes, and how they reached `main` (2026-11-24)

This document closes one scope: the Hermes Desktop's **AI reply side** — what
the reader sees while the assistant answers, and after it finishes. Five lanes
were built, reviewed and landed. The user-message side is not in this scope.

## 1. The requirements and where each one lives

| # | What was asked | Where it went | Verdict trail | Server-side proof |
| --- | --- | --- | --- | --- |
| 1 | The reply is drawn while it streams (= = the parts appear on the row as they arrive, = = not a pulse row) | `f635f261b5` on `main` | `t_022108d0` APPROVED at `f635f261b5` (shipping tip, round 3) | the commit is an ancestor of `main`; `t_8ef5861a`, `t_f1a669e7`, `t_244802f1` carried its rounds |
| 2 | The tool card settles its own call (= = the result merges into the call, = = a failed call settles as an error, = = an orphan result stays its own part) | `22277b9032` + `c3202a5144` on `main` | `t_ea0a890b` (round 1), `t_6cf31ac5` (round 2), `t_8fda5fe0` (round 3, CHANGES_REQUESTED), `t_419a320b` (round 4) APPROVED at `c9d5b0c69f` | the two commits are ancestors of `main`; round 4's three comment fixes are in `c3202a5144` |
| 3 | The reasoning trace reads inside a bounded rectangle | `07a5c1ef58` (= = a cherry-pick of `78c1b09fc1`) | `t_1702fd97` APPROVED at `78c1b09fc1` (round 6) | the commit carries `(cherry picked from commit 78c1b09fc1…)`; the registry row for `ChatReasoningPartView.swift` = = `ChatThinkingBoxTests.swift` is in the landed tree |
| 4 | The transcript knows where the reader is, and offers the way back (= = the arriving reply does not drag a reader who scrolled up back to the bottom) | `87718ca3a9` (= = a cherry-pick of `81e2da0760`) | `t_05f39c04` APPROVED at `81e2da0760` (round 5) | the commit carries `(cherry picked from commit 81e2da0760…)`; the reader-position members are in the landed `ChatViewModel.swift` |
| 5 | The sub-agent card says what the agent just did | `5420f6d64e` (= = a cherry-pick of `19c6d1c264`) | `t_a9b7f4b7` APPROVED at `19c6d1c264` (round 3) | the commit carries `(cherry picked from commit 19c6d1c264…)`; `SubAgentActivityLine.swift` and its tests are in the landed tree |

## 2. The landing shape, and why it is this shape

The five lanes were reviewed **separately**, each on its own branch, each
approved by a card that is not its implementer. The landing was therefore not
"push five branches": the review gate resolves a card by **the sha the branch
points at**, so a branch whose sha no card names carries NO verdict.

The shape that was measured, not chosen:

- **One integration branch**, `wt/chat-ai-reply-batch-2026-11-23`, carrying one
  commit per lane, each with a `(cherry picked from commit …)` trailer naming
  the lane's approved sha.
- **The registry is the only thing that conflicts.** `docs/agents/nfi.md` is a
  table of rows; the row-wise driver (`Scripts/merge-nfi-registry.py`) merges
  it at the key level, and every count cell a lane touched was then
  **re-measured in the merged tree** (= = the merged file is neither side's
  file). Measured: the driver reported at most seven conflicted keys per
  cherry-pick, and `nfi-loc-check` = = "13 row(s) checked: = 10 the change
  added, = 3 whose named file the change rewrote and did not add" = = exit 0.
- **The base is `main` itself**, so the landing is a **fast-forward**:
  `git merge-base --is-ancestor 85cfcc9e5e 87718ca3a9` = = true, and
  `git merge-tree --write-tree 85cfcc9e5e 87718ca3a9` = = rc 0 (= = no
  conflict at all). `main`'s content is carried by ancestry, not by a merge.
- **Two of the five lanes are not carried at all**: the streamed reply and the
  tool card's settlement were landed on `main` by another session while the
  integration was being built (`85cfcc9e5e` and `c3202a5144`), so carrying
  them again would have duplicated them.

## 3. What the three commits change

`git diff --shortstat 85cfcc9e5e...87718ca3a9` = = "23 files changed, 2660
insertions(+), 151 deletions(-)": 16 `Sources/` files, 6 `Tests/` files, and
the registry. Ten files are new (= = `SubAgentActivityLine.swift`,
`SubAgentRunner+Storage.swift`, `ChatScrollToBottomButton.swift`,
`ChatTranscriptBottom.swift`, `ChatView+Transcript.swift`, and five test
files); the rest are rewrites.

## 4. The gates, as they read at the landed tip

| gate | the tool's own line | rc |
| --- | --- | --- |
| `swift build` | `Build complete! (17.44秒)` | 0 |
| the six lane suites | `Test run with 44 tests in 6 suites passed after 11.987 seconds.` | 0 |
| `comment_lineage.py --base main --repo <worktree>` | `added comment lines: 996` / `offending: 0 rows / 0 files (P0=0, P1=0)` | 0 |
| `ci_change_gate.py --base main --check formatting` | `the change adds no unformatted line (21 changed Swift file(s) checked)` | 0 |
| `--check loc-cap` | `every changed Swift file is within the 600-LOC cap (21 file(s) checked)` | 0 |
| `--check pollution` | `the change adds no forbidden vocabulary (main...HEAD)` | 0 |
| `--check markdown-newline` | `the change drops no .md's trailing newline (1 changed .md file(s) checked)` | 0 |
| `nfi-loc-check.py --base main` | `13 row(s) checked: = 10 the change added, = 3 whose named file the change rewrote` | 0 |
| `git merge-tree --write-tree 85cfcc9e5e 87718ca3a9` | wrote a tree, no conflict output | 0 |

The reviewer re-ran all nine in the card's own worktree, with the worktree
clean before and after and its `HEAD` = = the named sha, and wrote no file in
it (`t_4abb4222`, APPROVED). It also re-derived the registry independently of
its gate (13/13 owned rows match their file's newline count, 499 = = 509 keys
with 0 lost) and checked the lane carry **by blob and by line**: 20 of the 23
files byte-identical to their lane's copy, and in the three exceptions
(`nfi.md`, `ChatViewModel.swift`, `Localizable.xcstrings`) **zero
lane-authored lines are absent** at the tip.

## 5. What this closeout does NOT resolve

- **The rendered look is the boss's to see.** No screenshot was taken and none
  is claimed (= = rule 7.7); a live-app proof would need the boss to launch
  the app.
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

## 6. The server-side proof

- The branch was pushed before the landing: the server's
  `wt/chat-ai-reply-batch-2026-11-23` = = `87718ca3a9b03e5f157f99c784430a7602b56003`
  = = the local tip (read back with `git ls-remote --heads origin`).
- The fast-forward and the push of `main`, and the read-back of
  `origin/main` = = the landed sha, are recorded in the landing card's own
  comment on the board.
