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

## 6. The rounds of review, and what each caught

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
| `t_a76df80c` | `6747dd2229` | changes_requested | this record itself: section 7 attributed the red to the report tool and named 4 cases that exist in no revision; line 12 carried a dangling register date; the sweep row copied the register's 79, measured by a tool the tree has never had |
| `t_e0ef2fed` | `e1b231525a` | changes_requested | round-1's three findings verified closed by measurement; section 7 was still one red short, and the correction had rewritten the same dangling pointer form into line 282 of the record it was fixing |
| `t_fcdcc953` | `c6fc14577d` | changes_requested | F1 and F2 re-run and closed; section 9 still printed the previous head — a read-back sha one commit stale, a timeline missing two arrivals, "one commit behind" where the measured distance was 2, and an outage asserted in present tense seven minutes after it ended, all of it surviving the verifier because the read-only command sat inside a `SKIP:` block |
| `t_c0d2669c` | `a9297fa128` | changes_requested | section 9's rebuild confirmed byte-exact; three sentences this commit wrote to describe its own fix carried unmeasured claims — an ellipsis the tool never prints (83 is occurrences, 19 the full distinct roster), a snapshot credited with review cards that started after its cutoff, and an absolute rule about `SKIP:` blocks that its own next section broke |

The repeating shape is one mistake, not thirteen: **a number published from the head where it was
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
in full (`test_inventory_measure.py:202-210`). An earlier version of this section claimed the tool
truncated that list and printed 19 of 83; nothing is truncated, the ellipsis was this file's own, and
the count and the roster are different units.

Two cases, not four. The same suite exits 1 with the same 2 cases at this scope's base
`437eb698bf` (83 occurrences / 19 ids) and at the pre-scope base `65590f4800` (84 occurrences), each
measured in its own detached worktree, so the debt predates this scope and is left standing: the boss
ruled hygiene out of this scope's remit, no fix is claimed here, and no gate is asserted that would
hide it — the change gates pass because this window's added lines are clean, not because that suite
is green.

The names the first version printed — `test_cjk_and_refactor_counters`,
`test_carry_lines_do_not_double_count_a_logical_line`,
`test_citation_counter_counts_each_ref_only_on_its_first_line`,
`test_gates_that_should_fire_do_fire` — exist in no revision of this repo: `git log --all -S` on
each returns only this document. They were written from memory, which is the failure the rest of
this record warns about; section 11 logs the round that caught it.

The same section was still one red short. `Tests/WenshuAppTests/Chat/View/`
`ChatViewHistoryShortcutTests.swift` `body_logs_history_metadata()` fails on this head too:

```
SKIP: this runs the Swift suite, which rebuilds first (about 5 minutes warm, much longer cold), so
it is not part of the doc's cheap re-runnable surface. It was run in the main checkout at
`e1b231525a` (dirt 0) at 17:03 on 2026-11-21, and again independently by the round-2 reviewer at
the same head; the reading is below.
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

Thirteen review cards with runs, 13 runs on the review lane, 257.8 minutes of reviewer wall clock,
and one card the reviewer created for the implementer that never ran (`t_ed400688`, archived). Every
card completed its run: zero `rate_limited`, zero `timed_out`, zero reclaims. Nine verdicts came
back changes_requested and four approved; the rounds, not the failures, were the price, and each
returned round cost a full re-measure of the published numbers.

```
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(coalesce(r.ended_at,strftime('%s','now'))-r.started_at)/60.0,1) from task_runs r where r.task_id in ('t_78c56873','t_040d46e6','t_9c5c9538','t_7000a317','t_cd27cc22','t_32bf3b9e','t_e9c37fab','t_ff60edef','t_15ebdbaa','t_a76df80c','t_e0ef2fed','t_fcdcc953','t_c0d2669c')"
#  13|257.8
```

The query sums over an EXPLICIT list of this scope's card ids, not over a creator and a time window:
every run in the list has ended, so the figure is fixed, and a filter on `created_by` would silently
price this scope with every other scope the profile ever dispatched. The card that judges **this**
revision is deliberately absent — it does not exist at the head whose figure this is — so a reader
who re-runs the query after that card has run will get a larger number, and that is the head's
reading, not a contradiction of this one.

```
SKIP: this query reads the live board, so its result moves with every run anyone dispatches;
pasting it as an executable assertion would be a claim about the future. The reading below is a
snapshot, taken at 16:49 on 2026-11-21 in the session that wrote this record, and the record cites
it only as that moment's reading — never as a current fact. Section 11 states the rule this
exception is subject to.
sqlite3 /Users/anbaiqiang/.hermes/kanban/boards/wenshu-par/kanban.db "select count(*), round(sum(coalesce(r.ended_at,strftime('%s','now'))-r.started_at)/60.0,1) from task_runs r join tasks t on t.id=r.task_id where t.created_by='pocock' and t.title like '%[T%'"
#  592 | 14162.7
```

That reading is board-wide, so it counts every scope this profile ever dispatched up to its own
cutoff: 592 runs, 14162.7 minutes (236.0 hours). Of this record's own review cards exactly **one**
was inside that cutoff — `t_a76df80c` started at 16:05:53 — while `t_e0ef2fed` (16:55:21),
`t_fcdcc953` (17:45:52) and `t_c0d2669c` (18:10:08) all started after it. The sentence here used to
say "all three of this record's own review cards are inside it", which the board's own `started_at`
column refutes; a dated snapshot has to date what it contains as well as when it was taken. The
scope's own figure is the explicit 13-card sum above, and the two numbers are not the same
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
- The other 15 carry `review <review@local>` — the citation repair and the four rounds of
  findings that followed it.

Both remotes were pushed and read back separately, because a push that reported success on one
remote says nothing about the other. Only the push itself is marked `SKIP:`; the read-back is a
command that mutates nothing, so it lives in its own executable block — a value that rides inside a
skipped block is a value the verifier cannot re-print, and that is how the last version of this
section kept a stale sha.

```
SKIP: pushing, and a push writes to a remote the reader may not own: `git push origin main` and
`git push old-origin main`, eight and seven arrivals respectively for this scope, listed below.
```

```
git reflog show --date=format:'%H:%M' origin/main | grep -E '^(a28cc8be80|437eb698bf|1d1d7c937b|8e7481ff8f|6747dd2229|e1b231525a|fc18fcc692|c6fc14577d) refs' | sed 's/ refs.*@{/  @{/; s/}: update by push//'
#  c6fc14577d  @{17:43}
#  fc18fcc692  @{17:36}
#  e1b231525a  @{16:51}
#  6747dd2229  @{16:04}
#  8e7481ff8f  @{15:44}
#  1d1d7c937b  @{15:34}
#  437eb698bf  @{12:39}
#  a28cc8be80  @{10:19}
git reflog show --date=format:'%H:%M' old-origin/main | grep -E '^(a28cc8be80|437eb698bf|1d1d7c937b|8e7481ff8f|6747dd2229|e1b231525a|fc18fcc692|c6fc14577d) refs' | sed 's/ refs.*@{/  @{/; s/}: update by push//'
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
o=$(git ls-remote origin refs/heads/main | cut -f1); m=$(git ls-remote old-origin refs/heads/main | cut -f1); l=$(git rev-parse main)
[ "$o" = "$l" ] && echo "origin == main"; [ "$m" = "$l" ] && echo "old-origin == main"
echo "delta_origin=$(git rev-list --count $o..$l) delta_old_origin=$(git rev-list --count $m..$l)"
#  origin == main
#  old-origin == main
#  delta_origin=0 delta_old_origin=0
```

The one outage this scope hit is a dated interval, not a standing state: between **17:36 and 17:43
on 2026-11-21** the route to GitHub was closed — `git push old-origin main` died on the wire,
`ssh -T git@github.com` returned `Connection closed by 198.18.0.26 port 22`, and HTTPS failed at the
handshake (`curl https://api.github.com` -> `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`, http_code
`000`). A bounded retry loop pushed on its first attempt at 17:43, and at the time of writing the
same `ssh -T` authenticates (`Hi ZIYU-FUI! You've successfully authenticated`) with
`git ls-remote old-origin refs/heads/main` answering rc 0. An earlier version of this section
asserted that wall in undated present tense and asserted a second remote "one commit behind" — the
distance was 2 against the head then shipping, and both halves stopped being true seven minutes
after they were written. Section 10 item 5 carries the reading, the check command, and the fact that
the reader, not the file, decides which side of the interval they are on.

## 10. Left open on purpose

1. The 2 failing cases in `Tools/wenshu-devtool/tests/test_inventory_measure.py`, and the chat
   lane's `ChatViewHistoryShortcutTests.body_logs_history_metadata()` (both in section 7:
   pre-existing, hygiene, not this scope's remit).
2. The wake path for board notifications still has no evidence that a subscriber receives a
   verdict; repairing it means restarting the gateway, which is off the table while other
   sessions are working. Every verdict this scope used was read by polling the board.
3. The five restored pointers are the second version of that story. If registry key cells
   keep carrying a tag after the date, the widened matcher is the thing that has to stay
   widened, and `citation_inventory.py --sites` is where a reader can check each one.
4. The census has a blind spot, and this record walked into it twice. `citation_inventory.py` scans
   `git ls-files -- '*.swift' '*.py' '*.sh' '*.js'`, so a pointer inside a `.md` is invisible to it —
   which is how a `DANGLING: 0` reading coexisted with a dangling pointer on line 12 of this file,
   and then coexisted with a second one on line 282 of the correction that fixed the first. At this
   head the tracked `.md` files carry 5 dangling pointers, all pre-existing and all outside this
   scope's remit (`CHANGELOG.md:48` and `:101` -> `2026-09-24`, a date the register has no row for;
   `ComponentIndex.md:188` -> `2026-09-01`, `:407` -> `2026-09-07`; `SFRegions.md:53` ->
   `2026-10-01`). Widening the scan surface to `.md` is a tool change with findings of its own, not a
   documentation fix, and it belongs to the owner of the census. The record's own text is written to
   avoid the pointer form for dates the register does not carry, because the tool will not catch it.
5. A remote that is down for seven minutes is not a defect the file can pin, only a reading it can
   date. Section 9 carries the interval (17:36–17:43 on 2026-11-21) and the equality read-back; the
   reader's own check is `git ls-remote origin refs/heads/main` and the same for `old-origin`, both
   compared against `git rev-parse main`. What stays open is the habit, not the push: a value printed
   inside a `SKIP:` block is never re-run, so any read-only command that lives there is a value the
   verifier cannot keep honest.

## 11. This record's own rounds

Written on the merged tree at `8e7481ff8f`, in English. Its command blocks were each run; only a block
whose command **mutates** the tree or a remote carries a `SKIP:` line. A read-only command may sit in a
skipped block on one condition, and the condition is the sentence that makes it legal rather than the
block marker: the value must be declared a dated snapshot, and the record must never cite it as
current. Section 8's board-wide census is that case. Any value the record relies on as a fact about
this head has to live in a block the verifier executes, because the skipped surface is exactly where a
stale value survives re-verification. An earlier version of this paragraph said a read-only command
was "never allowed" inside a `SKIP:` block, and the commit that wrote it carried a read-only sqlite
select in its own section 8 — the rule was falsified by the file that stated it. This document does
not record its own review verdict — the card that judges it carries that, and a verdict is not this
file's to predict.

### Round 1 — card `t_a76df80c`, reviewed at `6747dd2229`

Two blockers and one provenance item, all reproduced by the reviewer before being filed:

- **B1** section 7 attributed the red to `inventory-measure.py` and named 4 cases under it. That
  command exits 0 and prints no case names, and those 4 names exist in no revision of this repo —
  they were written from memory. This is the record breaking its own promise, and the correction
  is in section 7 above.
- **B2** line 12 pointed at register date `2026-11-20` in the pointer form, a date the register
  carries zero times (`grep -c '2026-11-20' OOB.md` = 0); the ruling is keyed `2026-11-21` at
  `OOB.md:135`. The closure record itself shipped a dangling pointer the scope had just been spent
  removing, because the census does not read `.md` (section 10, item 4). This bullet is deliberately
  written without the pointer form: the same sentence in the first correction became round 2's F2.
- **B3** the sweep row published the register's "79 comment rows", a figure measured by
  `comment_unity.py`, a tool that exists in no revision of this repo — the same copy-instead-of-
  measure failure the four preceding cards were about. The diff-derived figure replaces it.

Everything else reprinted exactly at that head: the table in section 1, the 165/165/0 census, the
148/0 judge, the 9-row registry check, the 88-token decomposition, the 93-versus-88 comparison
arm, and the push block's read-back lines.

### Round 2 — card `t_e0ef2fed`, reviewed at `e1b231525a`

Round 1's three findings were re-measured by the reviewer and closed (B1's two case names verbatim
with 19 printed ids token-for-token; B2's line 12 resolving to `OOB.md:135`; B3's 25/57/+176/-188
with all 364 changed lines being comment lines). Two new findings, both about this record's own
completeness:

- **F1** a section titled "what is still red on this tree" named one red while a second was standing.
  `ChatViewHistoryShortcutTests.body_logs_history_metadata()` fails at this head; the reviewer ran
  the filtered Swift suite independently and got the same reading recorded in section 7, then ruled
  that the fix belongs here as a disclosure line and not as a repair. The mechanism they measured is
  also not the one the first draft of that disclosure claimed: `totalTokens` is absent from the source
  file entirely, so the 1500-character window was never the cause, and section 7 now says so.
- **F2** the correction removed the pointer form from line 12 and rewrote it into line 282 of the same
  file, in the sentence that described the fix. So the census-invisible `.md` dangling count read 6
  both before and after, and the record was its own counter-example. Section 10 item 4 now states the
  count as 5 pre-existing sites and explains why the text avoids the form.

One board fact belongs here because it is how a verdict reaches a record: the reviewer's run 4805
stored its metadata under `review_outcome_details` instead of the top-level `review_outcome`, so
`review_gate.py` read the card as `not_approved` (= no verdict on the record) rather than
`changes_requested`, and `merge-preflight.sh` refused the branch for the right reason with the wrong
word. The reviewer re-stamped the run's own metadata row, with a DB snapshot beside it, without
touching the tree or the sha.

While re-measuring for this round the reflog caught a fifth figure of the same kind, in section 9 and
not in the reviewer's findings: the push timeline had listed `16:11` twice, and no push happened at
16:11 — the two arrivals were 16:04 and 16:51. It had been written from the session's memory of when
the pushes felt like they happened. Section 9 now prints the reflog's own values.

### Round 3 — card `t_fcdcc953`, reviewed at `c6fc14577d`

F1 and F2 were closed on the reviewer's own re-run, not on this record's account of them: the
filtered Swift suite fails only `body_logs_history_metadata()` at that head with `totalTokens`
measured 0 in the source and 1 in the test, `git diff --numstat 65590f4800..HEAD` prints nothing for
either file, and the `.md` census prints exactly the five sites section 10 item 4 names while the
record carries none. Section 4's 9-row and 3-`.md` readings were verified true at the head they name
(`8e7481ff8f`), in a detached worktree, where the same commands read 10 rows and 4 `.md` here — which
lines 5-6 of that section disclose rather than smooth over.

One blocker remained, and it was this record's own subject wearing its last costume: section 9 and
item 5 printed the previous head. `git ls-remote origin` and `git rev-parse main` both read
`c6fc14577d` while the block pasted `fc18fcc692`; the arrival timeline omitted both `17:43` pushes, so
`head -7` no longer returned the pasted set (the scope's arrivals on `origin` are 8); "one commit
behind" measured **2** against the head then shipping; and the GitHub outage was asserted in undated
present tense at a moment when `ssh -T git@github.com` authenticated and `ls-remote` answered rc 0.

The root cause is structural rather than arithmetic, and it is the reason the fix is a block layout
and not a corrected sha: `git ls-remote` mutates nothing and any reader can run it, but it rode
*inside* the `SKIP:`-marked push block, so `verify_doc_commands.py --run` never touched it. A value
can only be kept honest by the re-runnable surface if the value sits in a block that surface
executes. Section 9 is therefore three blocks now — the push, marked `SKIP:`; the two arrival
timelines, executable; and a read-back that prints `origin == main` / `old-origin == main` / deltas
`0` instead of a sha, because a record cannot print the sha of its own commit and an equality can be
true at every head that follows.

### Round 4 — card `t_c0d2669c`, reviewed at `a9297fa128`

Section 9's rebuild closed byte-exact on the reviewer's own run: three blocks, the `SKIP:` block
carrying no readable value at all, 8 and 7 arrival rows, the equality printing at that head, the
verifier at `PASS (12 block(s) seen, 6 executed)`, and every gate reproducing including the 12-card sum
and the registry suite at `PASS=32 FAIL=0`. Three blockers came back instead, and all three were
sentences this record had just written to describe its own fix:

- **B1'** the ellipsis in section 7's id roster was the file's, not the tool's.
  `test_inventory_measure.py:202-210` returns `sorted({tok for tok, _ in offenders})` — the full
  **19 distinct ids**, with `83` counting **occurrences**. Nothing is truncated, and a sentence blaming
  the tool for its own invented `…` is the copy-instead-of-measure failure wearing a footnote.
- **B2'** section 8 credited the 16:49 board-wide snapshot with all of this record's own review cards.
  `task_runs.started_at` puts `t_a76df80c` inside (16:05:53) and the three later cards outside
  (16:55:21, 17:45:52, 18:10:08). A dated snapshot has to date its contents, not only its timestamp.
- **B3'** the paragraph at the head of this section stated an absolute rule — no read-only command
  inside a `SKIP:` block — and the same commit left a read-only sqlite census in section 8's skipped
  block. The rule is now conditional, with section 8 naming the condition it relies on.

The shape worth carrying forward: after three rounds the defects had moved out of the numbers and into
the sentences *about* the numbers. A command block gets re-run by the verifier; a sentence about a
command block gets read once, by the person who wrote it, immediately after writing it. Every figure in
this record now names the command that prints it, and every sentence that characterises a command names
the source lines it read to learn that.
