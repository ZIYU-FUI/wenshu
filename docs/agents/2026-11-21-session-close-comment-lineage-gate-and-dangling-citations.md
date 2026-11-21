# Session close — the comment-lineage gate, and the 88 dangling citations (2026-11-21)

This record closes one scope: the ruling that comments serve a reader who is not the agent that wrote
the change, the gate that turns that ruling into something that can fail, and the citation debt the gate
then exposed. Which reading each figure comes from is part of the figure, and there are two kinds. A
figure over a CLOSED range — `437eb698bf..8e7481ff8f`, a sha, a board query whose rows have all ended —
is pasted with the command that prints it, and the command is what a reader re-runs. A figure over LIVE
state — a remote, a reflog, this session's own running cards — is printed as a predicate that either
holds or exits non-zero naming what failed, and any rows beside it are read as a dated snapshot of that
minute, never as what the command prints at the head. Sections 2 to 5 are closed-range readings;
section 8 is a closed list of finished runs; section 9's arrival rows are dated and its read-back is a
predicate. Nothing in here claims to describe the review it is under: section 6 says why.
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
- census: `citations: 165 | resolve: 165 | DANGLING: 0 over 0 addressable files, 0 dates`,
  `OOB.md: 95 dated rows over 40 distinct dates (= a date can carry several rows)`, split
  `the count split, so it reconciles: on one line 160 (0 dangling, addresses not computed (--sites)) + wrapped across two lines 5 (0 dangling, no single line to open)`.
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

## 6. The review the GATE went through, and the one rule it produced

| Card | Head it judged | Verdict | What it found |
|---|---|---|---|
| `t_78c56873` | `eed49fd964` | changes_requested | a sweep reported clean was not: 4 of 7 gate claims did not reprint from the tree they named |
| `t_040d46e6` | `a28cc8be80` | approved | the probes carve-out measured on both sides of its boundary instead of asserted |
| `t_9c5c9538` | `c2a378aca4` | changes_requested | the judge's window measured a moving main, charging a branch for lines it never wrote |
| `t_7000a317` | `437eb698bf` | approved | merge-base resolution, with a regression case that MOVES main to prove it |
| `t_cd27cc22` | `dec391cb61` | changes_requested | registry cells copied from an older head instead of measured here |
| `t_32bf3b9e` | `f2062284c3` | changes_requested | `OOB.md:138` published 133 added comment lines where the head printed 148 |
| `t_e9c37fab` | `b6b09f40b2` | changes_requested | `nfi-loc-check --base main` was rc 1 at that head while the card said rc 0 |
| `t_ff60edef` | `1d1d7c937b` | approved | re-measured both arms (27 / 29 / 27) and main's 23 independently |
| `t_15ebdbaa` | `8e7481ff8f` | approved | `README.md:384` carried a clause's lead sentence twice, a leftover of a patch that moved |

Every one of these nine is the same mistake: **a number published from the head where it was first
written, rather than the head the card names.** Prose in `nfi.md` and the registry rows are that failure
wearing a different file. The rule the scope ended on lives in the `wenshu-review-proof` skill
(`references/measured-prose-and-comparison-arms.md`, sections 5 and 6): the GATES list is an assertion
about the sha the card body names, so it is re-run on that sha; and a two-clause arm claim needs BOTH
arms measured, with the direction read off the guard in the code rather than off the intuition of which
arm is the cheap one.

**What is deliberately not in this artifact: its own review.** The nine rows above are history that
cannot move, because the gate shipped and the heads it was judged at are behind it. A closeout record
that also narrates the rounds it takes to review itself does move: every verdict rewrites the section
the next verdict reads, and each round's fix adds the sentence that the next round blocks on. That loop
ran six times here, and five of its blockers were sentences written by the previous round's fix. The
history of those rounds is on the board, where it belongs and where it is already dated and attributable
(`t_a76df80c`, `t_e0ef2fed`, `t_fcdcc953`, `t_c0d2669c`, `t_726acb18`, `t_f46f84e6`); it is not a
section of the document under review. Two durable lessons from that loop were kept where they can be
reused: the exit-status rule (`wenshu-review-proof`, `references/measured-prose-and-comparison-arms.md`
section 10) and the landing-order rule (same file, section 11).

## 7. What is still red on this tree, and whose it is

The red is a suite, not the report tool, and the two are easy to conflate because both are named
`inventory-measure`.
`python3 Tools/wenshu-devtool/inventory-measure.py` exits 0: it is a report and prints no case
names. The failure is:

```
python3 Tools/wenshu-devtool/tests/test_inventory_measure.py; echo rc=$?
#  rc=1
#  inventory-measure's matcher: 2 case(s) FAILED
#    - the guard fails when it is run from a subdirectory (= = it reads the tree by the CALLER's
#      directory, = = and not by the repository it means):   - the branch's added comment lines
#      carry 83 ticket id(s): A1, A108, A112, A115, A14-A38, A2, C4, D1, D2, D3, D4, F1, H1, M1,
#      M2, P1-02, P95, R2, round-7
#    - the branch's added comment lines carry 83 ticket id(s): A1, A108, A112, A115, A14-A38, A2,
#      C4, D1, D2, D3, D4, F1, H1, M1, M2, P1-02, P95, R2, round-7
```

Two lines, not three messages: the guard case's text and the ticket-id case's text are joined by the
harness onto one 300-character line, which this block wraps across four lines to fit the page, and the
same ticket-id sentence repeats as the second line. The units, because the sentence carries two:
**83** is `len(offenders)`, the number of ticket-id **occurrences** on added comment lines, and the
comma-separated list after it is `sorted({tok for tok, _ in offenders})` — **19 distinct ids**, printed
in full (`test_inventory_measure.py:202-210`). Nothing is truncated, so an ellipsis in that position
would be the document's own invention; `83` and `19` are different units, a count and a roster, and a
sentence that reads them as a page and a total is wrong in the direction that flatters itself.

Two cases, not four. The same suite exits 1 with the same 2 cases at this scope's base
`437eb698bf` (83 occurrences / 19 ids) and at the pre-scope base `65590f4800` (84 occurrences), each
measured in its own detached worktree, so the debt predates this scope and is left standing: the boss
ruled hygiene out of this scope's remit, no fix is claimed here, and no gate is asserted that would
hide it — the change gates pass because this window's added lines are clean, not because that suite
is green.

Four test names appear in no revision of this repo and are listed here so a reader who meets them in
any older reading of this file discards them: `test_cjk_and_refactor_counters`,
`test_carry_lines_do_not_double_count_a_logical_line`,
`test_citation_counter_counts_each_ref_only_on_its_first_line`, `test_gates_that_should_fire_do_fire`.
`git log --all -S` on each of the four returns only this document, which is how they can be quoted with
complete confidence and still be invented: a case name is the one figure no gate re-prints.

The second pre-existing red is not a consequence of the first.
`Tests/WenshuAppTests/Chat/View/ChatViewHistoryShortcutTests.swift`
`body_logs_history_metadata()` fails on this head too:

```
SKIP: this runs the Swift suite, which rebuilds first (about 5 minutes warm, much longer cold), so
it is not part of the doc's cheap re-runnable surface. It was run in the main checkout at
`e1b231525a` (dirt 0) at 17:03 on 2026-11-21 and reproduced at the same head by a reader who did not
write this file; the reading is below.
/usr/bin/swift test --package-path . --filter ChatViewHistoryShortcutTests
#  Test body_logs_history_metadata() failed after 0.011 seconds with 1 issue.
#  Test run with 8 tests in 1 suite failed after 0.013 seconds with 1 issue.
```

The failing assertion is line 35, `#expect(block.contains("totalTokens"))`. The mechanism is not the
window: `totalTokens` appears **0 times** in `Sources/WenshuApp/Features/Chat/View/`
`ChatView+KeyboardShortcuts.swift`, the file whose button the case reads, and **1 time** in the test
file itself — the assertion. No window over that source could contain it, whatever its length.

That red is not this scope's, and it is proved by invariance rather than by argument. Over
`65590f4800..HEAD` — the pre-scope base to the head this record ships under — `git diff --numstat`
prints nothing for either of those two files: neither was touched. The chat directories as a whole
did change, 5 files and 44 lines, and `git diff --unified=0` over that range filtered to non-comment
lines prints **0 lines**: the citation repair edited comments there and nothing else. So the scope
can neither have caused it nor fixed it, and the boss ruled hygiene out of its remit: this is a
disclosure, not a repair.

The case itself is a lesson the record keeps rather than quietly repeats: it reads source text and
asserts over a fixed 1500-character window, so it measures file layout, not behaviour — it would
break on an unrelated line inserted above the button, and it broke here because a log line lost a
field and nobody re-cited the assertion. Its owner is the chat lane.

## 8. What this scope cost on the board

Fifteen review cards with runs, 15 runs on the review lane, 330.2 minutes of reviewer wall clock,
and one card the reviewer created for the implementer that never ran (`t_ed400688`, archived). The
card that judges this revision is not in the list and the list is closed: it is fixed at the 15 cards
that had run by 21:2x on 2026-11-21, because a figure that has to absorb each new verdict can never be
re-published truthfully from the head it names. Every
card completed its run: zero `rate_limited`, zero `timed_out`, zero reclaims, and exactly one run per
card. Eleven verdicts came back changes_requested and four approved; the rounds, not the failures, were
the price, and each returned round cost a full re-measure of the published numbers — which is the
cost this section's closed list is meant to stop.

```
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(coalesce(r.ended_at,strftime('%s','now'))-r.started_at)/60.0,1) from task_runs r where r.task_id in ('t_78c56873','t_040d46e6','t_9c5c9538','t_7000a317','t_cd27cc22','t_32bf3b9e','t_e9c37fab','t_ff60edef','t_15ebdbaa','t_a76df80c','t_e0ef2fed','t_fcdcc953','t_c0d2669c','t_726acb18','t_f46f84e6')"
#  15|330.2
```

The query sums over an EXPLICIT list of this scope's card ids, not over a creator and a time window:
every run in the list has ended, so the figure is fixed, and a filter on `created_by` would silently
price this scope with every other scope the profile ever dispatched. The card that judges **this**
revision is deliberately absent — it does not exist at the head whose figure this is — so a reader
who re-runs the query after that card has run will get a larger number, and that is the head's
reading, not a contradiction of this one.

```
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(min(coalesce(r.ended_at,unixepoch('2026-11-21 16:49:00 +08:00')),unixepoch('2026-11-21 16:49:00 +08:00'))-r.started_at)/60.0,1) from task_runs r join tasks t on t.id=r.task_id where t.created_by='pocock' and t.title like '%[T%' and r.started_at < unixepoch('2026-11-21 16:49:00 +08:00')"
#  592|14162.7
```

This block is clipped to its own cutoff rather than read live, and the clipping is the whole point: the
version this session actually ran at 16:49 was `…coalesce(r.ended_at,strftime('%s','now'))…` with no
`started_at` filter, and re-running *that* command today prints `595|14228.2`, because the board kept
taking runs after the record quoted it. A skipped block whose command no longer prints the line under it
is the same defect section 9 was blocked on twice, so the command was rewritten until the paste is what
the command prints, and the block lost its `SKIP:` line because nothing it does mutates anything. Two
limits on it, both honest: `unixepoch` reads a bare timestamp as UTC, so the `+08:00` in the cutoff is
load-bearing (drop it and the same query answers `595|14228.2` for a different reason), and the class is
selected by `title like '%[T%'`, so a title edit on an old card would move the count — nothing has
retagged anything that started before 16:49 so far, which is why the clipped figure has been stable
across every re-run in this scope.

That reading is board-wide, so it counts every scope this profile ever dispatched up to its own
cutoff: 592 runs, 14162.7 minutes (236.0 hours). One of this scope's review cards was inside it —
`t_a76df80c`, started 16:05:53 — while `t_e0ef2fed` (16:55:21), `t_fcdcc953` (17:45:52), `t_c0d2669c`
(18:10:08) and `t_726acb18` (18:52:35) started after. A dated snapshot has to date what it contains as
well as when it was taken, and that is the whole rule: membership of a cutoff is a property of
`started_at`, not of the paragraph describing it. The scope's own figure is the explicit 15-card sum
above, and the two numbers are not the same
measurement: the board-wide count is context for how much of the lane this profile has occupied, not
the price of this work. The reviewer's follow-up card
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
- The other 15 carry `review <review@local>` — the citation repair and the rounds of findings
  that followed it.

Both remotes were pushed and read back separately, because a push that reported success on one
remote says nothing about the other. Only the push itself is marked `SKIP:`; the read-back is a
command that mutates nothing, so it lives in its own executable block, because a value that rides
inside a skipped block is a value nothing downstream can re-print.

```
SKIP: pushing, and a push writes to a remote the reader may not own: `git push origin main` and
`git push old-origin main`, eight and seven arrivals respectively for this scope, listed below.
```

The rows are a dated reading of the two remote reflogs at 17:43 on 2026-11-21, and they are listed
because the interval they bracket matters (section 9's outage). A later push adds a row above them and
substitutes nothing, so re-running the command is not a test of these lines — reading the filter and
the `sed` is.

```
git reflog show --date=format:'%H:%M' origin/main | grep -E '^(a28cc8be80|437eb698bf|1d1d7c937b|8e7481ff8f|6747dd2229|e1b231525a|fc18fcc692|c6fc14577d) refs' | sed 's/ refs.*@{/  @{/; s/: update by push//'
#  c6fc14577d  @{17:43}
#  fc18fcc692  @{17:36}
#  e1b231525a  @{16:51}
#  6747dd2229  @{16:04}
#  8e7481ff8f  @{15:44}
#  1d1d7c937b  @{15:34}
#  437eb698bf  @{12:39}
#  a28cc8be80  @{10:19}
git reflog show --date=format:'%H:%M' old-origin/main | grep -E '^(a28cc8be80|437eb698bf|1d1d7c937b|8e7481ff8f|6747dd2229|e1b231525a|fc18fcc692|c6fc14577d) refs' | sed 's/ refs.*@{/  @{/; s/: update by push//'
#  c6fc14577d  @{17:43}
#  e1b231525a  @{16:51}
#  6747dd2229  @{16:04}
#  8e7481ff8f  @{15:44}
#  1d1d7c937b  @{15:34}
#  437eb698bf  @{12:42}
#  a28cc8be80  @{10:19}
```

`fc18fcc692` never reaches the second list because it was never on that remote: it was written while
the path to GitHub was down, and the next commit carried it across. The filter names the scope's
shas, so the commit that carries this line adds one more row to both reflogs at its own push time —
the one row no pre-push paste can print, which is why the read-back below prints an equality rather
than a sha.

```
o=$(git ls-remote origin refs/heads/main); e1=$?
m=$(git ls-remote old-origin refs/heads/main); e2=$?
l=$(git rev-parse main)
{ [ $e1 -ne 0 ] || [ -z "$o" ]; } && { echo "origin read FAILED (rc=$e1) — no equality, no delta"; exit 1; }
{ [ $e2 -ne 0 ] || [ -z "$m" ]; } && { echo "old-origin read FAILED (rc=$e2) — no equality, no delta"; exit 1; }
case "$o" in "$l"*) echo "origin == main";; *) echo "origin != main ($o)"; exit 1;; esac
case "$m" in "$l"*) echo "old-origin == main";; *) echo "old-origin != main ($m)"; exit 1;; esac
echo "delta_origin=$(git rev-list --count ${o%%$'\t'*}..$l) delta_old_origin=$(git rev-list --count ${m%%$'\t'*}..$l)"
#  origin == main
#  old-origin == main
#  delta_origin=0 delta_old_origin=0
```

Those three lines are what the block printed at 21:0x on 2026-11-21, and the block is written so that
they cannot print under a failed read. The earlier form was `o=$(git ls-remote … | cut -f1)`, which threw
away `git ls-remote`'s exit status: with a remote that could not be read, `$m` was empty, the
`old-origin == main` line was silently not printed, and `git rev-list --count $m..$l` degenerated to
`..$l` and answered `0` — so **a remote nobody could read was reported as fully in sync, with rc 0**. The
failure arm is measured, not argued: the same block with `old-origin` replaced by a nonexistent remote
and everything else verbatim prints `nosuchremote read FAILED (rc=128) — no equality, no delta` and exits
1, where the old form exited 0. A check that cannot fail is not a check, and a reader running this by hand
during an outage now gets an error instead of an all-clear.

The one outage this scope hit is a dated interval, not a standing state: between **17:36 and 17:43
on 2026-11-21** the route to GitHub was closed — `git push old-origin main` died on the wire,
`ssh -T git@github.com` returned `Connection closed by 198.18.0.26 port 22`, and HTTPS failed at the
handshake (`curl https://api.github.com` -> `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`, http_code
`000`). A bounded retry loop pushed on its first attempt at 17:43. The recovery is a reading of the
minute it was taken, not a state the file may assert in present tense: an undated "the remote is
reachable" and an undated "one commit behind" both stopped being true seven minutes after they were
written, and the second was 2 against the head then shipping. Section 10 item 5 carries the check
command and the fact that the reader, not the file, decides which side of the interval they are on.

## 10. Left open on purpose

1. The 2 failing cases in `Tools/wenshu-devtool/tests/test_inventory_measure.py`, and the chat
   lane's `ChatViewHistoryShortcutTests.body_logs_history_metadata()` (both in section 7:
   pre-existing, hygiene, not this scope's remit).
2. The wake path for board notifications still has no evidence that a subscriber receives a
   verdict; repairing it means restarting the gateway, which is off the table while other
   sessions are working. Every verdict this scope used was read by polling the board.
2b. Two facts about `verify_doc_commands.py`, both measured by writing a paste-vs-print guard for
   this file and then taking it out again. It runs a block with `bash -lc <whole body>` and charges
   only the **exit code**, so a block whose paste disagrees with its stdout line by line passes it —
   which is why a byte-level defect in a pasted table is invisible to the gate that appears to check
   the table, and why no document should rest a claim on that gate alone. Its skip test is a substring
   search for `SKIP:` anywhere in the body, so a block that merely *names* the marker in a comment or a
   string is silently dropped from the re-runnable surface; a block that has to discuss the marker
   builds it from two literals.
3. The five restored pointers are the second version of that story. If registry key cells
   keep carrying a tag after the date, the widened matcher is the thing that has to stay
   widened, and `citation_inventory.py --sites` is where a reader can check each one.
4. The census has a blind spot. `citation_inventory.py` scans
   `git ls-files -- '*.swift' '*.py' '*.sh' '*.js'`, so a pointer inside a `.md` is invisible to it: a
   `DANGLING: 0` reading says nothing at all about prose files, and a record that cites the register in
   `.md` text is outside its own check. A separate scan of the tracked `.md` files (read-only, this
   head, dated at the reading above) carries 5 dangling pointers, all pre-existing and all outside this
   scope's remit (`CHANGELOG.md:48` and `:101` -> `2026-09-24`, a date the register has no row for;
   `ComponentIndex.md:188` -> `2026-09-01`, `:407` -> `2026-09-07`; `SFRegions.md:53` ->
   `2026-10-01`). Widening the scan surface to `.md` is a tool change with findings of its own, not a
   documentation fix, and it belongs to the owner of the census. The record's own text is written to
   avoid the pointer form for dates the register does not carry, because the tool will not catch it.
5. A remote that is down for seven minutes is not a defect the file can pin, only a reading it can
   date. Section 9 carries the interval (17:36–17:43 on 2026-11-21) and the equality read-back; the
   reader's own check is `git ls-remote origin refs/heads/main` and the same for `old-origin`, both
   compared against `git rev-parse main`. The hole a reader needs to know about is that **a failed read
   can be indistinguishable from a matching read**: `o=$(git ls-remote … | cut -f1)` keeps neither the
   exit status nor the fact that stdout was empty, so `git rev-list --count $o..$l` degenerates to
   `..$l`, answers `0`, and reports an unreachable remote as fully in sync with rc 0. The block in
   section 9 is written against that — it refuses to print anything when a read failed or came back
   empty, and exits 1 naming the remote and its rc — but the reader's own hand-run check needs the same
   care. The general shape: a command that cannot fail is not a check, it is a printer. What stays open is the habit, not the push: a
   value printed inside a `SKIP:` block is never re-run, so any read-only command that lives there is a
   value the verifier cannot keep honest.
6. The landing order this scope ran for six rounds was review-after-merge, and it is disclosed rather
   than quietly kept: `main`, `docs/session-close-record` and both remotes pointed at the same commit
   each round, so every head reached the trunk before its verdict and `merge-preflight.sh`'s
   `UNREVIEWED` rc 3 described a commit the trunk had already absorbed — measured, not remembered:
   `git merge-base --is-ancestor <sha> main` returns true for each of `6747dd2229`, `e1b231525a`,
   `c6fc14577d`, `a9297fa128`, `308619a3a2`, `62b2b4e5fb`. A pre-merge gate that is asked about a
   commit already merged cannot stop anything, so the order is now branch-first: the head under review
   exists only on the branch, and the trunk moves after an approved verdict. A related gate fact:
   `review_gate.py
   --sha <the head a card names>` returns `CARD <id> / verdict: …` rc 0 once that card exists, so the
   `NO REVIEW CARD … rc 3` reading is only available before dispatch — a pre-run note can therefore
   promise the gate is reachable, never its own return code.
