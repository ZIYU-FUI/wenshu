# Session close — 2026-10-21 — the leftovers, cleared through the new processes

> Boss directive 2026-10-21: "there is a new parallel development process, and
> there is a new screenshot test process. Clear the leftover problems."
> Session: `20261020_112058_62887e` (TUI). Parallel sessions: the `wenshu-dev`
> workers on the `wenshu-par` board, plus the sessions running the tab-strip,
> sidebar, chat, status-bar and Info.plist cards.
> Closure type: 6 code tickets (6 cards, 7 commits) + this closure doc.

## 1. The two processes this session used

**Parallel development** = a card on the `wenshu-par` board, one commit on the
card's own branch, a worktree per card (`docs/agents/parallel-development.md`).
Every ticket below ran that way: the work happened in the card's worktree, the
commit landed on the card's branch, and main took it as a fast-forward.

**Screenshot testing** = the `wenshu-visual-audit` skill: `scripts/wenshu-shot.sh`
captures the app without taking the focus (3840x1966, the app renders the PNG
inside its own process), and `scripts/preview-ticket.sh` builds a card's own
worktree and puts it in front of the boss.

## 2. The leftovers, and what each one turned out to be

| Card | The leftover | The finding | Commit |
| ---- | ------------ | ----------- | ------ |
| `t_8b2bb568` | The component index said the right rail was deleted and had no replacement | The rail came back as an empty shell, so the index told the next reader the wrong thing. The removal record stays; a new entry describes the shell | `d2260480f` |
| `t_2cc2f0b5` | The tool-dispatch header claimed five ported hermes helpers | Only the two multimodal helpers were ported. The untrusted-tool-result wrapper (= the promptware defense) and its high-risk tool lists were never written, and the test file listed four functions it never verified | `7914fbf4c` |
| `t_f50791bc` | A retry branch that could never run | `withClassifierRetry` had no production caller, and the type it gated on (`ClassifiedLLMError`) was built nowhere but its own tests. The live decision is `LLMConnectorErrorClassifier.isTransient` | `5aa97ffb7` |
| `t_ea114bf3` | The nervous file index's line counts | Eight counts no longer matched their files, and two rows still claimed a toolbar of 11 window buttons (= 9 secondary windows were removed on 2026-10-21) | `cb9e13752` |
| `t_4b77a18a` | The catalog's dead keys | 471 of the catalog's 834 keys were asked for by nothing: 277 were the machine-named residue of a string-extraction pass (= the literals of the deleted features), 194 were the named labels of the removed windows, the right rail's tools and the todo pane | `401d5e72a` + `ab5a0afcc` |
| `t_76a7e87b` | Two scripts assembling the same app | `Tools/build-wenshu.sh` was an older copy of `Scripts/build-app.sh`: it built a smaller bundle, skipped the third-party scanner, and copied source `.lproj` files the tree no longer has. The old copy is gone; the three places that named it now name the real one | `88dde181f` |

## 3. The catalog cleanup needed a correction of its own

The first pass judged a key dead when no Swift file spelled it out. That rule
missed the 12 VoiceOver labels the editor toolbar builds with
`NSLocalizedString("editor.format.\(rawValue).a11y", ...)`, and the
`LocalizedKeyTests` suite caught it. The comparison was also made against
`HEAD~1`, which another session's merge had turned into the cleanup's own
commit (= the keys looked absent because the "before" file was the already
reduced file).

The corrected rule keeps every key a literal names **and** every key an
interpolation site can reach. The catalog holds 363 keys, every one of them
live, and the editor format test passes again.

## 4. Verification

| Measure | Baseline (pre-cleanup) | Delivered tree |
| -------- | --------------------- | -------------- |
| Full-suite issues | 67 | 58 |
| Failing tests | 47 | 40 (= in 24 files, against the baseline's 28) |
| New failing tests vs baseline | — | **0** |
| Baseline failures that disappeared | — | 7 |
| Real compile errors | 0 | 0 (every build and suite run of this session) |
| Production types with no reference | 0 | 0 |
| Catalog keys | 834 | 363 (= 471 removed; = 0 live keys removed) |

The app was rebuilt with the canonical script (`bash Scripts/build-app.sh`,
exit 0) and captured with the screenshot flow. The capture shows no raw
translation key, the right rail shows its page title and the shared empty
state, and the rail's column title measures 232 luminance against 232 for the
neighbouring column's title (= the same tier; = a low-contrast reading of the
capture would have been wrong).

## 5. What the workers taught this session

Six cards ran on the board. The workers that started on the first attempt spent
their whole 30-minute budget reading and searching and wrote no file: one card
body was measured at 31 `search_files` calls and 0 writes. The fix is
mechanical: a card body has to carry exact `file:line` anchors, because the
worker's spec is the body and nothing else. A parallel session re-dispatched
its cards the same way.

The other lesson is the one that cost this session a rebuild: a worker and a
session editing the same worktree at the same time is the same collision the
worktree convention was supposed to prevent, so the card was reclaimed and the
change finished in the card's own worktree, on the card's branch.

## 6. What is left (= the boss's call, not acted on)

### 6.1 Product

1. **The promptware defense is still not ported.** The untrusted-tool-result
   wrapper (= hermes's `maybeWrapUntrusted` and its three siblings) is the
   control that marks a tool's output as untrusted data before the model reads
   it. The port needs its own ticket and its own design, and the hermes
   source it would be ported from is not on this machine. The gap is now named
   in the code instead of claimed, and the four helper names are listed where
   the next reader will look (= the dispatch helpers' header, the port test's
   H4.2 marker, and the `ErrorClassifier` gap marker).
2. **The suite is not green.** The baseline itself has 47 failing tests, and
   the failures move between runs (= the timing tests are load-sensitive: one
   3-second auto-save test failed once under load and passed 5/5 in
   isolation). The gate is the failing-test SET, never the issue count. The
   delivered tree is at 40 failing tests with 0 new.

### 6.2 The board and the tree

3. **Two cards are blocked and need a human.** `t_7bae9cda` (= the editor
   status bar) and `t_c53736f4` (= the chat turn spacing) are blocked; their
   re-dispatched replacements `t_c50a2cdf` (= the tab strip) and
   `t_4bd0e18b` (= the kanban window) are running, and `t_575a8577` (= the
   narrow-window crash) is running. A blocked card waits for the boss.
4. **One branch carries work that is not on the board.**
   `feature/inspector-wake` is 2 commits ahead of main (= the inspector's page
   strip waking a hidden column, and a note on launching the app without
   taking the focus) and has no card. It needs a card or it is lost.
5. **Eight worktrees are still on disk**, one per live card plus
   `/private/tmp/ws-baseline` and `scratch/wt-inspector-wake`. Each card's
   worktree goes when its branch merges: `git worktree remove --force` then
   `git branch -D`. This session removed its own six plus four stale ones
   (= two `ab-*` and two `vw-*`/two `cw-*` at the pre-rail commit, which held
   old builds that fought for the foreground and for the app's process).
6. **The Info.plist card merged cleanly** (`0e9dbd405`) and its edit to
   `Tools/build-wenshu.sh` went with the file's deletion (= the board comment
   on that card was the right call).

## 7. The state at the end of the session

| Item | Value |
| ---- | ----- |
| `main` | `0e9dbd405` (= this session's 8 commits + 3 from the parallel sessions) |
| `origin` / `old-origin` | 3 commits behind main (= the parallel sessions' merges are not pushed yet; = whoever pushes next pushes all four) |
| The working tree | clean |
| The catalog | 363 keys (= every key a literal names, plus every key an interpolation site can reach) |
| The app bundle | `bash Scripts/build-app.sh` exits 0 (= the canonical script; = the stale duplicate is gone) |

The session's own commits, in order: the component index, the tool-dispatch
port claim, the retry classifier, the nervous file index, the catalog cleanup,
the catalog cleanup's correction, the build script, and this closure doc.

The two skills the session taught are updated: `wenshu-pocock-workflow` carries
the pitfalls (= a stale build script that nobody runs, a visual finding that
the measurement contradicts, a "before" snapshot pinned to `HEAD~1`), and
`wenshu-parallel-dev` carries the card-body rules (= exact `file:line`
anchors, a comparison basis pinned by SHA).
