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

1. **The promptware defense is now ported.** The untrusted-tool-result
   wrapper (= hermes's `maybeWrapUntrusted` and its three siblings) marks a
   tool's output as untrusted data before the model reads it. The `web` and
   `web_search` outputs now reach the model inside a boundary that says the
   content is data, that directives inside it must not be followed, and that
   only the user can issue instructions; the content itself is unchanged, and
   only the model's copy is framed (= the user still sees the page's text,
   and the permission gate's own denial is left alone, because that is the
   app's message, not the tool's output). The high-risk list is a NAME list
   chosen for THIS app: hermes wraps `web_extract` plus any `browser_*` /
   `mcp_*` tool, and this app has none of those, so a literal copy of hermes's
   list would have wrapped nothing while appearing to be done. `delegate_research`
   is deliberately off the list (= it returns a "research delegated" receipt,
   not the fetched content). The three gap markers now state what was ported,
   with the real hermes path and the real line numbers.
2. **The suite is not green.** The baseline itself has failing tests, and
   the failures move between runs (= the timing tests are load-sensitive: one
   3-second auto-save test failed once under load and passed 5/5 in
   isolation). The gate is the failing-test SET, never the issue count.
   The delivered tree has 0 new failing names against the base-commit
   control.

   One environment caveat, measured: the XCTest phase of `swift test`
   intermittently deadlocks in test DISCOVERY (= `XCTestCase.allSubclasses`
   against the AddressBook framework's `CFPrefsSearchListSource` lock), before
   any test runs. It reproduces on unmodified main in a separate worktree, so
   it is not a property of any change. A run that hangs there produced no
   result at all; the Swift Testing phase is the part that reports.

### 6.2 The board and the tree

3. **Two cards are blocked and need a human.** `t_575a8577` (= the
   narrow-window crash) came back from review with no deliverable (= the
   worktree is clean at its base commit and the fix arm still crashed 10/10,
   so both acceptance criteria were unmet), and `t_22e72dc5` (= moving the
   tool contract, registry, executor and path guard into the WenshuAgent
   package) ran out of its wall clock twice with its move staged but
   uncommitted in its worktree. A blocked card waits for the boss.
4. **The orphan branch is gone.** `feature/inspector-wake` (= the
   inspector's page strip waking a hidden column, and a note on launching the
   app without taking the focus) had no card and would have been lost. It
   now has one (`t_0c4aa820`), and its work is on main.
5. **The worktrees are mostly cleaned.** Each card's worktree goes when its
   branch merges: `git worktree remove --force` then `git branch -D`. The
   merged cards' worktrees and branches are gone, and the branches whose
   content is already on main were removed after comparing them by CONTENT
   (not by SHA, because a rebased or cherry-picked branch carries the same
   change under a different SHA).
6. **The Info.plist card merged cleanly** (`0e9dbd405`) and its edit to
   `Tools/build-wenshu.sh` went with the file's deletion (= the board comment
   on that card was the right call).

## 7. The state at the end of the session

| Item | Value |
| ---- | ----- |
| `main` | `0bea8cac6` (= this session's commits + the parallel sessions' merges) |
| `origin` / `old-origin` | in sync with main (= the GitHub remote needs SSH over port 443 on this machine; = port 22 is closed by the local proxy) |
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

## 8. What the follow-up session added

The follow-up session worked this document's section 6 as its task list.

**Landed on main** (= each one commit, each one fast-forward):

| Card | What landed | Commit |
| ---- | ----------- | ------ |
| `t_0c4aa820` | The inspector's page strip wakes a hidden column, plus the launch note that keeps the focus off the user's machine | `4012a75f1` + `e3c2f118d` |
| `t_c50a2cdf` | The editor's selected tab shows its title; the user's own chat message gets a surface its words can sit on; the status bar stops slicing the last line | `5824726c7` + `0503303a5` + `a0720c5e3` |
| `t_937280a6` | The promptware defense (= the untrusted-tool-result wrapper) | `0bea8cac6` |

The three cards' branches carried the same content under different SHAs
(= a rebased or cherry-picked branch), so they were compared by CONTENT
before anything was deleted: `git diff main <branch> -- Sources/ Tests/`
on the files each commit touched, not a comparison of commit lists.

**One real conflict, resolved by keeping both intents.** The chat bubble
commit and main's band-height commit touched the same modifier chain
(`ChatMessageView.swift`): main's version drops the vertical padding and
floors the band at the composer's field height, and the bubble commit's
version replaces the glass fill with the semantic inactive-selection surface
and adds a hairline edge. The merge keeps both = the semantic surface, the
hairline edge, the shared `ChatSurfaceShape`, AND the height floor.

**The trial build.** The five fixes were combined into one bundle with a
unique bundle identifier, so it could not take the foreground from another
live instance, and it was captured in-process. The capture shows the
selected tab's title readable, the user bubbles on a distinct surface, no
raw translation key, and the inspector's empty state.

**Two lessons the board taught, and they are now in the skills.**

1. *A worker that burns its budget is a card problem, not a lost ticket.*
   The promptware worker spent two 45-minute budgets reading and wrote
   nothing (= 55 terminal calls, 0 writes, twice). The fix was to finish the
   change in the card's own worktree, which is what the worktree was for.
   The second attempt failed the same way even after the card body was
   rewritten to lead with the recipe instead of the architecture, so the
   body alone was not the lever.
2. *A branch that a card moved is a rename, and a rename plus an edit is a
   conflict waiting to happen.* The tool-mechanism move card relocates the
   very files the promptware wrapper lives in (= `ToolDispatchHelpers.swift`
   and `ToolExecutor.swift`), so the two cards had to be sequenced, not run
   side by side. The wrapper is in the file that moves, and the call sites
   are in the file that moves, so the two changes travel together. The move
   has since landed, and it carried the wrapper with it (= the wrapper and
   its two call sites are now in
   `Sources/WenshuAgent/Sources/WenshuAgent/Tool/`).

3. *A windowless app is a bundle problem until the bundle is controlled.*
   A review build launched, stayed alive for 98 minutes, and never produced
   a window. The first three experiments all pointed at the code: the
   bundle's base was 8 commits behind a base that worked, the ONE UI
   commit in that range was the obvious suspect, and rebuilding without it
   DID produce a window. All three were coincidence. The decisive control
   was to rebuild the SUSPECTED BASE IN THE SAME WORKTREE that had just
   produced a working window, changing only the commit: both bases
   produced a window on the first try. The variable that mattered was the
   bundle (= the unique bundle id, the re-sign, the seeded UserDefaults
   domain, and the worktree it was built in), not the code. The lesson is
   in the skill: control the bundle before you bisect the code, and treat
   an experiment as void if its artifact is deleted mid-run.

