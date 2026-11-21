# Session close — the comment-lineage gate, and the 88 dangling citations (2026-11-21)

This record closes one scope: the ruling that comments serve a reader who is not the agent
that wrote the change, the gate that turns that ruling into something that can fail, and the
citation debt the gate then exposed. Every number below was re-run on the MERGED tree
(`8e7481ff8f`) unless a pair is named, and each block carries the command that prints it.
Blocks that mutate the tree or a remote are marked `SKIP:` and are not part of the doc's
re-runnable surface.

## 1. What was asked

The boss ruled the comment corpus (see OOB.md #2026-11-21): a comment exists for a human
reader, and two obligations followed — 1.5 (no refactor or lineage narrative in comments)
and 1.6 (an out-of-band reference is only a pointer, never the directive's own words) —
written into `AGENTS.md` as Manual prose. Prose does not stop a tree from drifting, so the
scope had a second half: make 1.5/1.6 a gate that can fail, then pay the debt it points at.

## 2. What the tree looked like before

```
SKIP: this block creates a detached worktree at the scope's base; the reader is expected to
pick their own scratch path.
git worktree add --detach /tmp/wt-base-cite 437eb698bf
```

The baseline figure changed once during this scope, and the reason is a matcher bug, not a
tree change. Five sites cite `2026-07-23`, a date the register carries in a row keyed
`| 2026-07-23 (v0.74 boss OOB) |`: the key cell puts a tag AFTER the date, and the matcher
did not read past it, so five live pointers were called dead. Measured on the same base tree
with both versions of the census:

```
SKIP: needs /tmp/wt-base-cite from the block above, and writes one temp file.
git show dec391cb61:Tools/wenshu-devtool/citation_inventory.py > /tmp/census_pre_widening.py
python3 /tmp/census_pre_widening.py --repo /tmp/wt-base-cite
#  citations: 253 | resolve: 160 | DANGLING: 93 over 43 addressable files, 19 dates
#     on one line 245 (90 dangling) + wrapped across two lines 8 (3 dangling)
python3 Tools/wenshu-devtool/citation_inventory.py --repo /tmp/wt-base-cite
#  citations: 253 | resolve: 165 | DANGLING: 88 over 40 addressable files, 18 dates
#  OOB.md: 93 dated rows over 40 distinct dates
```

**The true baseline is 88 dangling sites over 18 dates, not 93 over 19.** The scope worked
against 93, and the 5 sites it deleted on that premise had to be put back.

## 3. What shipped, in four moves

| Move | Commits | What it is |
|---|---|---|
| The gate | `c2a378aca4`, `437eb698bf`, `a28cc8be80` | `comment_lineage.py` (the judge), wired into `pre_review_gate.py` and `ci_change_gate.py`; `citation_inventory.py` (the census); a 29-call suite |
| The sweep | `19ce550670`, `eed49fd964`, `b6d9c40d6a` | 25 files, 57 hunks, +176/-188 comment lines, and the 18 registry rows it rewrote |
| The citation repair | `bacd13bb60` .. `5cf748ee4d` | dead pointers dropped or rewritten, wrapped sites joined, live pointers restored |
| Measure where it is read | `dec391cb61` .. `8e7481ff8f` | four rounds of findings about numbers that had been copied instead of re-measured |

The sweep row follows the same rule. The register's ruling row (`OOB.md #2026-11-21`) records
79 violating rows measured by `comment_unity.py` — a tool that exists in no revision of this
repo, so the tree cannot reprint 79. What `git show --format= 19ce550670` prints is 25 files,
57 hunks, +176/-188 comment lines, and that is the figure above.

The repair is counted off each commit's own diff, not off its subject:

| Commit | Measured on its own diff |
|---|---|
| `bacd13bb60` | 65 citation tokens dropped over 30 files, no other parenthesis touched |
| `acbbc97d84` | 25 tokens dropped over 17 files, each line rewritten to state the engineering fact |
| `792e0bdfdc` | 3 sites whose citation was wrapped across two lines joined (0 token delta, because the judge works per line and could not see them) |
| `5cf748ee4d` | 5 tokens added back over 4 files (`LLMConnector.swift:141`, `AssetsPane.swift:209`, `CardOpenOps.swift:127` and `:352`, `PreviewPaneCard+Body.swift:271`) |

65 + 25 + 3 = 93 touched, minus the 5 that were never dead = **88 cleaned**, which is what
the widened census prints at the base. No site was retargeted at another date: the census
offers a repoint by token overlap, all ten suggestions were read, and each lands on an
unrelated ruling — a dead pointer replaced by a false one is worse than no pointer.

## 4. Gates on the MERGED tree, at `8e7481ff8f`

```
SKIP: this one rebuilds and runs the Swift suite (about 90 seconds warm, more cold), so it is
not part of the doc's cheap re-runnable surface. It was run at this tip before the landing.
python3 Tools/wenshu-devtool/pre_review_gate.py --base 437eb698bf --filter PaneTabStripCloseTests
#  pre_review_gate: the tree is clean at 8e7481ff8f
#    build --build-tests: exit 0
#    swift test --filter 'PaneTabStripCloseTests': exit 0  Test run with 29 tests in 1 suite passed after 1.743 seconds.
#    ci_change_gate --check formatting: exit 0
#    ci_change_gate --check pollution: exit 0
#    ci_change_gate --check loc-cap: exit 0
#    comment-lineage: exit 0 (offending: 0 rows / 0 files (P0=0, P1=0))
#    the CJK audit: exit 0 (no new CJK comment line (137 added line(s) scanned))
#    verify-dead: exit 0 DEAD (= all decls dead): 0
#    the registry's round-trip: exit 0
```

The rest are cheap and are each printed by the command above its result:

```
python3 Tools/wenshu-devtool/comment_lineage.py --base 437eb698bf
UNITY_CARVE=0 python3 Tools/wenshu-devtool/comment_lineage.py --base 437eb698bf
python3 Tools/wenshu-devtool/citation_inventory.py
for c in markdown-newline pollution formatting loc-cap; do python3 Tools/wenshu-devtool/ci_change_gate.py --base 437eb698bf --check $c; done
python3 Tools/wenshu-devtool/nfi-loc-check.py --base 437eb698bf
python3 Tools/wenshu-devtool/tests/test_comment_lineage_gate.py
git diff --shortstat 437eb698bf..8e7481ff8f
git diff --shortstat 65590f4800..8e7481ff8f
```

Readings at this tip, in that order:

- judge over `437eb698bf..8e7481ff8f`: `added comment lines: 148`, `offending: 0 rows / 0
  files (P0=0, P1=0)` — and with `UNITY_CARVE=0` the same `offending: 0`, which is the gate
  passing the carve-out boundary it defines for itself.
- census: `citations: 165 | resolve: 165 | DANGLING: 0`, `OOB.md: 95 dated rows over 40
  distinct dates`, split `on one line 160 (0 dangling) + wrapped across two lines 5 (0)`.
- the four change gates: all rc 0 (`3 changed .md file(s)`, `no forbidden vocabulary`,
  `44 changed Swift file(s)`, `44 file(s) within the 600-LOC cap`).
- `nfi-loc-check --base 437eb698bf`: rc 0, `9 row(s) checked: 0 the change added, 9 whose
  named file the change rewrote and did not add`.
- the suite: `27` PASS lines, `OK — every case passed`.
- `437eb698bf..8e7481ff8f` is `50 files changed, 279 insertions(+), 174 deletions(-)`;
  the whole scope `65590f4800..8e7481ff8f` is `78 files changed, 1351 insertions(+), 367
  deletions(-)` over 21 commits.

## 5. The suite's case count, and the arm that does not exist

The suite prints 27 PASS lines where the tree carries no dangling citation, and 29 where one
is planted. Both arms were measured: a scratch worktree at `b6b09f40b2`, a dangling citation
planted in `LLMConnector.swift` and committed, three runs (27 before, 29 with the planted
site, 27 after reverting). `test_comment_lineage_gate.py:233` gates cases 8d and 8e behind
`if rep["dangling"]:`, so the guard ADDS those two cases — for three rounds this scope
published that pair backwards, and once it published `24` for a head that prints neither
number. `23` is main's own call count (24 `check(` tokens minus its `def check(`), measured
in a detached worktree at `437eb698bf`, and is not this file's low arm: main's tree carries
dangling citations, so all 23 of its calls fire.

`27` and `29` count PASS lines; `29` is also the count of `check()` calls in the file at this
tip. The `swift test --filter PaneTabStripCloseTests` reading of 29 tests in section 4 is a
DIFFERENT 29 — Swift tests, unrelated population, same magnitude. Anyone comparing those
numbers is comparing things that happen to share a digit.

## 6. Four rounds of review, and what each caught

| Card | Head it judged | Verdict | What it found |
|---|---|---|---|
| `t_78c56873` | `eed49fd964` | changes_requested | a sweep reported clean was not: 4 of 7 gate claims did not reprint from the shipped artifact; the dangling figure was 93 of 253, not 84; the registry rows it rewrote were stale (18 rows, 7 files) |
| `t_040d46e6` | `a28cc8be80` | approved | the probes carve-out measured on both sides of its boundary instead of asserted |
| `t_9c5c9538` | `c2a378aca4` | changes_requested | the judge's window measured a moving main, charging a branch for lines it never wrote; census numbers did not reprint; a truncation marker was missing |
| `t_7000a317` | `437eb698bf` | approved | merge-base resolution, with a regression case that MOVES main to prove it |
| `t_cd27cc22` | `dec391cb61` | changes_requested | registry cells copied from an older head instead of measured here |
| `t_32bf3b9e` | `f2062284c3` | changes_requested | `OOB.md:138` published 133 added comment lines where the head printed 148 (133 was the previous tip's reading, copied forward); README and nfi.md claimed a suite of 24 cases, a number nothing prints |
| `t_e9c37fab` | `b6b09f40b2` | changes_requested | `nfi-loc-check --base main` was rc 1 at that head while the card said rc 0 — `comment_lineage.py` registered at 277 against a real 282, `citation_inventory.py` at 177 against 196 — and that gate is not on the landing path, so nothing else would ever have caught it |
| `t_ff60edef` | `1d1d7c937b` | approved | re-measured both arms (27 / 29 / 27) and main's 23 independently |
| `t_15ebdbaa` | `8e7481ff8f` | approved | `README.md:384` carried a clause's lead sentence twice, a leftover of a patch that reworded one of the two halves |

The repeating shape is one mistake, not nine: **a number published from the head where it was
first written, rather than the head the card names.** Prose in `nfi.md` and the registry rows
are the same failure wearing a different file. The rule the scope ended on lives in the
`wenshu-review-proof` skill (`references/measured-prose-and-comparison-arms.md`, sections 5
and 6): the GATES list is an assertion about the sha the card body names, so it is re-run on
that sha; and a two-clause arm claim needs BOTH arms measured, with the direction read off
the guard in the code rather than off the intuition of which arm is the cheap one.

## 7. What is still red on this tree, and whose it is

The red is a suite, not the report tool, and the first version of this section got that wrong.
`python3 Tools/wenshu-devtool/inventory-measure.py` exits 0: it is a report and prints no case
names. The failure is:

```
python3 Tools/wenshu-devtool/tests/test_inventory_measure.py; echo rc=$?
#  rc=1
#  inventory-measure's matcher: 2 case(s) FAILED
#    - the guard fails when it is run from a subdirectory (= = it reads the tree by the CALLER's
#      directory, = = and not by the repository it means)
#    - the branch's added comment lines carry 83 ticket id(s): A1, A108, A112, A115, A14-A38,
#      A2, C4, D1, D2, D3, D4, F1, H1, M1, M2, P1-02, P95, R2, round-7 … (83 ids printed)
```

Two cases, not four. The same suite exits 1 with the same 2 cases at this scope's base
`437eb698bf` (83 ids) and at the pre-scope base `65590f4800` (84 ids), each measured in its own
detached worktree, so the debt predates this scope and is left standing: the boss ruled hygiene
out of this scope's remit, no fix is claimed here, and no gate is asserted that would hide it —
the change gates pass because this window's added lines are clean, not because that suite is green.

The names the first version printed — `test_cjk_and_refactor_counters`,
`test_carry_lines_do_not_double_count_a_logical_line`,
`test_citation_counter_counts_each_ref_only_on_its_first_line`,
`test_gates_that_should_fire_do_fire` — exist in no revision of this repo: `git log --all -S` on
each returns only this document. They were written from memory, which is the failure the rest of
this record warns about; section 11 logs the round that caught it.

## 8. What this scope cost on the board

Ten review cards, 9 runs on the review lane, 168.4 minutes of reviewer wall clock. Every card
completed its run: zero `rate_limited`, zero `timed_out`, zero reclaims. The rounds, not the
failures, were the price — five verdicts came back changes_requested and each cost a full
re-measure of the published numbers.

```
SKIP: this query reads the live board, so its result moves with every run anyone dispatches;
pasting it as an executable assertion would be a claim about the future. The reading below was
taken at 16:49 on 2026-11-21, in the session that wrote this record.
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(coalesce(r.ended_at,strftime('%s','now'))-r.started_at)/60.0,1) from task_runs r join tasks t on t.id=r.task_id where t.created_by='pocock' and t.title like '%[T%'"
#  592 | 14162.7
```

That reading is board-wide, so it counts every scope this profile ever dispatched (592 runs,
236.0 hours), and it grows on every re-run — the round-1 card itself is inside it. The 9-card
subset is listed in section 6, and its 168.4 minutes are the sum of the same table filtered to
the card ids named there. The reviewer's follow-up card
(`t_ed400688`) was created by the reviewer and assigned to the implementer; the fix is one
sentence and a reviewer does not dispatch implementation work to itself, so it was executed in
this scope and the card archived.

## 9. Commits, and the ones that are not mine

21 commits, `65590f4800..8e7481ff8f`, three author identities and no sibling scope inside the
range:

```
git log --format='%an' 65590f4800..8e7481ff8f | sort | uniq -c
#    15 review
#     4 t
#     2 wenshu-dev
```

- `e01689b8a1`, `b6d9c40d6a`, `a28cc8be80`, `c2a378aca4` carry `t <t@t>` — the ruling, the
  probe-boundary landing and the gate itself.
- `eed49fd964` and `19ce550670` carry `wenshu-dev <dev@wenshu.local>`: dispatched cards this
  session wrote the brief for and reviewed the result of, so this scope's work under another
  profile's identity.
- The other 15 carry `review <review@local>` — the citation repair and the four rounds of
  findings that followed it.

Both remotes were pushed and read back separately, because a push that reported success on one
remote says nothing about the other:

```
SKIP: pushing. This scope's pushes were: origin at 10:19, 12:39, 15:34, 15:44, 16:11 and
old-origin at 12:42, 15:34, 15:44, 16:11.
git ls-remote origin refs/heads/main
git ls-remote old-origin refs/heads/main
#  6747dd22295a3847e2d68b6a3b4120d7e9d5a062   (both, and git rev-parse main locally)
```

A record cannot print the sha of its own commit, so the correction this round ships under is
verified the same way rather than pasted here: after it lands, `git ls-remote origin
refs/heads/main` and `git ls-remote old-origin refs/heads/main` must both equal
`git rev-parse main`.

## 10. Left open on purpose

1. The 2 failing cases in `Tools/wenshu-devtool/tests/test_inventory_measure.py` (section 7:
   pre-existing, hygiene, not this scope's remit).
2. The wake path for board notifications still has no evidence that a subscriber receives a
   verdict; repairing it means restarting the gateway, which is off the table while other
   sessions are working. Every verdict this scope used was read by polling the board.
3. The five restored pointers are the second version of that story. If registry key cells
   keep carrying a tag after the date, the widened matcher is the thing that has to stay
   widened, and `citation_inventory.py --sites` is where a reader can check each one.
4. The census has a blind spot, and this record walked into it. `citation_inventory.py` scans
   `git ls-files -- '*.swift' '*.py' '*.sh' '*.js'`, so a pointer inside a `.md` is invisible to
   it — which is how a `DANGLING: 0` reading coexisted with a dangling pointer on line 12 of this
   file. At `6747dd2229` the tracked `.md` files carry 6 dangling pointers, 5 of them pre-existing
   (`CHANGELOG.md:48` and `:101` -> a date the register has no row for, `2026-09-24`;
   `ComponentIndex.md:188` -> `2026-09-01`, `:407` -> `2026-09-07`; `SFRegions.md:53` ->
   `2026-10-01`), left standing as hygiene. Widening the scan surface to `.md` is a tool change
   with findings of its own, not a documentation fix, and it belongs to the owner of the census.

## 11. This record's own rounds

Written on the merged tree at `8e7481ff8f`, in English. Its command blocks were each run; blocks
that mutate the tree or a remote carry a `SKIP:` line and are excluded from the re-runnable
surface. This document does not record its own review verdict — the card that judges it carries
that, and a verdict is not this file's to predict.

### Round 1 — card `t_a76df80c`, reviewed at `6747dd2229`

Two blockers and one provenance item, all reproduced by the reviewer before being filed:

- **B1** section 7 attributed the red to `inventory-measure.py` and named 4 cases under it. That
  command exits 0 and prints no case names, and those 4 names exist in no revision of this repo —
  they were written from memory. This is the record breaking its own promise, and the correction
  is in section 7 above.
- **B2** line 12 cited `OOB.md #2026-11-20`, a date the register carries zero times
  (`grep -c '2026-11-20' OOB.md` = 0); the ruling is keyed `2026-11-21` at `OOB.md:135`. The
  closure record itself shipped a dangling pointer the scope had just been spent removing, because
  the census does not read `.md` (section 10, item 4).
- **B3** the sweep row published the register's "79 comment rows", a figure measured by
  `comment_unity.py`, a tool that exists in no revision of this repo — the same copy-instead-of-
  measure failure the four preceding cards were about. The diff-derived figure replaces it.

Everything else reprinted exactly at that head: the table in section 1, the 165/165/0 census, the
148/0 judge, the 9-row registry check, the 88-token decomposition, the 93-versus-88 comparison
arm, and the push block's read-back lines.
