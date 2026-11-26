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
  "$HOME/Documents/wenshu-backups/2026-11-26-pre-seed-cleanup"
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
= mode 600. = A SwiftData store is a WAL database, = = and the copy was taken
without its sidecars, = = so the first cold `sqlite3 -readonly` open of it fails
(`unable to open database file`). = The fix is one command, = = run on the **copy**:
`sqlite3 "$HOME/Documents/wenshu-backups/2026-11-26-pre-seed-cleanup/WenshuStore.store" '
pragma journal_mode=delete;'` -- = which folds the log back in and leaves a plain
single-file database. = After it, = = the same read-only open reports 576 rows and
`pragma integrity_check` says `ok`.
The sweep's own backup of the same state is the file it made before touching
anything. = = The live store was never edited without that copy in place.

## The gate run, and which labels are the evidence

`gate_run.sh` resolves its log directory from its own path, = so running it from a
worktree needs `LOGDIR` pointed at the shared checkout, = = and it takes the tree
as an argument -- = which means **the label and the tree have to be quoted
together or neither is evidence**. = The merged-tree run was made in a worktree
detached at `main`, = = not in the branch being closed; = = its label is
`closeout-merged-main` (= nine commands, = = `rc=0`), = = and `closeout-merged-main_1.log`
begins `0f9c784db60c...`, = = the main tip. = Reproduce it from nothing:

```bash
R=/Volumes/ANAN/Engineering/wenshu
B=3ad2ccebfacab0e52b4208488e4acae196e64c96
D=$(mktemp -d)/mergedtree; git -C $R worktree add --detach "$D" 0f9c784db60c653f4f2a331b6a25fd5245aeb23c >/dev/null
T="$D"
LOGDIR=$R/.gate-logs PER_CMD_TIMEOUT=900 bash $R/Scripts/gate_run.sh "$T" closeout-merged-main \
  "git -C $T rev-parse HEAD" \
  "swift build --package-path $T --disable-sandbox" \
  "swift test --package-path $T --disable-sandbox --filter PlanSeedIdempotenceTests" \
  "python3 $T/Tools/wenshu-devtool/ci_change_gate.py --base $B" \
  "python3 $T/Tools/wenshu-devtool/comment_lineage.py $T $B" \
  "swift-format lint --recursive --strict $T/Sources/WenshuApp/App/PlanSeed.swift $T/Tests/WenshuAppTests/App/PlanSeedIdempotenceTests.swift" \
  "python3 $T/Tools/wenshu-devtool/loc-cap-check.py --base $B" \
  "python3 $T/Tools/wenshu-devtool/markdown-newline-check.py --base $B" \
  "python3 $T/Tools/wenshu-devtool/pollution_check.py --base $B" \
  "python3 $T/Tools/wenshu-devtool/nfi-loc-check.py --base $B"
ls $R/.gate-logs/closeout-merged-main_*.log | wc -l      # 9
head -1 $R/.gate-logs/closeout-merged-main_1.log         # 0f9c784db60c...6a25fd5245aeb23c
git -C $R worktree remove --force "$D"
```
Re-running it **overwrites the nine cited files**, = so a reader who wants their own
copy runs it under a **different label**. = The corrected version of this record was
measured that way, = = under label `closeout-record-r4` (= seven commands, = = base
`7e036f7613`), = = and the rule that keeps that citation honest is one line:
`head -1 .gate-logs/closeout-record-r4_1.log` must print the tip of the branch this
record lands on. = = If it prints anything else, = = the label belongs to an earlier
draft of these words.

The record's own diff was gated on its own tip under a second label family,
= seven commands, = = `closeout-seed-doc-r3` (= each of the three rounds below the
first names the tip it measured):

```bash
R=/Volumes/ANAN/Engineering/wenshu
T=$R/.worktrees/seed-closeout-2026-11-26
LOGDIR=$R/.gate-logs bash $R/Scripts/gate_run.sh "$T" closeout-seed-doc-r3 \
  "git -C $T rev-parse HEAD" \
  "python3 $T/Tools/wenshu-devtool/tests/test_probe_index.py" \
  "python3 $T/Tools/wenshu-devtool/comment_lineage.py $T 0f9c784db60c653f4f2a331b6a25fd5245aeb23c" \
  "python3 $T/Tools/wenshu-devtool/nfi-loc-check.py --base 0f9c784db60c653f4f2a331b6a25fd5245aeb23c" \
  "python3 $T/Tools/wenshu-devtool/pollution_check.py --base 0f9c784db60c653f4f2a331b6a25fd5245aeb23c" \
  "python3 $T/Tools/wenshu-devtool/markdown-newline-check.py --base 0f9c784db60c653f4f2a331b6a25fd5245aeb23c" \
  "wc -l $T/docs/agents/2026-11-26-session-close-seed-idempotence.md"
ls $R/.gate-logs/closeout-seed-doc-r3_*.log | wc -l      # 7
head -1 $R/.gate-logs/closeout-seed-doc-r3_5.log         # pollution ... (0f9c784db6...HEAD)
```

The denominators, = read out of the nine log bodies: = `Build complete!`; = = *Test
run with **4 tests** in 1 suite passed*; = = `added comment lines: 59` = with
`offending: 0 rows / 0 files (P0=0, P1=0)`; = = `nfi-loc-check: ... (1 row(s)
checked)`; = = `formatting: ... (2 changed Swift file(s) checked)`; = = `loc-cap:
... (2 file(s) checked)`; = = `markdown-newline: ... (1 changed .md file(s)
checked)`; = = and `pollution: no forbidden vocabulary, no CJK outside the exempt
families` **over `3ad2ccebfaca...HEAD`** -- = the window that log names, = = which
is not `origin/main...HEAD`, = = and not the window this record's own diff sits in
either (= that one is `0f9c784db6...HEAD`).

Two labels are named so the record does not over-claim:

- **`t_c0545641_a1_1` to `_a1_8`** — the landing run's own eight gate logs. =
  They carry no FAIL (= `grep -c FAIL` = 0 on each), = = but their first line is
  command output and not the sha, = so they prove the eight denominators and
  **not** which tree they were taken from. = The tree identity comes from
  `closeout-merged-main_1.log`, = and this record is the only place that says so.
- **no label at all for the pre-merge tip `f3a28ccea7`.** = The first version of
  this record cited `wt/seed-idempotence-2026-11-26_a1_*` for it, = = and that
  label cannot exist: = `gate_run.sh` writes `${LABEL}_${i}.log`, = = so a label
  containing a `/` would have to create a file inside a directory that is not
  there. = = `ls .gate-logs | grep -c seed-idempotence-2026-11-26` is **0**, = = and
  `grep -rl f3a28ccea7 .gate-logs` finds nothing. = = The pre-merge tree was gated
  by its own card's run (`t_fc936f38`), = = not by a label this session keeps.

## The landing, and the ff that moved nothing under anyone

The verdict was taken at `f3a28ccea7` (= whose parent is `ab648fbde4`, = = which is
`merge-base main f3a28ccea7`; = = `d7659413b0` is an **earlier iteration of the
same subject** on the same branch, = = not the base). = Main had moved
**7 commits** since, = so the branch was rebased and re-asked:

```bash
B=$HOME/.hermes/kanban/boards/wenshu-par/kanban.db
sqlite3 -readonly "$B" "select json_extract(metadata,'\$.review_outcome'),
  json_extract(metadata,'\$.reviewed_sha') from task_runs where id=5203;"
  # approved | f3a28ccea79636baa6ab3fa8ebc79a31fe88f6aa
sqlite3 -readonly "$B" "select json_extract(metadata,'\$.verdict_lineage'),
  json_extract(metadata,'\$.main_before') from task_runs where id=5209;"
  # matched by change | 3ad2ccebfacab0e52b4208488e4acae196e64c96
python3 /Volumes/ANAN/Engineering/wenshu/Tools/wenshu-devtool/review_gate.py --card t_fc936f38
```
The lineage is read from the **run row**, = = not from a second `review_gate.py`
invocation. = = The shape the first draft printed -- `--branch ... --sha HEAD` -- is
wrong twice over: = `HEAD` resolves where it is typed (= = a reader in the shared
checkout stands on `main`), = = and the explicit form
`--branch wt/seed-idempotence-2026-11-26 --sha 0f9c784db6...` **exits 3** now, = =
because the branch tip is that landed sha and `main` already contains it, = = so the
branch has no remaining diff for a card to match. = = A landing consumes its own
gate: = after it, = = the evidence that the verdict covered the landed commit is the
landing run's `verdict_lineage` field, = = which the two commands above print.

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
is a card that carries an approving verdict over each sha. = = **All three** fall
under one card: = `t_ad63a13f`, = run 5192, = = `approved`, = = measured at
`3ad2ccebfa`, = = with `git merge-base --is-ancestor` holding for each of the three
(`a694f4ffeb` = yes, = `9421df43a8` = yes, = `3ad2ccebfa` = yes). = = The first draft
of this record split them across two cards and named `t_88bff3b5` as the verdict
for the third; = = that card approves `5eb6a5034a`, = = which is not an ancestor of
`main` at all, = = so it was read only to be excluded.

`main` has moved twice since (`b6442f5891`, `7e036f7613`, the devtool lane), so every
claim in this record is stated as **ancestry** and never as a tip: the code commit is
an ancestor of `main` (`git merge-base --is-ancestor 0f9c784db6 main` -> rc 0), and the
second remote is behind again by exactly the commits that arrived after it was pushed
(`git rev-list --count refs/remotes/old-origin/main..main` -> re-take this line before
judging the number stale).

## Lessons that went into the skills

Written into the tree the next session loads (= `~/.hermes/shared/wenshu-skills/`),
= not into memory, = = and not into this document alone:

| skill file | the rule that went in |
|---|---|
| `wenshu-pocock-workflow/references/standard-closeout.md` | **a green `GATE_RC=0` from a run handed no command is not a green gate** (= `gate_run.sh` loops over its trailing arguments, = = so zero arguments iterate zero times, = = write no log, = = and exit 0). = Measured here: = = one such call printed `GATE_RC=0` and produced zero labels. = = The reading is the label count **and** each log's verdict sentence. |
| the same file, step 3 | **every number the record publishes must be re-takable by an instrument the tree carries**. = The 518 was published from a scratch binary, = = which is a claim and not an instrument; = = moving it into `Tools/wenshu-devtool/probes/` with its three arms is what made it evidence. |
| `wenshu-parallel-dev/references/a-review-card-that-never-spawns.md` | the second fix for a card that will not spawn: = free the branch NAME by detaching the author's worktree (= `checkout --detach` keeps the tip), = = and let the dispatcher retry on its next tick (= run 5220 `spawn_failed` to run 5221 `running`, = = no board write). = The hand-write to `consecutive_failures` is refused and was never the obstacle. |

That commit is citable, = which is the point of committing the skills tree at all:
`git log --oneline -1 -- wenshu-pocock-workflow/references/standard-closeout.md`
reads `77b72e6`, = = and `git show 77b72e6^:` of the same file has **none** of the
four rules above. = = Before it they lived only in the working tree. = = The first
draft of this section claimed the `LOGDIR` rule and the "log-body-names-the-sha"
rule were "already in `standard-closeout.md`", = = meaning a rule this session did
not write; = = the probe says otherwise, = = so the claim is gone and the commit is
the provenance. = The branch-occupancy cause, = by contrast, = was already there in
`a-review-card-that-never-spawns.md`, = = which is why the third table row above
records only the *second* fix and not the diagnosis.

## Open items this scope leaves behind

| # | item | the card or the command |
|---|---|---|
| 1 | `verify_doc_commands.py` **does exist** (= `~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/scripts/verify_doc_commands.py`) = and was run against this record: = `PASS (7 blocks)`, = = 6 ok and 1 red, = = the red one being a `review_gate --sha HEAD` line this record has now corrected. = = The defect is not its absence but its **address**: = `git ls-files \| grep -i verify_doc` in the repo is empty, = so the tool that the closeout flow makes a gate of lives outside the repo it audits and is wired into no gate. | `Tools/wenshu-devtool/` owns it; = the card moves it in and registers it |
| 2 | Where `WS_SEED_PLAN=1` came from is **unresolved**. = Ruled out: = the repo, = `~/Library/LaunchAgents/`, = the app bundle's `LSEnvironment`, = `~/.zsh_history`, = this profile's config. = One interactive shell session was never excluded, = = and until it is, = = a future launch can seed again (= now self-replacing, = = so at worst one batch). | the boss's own launch path; = = no code change is owed |
| 3 | `seedCrew()`'s write target was never measured, = = only that `ZWSSUBAGENTRUN` is 0 in the live store. | a probe, = = same directory, = = before any claim about it |
| 4 | The shared checkout's index held a **stale tree that reverted landed work**: = = `PlanSeed.swift` back to 175 lines and the test file staged for deletion, = = and `docs/agents/nfi.md` missing rows for both. = My two paths are restored to HEAD (= `git checkout HEAD -- <those two>`); = = 19 paths remain, = = 5 of them named by live cards, = = and at least one of those still stages deletions of rows that are already on main. | `t_b2ac2eda` owns `OOB.md` and its own closeout doc, = = which are among the staged paths |
| 5 | `t_fbb810a3` is still `blocked` in the review column (= `[T2]` the code-block chord). = = It is not this scope's and no action was taken on it. | the board's open columns, = = recounted with: = `hermes kanban list --limit 200` |

## The review round this record itself went through

A closeout record is a committed artifact, = so it gets a card, = and this one came
back with **six citation defects** (= `t_93d5a560`, = = run 5221, = =
`review_outcome: changes_requested` at `7be5534aa1`). = Every one of them was real,
= every one was reproducible by a command the reviewer printed, = and none of them
was a style comment:

| finding | what was wrong | what closed it |
|---|---|---|
| a label that cannot exist | the record cited `wt/seed-idempotence-2026-11-26_a1_*` for the pre-merge tree; `gate_run.sh` writes `${LABEL}_${i}.log`, = = so a label with a `/` writes nothing, = = and `grep -rl f3a28ccea7 .gate-logs` is empty | the bullet now states the absence, = = with the two commands that show it |
| a denominator from the wrong window | `pollution` was quoted as `origin/main...HEAD` while `closeout-merged-main_4.log` names `3ad2ccebfaca...HEAD` | the window is quoted from the log, = = and the record's own window (`0f9c784db6...HEAD`) is named as a third, = = different thing |
| a vacuous gate command | the repro block ran `gate_run.sh <tree> <label>` with **no commands**, = = the exact shape that exits 0 and writes zero logs | the block now prints all nine commands |
| inverted sibling attribution | the record split the three sibling commits over `t_ad63a13f` and `t_88bff3b5`; = = the latter approves `5eb6a5034a`, = = which is not on `main` | one card covers all three (= `t_ad63a13f`, = = run 5192, = = approved at `3ad2ccebfa`), = = and the other is named as an exclusion |
| a backup that cannot be opened cold | the durable copy was WAL-without-sidecars, = = so `sqlite3 -readonly` failed; = = the probe arm had run against a scratch copy that no reader keeps | `pragma journal_mode=delete` on the copy, = = both arms re-taken from the durable path, = = `probe-index.md`'s arm moved off scratch |
| unbacked provenance | the record said two rules were "already in `standard-closeout.md`"; = = they were uncommitted working-tree text, = = absent from `5e6c37a` | the skills tree is committed (`77b72e6`) = and `git show 77b72e6^:` of that file carries **none** of the four rules |

Plus two found while making those blocks runnable, = = after the reviewer had
already returned: = the merged-tree block passed the **closeout** worktree as its
tree argument while quoting a log whose first line is the **main** tip (= so the
repro could not produce the reading it cited), = = and the doc-round label family
was never named at all, = = though `closeout-seed-doc_1.log` = `b43c2a4f43`, = =
`-r2_1.log` = `6c6cf25c1e` = and `-r3_1.log` = `7be5534aa1` are the three tips this
record passed through. = = Both are fixed above.

Plus one from the verifier the reviewer pointed at, = = which the first draft had
declared missing: = a `review_gate.py --branch ... --sha HEAD` line that resolves
HEAD where it is typed (= the shared checkout, = = = i.e. `main`, = = = on which this
branch carries no verdict) rather than naming the sha under review.

The durable lesson is narrower than "check your citations": = **a record's commands
are its test suite, = and the test that matters is the one a reader runs cold.** =
Every number in this document is now either printed by a command inside the fenced
blocks or read out of a `.gate-logs` file that block names, = = and the two
artifacts they read (the backup store, = the skill file) = are at paths the reader
still has tomorrow.
