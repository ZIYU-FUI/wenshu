# Session: the repo was deleted mid-session, and how it came back

## 1. What happened

At 2026-11-16 18:30-18:32 the whole repository directory
`/Volumes/ANAN/Engineering/wenshu` was deleted: the source tree, the
`.git` directory, every `.worktrees/` checkout, and the three
untracked copies that lived in the repo root (`fmtctl2/`, `wt-base/`,
`wt4_D3c/`). The volume `/Volumes/ANAN` itself was healthy (= 1.4 Ti
free, the other project directories intact).

The session's own uncommitted work (= the side-by-side removal, which
lived only in a worktree's working tree, never staged) was lost with
it.

## 2. How it was found

The next `swift build` in the worktree failed with "no such file or
directory". `git worktree list` reported the tree as `prunable` (= its
directory is gone). `ls /Volumes/ANAN/Engineering/wenshu` showed one
entry: `.worktrees/`, holding two mostly-empty directories.

The review profile's own agent log shows it hitting the same wall at
18:34 (= a session that read `git worktree list` and got "fatal: not a
git repository").

## 3. What is KNOWN about the cause

The Hermes checkpoint manager logged, in the review profile, a burst of
prunes across 18:27-18:32:

```
tools.checkpoint_manager: Checkpoint store exceeded 500 MB — dropped the
oldest snapshot per project; space is reclaimed by the next prune
```

(seven times, at 18:27:54, 18:29:14, 18:29:36, 18:30:07, 18:31:16,
18:31:36, 18:31:48, 18:32:23.)

**WHAT IS NOT KNOWN**: the checkpoint pruner itself only deletes
snapshots inside its own store (= `tools/checkpoint_pruning.py`'s
`Pruner` calls `git` inside the store and drops refs; = it has no
`rmtree` of a working directory). The `worktree_sweep` only reads
`<repo>/.worktrees`. Neither module deletes a repo root. So the
mechanism that removed `/Volumes/ANAN/Engineering/wenshu` has NOT been
identified, and this document does not name one.

**WHAT IS KNOWN**: the deletion window (18:30-18:32) coincides exactly
with the checkpoint-prune burst. That is a correlation, not a
mechanism.

## 4. How it came back

Two independent recovery sources existed, both OUTSIDE the deleted
tree:

1. **`/Volumes/ANAN/Engineering/wenshu-backup.git`** (= a mirror clone,
   created 18:35 by whichever session noticed the deletion): 823 MB,
   6489 commits, tip `58dd224bb`.
2. **The Hermes checkpoint stores** (= `profiles/<profile>/checkpoints/store`,
   a bare git repo of file snapshots): the review store's
   `refs/hermes/28ee2d2f4f1914df` (= 18:25:33, 1711 files) held a
   complete file-level snapshot of the repo taken seven minutes before
   the deletion.

The restore used (1) for the git history and the object store, and (2)
for the working tree, then `git checkout -f HEAD -- .` put every tracked
file back at the tip.

**Restored state** (measured):

- `git log -1` = `58dd224bb` (= the exact tip the session started from).
- `git rev-list --count main..origin/main` = 0 (= main == origin/main).
- `git fsck --connectivity-only` = clean (= no dangling/missing objects).
- `git status --short` = one untracked file
  (`docs/agents/2026-11-14-session-close-the-app-store-editorial-card.md`,
  = a doc another session wrote at 18:32, = outside the tip, = rescued
  from that session's own write and kept).
- `swift build` = Build complete.

## 5. The lesson this session carries

**The work that is not committed is not work.** The whole side-by-side
removal (= 15 files, ~380 insertions, ~1070 deletions) was lost
because it lived only in a worktree's working tree. The second time
round, the same change was re-applied and committed in FOUR steps, so
each step was already in the git object store before the next began.

**⇒ ⇒ ⇒ AND A WORKTREE IS A PLACE A DELETE CAN REACH.** The repo's
own house rule already says it: `wenshu-parallel-dev/references/
wrap-up-and-residue.md` = "recovery. Before `git worktree remove`, copy
any untracked harness into its...". The rule is about the harness; the
lesson is wider: = anything that only exists in a working tree is one
`rm -rf` from gone, = so commit early, = and keep a mirror outside the
tree the tooling sweeps.

## 6. What is left to do

- The mechanism that deleted the repo is NOT identified. It is not this
  session's finding to fix (this session is a code change, not a Hermes
  change), but it is a real hazard for every session on this machine.
- The recovery sources are now in place (= the mirror), so a repeat is
  survivable. Whether the mirror survives the next sweep is not
  measured: it lives OUTSIDE `/Volumes/ANAN/Engineering/wenshu`, so a
  sweep of that directory cannot reach it.
