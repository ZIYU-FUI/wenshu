# The board's sample is written once, and a task that borrows only the title stays (2026-11-26)

## The scope

One report from the boss: the right-hand board column showed the same card three
times. It was data AND it was a defect, and the two halves are carried by
different things, because the fix cannot un-write 518 rows that already exist.

| # | requirement | the carrier | the adjudication | the server's proof |
|---|---|---|---|---|
| 1 | the seeded sample must stop stacking a new copy of itself on every launch | `0f9c784db6` (`Sources/WenshuApp/App/PlanSeed.swift`, `Tests/WenshuAppTests/App/PlanSeedIdempotenceTests.swift`, one `docs/agents/nfi.md` row) | card `t_fc936f38` (= run 5203, = = `review_outcome: approved`), = and the landing card `t_c0545641` (= run 5209) | `git ls-remote origin refs/heads/main` = `0f9c784db60c653f4f2a331b6a25fd5245aeb23c`; = = `git ls-remote old-origin refs/heads/main` after the push in the section below |
| 2 | the rows the old seed already wrote into the live library must go, = = and the real tasks must stay | a hand sweep of `~/Documents/anbaiqiang.ws/WenshuStore.store` (= 576 rows to 58), = = proven on a copy first | no card (= it is the user's own data, = = not the tree's) | the store reads 58 rows and the in-repo probe reads 0 sample rows in it |

## What the tree actually did, measured

`PlanSeed.seedTasks()` appends seven fixed-literal sample tasks to the CURRENT
book on every launch, = under `WS_SEED_PLAN=1`, = = and it deduplicates nothing.
Its id is `UUID()` and the model's `id` is `@Attribute(.unique)`, = so a new
identifier is handed to the uniqueness check every time and nothing can ever
book `68F9A258-ECEC-4CFE-8FB0-49409E5EB750`. = The store's own shape says how
often it ran: = **518 rows carry a body** = = = 7 sample titles times **74
copies** each, = = 497 of them with **no book attached** and 21 in the book above
(= three batches of seven, = = the three-fold duplicate the boss saw).

```bash
K=~/Documents/wenshu-backups/2026-11-26-pre-seed-cleanup/WenshuStore.store
sqlite3 -readonly "$K" 'select count(*) from ZWSKANBANTASK;'                        # 576
sqlite3 -readonly "$K" 'select count(*) from ZWSKANBANTASK where ZBODY is not null
  and ZBODY<>"";'                                                                   # 518
sqlite3 -readonly "$K" 'select coalesce(ZBOOKID,"(none)") b, count(*) from ZWSKANBANTASK
  where ZBODY is not null and ZBODY<>"" group by b;'                    # (none) 497 | 68F9A258-…-750 21
sqlite3 -readonly ~/Documents/anbaiqiang.ws/WenshuStore.store 'select count(*) from ZWSSUBAGENTRUN;'   # 0
```

The second reading is the one that bounded the cleanup: = = the seed's crew half
(`seedCrew()`) writes nothing to that table, = so the sweep had one table to
touch and not two.

## The fix, and the line that carries it

The seed now reclaims its own rows before it writes, = and it recognises them by
the **pair** of title and body rather than by the title alone:

```bash
grep -n removeSeededRows Sources/WenshuApp/App/PlanSeed.swift   # the call site and the definition
```

The pair is the whole decision. = = A user's task that borrows one sample's title
is a real task and stays, = which is what the third test holds; = = and the
reclaim runs over the whole store and not over the current book, = so a sample
left behind in an older book collapses the next time the seed runs anywhere. =
The fourth test holds that: = = the sample follows the session's book instead of
piling up per book.

`PlanSeed.swift` is 220 lines and `PlanSeedIdempotenceTests.swift` is 122, =
four tests, = = an in-memory container each so a seeded launch can never write
into the user's real store:

```bash
wc -l Sources/WenshuApp/App/PlanSeed.swift \
      Tests/WenshuAppTests/App/PlanSeedIdempotenceTests.swift
grep -c '@Test' Tests/WenshuAppTests/App/PlanSeedIdempotenceTests.swift   # 4
```

## The data already in the store, and the instrument that re-measures it

The repair number that matters is the one an outsider can re-take. = The first
sweep was measured by a throwaway binary in a scratch directory, = = which the
repo does not carry and which a reader cannot run. = So the same reading was
re-taken with an in-repo instrument, = registered the way every other probe in
this tree is registered:

```bash
python3 Tools/wenshu-devtool/probes/seed_sample_rows.py --dry-run \
  "$HOME/Documents/anbaiqiang.ws"
python3 Tools/wenshu-devtool/probes/seed_sample_rows.py --dry-run \
  /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/arm1-pre-cleanup
python3 Tools/wenshu-devtool/tests/test_probe_index.py
```

Its arms, = all three of which are in `Tools/wenshu-devtool/probe-index.md`
under **Recorded measurement**: = the live store (58 rows, = = 0 sample rows),
= the pre-repair backup (576 rows, = = **518** sample rows, = = 58 not the
seed's), = and a directory with no store in it (= `exit 2`). = The first two
arms are why the published 518 is now a repo-measurable number and not a claim.
The third arm is the one that makes the other two worth reading: = = an empty
reading must never be readable as a clean store. = The live reading also prints
the load-bearing line in its own shape — = *58 rows carry no body* — = so on this store
the pair predicate matches nothing at all, = and a row can only be taken by the
seed path that wrote it.

The pre-repair backup is **not** left in a scratch directory (they are pruned):
it is at `~/Documents/wenshu-backups/2026-11-26-pre-seed-cleanup/WenshuStore.store`,
= mode 600, = = where it reads 576 rows and `pragma integrity_check` says `ok`.
The sweep's own backup of the same state is the file it made before touching
anything. = = The live store was never edited without that copy in place.

## The gate run, and which labels are the evidence

`gate_run.sh` resolves its log directory from its own path, = so running it from
a closeout worktree needs `LOGDIR` pointed at the shared checkout. = The merged
tree was gated at label `closeout-merged-main` (= nine commands, = = `rc=0`),
= and the first log line is the raw sha, = = so a reader who has only the sha
finds the nine files holding it:

```bash
LOGDIR=/Volumes/ANAN/Engineering/wenshu/.gate-logs \
  bash Scripts/gate_run.sh \
  /Volumes/ANAN/Engineering/wenshu/.worktrees/seed-closeout-2026-11-26 \
  closeout-merged-main
ls /Volumes/ANAN/Engineering/wenshu/.gate-logs/closeout-merged-main_*.log | wc -l   # 9
head -1 .gate-logs/closeout-merged-main_1.log      # 0f9c784db60c653f4f2a331b6a25fd5245aeb23c
```

The denominators, = from the log bodies: = `Build complete!`; = = *Test run with
**4 tests** in 1 suite passed*; = = `added comment lines: 59` = with `offending:
0 rows / 0 files (P0=0, P1=0)`; = = `nfi-loc-check: ... (1 row(s) checked)`; = =
`formatting: ... (2 changed Swift file(s) checked)`; = = `loc-cap: ... (2
file(s) checked)`; = = `pollution: ... (origin/main...HEAD)`; = =
`markdown-newline: ... (1 changed .md file(s) checked)`.

Two labels are named so the record does not over-claim:

- **`t_c0545641_a1_1` to `_a1_8`** — the landing run's own eight gate logs. =
  They carry no FAIL (= `grep -c FAIL` = 0 on each), = = but their first line is
  command output and not the sha, = so they prove the eight denominators and
  **not** which tree they were taken from. = The tree identity comes from
  `closeout-merged-main_1.log`, = and this record is the only place that says so.
- **`wt/seed-idempotence-2026-11-26_a1_*`** — an earlier attempt at the pre-merge
  tree (`f3a28ccea7`), = = superseded by the rebase. = It is not the evidence;
  = = the merged tree is.

## The landing, and the ff that moved nothing under anyone

The verdict was taken at `f3a28ccea7` (= base `d7659413b0`). = Main had moved
**7 commits** since, = so the branch was rebased and re-asked:

```bash
python3 Tools/wenshu-devtool/review_gate.py --card t_fc936f38
python3 Tools/wenshu-devtool/review_gate.py --branch wt/seed-idempotence-2026-11-26 --sha HEAD
```

The rebased verdict reads **`matched by change`**: = the set of written lines is
identical, = = and the `patch-id` differs only where the moved base put its
neighbouring files into the hunks. = Main then moved by compare-and-swap,
= expected `3ad2ccebfaca`, = = landed `0f9c784db6`, = = pushed to `origin`
(= `remote: Start Git Hooks Checking [PASSED]`).

The fast-forward question this closeout had to answer, = because the board was
never empty: = = **does moving main by ff disturb a verdict someone else is
waiting on?** = Measured rather than argued, = for the three reviews that were
live at the time (= `t_88bff3b5` at `5eb6a5034a2f`, = `t_16ff9709` at
`c5d54473162a`, = `t_89b652cd` at `3fa6d178f6e0`): = their `merge_base(main, sha)`
and their `change_id` were **byte-identical before and after** the ff. = An ff
adds descendants to main, = = and a verdict measures a base and a change id, = so
neither moved. = The card `t_89b652cd` that was waiting on a main that had not
moved got its move.

## The second remote, pushed here

`land_card.sh` pushes one remote (= `git push origin main`), = so `old-origin`
(= github) is the closeout's job. = It read **behind**, = not divergent:

```bash
git fetch old-origin main
git rev-list --count refs/remotes/old-origin/main..main    # 4
git rev-list --count main..refs/remotes/old-origin/main    # 0
```

Four commits ride the push and **three of them are not this scope's** (=
`a694f4ffeb`, = `9421df43a8`, = = `3ad2ccebfa`, = = the landing-gate lane).
= They are named here because a push of `main` publishes a sibling's merged
commit, = = and the check that makes that maintenance rather than impersonation
is that the sibling's own card carries an approving verdict: = = `t_ad63a13f`
(run 5192, = = `review_outcome: approved`) for the first two, = = `t_88bff3b5`
(run 5206, = = `approved`) for the third, = all three already on `origin/main`.

## Lessons that went into the skills

Written into the tree the next session loads (= `~/.hermes/shared/wenshu-skills/`),
= not into memory, = = and not into this document alone:

| skill file | the rule that went in |
|---|---|
| `wenshu-pocock-workflow/references/standard-closeout.md` | **a green `GATE_RC=0` from a run handed no command is not a green gate** (= `gate_run.sh` loops over its trailing arguments, = = so zero arguments iterate zero times, = = write no log, = = and exit 0). = Measured here: = = one such call printed `GATE_RC=0` and produced zero labels. = = The reading is the label count **and** each log's verdict sentence. |
| the same file, step 3 | **every number the record publishes must be re-takable by an instrument the tree carries**. = The 518 was published from a scratch binary, = = which is a claim and not an instrument; = = moving it into `Tools/wenshu-devtool/probes/` with its three arms is what made it evidence. |
| `wenshu-parallel-dev/references/a-review-card-that-never-spawns.md` | the second fix for a card that will not spawn: = free the branch NAME by detaching the author's worktree (= `checkout --detach` keeps the tip), = = and let the dispatcher retry on its next tick (= run 5220 `spawn_failed` to run 5221 `running`, = = no board write). = The hand-write to `consecutive_failures` is refused and was never the obstacle. |

Two rules this record had to **leave out**: = the `LOGDIR` rule and the
"log-body-names-the-sha" rule are already in `standard-closeout.md` (= they are
why this run obeyed them), = and so is the branch-occupancy cause. = A closeout
that credits itself for following an existing rule is inflating the ledger.

## Open items this scope leaves behind

| # | item | the card or the command |
|---|---|---|
| 1 | `scripts/verify_doc_commands.py` is named by five skill references (= including this flow's own step 3) and **does not exist in the tree** (= `git ls-files \| grep -i verify_doc` = empty). = The command blocks above were executed by hand instead. | `Tools/wenshu-devtool/` owns it; = the card should name the five references, = not one |
| 2 | Where `WS_SEED_PLAN=1` came from is **unresolved**. = Ruled out: = the repo, = `~/Library/LaunchAgents/`, = the app bundle's `LSEnvironment`, = `~/.zsh_history`, = this profile's config. = One interactive shell session was never excluded, = = and until it is, = = a future launch can seed again (= now self-replacing, = = so at worst one batch). | the boss's own launch path; = = no code change is owed |
| 3 | `seedCrew()`'s write target was never measured, = = only that `ZWSSUBAGENTRUN` is 0 in the live store. | a probe, = = same directory, = = before any claim about it |
| 4 | The shared checkout's index held a **stale tree that reverted landed work**: = = `PlanSeed.swift` back to 175 lines and the test file staged for deletion, = = and `docs/agents/nfi.md` missing rows for both. = My two paths are restored to HEAD (= `git checkout HEAD -- <those two>`); = = 19 paths remain, = = 5 of them named by live cards, = = and at least one of those still stages deletions of rows that are already on main. | `t_b2ac2eda` owns `OOB.md` and its own closeout doc, = = which are among the staged paths |
| 5 | `t_fbb810a3` is still `blocked` in the review column (= `[T2]` the code-block chord). = = It is not this scope's and no action was taken on it. | the board's open columns: = = 5 running, = = 4 ready, = = 1 blocked |
