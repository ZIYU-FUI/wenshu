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

4. *The suite gate has two halves, and only one of them hangs.* The gate is
   the SET of failing names, and the set has two parts: the Swift Testing
   summary and the XCTest summary. On this machine the XCTest phase of a
   FULL `swift test` deadlocks in class enumeration (= the AddressBook
   framework's preferences lock), before any test runs, and it does so on
   unmodified main too (= it is the machine, not the change). The XCTest
   half is still measurable, because the hang is in the enumeration and a
   NAMED filter skips it: naming the suites that carry the baseline's
   XCTest failures and running exactly those reported 99 tests and 13
   failures in 1.2 s, with the failing set IDENTICAL to the baseline's. So
   both halves of the promptware gate are measured (= 0 new names in the
   Swift Testing set, 0 new in the XCTest set), and the recipe is in
   `wenshu-visual-audit/references/measuring-the-xctest-half.md`.

5. *One name in the gate is a wall-clock flake, and it fails on the
   baseline too.* `TodoStoreTool.execute() returns in under 5 seconds`
   asserts that two concurrent tool calls finish inside a 5 second budget.
   On this machine that budget is a coin flip under load: the BASELINE
   passed it in 12.8 seconds, the loaded promptware run failed it in 8.6
   seconds, and in isolation it passes in 0.042 seconds. The same name
   appears in the baseline log, the main-without-the-change log, and both
   promptware logs, so it is a property of the box, not of any change. The
   rule that falls out of it: a wall-clock budget in a test is a flake
   generator on a loaded machine, so a name that appears in the BASELINE
   log is not evidence against a branch. Compare the failing SET, and
   exclude a name that the baseline also produces.

6. *The narrow-window card's premise was wrong, and its own harness is
   why.* `t_575a8577` asserted "THIS IS NOT THE INSPECTOR" on the strength
   of a 3/3 measurement. The single-variable pair, run with the harness's
   four identity defects fixed, says the opposite: the parent commit
   (= no inspector) crashed **0 of 10**, and the commit that adds the
   `.inspector` modifier crashed **10 of 10** with AppKit's own counter
   reading `limit: 342, count: 348`. The card's number came from a harness
   whose counter readback was dead (= it grepped a format AppKit does not
   emit), whose log predicate had no pid filter, and whose resize readback
   was discarded. The lesson is the one the card's own review already
   stated: **a rate measured by a harness with broken identity assertions
   is not a rate.** The measurement was the deliverable, and it had to be
   re-done before it could be believed.

7. *A harness's own abort can discard the very result it was looking for.*
   The arm aborted with "the resize never landed" when a trial CRASHED
   mid-drag, because the width could not be read back from a process that
   had already died. The arm therefore threw away the arm that reproduced
   the crash and kept the one that did not. A crash trial IS a trial where
   the resize landed (= the window was being resized when it died); only
   the readback is unavailable. Same shape as the dead-counter bug: the
   instrument fails in a way that is invisible in the summary line, and
   the failure is always in the direction that loses the result.

8. *The narrow-window crash is fixed: the nested split was reporting a
   second, competing width number.* The outer `NavigationSplitView`'s
   detail column hosts an AppKit `NSSplitViewController`, and the default
   `sizeThatFits` reported that inner split's OWN size to the SwiftUI
   layout engine. So the outer split negotiated the column width against
   a number the nested split kept recomputing, each negotiation re-armed
   the window's "Update Constraints in Window" pass, and AppKit's
   runaway-layout guard aborted the app once the count passed the
   window's view count. Reporting the parent's PROPOSAL instead makes the
   reported size a function of the parent's own layout, so the feedback
   loop has nowhere to close. Measured over 10+ trials per arm, each arm
   with its own worktree, build directory, binary uuid and bundle id, and
   a crash counted only when a crash report carried that arm's uuid AND
   the expected AppKit frame: the parent commit 0/10, the commit that
   adds the inspector 10/10, HEAD 10/10, HEAD + the fix 0/10, and the
   fix on top of current main 0/12. The fixed build narrowed the window
   to 711 px, which is narrower than the 897 px the crashing build
   reached (= the fixed window is not sitting at its floor being
   refused; it really did resize).

   Two things worth keeping from that: the card's own premise ("THIS IS
   NOT THE INSPECTOR") was wrong and the reason it was wrong was the
   measurement, not the reasoning; and the skill's OTHER named suspect
   (= value-guarding the thickness write in `viewDidLayout`) is a real
   self-feeding loop but does NOT fix this crash on its own (10/10). It
   had only ever been tested bundled with a second change, so it had
   never been isolated. A suspect named by a skill is a hypothesis, not
   a measurement.

9. *A failing test's SET can differ between two runs of the SAME code.*
   The narrow-window fix was gated on "no NEW failing name versus the
   baseline", and four full-suite runs of the SAME two commits produced
   four different sets, each with one or two names the others did not
   have. Reading them as a branch difference would have been wrong:
   every disputed name flips between runs of the SAME branch and the
   SAME code, so none of them is a property of a change. The
   mechanisms, each proven rather than assumed:

   - `FileTools` fails ONLY in a worktree under `/.hermes/`, because
     `FileTools.swift`'s path guard deny-list contains `/.hermes/` and
     the tests write to `FileManager.default.currentDirectoryPath`. The
     report says it outright: `Caught error: .pathDenied(path:
     "/Volumes/ANAN/.hermes/.../wt-loadmain/.test-test-924327EB.txt")`.
     The same tests PASS in a worktree under the repo. So the failing
     set depends on WHERE the worktree lives, which is a property of
     the harness, not of the diff.
   - `ToolRegistry` (3 names) fails in three of the four runs and passes
     in one; `TodoStoreTool` is the known 5-second wall-clock budget;
     the conductor test is a ~30-second timeout at the edge of the
     machine's capacity; the provider test whose name means "network fail
     returns curated fallback" asserts that an HTTP call FAILS, so it passes
     or fails with the network's reachability (it passes 4/4 in isolation
     on both branches).

   The rule: **compare the failing set only across runs that share the
   same worktree LOCATION, the same load, and the same protocol.** A
   name that appears in one run of a branch and not another is a
   candidate for investigation, never evidence of a regression, and the
   cheapest way to tell them apart is to run the disputed test in
   isolation on BOTH branches: if it passes on both, it is the
   environment.

## 9. The state at the end of the follow-up session

Section 6 is the first session's record and is left as it was written.
This section is the current handoff, and it supersedes section 6.2's
"two cards are blocked" (= both of them are done now).

### 9.1 Landed on main, each one commit, both remotes in sync

| Card | What landed | Commit |
| ---- | ----------- | ------ |
| `t_0c4aa820` | The inspector's page strip wakes a hidden column | `4012a75f1` + `e3c2f118d` |
| `t_c50a2cdf` | The editor's tab title, the user chat bubble's surface, the status bar | `5824726c7` + `0503303a5` + `a0720c5e3` |
| `t_937280a6` | The promptware defense | `0bea8cac6` |
| `t_22e72dc5` | The tool mechanism moved into the `WenshuAgent` runtime package | (carried the promptware with it) |
| `t_575a8577` | **The narrow-window crash is fixed** | `0b871acb0` (= merge `8350ddbe7`) |
| `t_4bd0e18b` | The kanban window shows the board for the selected book | `a6fb46ab7` |
| `t_ff446c5d` | The chat bubble's palette moved to its own file | `4012a75f1` |

The narrow-window fix: `EditorChatSplitHost.sizeThatFits` reports the
size the PARENT proposed, instead of letting the default implementation
report the inner `NSSplitViewController`'s own size. The outer
`NavigationSplitView` was negotiating its detail column's width against a
number the nested split kept recomputing; each negotiation re-armed the
window's "Update Constraints in Window" pass, and AppKit's runaway-layout
guard aborted the app once the count passed the window's view count.

Measured over 10+ trials per arm, each arm with its own worktree, build
directory, binary uuid and bundle id, and a crash counted only when a
crash report carried that arm's uuid AND the expected AppKit frame:
parent commit 0/10, the commit that adds the inspector 10/10, HEAD
10/10, HEAD + the value-guarded thickness write 10/10, HEAD + the fix
0/10, and the fix on top of current main 0/12. The fixed build narrowed
the window to 711 px, narrower than the 897 px the crashing build
reached (= it really resized rather than being refused at its floor).

### 9.2 Open, and what it needs

1. **`t_c8c53697` (= the provider fallback test) is blocked, with the
   seam written and compiling.** Two worker runs spent their budget in the
   build and the XCTest discovery phase. The work is PARTIAL and it is on
   disk: `ProviderFetcher.swift` carries a `ProviderLiveModelFetching`
   protocol plus a `CachedLiveModelFetcher` production implementation
   (+27 lines, unstaged, in the card's worktree), and it compiles. What
   remains: wire the fetcher through `loadModelIds`, rewrite the two
   tests against the seam, and gate with `swift test --filter
   ProviderFetcherTests` rather than the full suite. The exact handoff is
   in the card's comment.

2. **`t_c8f6aaec` (= moving the agent runtime into the `WenshuAgent`
   package) is blocked**, with three file renames staged and uncommitted
   in its worktree. It belongs to a sibling session.

3. **The narrow-window harness is durable, but it is NOT in the repo.** It
   lives in the `macos-narrow-window-layout-crash-triage` skill's
   `scripts/` (= `arm2.sh`, `drag3.swift`, `commit_test.sh`,
   `assemble.sh`, `reset-trial.sh`). The original lived in the card
   worktree's gitignored `.scratch/` and died with the worktree when the
   dispatcher removed it on completion. Keep the harness OUTSIDE a
   ticket's worktree, or the evidence dies with the tool that produced it.

### 9.3 The environment, measured and recorded

- The XCTest phase of a FULL `swift test` deadlocks in class enumeration
  on this machine (= `allSubclasses` -> `ABAddressBook` ->
  `CFPrefsSearchListSource`), before any test runs, and it reproduces on
  unmodified main. The XCTest half is still measurable: the hang is in
  the enumeration, so a NAMED filter skips it. The recipe is in the
  `wenshu-visual-audit` skill's `references/measuring-the-xctest-half.md`.
- The failing SET moves between runs of the SAME code (lesson 9 above).
  Compare sets only across runs sharing the same worktree LOCATION, the
  same load and the same protocol.
- A background process's exit code can belong to a LATER command in the
  chain: `grep -c` exits 1 when it matches nothing, so a clean build can
  report exit 1 (pitfall 34 in `wenshu-pocock-workflow`).
- Both git remotes sit behind the local proxy. GitHub needs port 443
  (`ssh -p 443 -o Hostname=ssh.github.com`); gitcode needs port 22 to
  the RESOLVED IP. The exact commands are in `wenshu-parallel-dev`.
## 10. The state at the end of the second follow-up session

This session RE-OPENED the narrow-window question, because the first
follow-up's conclusion and this session's own first reading of it
disagreed. Both were wrong in a way that only a rebuild settles.

### 10.1 The root cause was the size report, not the nested split

The first follow-up landed `0b871acb0`, which overrides
`EditorChatSplitHost.sizeThatFits` to report the PARENT's
`ProposedViewSize` instead of the wrapped `NSSplitViewController`'s own
size. THIS session's first reading was that the crash was caused by the
nested split itself, and that the fix should be to remove it (a pure
SwiftUI `VSplitView`, or moving the nested split out of the
`NavigationSplitView`).

**That reading was wrong**, and the reason it was wrong is worth
recording: the A/B that produced it moved TWO variables at once (the
nested split AND the commit), so a difference in crash rate could not be
attributed to either. The skill had already warned about this - "the two
arms must differ in ONE thing" - and the warning was ignored.

The real mechanism: `NSViewControllerRepresentable.sizeThatFits(_:nsViewController:context:)`
(macOS 13+) DEFAULTS to reporting the WRAPPED AppKit controller's own size
to the SwiftUI layout engine. The outer `NavigationSplitView` therefore
negotiates its detail column's width against a number the nested split
keeps recomputing; each negotiation re-arms the window's "Update
Constraints in Window" pass; the count passes the window's view count and
AppKit aborts the app. Reporting the parent's PROPOSAL makes the reported
size a function of the parent's own layout, so the feedback loop has
nowhere to close.

The fix KEEPS the nested split and keeps the chat pane. Removing the
nested split is not required, and would have cost the Keynote-style
collapse behaviour.

### 10.2 The binary under test was PRE-FIX, and that nearly repeated the mistake

The shared `build/Wenshu.app` is rebuilt by other sessions and by every
ticket, so it can easily predate a fix by hours. This session measured
"the fix does not work: 2/6 still crash" against a binary built at 00:16,
while the fix was committed at 01:58. The timeline, not the crash rate,
was the answer.

After rebuilding from the current HEAD:

| build | crashes | valid | resizes landed | narrowest |
| --- | --- | --- | --- | --- |
| pre-fix (00:16, uuid `1D2FC41E`) | 2 | 2 | 5 | 1250 |
| **fixed (07:00, uuid `7A55E7AC`)** | **0** | 6 | **73** | **711** |

The fixed window reaches 711 px where the crashing one stopped at 897 px.
Reaching NEW, NARROWER widths is the pattern that proves a fix; a window
that merely refuses to shrink has not been fixed, it has been stuck.

So a "the fix does not work" report is exactly as wrong as an "it is
fixed" report. Both need the binary's identity AND its build time.

### 10.3 A trial with NO WINDOW can still be a CRASH

The pre-fix run reported "2 crashes, 4 VACUOUS" - but the crash-report
corpus held SIX reports carrying that arm's binary uuid. The four
"vacuous" trials were crashes too: the app had already died, so the AX
window check found no window and filed the trial as "never reached the
editor".

"No window" is AMBIGUOUS: onboarding, an app that already died, or a
window that is still opening (~20 s). Classify by the crash report FIRST
(a report carrying this arm's uuid = a crash, whatever the window count),
and only call a trial vacuous when there is NO report AND no window.
Otherwise a crash-heavy arm is silently filed under "vacuous" and its
rate is understated - the failure always runs in the direction that loses
the result.

### 10.4 A staircase where BOTH arms clamp at the same floor is a fixture bug

The first width-staircase measurement had both arms clamp at exactly
1815, contradicting a three-arm run where the nosplit arm landed 13
distinct widths. The FIXTURE was the cause, not the arms: the staircase
ran against the harness's COPY of the library, and the copy (made without
the sqlite WAL) held different content, so the columns negotiated
differently. Re-run against the ORIGINAL library, both arms back to back,
one variable:

| arm | opened at | floor reached | distinct widths landed | outcome |
| --- | --- | --- | --- | --- |
| ctrl (nested split present) | 2177 | **1815** | 0/18 | **DIED** at target 800 |
| nosplit (plain SwiftUI stack) | 1452 | **1118** | 8/18 | survived, no crash |

A measurement where EVERY arm lands on the identical number is a broken
fixture until proven otherwise. It reads exactly like a real effect (a
shared floor IS plausible), so it is worth a fixture check before it is
worth a theory.

### 10.5 The suspect that was NOT the cause

`NSSplitViewController.viewDidLayout()` writing `item.minimumThickness`
/ `item.maximumThickness` on every layout pass IS a real self-feeding
loop, and writing each value only when it differs is correct in its own
right. Measured on its own it does NOT fix this crash: **10/10 still
crashed**. It had only ever been tested bundled with a second change, so
it was never isolated. A suspect named by a skill (or by a previous
attempt) is a HYPOTHESIS, not a measurement.

### 10.6 The measurement record is durable, in the skill

`references/measurements-2026-10-21.md` in the
`macos-narrow-window-layout-crash-triage` skill holds the numbers behind
the fix: the 748 "Marking window" events of which **582 had `count` above
`limit`** (by up to +9), the 1815 floor arithmetic (200 + 240 + 1374),
the per-arm crash table, and the UserDefaults audit of every arm.

The harness also moved into the skill's `scripts/`: `verify_fix.sh`
(verifies a SHIPPING binary - own bundle id, own bookmark, own library
copy, polls for the window, reads every resize back), `set_lib2.py`
(writes a plain, NOT `.withSecurityScope`, bookmark into a test domain),
`verify_uuid.py` and `final_verdict.py` (match a report corpus against
one binary's uuid), and `domain_audit.py` (did the arm reach the editor?).

### 10.7 The residue this session cleared, and what it kept

The skill's wrap-up rule is "leave no residue of your own, and account for
all seven kinds before answering". This session's inventory found and
cleared:

| Kind | Found | Action |
| --- | --- | --- |
| App instances | 4 orphans from MY harness bundles (up to 8 h 24 m) | killed |
| Stale shells | 6 shells whose cwd had been deleted (up to 8 h 50 m) | killed |
| Scratch entries | 678 of 709 entries, 183 MB | deleted |
| Crash reports | 74 reports from MY invalidated early batches | deleted |
| Test domains | 2 (`com.wenshu.verify.test`, `com.wenshu.harness.test`) | KEPT - the delete was not approved |

KEPT, deliberately:

- **The boss's 30 `WenshuApp-*.ips`** = the real crash corpus. Never
  touched.
- **41 `WenshuArm2*` / `WenshuFix` reports** = the shipped fix's A/B
  corroboration.
- **Three worktrees**: `t_c8c53697` (1 unstaged file, a compiling seam)
  and `t_c8f6aaec` (34 staged paths) hold REAL work for two BLOCKED
  cards, and both cards carry a handoff comment naming the exact state.
  `subagent-sa-0-0a8132df` has a LIVE process with its cwd inside it.
- **A sibling session's live work**: at 07:43 another session started
  writing into this profile's scratch (`hig/`, `docs/`, `keynote_*`,
  the `*.py` probes) and had a `swift-build --scratch-path .../wenshu-build`
  RUNNING against it. All of it is left alone, and its 559 MB build dir
  is why the scratch area still reads 564 MB.
- **The production domain** `com.wenshu.app` and the ORIGINAL library
  `~/Documents/anbaiqiang.ws`.

Two deletions were not approved and are still on disk:
`~/Library/Preferences/com.wenshu.verify.test.plist` and
`~/Library/Preferences/com.wenshu.harness.test.plist` (3191 and 90756
bytes). Both are test-only domains; they affect nothing that runs.

### 10.8 The state at the end of the second follow-up session

| Item | Value |
| ---- | ----- |
| `main` | `bdec990f6` (= in sync with `origin/main` and `old-origin/main`) |
| The working tree | clean |
| The narrow-window fix | `0b871acb0`, on main, verified 0/6 crashes on a fresh build of HEAD |
| The app bundle | rebuilt 07:00 from HEAD (= contains the fix); the boss must rebuild if he runs a copy from elsewhere |
| The harness | in the `macos-narrow-window-layout-crash-triage` skill's `scripts/`, plus `references/measurements-2026-10-21.md` |
| Open cards | `t_c8c53697` and `t_c8f6aaec`, both BLOCKED, both with work on disk and a handoff comment |
