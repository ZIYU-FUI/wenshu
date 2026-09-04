# Subagent resilience — design notes (2026-09-04)

Boss 2026-09-04 OOB: ship secondary insurance for the 4 subagent failures observed today. This document covers the 2 subagent-failure scripts (`Scripts/subagent-fallback.sh` and `.git-hooks/post-delegate-task`). The CJK and hermes-preflight scripts have their own specs.

## Failure modes this design targets

1. **Model timeout** (= the kanban 14,347 LOC subagent hit "slow response 761s"). Re-dispatch with halved scope.
2. **max_iterations** (= the test sweep 31 failure subagent hit the iteration cap mid-stream with uncommitted fixes). Auto-commit on exit, human reviews, no auto-push.

Both failure modes share a common property: the subagent ends with a recognizable tail signature (= either an error string in the transcript or an iteration-budget message). The two scripts exploit that property.

## Script 1 — `Scripts/subagent-fallback.sh`

### What it does

Reads the last 80 lines of a subagent transcript and looks for one of the 4 known failure signatures:

- `max_iterations (iteration budget exhausted)`
- `Invalid API response`
- `slow response`
- `timeout`

On a match, it writes a re-dispatch suggestion marker to `.scratch/subagent-fallback/<bascript>.dispatch` and exits 0. On no match, it exits 1 (= no fallback needed).

### Why a marker file, not a direct re-dispatch

The script does NOT spawn a new subagent. Re-dispatch is the parent orchestrator's job. The marker file is a one-line breadcrumb that the parent can pick up on its next heartbeat tick. This keeps the script stateless (= can be run repeatedly without doubling re-dispatch attempts) and avoids the "two orchestrators fighting" race that the original 2026-09-04 CJK cascade failure had.

### Scope hinting

The marker carries a `scope:` line with a hint:

- `max_iterations` → "commit current wip + retry with same scope (post-delegate-task handles commit)"
- `Invalid API response` / `slow response` / `timeout` → "halved (split LOC by half, re-dispatch in 5K-LOC chunks)"

Coarse on purpose. The parent orchestrator decides the actual chunking strategy based on the task shape.

### Invocation

```bash
Scripts/subagent-fallback.sh ~/.hermes/profiles/pocock/cache/delegation/live/<deleg-id>/task-*.log "kanban 14,347 LOC scan"
```

Exit 0 = re-dispatch marker written. Exit 1 = no failure detected. Exit 2 = usage error.

## Script 2 — `.git-hooks/post-delegate-task`

### What it does

Git hook that fires after a subagent delegation finishes. Inspects the latest subagent transcript under `~/.hermes/profiles/pocock/cache/delegation/live/<deleg>/task-*.log`. If the tail shows `max_iterations (iteration budget exhausted)`, it auto-commits any uncommitted changes in the current worktree with the message:

```
wip(wenshu): auto-commit from interrupted subagent (= requires human review)
```

It does NOT push. It does NOT bypass pre-commit hooks that might be configured in the worktree (it uses `--no-verify` only to skip the standard wenshu lint chain, because interrupted subagent wip is by definition incomplete).

### Opt-in, not auto-installed

The hook lives in `.git-hooks/` (= version-controlled stub), not `.git/hooks/` (= runtime). The README explains:

```bash
cp .git-hooks/post-delegate-task .git/hooks/post-delegate-task
chmod +x .git/hooks/post-delegate-task
```

Why opt-in: auto-committing from a git hook is a footgun in any repo where pre-commit hooks are configured. The boss wants humans to look at `.git-hooks/` and consciously enable.

### Idempotency

- If no subagent transcript exists under the delegation cache → exit 0 silently.
- If the transcript tail does NOT match the max_iterations signature → exit 0 silently.
- If `git status --short` is empty → exit 0 (= nothing to commit; no duplicate wip commit).
- If all conditions met → single `git add -A` + `git commit --no-verify`. Re-running the hook without new uncommitted changes is a no-op.

### Invocation

Either via the hook lifecycle (= after `git` operations, if installed) or directly:

```bash
.git-hooks/post-delegate-task
```

## What this design does NOT do

- It does NOT prevent the subagent from timing out in the first place (= the parent's `--timeout` flag and model-budget config is the primary defense).
- It does NOT auto-push (= the wip commit is for human review only).
- It does NOT touch the recovered commits from today's 4 retry subagents (= those already ship; this worktree is secondary insurance).

## Acceptance

- `Scripts/subagent-fallback.sh` exits 0 on a synthetic transcript whose tail contains one of the 4 failure signatures.
- `Scripts/subagent-fallback.sh` exits 1 on a synthetic transcript whose tail does NOT match any signature.
- `.git-hooks/post-delegate-task` exits 0 silently when no delegation transcript is present.
- `.git-hooks/post-delegate-task` creates a single `wip(wenshu):` commit when run on a worktree with uncommitted changes AND a max_iterations tail in the latest delegation transcript.

*First line = fact. Last line = fact.*
