# Session close — the comment-lineage gate, and the 88 dangling citations (2026-11-21)

This record closes one scope: the ruling that comments serve a reader who is not the agent
that wrote the change, the gate that turns that ruling into something that can fail, and the
citation debt the gate then exposed. Every number below was re-run on the MERGED tree
(`8e7481ff8f`) unless a pair is named, and each block carries the command that prints it.
Blocks that mutate the tree or a remote are marked `SKIP:` and are not part of the doc's
re-runnable surface.

## 1. What was asked

The boss ruled the comment corpus (see OOB.md #2026-11-20): a comment exists for a human
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
| The sweep | `19ce550670`, `eed49fd964`, `b6d9c40d6a` | the 79 comment rows the ruling left violating, and the 18 registry rows that sweep rewrote |
| The citation repair | `bacd13bb60` .. `5cf748ee4d` | dead pointers dropped or rewritten, wrapped sites joined, live pointers restored |
| Measure where it is read | `dec391cb61` .. `8e7481ff8f` | four rounds of findings about numbers that had been copied instead of re-measured |

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

`python3 Tools/wenshu-devtool/inventory-measure.py` fails 4 cases
(`test_cjk_and_refactor_counters`, `test_carry_lines_do_not_double_count_a_logical_line`,
`test_citation_counter_counts_each_ref_only_on_its_first_line`,
`test_gates_that_should_fire_do_fire`). It fails identically at this scope's base — measured
in a detached worktree at `437eb698bf`, the same 4 cases, and none of the 4 files sits in
this scope's diff. It is pre-existing debt, left standing: the boss ruled hygiene out of this
scope's remit, so no fix is claimed here, and no gate is asserted that would hide it — the
change gates pass because this window's added lines are clean, not because that tool is green.

## 8. What this scope cost on the board

Ten review cards, 9 runs on the review lane, 168.4 minutes of reviewer wall clock. Every card
completed its run: zero `rate_limited`, zero `timed_out`, zero reclaims. The rounds, not the
failures, were the price — five verdicts came back changes_requested and each cost a full
re-measure of the published numbers.

```
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(coalesce(r.ended_at,strftime('%s','now'))-r.started_at)/60.0,1) from task_runs r join tasks t on t.id=r.task_id where t.created_by='pocock' and t.title like '%[T%'"
#  591 | 14138.8
```

That reading is board-wide, so it counts every scope this profile ever dispatched (591 runs,
235.6 hours). The 9-card subset is listed in section 6, and its 168.4 minutes are the sum of
the same table filtered to the card ids named there. The reviewer's follow-up card
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
SKIP: pushing. This scope's pushes were: origin at 10:19, 12:39, 15:34, 15:44 and old-origin
at 12:42, 15:34, 15:44; the read-back after each is the sha below.
git ls-remote origin refs/heads/main
git ls-remote old-origin refs/heads/main
#  8e7481ff8fddc80d6202d2b3546e0953191a243f   (both, and git rev-parse main locally)
```

## 10. Left open on purpose

1. The `inventory-measure` failures in section 7 (pre-existing, hygiene, not this scope's
   remit).
2. The wake path for board notifications still has no evidence that a subscriber receives a
   verdict; repairing it means restarting the gateway, which is off the table while other
   sessions are working. Every verdict this scope used was read by polling the board.
3. The five restored pointers are the second version of that story. If registry key cells
   keep carrying a tag after the date, the widened matcher is the thing that has to stay
   widened, and `citation_inventory.py --sites` is where a reader can check each one.

## 11. This record's own rounds

Written on the merged tree at `8e7481ff8f`, in English. Its command blocks were each run, and
the results are pasted from output rather than from memory; blocks that mutate the tree or a
remote carry a `SKIP:` line and are excluded from the re-runnable surface. This document does
not record its own review verdict — the card that judges it carries that, and a verdict is not
this file's to predict.
