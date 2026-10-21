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

```bash
cd /Volumes/ANAN/Engineering/wenshu
hermes kanban create "<ticket title>" \
  --assignee wenshu-dev \
  --workspace worktree \
  --project project \
  --body "<spec: what to build, acceptance criteria, what NOT to touch>" \
  --max-runtime 30m
```

`--workspace worktree` is what makes the task isolated. `--project project` anchors the
worktree under this repo's `.worktrees/` with a deterministic branch name. Both flags
matter; see the pitfalls below.

The body is the worker's entire spec. An empty body means the worker improvises. Always
state what to build, how it is accepted, and which files are out of scope.

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
git -C /Volumes/ANAN/Engineering/wenshu merge project/<task-id>-<slug>
```

Merge one branch at a time, rebuild, then the next. Two branches touching the same file
conflict for real, and the same file touched by two tickets is a collision hotspot.

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

## References

- `AGENTS.md` rule 1.12 = the rule. Section 8.2 = where it enters the pipeline.
- `.hermes.md` = the startup pointer every session reads.
- `~/.hermes/profiles/pocock/skills/wenshu-parallel-dev/SKILL.md` = the execution
  contract, including the full command reference and the generic Hermes mechanism
  background.
- `docs/agents/issue-tracker.md` = the local markdown issue tracker that the board
  complements.
