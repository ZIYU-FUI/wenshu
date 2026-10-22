# Parallel development

Wenshu's convention for running multiple development sessions at once without
colliding.

## The rule

**Every code-changing ticket runs in its own git worktree. It does not touch the shared
checkout.**

The shared checkout at `/Volumes/ANAN/Engineering/wenshu` (branch `main`) is for read-only
work, for the boss's merges, and as the base commit a worktree branches from. A session
that writes a feature there while another session is live is the failure this convention
prevents.

## Why

Two Hermes sessions in one working tree interleave their git operations. One session's
`git stash` removes the other's staged work. One session's `git add -A` sweeps the other's
in-flight files into its commit. `git status` changes between two consecutive reads. The
symptom is a working tree that moves under you, with stash entries appearing and
vanishing.

A worktree removes the conflict at the filesystem level. Each ticket gets its own branch
and its own checkout, so file-level interference cannot happen.

## The board

The board is the shared task queue across sessions. Profiles are the team members. The
dispatcher (running inside the gateway, one tick per minute) is the lead that claims
tasks and spawns workers.

| Piece | Value |
| ----- | ----- |
| Board | `wenshu-par` |
| Board default workdir | `/Volumes/ANAN/Engineering/wenshu` |
| Implementer profile | `wenshu-dev` |
| Reviewer profile | `wenshu-review` |
| Task branch | `project/<task-id>-<slug>` |
| Task worktree | `<repo>/.worktrees/<task-id>` |

## Creating a ticket

Write the body first, then rate it:

```bash
cd /Volumes/ANAN/Engineering/wenshu
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md
```

The tier is derived from the work the body describes, never hand-set. It
decides the cap, the retry budget, the gate width and the body budget.

```bash
hermes kanban create "[<tier>] <ticket title>" \
  --assignee wenshu-dev \
  --workspace worktree \
  --project project \
  --body-file card.md \
  --max-runtime <tier cap> \
  --max-retries <tier budget>
```

| Tier | Cap | Retries | Body budget | Gate |
| ---- | --- | ------- | ----------- | ---- |
| T1 | 15m | 2 | 4000 chars | build + ONE filtered suite |
| T2 | 25m | 3 | 10000 chars | build + a filtered suite per touched area |
| T3 | 45m | 5 | 32000 chars | the full gate set |

`--workspace worktree` is what makes the task isolated. `--project project` anchors the
worktree under this repo's `.worktrees/` with a deterministic branch name. Both flags
matter; see the pitfalls below.

The body is the worker's entire spec. An empty body means the worker improvises. Always
state what to build, how it is accepted, and which files are out of scope.

The tier never skips the dual-axis review and never marks a test skipped. It sizes the
clock and the gate, nothing else. `docs/agents/ticket-tiers.md` carries the derivation
and the measurements behind the numbers.

## Watching and dispatching

```bash
hermes kanban list             # board state
hermes kanban show <task-id>   # status, runs, summary, metadata, event history
hermes kanban watch            # live event stream
hermes kanban dispatch         # force one dispatch tick now
hermes kanban stats            # per-status and per-assignee counts
```

The dispatcher already runs every 60 seconds inside the gateway. `dispatch` is only for
when the boss wants work to start now.

## The review loop

A worker ends its run with exactly one of:

- `kanban_complete(summary, metadata)` = done.
- `kanban_request_review(summary, metadata, reviewer="wenshu-review")` = the card moves
  to `review`; the dispatcher re-claims it with the bundled `sdlc-review` skill; the
  reviewer approves or calls `kanban_request_changes`, which routes the card back to its
  original implementer.
- `kanban_block(reason)` = waiting on a human. The boss comments and unblocks it.

A worker that exits without one of these counts as crashed and is retried. After two
consecutive failures the card auto-blocks.

## Context handoff between cards

A new card with `--parent <done-task-id>` inherits the parent's completion summary and
metadata (changed files, decisions) verbatim, and becomes eligible as soon as the parent
is done. Follow-up work on a finished card is a new child card, never a reopened one.

## Merging back to main

The worker commits on its own branch inside its own worktree. The boss merges:

```bash
REPO=/Volumes/ANAN/Engineering/wenshu

# 1. Preflight: will this card conflict with main?  (read-only; exit 1 = conflict,
#    and the conflicting paths are printed)
"$REPO/Scripts/merge-preflight.sh" <card-branch>

# 2. Rebase the card branch onto main INSIDE ITS WORKTREE (= where a conflict is
#    resolved in isolation, where it cannot destroy a sibling's staged work)
git -C "$REPO/.worktrees/<task-id>" rebase main

# 3. Fast-forward main into the branch (= one commit per ticket, rule 7.8)
git -C "$REPO" merge --ff-only <card-branch>
```

Merge one branch at a time, rebuild, then the next. Two branches touching the same file
conflict for real, and the same file touched by two tickets is a collision hotspot.

Never resolve a conflict in the shared checkout, and never `git reset --hard` `main`
there: a reset is the one operation that destroys a live sibling's staged work.

Two kinds of collision exist, and they need different fixes. **Text conflict** = two
branches edited the same lines (measured: 1 real conflicted merge in the last 30 days).
**Base drift** = the card branch is behind `main`, so the merge builds a merge commit
instead of a fast-forward (measured: 76 `ort` landings vs 14 fast-forwards). Drift is
not a conflict, and the rebase in step 2 is its fix.

## The string catalog merges by key

`Localizable.xcstrings` is the most-touched file in a wave, and its keys are NOT
sorted (= a new key lands in the MIDDLE of the file). Two cards that each add a
DIFFERENT key therefore collide textually, because both insertions land in the same
neighbourhood. Measured: `git merge-tree` on two branches adding one distinct key each
= CONFLICT.

`Scripts/merge-xcstrings.py` is a merge driver that merges the catalog at the KEY level,
so that class of collision does not happen. A genuine disagreement (= the same key, two
different values) still conflicts, and the driver NAMES the key, so the resolution is
about a string rather than a marker in a 6400-line file.

Verified on this repo: the SAME two branches, each adding one distinct key, conflict
without the driver (`merge-tree` rc=1) and merge cleanly with it (rc=0). The driver's
test suite is `Tools/wenshu-devtool/tests/test_merge_xcstrings.sh`.

## The nervous file index merges by key, in its own file

`AGENTS.md` is the wave's second magnet (4 cards write it), and its nervous file index
table is APPEND-ONLY (= a new row lands at the END). Two cards that each add a row
therefore collide textually, because both insertions write the same last line.

Measured, before choosing a fix:
- both cards APPEND a row = CONFLICT
- both cards INSERT a sorted row = STILL a conflict (= sorting does NOT help, the hunks
  end up adjacent)
- `merge=union` = merges, but it keeps BOTH versions of a disagreeing row as two rows
  with the same key, silently (= measured: one extracted file appeared twice, with LOC
  777 and LOC 888)

So the table moved to `docs/agents/nfi.md` with its own key-level driver
(`Scripts/merge-nfi-registry.py`, the same shape as the catalog's). Two cards' rows both
survive, and a genuine disagreement still conflicts with the key named. `AGENTS.md` keeps
the rule and points there; its PROSE keeps the normal merge (= a union merge there would
keep both versions of a rewritten paragraph instead of reporting the disagreement).

All 30 rows were carried over verbatim, in order.
`python3 Tools/wenshu-devtool/nfi-split.py --check` verifies the split against the
table's last home in git history. The driver's test suite is
`Tools/wenshu-devtool/tests/test_nfi_registry.sh`.

The driver needs two local settings, and `Scripts/setup-dev-env.sh` installs both:

```bash
git config merge.xcstrings.driver "python3 Scripts/merge-xcstrings.py %O %A %B"
git config merge.nfi-registry.driver "python3 Scripts/merge-nfi-registry.py %O %A %B"
git config rerere.enabled true
```

`.gitattributes` (tracked) carries the `*.xcstrings merge=xcstrings` and
`docs/agents/nfi.md merge=nfi-registry` rules; the `git config` values are LOCAL (= `.git/config`,
not committed), so a fresh clone installs them via `setup-dev-env.sh`. `rerere` records how a
conflict was resolved once and replays it the next time the same conflict appears on the
same file: the recurring magnets then cost one resolution per wave instead of one per
card.

## The wave's file ownership, checked before dispatch

Two cards that write the same file cannot land in any order without a text conflict.
The card body names every file the worker will touch, in SECTIONS (= WHAT TO BUILD vs
MUST NOT CHANGE), so the collision is knowable before the wave starts:

```bash
python3 Tools/wenshu-devtool/wave_gate.py --plan
python3 Tools/wenshu-devtool/wave_gate.py --live
```

It prints the magnet files, the colliding pairs, and the STALE must-not-change lists
(= one card writes a file another card was told to leave, so the second card's list is
already out of date when it lands). `--plan` prints the `hermes kanban link` order that
serializes the collisions.

Read the SECTIONS, not the raw body: a naive scan that counts every path mentioned
over-reports 5x (90 of 153 card pairs, against 16 real ones), because a body mentions a
file it will only READ and a rule it cites ("AGENTS.md §7.3").

The gate reads the card the way the card is written, which took four fixes:

- `hermes kanban show` prints the body AND the comments AND the event log under the
  same stream. Taking everything after `Body:` swept the comments in, so a comment that
  named a file made the gate report that card as writing it. The body ends at
  `Comments (N):`.
- A path under `MUST NOT CHANGE` is not always forbidden. A card can list a file there
  and still be told to add a row to it (= the nervous file index, which every card
  appends to), so the classification is per BULLET and a bullet that grants a write
  wins.
- A path and the sentence that grants the write are two sentences of ONE bullet, so
  the section is split into bullets, not sentences.
- A cited rule is not a write. The pattern allows a closing backtick and a space
  between the filename and the marker, and a decimal section number
  ("`AGENTS.md` §7.3").

The gate also reads `.gitattributes`, so a file with a merge driver is reported as
"handled by a merge driver" instead of a collision to serialize: the driver merges it at
the key level, so both cards keep their row. On the current board that moved 7 pairs
(every xcstrings pair) out of the collision list.

The gate's test suite is `Tools/wenshu-devtool/tests/test_wave_gate.py`.

### The gate reports; it does not block

The gate is a report, not an interceptor, and that is a measured decision. Of the 26 card
pairs that share a file, only 7 were ever in flight at the same time (= the board's own
`task_runs` windows); the other 19 ran in sequence and could never collide. Of those 7,
3 were the string catalog (now solved by its driver), 2 were `AGENTS.md` (now solved by
the registry's own file and driver), and 2 were real code conflicts in
`ChatMessageView.swift` (= a genuine disagreement, which SHOULD conflict). Interception
would gate ~2 pairs by changing the Hermes dispatcher (a different repo) or hooking
`hermes kanban create` (a step that can fail).

The serialization primitive already exists and needs no new code:
`hermes kanban link <parent> <child>` makes the board hold the child until the parent is
done (the dispatcher's `claim_task` refuses a `ready` card whose parents are open). The
gate prints the plan; the boss applies it.

## Fan-out

When one request splits into independent tickets, create one card per ticket. The
dispatcher runs them side by side, each in its own worktree.

```bash
hermes kanban swarm "<goal>" \
  --worker wenshu-dev:"<title A>" \
  --worker wenshu-dev:"<title B>" \
  --verifier wenshu-review \
  --synthesizer pocock
```

The swarm creates a durable graph: N parallel workers, then a verifier gated on all of
them, then a synthesizer gated on the verifier. The root card is the shared blackboard
that every worker reads.

## Collision hotspots

When several workers each add a little to the same file, that file becomes a conflict
magnet. The worker that notices leaves a comment on its own card:

```
hotspot: Sources/WenshuApp/Features/Agent/Store/SubAgentRunner.swift — third conflicting edit this wave
```

Two or more `hotspot:` comments naming the same path means: create a dedicated refactor
card for that file before queueing more work that touches it.

When two branches already conflict, do not let either worker self-adjudicate. Create a
reconciliation card assigned to a third neutral profile, with both conflicted cards as
parents, so the reconciler receives both diffs and both intents.

## Pitfalls

1. **A worktree branches from `HEAD`, not from uncommitted work.** If the shared checkout
   is dirty, the workers cannot see those changes. Commit the boss's own work first. If
   the dirt belongs to a live sibling session, leave it alone and merge separately.
2. **Board state is global; project bindings are per profile.** `hermes kanban boards list`
   shows the same boards everywhere. `hermes project list` does not: each profile has its
   own `projects.db`. Use `--project project` only from a profile that has the binding.
3. **`--workspace worktree` without `--project` anchors to the board's default workdir**,
   which is the repo root. The dispatcher still isolates it, but the task row's
   `workspace_path` reads like the shared checkout. Check the `workspace` line in the
   dispatch output, not the row.
4. **Do not `git add -A` in the shared checkout.** It sweeps a live sibling's in-flight
   files into your commit. Stage by path and verify with `git diff --cached --name-only`.
5. **Do not `git stash` in the shared checkout while a sibling is live.** It removes the
   sibling's staged work.
6. **Clean up finished worktrees.** After a merge: `git worktree remove <path>` then
   `git branch -D <branch>`. `hermes worktree prune` reclaims safe ones.
7. **A dirty tree is not proof of a live sibling.** The boss's own unpushed work looks
   identical. Check the session store before concluding.
8. **Keep a ticket's worktree OUT of the shared repo's `.worktrees/`.** That directory is the
   prune target: a parallel session's cleanup removes worktrees from it mid-run, and a
   `git worktree add <path> <branch>` on a branch that is already checked out fails outright
   (= `fatal: 'main' is already used by worktree at ...`). Keep long-lived worktrees under the
   session's own scratch directory and use `git worktree move` to relocate one.
   The branch and its commits survive the move.
9. **The saved layout defaults must be cleared before each verification run.** The app persists
   its `NSSplitView Subview Frames ...` and `NSWindow Frame ...` values, and a stale set whose
   columns total more than the next run's window width changes how the window lays out.
   It reproduces on the pre-removal commit too, so it is not a restore artifact.
10. **Do NOT read a window death as a failure of the code under test.** AppKit's "Update
    Constraints in Window pass" guard kills the window when a drag delivers enough resize
    events, and it fires on the commit WITHOUT the right rail exactly as it fires with it.
    The cause is two split systems in one window (the SwiftUI `NavigationSplitView` whose
    detail column hosts the AppKit `NSSplitViewController`), not the inspector.
    Triage it with the `macos-narrow-window-layout-crash-triage` skill.
11. **Run the baseline and the branch in the SAME conditions, alternating, several rounds.** One
    run each is not enough: a parallel session's `pkill` (its own build's full executable path
    can match yours if the paths share a prefix) kills an instance mid-measurement and reads as
    a failure of the code under test.

## Live sibling detection

```bash
sqlite3 ~/.hermes/profiles/<profile>/state.db \
  "select id, source, git_repo_root, datetime(last_activity_at,'unixepoch') from sessions where git_repo_root = '/Volumes/ANAN/Engineering/wenshu';"
```

A row with a recent `last_activity_at` is live. A row that exists but is old is a
finished session, not a conflict.

## Launching the app for verification

Never launch the Wenshu app by exec'ing its binary (`.../Wenshu.app/Contents/MacOS/WenshuApp &`).
The app calls `NSApp.activate` and jumps to the frontmost position, so the user loses focus
mid-work. Launch with `open -g` (= no activation).

`~/.hermes/profiles/pocock/skills/wenshu-visual-audit/scripts/wenshu-shot.sh` implements the
whole no-focus contract: `launchctl setenv` + `open -g` + an in-process render (so no screen
recording permission) + `axwin` for the resize (the System Events bridge activates the app, so
never use it). Set `WENSHU_APP` to choose which build it launches.

Two traps when a session has its own build:

- Address the instance by its FULL executable path. A loose `build/Wenshu.app` pkill pattern
  matches every session's bundle, so it kills a parallel session's app and then kills yours
  mid-run.
- A readiness check must not have side effects. Running the full AX probe (which presses
  buttons) as the "is the app up yet" check toggles the inspector during startup and leaves
  the app in an unexpected state before the real run. Use `axwin probe` for readiness.
- The app can own more than one window. The welcome / onboarding page is a different window
  from the main workspace window, so taking the first window of the instance can drive the
  welcome page and measure nothing. Select the main window by CONTENT (= it shows the shelf
  column and the assets column and has at least 3 AXSplitters) and abort when it is absent.

The rules that govern a verification run itself (which worktree to use, which saved layout to
clear, how to read a window death, how to alternate the baseline and the branch) are numbered
items 8 to 11 of the Pitfalls list above.

## Why `delegate_task` is not used for code here

With `delegation.worktree_isolation: true`, each delegated child gets its own worktree,
but the child's terminal inherits the parent's cached shell environment, whose working
directory was already fixed to the parent's. Measured: the child's `pwd` was the shared
checkout, and a relative write landed there, mixed into the boss's own uncommitted
changes. The isolation note appended to the goal states that the terminal already starts
inside the worktree, which is false for the shell.

A board worker is a separate process launched with `cwd=workspace` and
`TERMINAL_CWD=workspace`, so its shell genuinely starts inside the worktree. Verified: a
board worker's `pwd` was `<repo>/.worktrees/<task-id>` with no `cd` needed, and it loaded
this repository's `AGENTS.md` and `.hermes.md` from the worktree.

`delegate_task` remains the right tool for read-only fan-out here: audits, inventories,
research, and spec-axis review.

## Wrap-up: leave no residue

A session's own residue is the session's job. Not the dispatcher's, not the next
session's, not the boss's. This is a hard requirement at the end of every session
that created anything, and it is the last thing done, after the last commit and the
last push.

Measured on 2026-10-21/22, one session that landed six tickets left behind: 7
worktrees (4 of them scratch worktrees outside `.worktrees/`), 2 merged branches
whose work was already on main, 7 orphaned app instances (the oldest had been
running 11 h 53 m), 2 hung test processes, 1 CPU burner, and 4.4 GB of scratch
directories (one `--scratch-path` build dir alone was 561 MB). Every item was free
to delete, and every item was still there at the end.

Account for all seven kinds before answering the boss:

| # | Residue | Check |
| - | ------- | ----- |
| 1 | Worktrees (repo, scratch, `/private/tmp`) | `git worktree list` + `ls -d .../scratch/wt-*` |
| 2 | Branches (a card's branch outlives its worktree) | `git branch -vv` |
| 3 | App instances (a harness launches and never reaps) | `ps -axo pid,etime,%cpu,command \| grep -E "WenshuArm\|<your-build>"` |
| 4 | Test processes (a killed `swift test` leaves its child) | `ps -axo pid,etime,command \| grep -E "xctest\|swift-test"` |
| 5 | Load (a runaway loop of your own making) | `ps -axo pid,command \| grep -E "^\s*[0-9]+\s+yes$"` |
| 6 | Build dirs (the biggest consumers, outside the worktree) | `du -sh .../scratch/* \| sort -rh` |
| 7 | Harness bundles and reports | `find .../scratch -maxdepth 2 -name "*.app"` |

Delete only what is proven dead, and prove it four ways (0 unstaged, 0 staged, 0
branch commits, no process with its cwd there), plus `git merge-base --is-ancestor`
for a detached worktree whose commit may be on main under a different sha.

```bash
git worktree remove --force <path>     # git must unregister it; `rm -rf` alone does not
git worktree prune                    # reclaim the ones git already knows are gone
git branch -d project/<id>-<slug>     # -d, NOT -D: -d refuses an unmerged branch
```

`git branch -d` is the proof: a successful `-d` means the branch's work is already
on main, and `-D` would happily discard a commit nobody merged. The `--scratch-path`
build dir goes with it, because it lives OUTSIDE the worktree and removing the
worktree does not touch it.

Keep: the app the boss is looking at, a live card's worktree (it holds the
evidence and the next worker picks it up there), and anything another session owns.
Another profile's scratch directory is not yours to sweep, even when you can see
its leftovers; leave them and say so.

Close with the residue named. "Scratch is 183 MB, two card worktrees kept (one holds
a compiling seam, one holds a sibling's 34 staged paths), the boss's app running" is
a handoff. "Cleaned up" is not. A residue you could not clear is still residue:
name the path and what it holds.

A WORKER is bound by the same requirement, before it calls `kanban_complete`: the
app instances it launched, the test processes it killed, the build dir it created,
and the harness bundles and reports it made. Its completion metadata says what it
cleared and what it left, and why.

## References

- `AGENTS.md` rule 1.12 = the rule. Section 8.2 = where it enters the pipeline.
- `.hermes.md` = the startup pointer every session reads.
- `~/.hermes/profiles/pocock/skills/wenshu-parallel-dev/SKILL.md` = the execution
  contract, including the full command reference and the generic Hermes mechanism
  background.
- `docs/agents/issue-tracker.md` = the local markdown issue tracker that the board
  complements.
