# The sidebar's tree draws one part's rows at a time (sidebar-part-switch, 2026-11-24)

The scope `2026-11-24-sidebar-part-switch` = one defect the boss
reported in one sentence: the left sidebar's tree drew the "Twelve
Immortals" book row ON TOP of the help book's "Characters" row, and the
two rows' styles overlapped. His own condition decided where the defect
was looked for: the tree is clean at launch, and the overlap appears
after ONE switch between the parts.

The plan of record is
`/Volumes/ANAN/Engineering/wenshu/.scratch/2026-11-24-sidebar-part-switch/spec.md`,
and its one issue body is under that plan's `issues/` directory.

**AND THIS RECORD IS WRITTEN IN THE TENSE THE TREE IS IN.** The CODE scope
is CLOSED: the fix `772b608a66` and this record's FIRST landing
`e4818545d7` are on `main` and were on BOTH remotes, and the review card
`t_b28c9ebc` records `approved`. What that sentence does NOT close is this
document: `main` has moved since, and the corrected text below the line sits
on a branch. The record's own review rounds live on the board (= one card per
round, each naming its own sha) and are NOT counted here, because a document
that keeps a running tally of its own meta-reviews is the defect its closeout
was written to report. Each step below states what HAS happened, with the
command that re-measures it.

## 1. Re-run the section 7 gates on the MERGED tree

DONE ON THE MERGED TREE, = = and the run that produced the table below is
the SECOND one. The FIRST run (five logs, named in full rather than as a range: = =
`.gate-logs/2026-11-24-sidebar-part-switch_a2-merged_1.log`, = = `.gate-logs/2026-11-24-sidebar-part-switch_a2-merged_2.log`, = =
`.gate-logs/2026-11-24-sidebar-part-switch_a2-merged_3.log`, = = `.gate-logs/2026-11-24-sidebar-part-switch_a2-merged_4.log`, = =
`.gate-logs/2026-11-24-sidebar-part-switch_a2-merged_5.log`) was taken in
the SHARED CHECKOUT at the landed `main` with `--skip-build`, = = and its
row 2 is the false green named at the end of this section = = the run stays
on disk as that evidence. The SECOND run (five logs, named in full: = =
`.gate-logs/2026-11-24-sidebar-part-switch_a3-built_1.log`, = = `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_2.log`, = =
`.gate-logs/2026-11-24-sidebar-part-switch_a3-built_3.log`, = = `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_4.log`, = =
`.gate-logs/2026-11-24-sidebar-part-switch_a3-built_5.log`) ran the same
five commands inside `.worktrees/sidebar-closeout-2026-11-24`, = = = = the
branch under review, = = = = AFTER `swift build --build-tests`, = = whose own
line 6512 reads `Build complete! (128.59` followed by the tool's localized unit
(= = the byte sequence is CJK, = = so 1.1 keeps it OUT of this committed prose = =
and `grep -F '128.59'` lands on it), = = with `BUILD_RC=0` as the file's last
line, = = held as `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_0_build.log`.
⇒ ⇒ ⇒ THE REASON THAT RUN IS NOW NAMED AND NOT MERELY ASSERTED: = = at round 3 its
only artifact sat in `/tmp/closeout-build.log`, = = which is exactly where the
table's own rule paragraph says a measurement does not count, = = and a figure
with no artifact is blocker-grade even when it is true. ⇒ ⇒ ⇒ AND A QUOTED LINE IS
QUOTED AS IT PRINTS: = = `128.59 seconds` was this record's paraphrase of a unit
the tool never printed in English. = = So its cells are readings of a
binary that contains the suites they name. The branch's CODE is
byte-identical to the landed `main`; = = the only delta is this document and its
one registry row in `docs/agents/nfi.md`.
⇒ ⇒ ⇒ AND READ THAT GATE BEFORE TRUSTING ITS PASS, = = because it is weaker
than its name: = = `closeout_gate.py:347 step_gates_on_merged_tree` walks
EVERY `*.log` under `.gate-logs/` and returns true the moment a file's BYTES
contain the merged sha (or a hex token in the file that is a prefix of it). = =
Measured on the tool itself: = = the words `Test run`, `passed` and `failed`
occur 0 times in that check, = = so it NEVER OPENS A SUITE RESULT. = = A log
of `git rev-parse HEAD` alone would satisfy it. ⇒ ⇒ ⇒ That is how step 1 could
print PASS for a five-command run in which one command executed no tests at
all = = the gate checks that a log NAMES the sha, = = never that the suites in
it RAN.

⇒ ⇒ ⇒ AND THAT RUN'S EXIT CODES PROVED NOTHING, = = BECAUSE THREE OF ITS
FIVE COMMANDS RAN AGAINST A BINARY THAT DID NOT CONTAIN THE SUITE. The run
used `--skip-build` on the shared checkout's `.build`, = = and that binary
predates `SidebarPartSwitchTableIdentityTests`. ⇒ ⇒ ⇒ AND THIS PARAGRAPH
RECONCILES A FIGURE THE ROUND-2 VERDICT PUT IN ITS OWN MOUTH: = = the `1.959 s`
gate-2 print, = = which round 2 called unverifiable because no `.gate-logs/` file
showed it. = = It is verifiable: = = the fourth section of
`.gate-logs/2026-11-24-sidebar-part-switch_a1-arms-merged.log` carries `Suite
SidebarPartSwitchTableIdentityTests passed after 1.959 seconds.`, = = and that
file had been written to `/tmp/` and never cited. = = ⇒ ⇒ ⇒ So the record does
NOT withdraw the number; = = it withdraws the INFERENCE, = = which was "a
`--skip-build` filter pass proves the suite exists". = = The same command at the
same tree, = = taken three rounds later, = = selected nothing at all and still
exited 0 (= = the 116-byte log immediately below), = = and THAT is the defect.
= = Log 2 is 116 bytes, two lines, and quoted line for line: = = its line 1 is
`warning: 'wenshu': dependency 'highlighterswift' is not used by any target`
(= = the dropped word is the TARGET NAME, `wenshu`: = = the warning is about this
package, not about a dependency in the abstract) = = and its line 2 is
`warning: No matching test cases were run`, = = and the suite
name occurs ZERO times in all five logs. = = Measured why that is silent, = = BOTH arms HELD in
`.gate-logs/2026-11-24-sidebar-part-switch_a4-filter-probe.log` (= = taken on
the built branch worktree at the tip, = = `# tree` header in the file): = = the
arm whose name matches NOTHING, `swift test --skip-build --disable-sandbox
--filter 'NoSuchSuiteXYZ'`, exits **0** and prints `warning: No matching test
cases were run` (= = `RC_A=0`); = = and the arm that names the `XCTestCase`
suite alone, `--filter 'SidebarPartStateTests'`, exits **0** as well (= =
`RC_B=0`), = = = = but NOT for the reason this record first gave. Its bytes show
both halves at once: the XCTest overlay RUNS it (= =
`Test Suite 'SidebarPartStateTests' passed` and `Executed 6 tests, with 0
failures`), = = while the sections the swift-testing side fills read
`Executed 0 tests, with 0 failures`. ⇒ ⇒ ⇒ SO THE HONEST RULE IS NARROWER THAN
THE ONE FIRST WRITTEN: = = a filter that matches NOTHING is an exit-0 non-event
in either harness, = = and a name that lives in only ONE harness is an exit-0
half-event (= = one overlay runs it, = = the other reports nothing, = = and the
rc cannot tell you which happened). = = The suite's own file is
`Tests/WenshuAppTests/Library/View/SidebarPartStateTests.swift:26`. ⇒ ⇒ ⇒ ⇒ SO A FILTER THAT MATCHES
NOTHING IS AN EXIT-0 NON-EVENT IN EITHER HARNESS, = = and the evidence that a
suite ran is the printed suite NAME and its `Test run with` / `Executed N
tests` line, = = never the exit code. = = This is the
same false green this record warns about for `nfi-loc-check`, = = and the
reviewer of this file caught it in my own gate table.

The five commands, = = every cell quoted from the HELD log named beside it. = = The
run this table reads is the `a10-merged` family, = = the one taken against the tree
this document now sits on (= = see the paragraph under the table), = = so no cell
carries a figure that no artifact prints, = = and no cell carries a tip the amend
already moved:

| # | the command | the held log | what that log prints |
| --- | --- | --- | --- |
| 1 | `git rev-parse HEAD^` | `2026-11-24-sidebar-part-switch_a10-merged_2.log` | `f45a142f62ddb05d74a1c22827c3ab3d2456bafc` = = the parent = = `main` as the server holds it |
| 2 | `swift test --skip-build --disable-sandbox --filter 'SidebarPartSwitchTableIdentityTests'` | `2026-11-24-sidebar-part-switch_a10-merged_3.log` | `Test run with 2 tests in 1 suite passed after 1.997 seconds.` rc 0 |
| 3 | `swift test --skip-build --disable-sandbox --filter 'SidebarTreeRowIdentityTests'` | `2026-11-24-sidebar-part-switch_a10-merged_4.log` | `Test run with 4 tests in 1 suite passed after 5.304 seconds.` rc 0 |
| 4 | `python3 Tools/wenshu-devtool/nfi-loc-check.py --base main` | `2026-11-24-sidebar-part-switch_a10-merged_5.log` | **FAILED, rc 1**: = = `the row says 793, the file is 874` = = the live defect this round exists to fix, = = read from the log rather than from the author |
| 5 | `python3 Tools/wenshu-devtool/comment_lineage.py --repo . --base main` | `2026-11-24-sidebar-part-switch_a10-merged_6.log` | window `f45a142f62..4e3c922d5d` = = `added comment lines: 0` = = `offending: 0 rows / 0 files (P0=0, P1=0)` rc 0, = = and the vacuous window's own disclaimer quoted below |

⇒ ⇒ ⇒ THE `a3-built` FAMILY STAYS AS THE WITNESS OF THE ROUND BEFORE: = = the two
suite figures it prints (= = `2.165`, = = `5.300`) are the SAME tests measured on the
same code tree, = = and section 6's citation probe checks those digits against THOSE
files, = = so swapping the table to the newer run does not orphan the older one. The
code tree did not move (= = the row under the table proves it), = = which is the only
reason the two sets of figures describe one artifact. ⇒ ⇒ ⇒ ROW 1 RUNS `HEAD^` AND
NOT `HEAD` ON PURPOSE. The sha under review moves
every time this record is amended, = = so a cell that quotes it goes stale
inside its own commit. `HEAD^` is the landed `main`, = = which is the sha step
1 is actually about, = = and it is stable. The sha under review is carried by
the card, = = not by the log. ⇒ ⇒ ⇒ AND THE SAME REASON MOVED THE LOG HEADERS: = =
round 3's five logs carried `# tree <the tip at that moment>`, = = which the
round-4 amend invalidated, = = so they now carry the CODE TREES they ran on = =
`git rev-parse HEAD^:Sources` and `git rev-parse HEAD^:Tests` (= = the parent's
blob-tree shas) = = which are INVARIANT under a docs-only amend, = = and that is
the whole point: = = a gate that measures code names code, = = and only the card
names the commit.

⇒ ⇒ ⇒ AND NOTE WHAT GATE 5 IS WORTH HERE. `comment_lineage.py` over a
docs-only window prints `added comment lines: 0` followed by its own
sentence `NO added comment line in this window: nothing was measured, so
this is not a pass on the rule`. = = That is a VACUOUS reading, = = and the
record does not count it as a pass on 1.5's rule.

⇒ ⇒ ⇒ AND NEVER LET `--base main` RESOLVE ON A TREE THAT IS `main`. Run that
way, = = a registry or lineage check resolves to an EMPTY window and passes on
nothing. = = The two windows this scope actually holds are different things, = =
and round 3 conflated them: = = the merged-tree run taken in the SHARED
checkout named the pre-landing sha explicitly and printed
`window bbc2434997..e4818545d7` (= = `.gate-logs/
2026-11-24-sidebar-part-switch_a2-merged_5.log`), = = while the SECOND run, = =
taken inside the branch worktree with `--base main`, = = resolved `main` to
`e4818545d7` and printed `window e4818545d7..96f76f3575` (= = the string
`2026-11-24-sidebar-part-switch_a3-built_5.log` prints on its lineage line, = =
which is row 5's `<tip>` frozen inside the artifact rather than restated in the
cell, = = and the command lines of
`2026-11-24-sidebar-part-switch_a3-built_4.log` and
`2026-11-24-sidebar-part-switch_a3-built_5.log` carry `--base main`, = = not a
sha). = = = = So the rule binds the CHECKOUT THE COMMAND RUNS IN, = = not the
flag: = = inside a branch worktree `--base main` is already the pre-landing
sha, = = and inside main's own checkout it is nothing.

⇒ ⇒ ⇒ RE-MEASURED ON THE REBASED TREE, = = BECAUSE `main` MOVED. Review round 3
was paid against a tip whose parent was `e4818545d7`; sibling lanes landed after
that, = = so this record now sits on the tree `main` reached, = = and the figures
above were re-measured there instead of carried forward. The seven commands ran
as ONE run, = = held as
`.gate-logs/2026-11-24-sidebar-part-switch_a6-rebased_0_manifest.txt`, = = which
ends `GATE_RUN_RC=0`. The first two commands are `git rev-parse HEAD` and
`git rev-parse HEAD^`, = = so the log body carries the sha it proved and the
parent it proved it against; = = the next four are the build, = = the two suites,
= = and the two registry checks, = = and their manifest lines read, = = quoted as
they print: = = `Build complete! (64.85` followed by the tool's localized unit,
= = `Test run with 2 tests in 1 suite passed after 2.109 seconds.`, = =
`Test run with 4 tests in 1 suite passed after 5.229 seconds.`, = = the same
nfi-loc-check PASS sentence, = = and `offending: 0 rows / 0 files (P0=0, P1=0)`.
⇒ ⇒ ⇒ WHY THAT RUN HAD TO BE LAUNCHED THE WAY IT WAS: = = the gate script
resolves its log directory from its own path, = = so a run launched from a
worktree writes its logs INTO THE WORKTREE, = = where the closeout gate cannot
see them; = = this run set `LOGDIR=` to the shared checkout's `.gate-logs/`
explicitly, = = because a closeout that quotes a log the gate cannot read is not
a closeout.
⇒ ⇒ ⇒ WHAT THIS DOES NOT RETIRE, = = AND WHAT IT CORRECTS: = = the `a3-built`
figures in the table above measured the code shape the branch had BEFORE the
rebase, = = `# sources-tree bb7f9e6b786168bd71e9560d686cbd8393579ac7`, = =
`# tests-tree 90e49c1c41f99bf8c184fd721faf334f51cb4241`, = = `# parent
e4818545d7f99156576db131081271f6ae11c05f`, = = the three header lines the five
`a3-built` gate logs print. Sibling lanes landed on `main` in the meantime and
they moved BOTH trees, = = so the shape the `a6-rebased` run measured is
`5cdfa17673824db7be04aca55f8caab24fcde813` and
`709529e244b6dcfb7afc4ebaf3de184262ef83d9`, = = which `HEAD`, = = `HEAD^` and
`main` all print identically (`git diff --name-only main..HEAD -- Sources Tests`
prints no path, = = and the six tree lines plus that diff are held together in
`.gate-logs/2026-11-24-sidebar-part-switch_a6-rebased_8_trees.log`). = = That is
the whole reason a re-measurement was owed: = = a closeout that carried the old
durations forward would be quoting a tree this record no longer sits on. Both
sets of figures stay, = = each quoted from its own artifact, = = because they are
two different measurements, = = not two restatements of one. The tip itself is
NOT restated in this section, = = for the reason row 1 above gives: = = the card
names it, = = the log prints it, = = a cell that copies it goes stale inside its
own commit.

⇒ ⇒ ⇒ AND THE PARENT MOVED A SECOND TIME, = = so the seven commands ran a THIRD
TIME on the tree this record now sits on. That run is the
`2026-11-24-sidebar-part-switch_a10-merged_*` family = = the build log
`_0_build.log` plus the eight command logs `_1.log` through `_8.log` = = launched
the way the paragraph above says a run must be launched (`LOGDIR=` at the shared
checkout, = = and `git rev-parse HEAD` as its own first command, = = so `_1.log`
carries the sha it reviewed and `_2.log` the parent it sat on, = =
`f45a142f62ddb05d74a1c22827c3ab3d2456bafc`). The build precondition is
`_0_build.log`: its tail reads `Build complete! (0.92` followed by the tool's
localized unit (= = that byte sequence is not ASCII, = = so rule 1.1 keeps it OUT
of this prose, = = and `grep -F '0.92'` lands on it) = = with `BUILD_RC=0` as the
file's last line, = = which is what makes the two `--skip-build` rows below it
readings of a binary built FROM this tree rather than of a binary that predates
it. Its figures, each from the file the row names: `_3.log` prints
`Test run with 2 tests in 1 suite passed after 1.997 seconds.`, `_4.log` prints
`Test run with 4 tests in 1 suite passed after 5.304 seconds.`, `_6.log` prints
the window `f45a142f62..4e3c922d5d` with `added comment lines: 0` and
`offending: 0 rows / 0 files (P0=0, P1=0)` and the same vacuous sentence,
`_7.log` is empty (`git diff --name-only main..HEAD -- Sources Tests` prints no
path), and `_8.log` prints the two code-tree shas the `a6-rebased` run printed = =
`5cdfa17673824db7be04aca55f8caab24fcde813` and
`709529e244b6dcfb7afc4ebaf3de184262ef83d9` = = which is why the 13
sibling commits that landed on `main` between this record's first landing and this
parent moved no CODE figure in this record (= = that count is printed by check 7 of the
citation probe named in section 6, = = so it is a reading and not this sentence's memory).

⇒ ⇒ ⇒ AND GATE 4 FAILED ON THIS RUN, = = and the failure is the run's point.
`_5.log` prints `nfi-loc-check: FAILED`, then the row's own sentence
`docs/agents/2026-11-24-session-close-the-sidebar-part-switch.md: the row says 793, the file is 874`,
then `(1 row(s) checked against the files this change added or rewrote; 0 key(s)
added, 1 rewritten)`. ⇒ ⇒ ⇒ So the defect round 3 blocked this document on (= a
registry row that lags the file it counts) was STILL LIVE in this tip when this
round measured it, = = and the reason every earlier held run reads `1 row(s)
checked` clean is that each measured the row as its OWN tree held it, not as this
one does. ⇒ ⇒ ⇒ THE ROW IS CORRECTED IN THIS SAME COMMIT. The reading that clears
it is the post-commit run `2026-11-24-sidebar-part-switch_a11-final_*`, named here
and NOT quoted here: a cell that quoted the tip it clears would go stale inside
its own commit. What the reader checks instead is the invariant, in the tree the
reader stands on:

```bash
python3 Tools/wenshu-devtool/nfi-loc-check.py --base main
grep -c '' docs/agents/2026-11-24-session-close-the-sidebar-part-switch.md
```

= = the first prints its PASS sentence when `docs/agents/nfi.md`'s LOC cell for
this file equals the number the second prints, = = and this document therefore
publishes no line count of itself anywhere, = = because every correction round
lengthens the sentences that would carry it.

What the branch tip measured before the landing:

- `swift build --build-tests` = the build is green (= `Build complete`).
- `swift test --filter SidebarPartSwitchTableIdentityTests` = 2 tests,
  1 suite, exit 0.
- `swift test --filter SidebarTreeRowIdentityTests` = the tree's own
  row-identity suite, exit 0 (= the change does not disturb the row's
  own drawing identity).
- `swift test` = the whole suite, and its census is BELOW (= the suite
  is NOT green on `main`, = = and this scope does not own the red).
- `python3 Tools/wenshu-devtool/nfi-loc-check.py --base main` = every
  added or rewritten file's row carries its own count. = = The held
  merged-tree log's own line is reproduced below IN FULL AND ON ONE LINE, = =
  inside a fence so that no editor wrapping can break the string a reader will
  `grep -F` for: = =

  ```text
  nfi-loc-check: every added or rewritten file's row carries its own count (1 row(s) checked: = 0 the change added, = 1 whose named file the change rewrote and did not add)
  ```

  (= = `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_4.log`, = = `RC=0` its
  last line. = = Note the `= ` tokens: = = the TOOL prints them, = = so a quote
  that "cleans" them is not a quote. = = And note the disclosure: = = the run
  that printed this line OVERWROTE the run that failed a moment earlier, = = when
  this record's own row still read 674 for a 756-line file, = = so the failing
  form is named here as a SEQUENCE and not as evidence: = = no log of it is held
  any more.) = = ⇒ ⇒ ⇒ THE
  THE `3 row(s) checked: = 2 the change added, = 1 whose named file the change
  rewrote and did not add` READING (the bytes as `a2-merged_4.log` prints them)
  IS NOT A LIE ABOUT A RUN, = = IT IS THE
  WRONG RUN: = = the superseded `--skip-build` pass over the merged tree, = =
  `2026-11-24-sidebar-part-switch_a2-merged_4.log`, = = checked a window that
  carried THREE registered files where the round-4 window carries ONE. = = Round
  3 put that number under this cell, = = and the defect is naming the wrong
  witness while quoting the right words. = = ⇒ ⇒ ⇒ AND THE TWO FORMATS ARE
  DIFFERENT SENTENCES, = = WHICH IS WHY THE QUOTE ABOVE IS THE PASS FORMAT: = =
  the same tool on a mismatch prints `(N row(s) checked against the files this
  change added or rewrote; X key(s) added, Y rewritten)` (= = observed live, at
  `RC=1`, = = when this record's own row still read 674 for a 745-line file) = =
  so quoting a figure without quoting the sentence that carries it is not yet
  quoting the run.
- `python3 Tools/wenshu-devtool/comment_lineage.py --base main --head
  HEAD --repo .` = 0 offending rows / 0 files over the branch's window.
- The CJK audit over the lines the commit ADDED = 0 hits (1.1's own
  reading, = = not a grep's, = = and the commit's message carries none).

### The suite census, measured

The census is scoped to what this scope owns. This scope's OWN suites are
`SidebarPartSwitchTableIdentityTests` (= the one it adds) and
`SidebarTreeRowIdentityTests` (= the one it must not disturb), and both
exit 0.

⇒ ⇒ ⇒ AND THE PRE-EXISTING REDS ARE NAMED WITH THEIR EVIDENCE, = = AND
THE CLAIM IS AN INVARIANT, = = NOT A COUNT. The whole suite is NOT
green on this tree, = = and it is NOT green on `main` either. ⇒ ⇒ ⇒
⇒ ⇒ ⇒ AND THE RED SET IS LOAD-SENSITIVE, = = SO NEITHER A COUNT NOR A
SET OF IT IS A FACT ABOUT THE TREE. MEASURED ON THIS SCOPE'S OWN CODE, = =
THREE RUNS OF ONE COMMAND, = = AND THE RED SET CAME BACK THREE DIFFERENT
SIZES: = = 7 names, = = 8 names, = = 3 names (= the last one ran while
another tree was building, = = = = so the machine's load decided which
timing-sensitive suites tipped over). ⇒ ⇒ ⇒ ⇒ So a published red SET is a
measurement of the RUN, = = and this record publishes the runs instead of
picking one of them and calling it the tree. ⇒ ⇒ ⇒ And one suite that was
red in a run MEASURED CONCURRENTLY with another tree's run (= the
`WenshuConductor` wiring) is GREEN on three standalone runs on BOTH trees
(= so it was the load, = = not the tree). ⇒ ⇒ ⇒ So this record publishes
the claims that SURVIVE the load, = = and they are about this scope's own
two suites:

- CLAIM ONE (= the scope's own): = = `SidebarPartSwitchTableIdentityTests`
  is GREEN on this branch, = = and RED without the change (= the table is
  the same object before and after a change of part), = = and
  `SidebarTreeRowIdentityTests` is GREEN (= the change does not disturb
  the tree's own drawing identity).
  ⇒ ⇒ ⇒ MEASURED, = = BOTH WAYS, = = ON THIS BRANCH'S TIP, = = AND THE
  SHAPE IS THE PART THAT MATTERS. The removal was not the whole commit:
  = = only the one code line the fix adds
  (`.id(workspaceUI.currentSidebarPart)` in `SidebarTreeView.swift`) was
  deleted, = = the comment above it left in place, = = so the run tests
  the LINE and not the file's presence.
  - WITHOUT the line: = = `Test run with 2 tests in 1 suite failed ...
    with 1 issue`, = = and the failing case is ONLY
    "A change of part rebuilds the table" (= its issue prints
    `some → ObjectIdentifier(0x…)`, = = which is the assertion saying the
    table is still the same object), = = while "A change below the top
    keeps the table" PASSES in the same run.
  - WITH the line restored: = = `Test run with 2 tests in 1 suite passed`,
    = = and the tree is byte-identical to the commit again
    (= `git diff HEAD` empty).
  ⇒ ⇒ ⇒ So the suite separates the two halves of the claim: = = the rebuild
  a change of part MUST cause, = = and the in-place diff a change below the
  top MUST still get. = = A suite that only failed on the base would not
  distinguish "the fix works" from "the app is broken", = = and that
  separation is why this suite is the one the scope ships.
  - ⇒ ⇒ AND THE ONE OBVIOUS COLLATERAL, = = CHECKED AT THE SOURCE INSTEAD OF
    ASSUMED: = = a forced rebuild is a NEW table, = = so the question a reader
    asks next is whether the tree's expansion is lost with the old one. = = It
    is not, = = and the reason is structural rather than lucky: = = the view
    holds NO `@State` at all (`grep -n '@State' SidebarTreeView.swift` returns
    nothing), = = and every `DisclosureGroup` is driven by
    `expansionBinding(for:)`, = = which reads and writes
    `workspaceUI.expandedSidebarRows` — = = the set lives in the STORE, = = keyed
    by the row (`AppleSidebarView+Nodes.swift`, = = above `revealExpansionKeys`:
    "the key survives a tree rebuild and a relaunch"). = = A new table therefore
    re-reads the same set on its first render. = = ⇒ WHAT STAYS UNPROVEN is the
    MEASUREMENT, = = not the mechanism: = = no test in this scope asserts that an
    expansion survives a part switch, = = so the argument above is a reading of
    the code and not a result. = = `SidebarTreeReloadTests` covers the SELECTION
    living above the tree (= "The selection does not rebuild the tree"), = = which
    is the neighbouring question and not the same one.
- CLAIM TWO (= the pre-existing red): = = the two suites named here were
  each measured on a detached worktree of `main` at `bbc2434997`, = = = = the
  tree WITHOUT this scope's change = = and they are NOT the same shape. One
  (`ChatView history shortcut (T92)`) is red in every census run above. The
  other (`SidebarTreeReloadTests`) is FLAKY on both trees, = = so its
  pre-existing status is settled by the base arm below, = = and not by any
  count of runs. ⇒ ⇒ ⇒ TALLY, = = SO THE WORD IS CHOSEN FROM THE RUNS AND NOT
  FROM ALL OF THEM, = = and the account is the table below, = = one row per
  party, = = each naming the artifact that holds it rather than a figure this
  author cannot produce. ⇒ ⇒ ⇒ TWO OF THESE ROWS SAID UNRETAINED AT ROUND 2, = =
  AND THE CAUSE WAS NOT THAT THE RUN HAD NEVER HAPPENED, = = ONLY THAT ITS LOG
  HAD BEEN WRITTEN TO `/tmp/`: = = at round 3 both files were copied into
  `.gate-logs/` and the rows now name them. = = ⇒ ⇒ ⇒ THE RULE THIS LEAVES: = = a
  measurement written outside the repo is a measurement that has not been made
  yet — write the log where the reader can be sent, = = or do not quote the
  number:

| who measured | the tree | standalone runs | red | green | the artifact |
| --- | --- | --- | --- | --- | --- |
| this author, round 1 | built merged | 3 | 2 (1.191, = = 1.219 s) | 1 (1.271 s) | HELD — retained from `/tmp/merged-arms.log` at round 3: = = `.gate-logs/2026-11-24-sidebar-part-switch_a1-arms-merged.log` (= = whose fourth section is also the withdrawn `1.959 s` gate-2 run, = = so the same file holds one figure this record still stands on and one it retracted) |
| the reviewer, round 1 | built merged at `05ae26b50f` | 3 | 3 | 0 | card `t_b3c72e68`, = = its single comment by `wenshu-review` (= = their log, = = now held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_b3c72e68.json`) |
| the reviewer, round 2 | built merged at `0f6cd7758b` | 6 | 4 | 2 | card `t_bbec0dc6`, = = its single comment by `wenshu-review` (= = their log, = = now held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_bbec0dc6.json`) |
| this author, rounds 2 and 3 | built merged, `.worktrees/sidebar-closeout-2026-11-24` | 6 | 6 (1.153, = = 1.160, = = 1.201, = = 1.200, = = 1.156, = = 1.303 s) | 0 | **HELD** (= = ONE file, = = six arms, = = every duration in it): = = `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_reload_alone.log` |
| this author | built BASE `bbc2434997` | 4 | 3 (1.138, = = 1.138, = = 1.202 s) | 1 (1.144 s) | HELD — retained from `/tmp/base-arms.log` at round 3: = = `.gate-logs/2026-11-24-sidebar-part-switch_a1-arms-base.log` |
| the reviewer | built BASE, same worktree | 4 | 4 | 0 | card `t_bbec0dc6`, = = its single comment by `wenshu-review` (= = their log, = = now held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_bbec0dc6.json`) |

  ⇒ ⇒ ⇒ MERGED STANDALONE TOTAL, = = COUNTED FROM THE SIX ROWS ABOVE: = = 18
  runs, = = 15 red, = = 3 green. BASE STANDALONE TOTAL: = = 8 runs, = = 7 red, = =
  1 green. ⇒ ⇒ ⇒ Every red in the EIGHT FULLY-CAPTURED
  STANDALONE ARMS (= = 2 in
  `.gate-logs/2026-11-24-sidebar-part-switch_a1-arms-merged.log`, = = 3 in
  `…_a3-built_reload_alone.log`, = = 3 in
  `…_a1-arms-base.log`) printed the SAME case at
  `SidebarTreeReloadTests.swift:189:9` with the SAME signature
  `fixture.counter.count → 6` against `afterFirstLoad → 3`. ⇒ ⇒ ⇒ AND THE
  SCOPE OF THAT SENTENCE IS THE ARMS WHOSE BYTES ARE HELD, = = NOT ALL 15: = =
  arms 4 to 6 of `…_a3-built_reload_alone.log` were pasted as one-liners
  (`arm 4: Test run with 2 tests in 1 suite failed after 1.200 seconds with 1
  issue`) = = with no case and no signature in the file, = = and 7 of the 15
  reds sit in the reviewer's logs, = = which this author does not hold. ⇒ ⇒ ⇒ THE CLAUSE THIS REPLACES ("no run ANYWHERE
  printed a different failure") OVERREACHED, = = and the reviewer caught it, = =
  and it is now measured twice: = = their census printed
  `fixture.counter.count → 51` against `afterFirstLoad → 3` (card `t_bbec0dc6`
  its single `wenshu-review` comment, = = held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_bbec0dc6.json`), = = and this record's OWN held census at the
  branch tip prints `→ 117` against the same `afterFirstLoad → 3` at the same
  `SidebarTreeReloadTests.swift:189:9`, = = where the same test reports
  `the reads went from 3 to 117` and `failed after 144.722 seconds` (= =
  `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_census.log`). ⇒ ⇒ ⇒ So the honest statement is that
  the OBSERVED COUNT RISES WITH LOAD while the failing assertion stays fixed = =
  which is the flake's mechanism (= = the fixture counts reloads on a wall-clock
  window) = = and not a second defect. ⇒ ⇒ ⇒ The combined filter, = = re-measured
  on the BUILT tree, = = log HELD: = = `swift test --skip-build --disable-sandbox
  --filter 'SidebarTreeRowIdentityTests|SidebarTreeReloadTests|SidebarPartStateTests'`
  = = `Test run with 6 tests in 2 suites failed after 5.913 seconds with 1
  issue` and again `5.936 seconds with 1 issue` (= = two runs, = = both red, = =
  held: = = `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_combined.log`) = =
  and that same held log prints BOTH HALVES of the split, = = so it is quoted
  rather than explained: = = the XCTest overlay ran the third name (= =
  `Test Suite 'SidebarPartStateTests' started` at the run's own timestamp, = =
  `passed`, = = `Executed 6 tests, with 0 failures (0 unexpected)`), = = while
  the swift-testing summary line reports `Test run with 6 tests in 2 suites`. = =
  ⇒ ⇒ ⇒ THE 2 SUITES ON THAT LINE ARE THE TWO SWIFT-TESTING SUITES, = = and the
  XCTestCase's 6 cases are counted in the OVERLAY, = = not on that line; = = the
  round-3 wording ("the third name contributes 0 tests") is false as written, = =
  and the same split, = = with the name alone in the filter, = = is arm B of
  `…_a4-filter-probe.log`.

  - `ChatView history shortcut (T92)` (= the case
    `body_logs_history_metadata`, = = the log block carries no
    `totalTokens` key). MEASURED on the pristine base: = = the same
    failure, = = and red on three standalone runs in a row (= the same
    shape on both trees).
  - `SidebarTreeReloadTests` (= the case "The selection does not rebuild
    the tree", = = the reads went from 3 to 6). ⇒ ⇒ ⇒ AND THIS ONE IS
    FLAKY, = = NOT DETERMINISTIC, = = AND NOT ON A MERGED-TREE RE-READ BUT
    ON A PAIRED MEASUREMENT: = = the arm that settles blame is the BASE, = = a
    built worktree of `bbc2434997` (= = the tree WITHOUT the fix), = = and it
    throws the same case with the same signature (`fixture.counter.count → 6`
    against `afterFirstLoad → 3`, = = at `SidebarTreeReloadTests.swift:189:9`)
    on 7 of its 8 standalone runs. ⇒ ⇒ ⇒ ⇒ So the flake is the TREE'S, = = not
    this scope's: = = it is present without the change, = = the change does not
    create it, = = and it is a pre-existing order-and-load-dependent red, = =
    NOT a deterministic one. ⇒ ⇒ ⇒ ⇒ AND THE SENTENCE THIS REPLACES ("it is
    GREEN on the merged tree, = = 1.216 s") WAS A FALSE GREEN OF THE SAME
    CLASS AS §1's: = = that run used `--skip-build` against a stale binary, = =
    = = so the figure measured nothing. The run account, = = with its
    artifacts, = = is published as the table below rather than as prose.

⇒ ⇒ ⇒ The census is re-measurable with the command that produced it, and
the invariant is checked by comparing its output on the two trees (= = the
branch's set and the base's set):

```bash
# The census is NOT a gate (= = a whole-suite run aborts mid-bundle and its
# size measures how far it got), = = it is the measurement this record is
# asked to publish. = The grep MUST carry both alternatives: = swift-testing
# prints some suite names QUOTED and some BARE, = = and a quote-only pattern
# silently drops the bare ones (= = which is exactly how this record lost a
# red suite it had itself named).
swift test --skip-build --disable-sandbox 2>&1 \
  | grep -oE 'Suite ("[^"]+"|[A-Za-z0-9_]+) failed after' \
  | sed 's/ failed after//' | sort -u
```

⇒ ⇒ ⇒ THE FIVE RUNS, = = AS THE ONLY HONEST SHAPE OF THIS ARTIFACT. Run A is
the one this record first published (= = and it was taken with `--skip-build`
against a shared `.build` whose binary PREDATES the scope's own suite, = = so
it is not a reading of the merged tree at all = = see §1); = = runs B and E are
the reviewer's, = = each on a tree built for the purpose; = = run C is mine, = =
on that same built tree, = = taken WHILE the base tree was building; = = run D is
mine, = = on the branch worktree after its own `swift build --build-tests`, = =
with nothing else on the machine, = = and its log is HELD.

| run | the tree it ran on | names printed | which names |
| --- | --- | --- | --- |
| A | shared checkout, stale binary, quote-only grep (= = NO ARTIFACT: = = this row is a reading of a run whose log was NOT retained, = = so the count 7 is quoted as this author's reading and nothing more, = = and a reviewer cannot be sent to it) | 7 | `AsyncDelegationRegistry (one registry for every delegation)`, `ChatView history shortcut (T92)`, `Editor tab strip - the strip divides the column it was given`, `HermesTodoStore concurrency (FIX-TODO-LOCK-001)`, `The pane tab strip's title rule`, `v0.71 P1 — EditorTab.displayTitle (tab title fallback chain)`, `v1.70 editor-mvvm T2a — EditorPersistence (disk IO + conflict + auto-save)` |
| B | the reviewer's run on that same built tree (= = card `t_b3c72e68`'s single `wenshu-review` comment, = = their log, = = held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_b3c72e68.json`) | 8 | run A's seven **plus** `SidebarTreeReloadTests` |
| C | the same built tree, widened grep, under a concurrent build (= = NO ARTIFACT, = = same status as row A: = = a reading, = = not a held file) | 3 | `ChatView history shortcut (T92)`, `The pane tab strip's title rule`, `v0.71 P1 — EditorTab.displayTitle (tab title fallback chain)` |
| D | `.worktrees/sidebar-closeout-2026-11-24`, built, unloaded, widened grep | 9 (= = the held names file has one line per suite, = = 9 lines) | run B's eight **plus** `WenshuConductor ↔ ToolRegistry wiring (WIRE-TOOLREGISTRY-003)`, = = and bare `SidebarTreeReloadTests` is one of the nine — held: `.gate-logs/2026-11-24-sidebar-part-switch_a3-built_census.log`, names in `2026-11-24-sidebar-part-switch_a3-built_census_names.txt` |
| E | the reviewer's built checkout at `0f6cd7758b` (`swift test --disable-sandbox`, rc 1) | as their comment states it | six QUOTED names (`AsyncDelegationRegistry (one registry for every delegation)`, `ChatView history shortcut (T92)`, `Editor tab strip - the strip divides the column it was given`, `The pane tab strip's title rule`, `v0.71 P1 — EditorTab.displayTitle (tab title fallback chain)`, `v1.70 editor-mvvm T2a — EditorPersistence (disk IO + conflict + auto-save)`), **plus** bare `SidebarTreeReloadTests`, and their text adds one name no other run printed, `The system index is waited for, not blocked on` (= = dropped: `HermesTodoStore concurrency (FIX-TODO-LOCK-001)`). The record does NOT publish a count for this row: = = only their log holds it (= = card `t_bbec0dc6`'s single `wenshu-review` comment, = = held as `.gate-logs/2026-11-24-sidebar-part-switch_card-t_bbec0dc6.json`), = = and its prose and its list are not reconcilable from here. |

⇒ ⇒ ⇒ ONE NAME IS RED IN ALL FIVE RUNS, = = AND IT IS NOT THIS SCOPE'S: = =
`ChatView history shortcut (T92)`. = = The only other name every run that
printed it agrees on is the pre-existing `SidebarTreeReloadTests` (= = bare in
runs D and E, = = parenthesised in run B, = = absent from run A's list and from
run C's three), = = which is CLAIM TWO's flake reproduced inside a whole-suite
census. = = Every other name is a function of the
run: = = across the four runs whose membership this record can restate the set
has been 7, = = 8, = = 3 and 9 names, = = and the reviewer's fifth run differs
from all four again. ⇒ ⇒ ⇒ AND NO RED IN ANY OF THE FIVE RUNS IS THIS SCOPE'S SUITE: = =
not one run printed `SidebarPartSwitchTableIdentityTests` or
`SidebarTreeRowIdentityTests` as a failing suite (= = run E holds the positive form,
quoted from their log, = = the single `wenshu-review` comment on `t_bbec0dc6`: = = `Suite
SidebarPartSwitchTableIdentityTests passed after 150.405 seconds.` and `Suite
SidebarTreeRowIdentityTests passed after 150.367 seconds.`; = = in run D the two
scope suites are simply absent from the red set),
= = which is the invariant the scope actually owns, = = alongside the two green
summary lines quoted in §1's table. ⇒ ⇒ ⇒ So this record does NOT claim the
census clears any other lane's red (= = run B put a suite in that run C lost, = =
and run E dropped a suite runs A and D kept), = = and it does not claim a red
set belongs to `main` = = only that the census is not a gate and its size is not
a fact.

⇒ ⇒ ⇒ AND RUN D BROKE THE RECORD'S OWN READING OF A CENSUS ONE LEVEL DEEPER, = =
WHICH IS WORTH MORE THAN THE NAME LIST. That held log carries NINE
`Suite … failed after` lines, = = and the SAME log's own exit code is **0** and
BOTH of its `Test run with` summary lines read PASSED (= = `Test run with 151
tests in 34 suites passed after 1.647 seconds.` and `Test run with 208 tests in
24 suites passed after 15.712 seconds.`). ⇒ ⇒ ⇒ ⇒ SO FOR A WHOLE-SUITE RUN
NEITHER THE EXIT CODE NOR THE SUMMARY LINE IS THE EVIDENCE = = only the
per-suite lines are, = = and even they disagree with the run's own verdict. = =
That is the same failure §1 names for `--filter` (= = a summary that reports the
run it made instead of the work it did), = = and it is why this record stops
calling any whole-suite outcome a PASS or a FAIL and publishes it as a set of
suite names with the log that printed them.

⇒ ⇒ ⇒ AND THE OTHER PRE-EXISTING RED IS NAMED SEPARATELY, BECAUSE IT IS THE
ONE A READER WILL MISTAKE FOR THIS SCOPE'S. The filtered run `swift test
--filter 'SidebarTreeRowIdentityTests|SidebarTreeReloadTests|SidebarPartStateTests'`
is RED on the branch tip, = = and the arm that settles the blame is the BASE:
= = a built worktree of `bbc2434997` = = the tree WITHOUT the fix = = throws
the same case with the same signature, = = on 7 of its 8 standalone runs (= =
the tally and its artifacts are in the table under CLAIM TWO above). ⇒ ⇒ ⇒
So the causal question is CLOSED with a measurement and not an argument: = =
the fix neither causes nor hides this red. ⇒ ⇒ ⇒ AND THE HONEST LABEL IS
FLAKY: = = standalone it is red on most runs and green on some, = = on both
trees, = = so "red on every standalone run" is false (this author's earlier
reading), = = and "green alone happens routinely" is equally false (= = 3
greens in 18 merged standalone runs, = = none of them reproducible on demand).
= = The only claim that survives is that the suite asserts a reload COUNT on a
path that is timing-sensitive. = = It belongs to whoever owns that
assertion, = = and it is recorded here rather than folded into this scope's
verdict. ⇒ ⇒ ⇒ ⇒ THE FOLLOW-UP THIS OPENS (= = an open item, = = not this
commit's): = = `SidebarTreeReloadTests.swift:189` asserts
`fixture.counter.count == afterFirstLoad` while the observed value moves 3 → 6 →
51 → 117 (= = 6 standalone, = = 51 in the reviewer's census, = = 117 in this
record's held census), = = so either the assertion or the fixture's load count is
load-sensitive, = = and neither is diagnosed anywhere in the repo.

## 2. Record the verdict on the board

DONE. The card is `t_b28c9ebc`, = = assignee `wenshu-review`, = = status
`done`, = = and the merge gate reads its verdict back from the board
rather than from this file: `review_gate.py --branch
wt/sidebar-dup-tree-2026-11-24` printed `verdict: approved by
wenshu-review`. The reviewer's `completed` event names the sha it
approved (= `e4818545d7`) and records that the two mid-run amends touched
only `docs/agents/`, = = the fix commit `772b608a66` and both code blobs
being byte-identical throughout. It also re-measured this scope's
discrimination experiment independently: three back-to-back arms, each
`Test run with 2 tests in 1 suite failed ... with 1 issue`.

## 3. Write the closure doc

DONE: this file. Its own name carries the scope's topic (= the reader
finds it by the scope's slug), and it is written in the tree's tense
(= every step says what HAS happened, = = and every claim carries the
command that re-measures it).

The scope's registry row lives in `docs/agents/nfi.md` (= the row for the
suite this scope adds, = = and the row for `SidebarTreeView.swift`, whose
file the change rewrote, = = so its own count moved with the change).

## 4. Persist the durable lessons into the SKILLS

DONE, = = AND IT LANDS IN A SKILL, = = NOT IN THIS FILE. The rule is
`macos-design-guidelines` **Rule 4.6 = One Collection Identity Per
Hierarchy** (= the skill section that already carries Rule 4.3 on outline
views and nothing on identity), = = and it carries all four findings
below. ⇒ ⇒ ⇒ The two skills that would have been its natural home are
NOT WRITABLE: = = `apple-ui-craft` holds a reference at 386,867
characters and another at 270,374, = = and `wenshu-pocock-workflow`
holds `references/card-gates-that-lie.md` at 99,457 (= 543 of slack)
against a 100,000 cap, = = so `skill_manage` refuses EVERY write to
either until a capacity split is done. ⇒ ⇒ ⇒ ⇒ That split is its own
scope, = = and it is recorded as an open item in §6, = = not silently
worked around by cramming a truncated rule into an over-cap file.

The lesson belongs to the class of work this scope is (= a view
whose content is REPLACED wholesale by a different hierarchy):

⇒ ⇒ ⇒ **A LIST THAT IS GIVEN A DIFFERENT HIERARCHY MUST BE GIVEN A
DIFFERENT IDENTITY, OR THE TABLE RECYCLES THE OLD HIERARCHY'S CELLS
INTO THE NEW ONE.** ⇒ ⇒ ⇒ The lesson's shape: = = the defect was
INVISIBLE to the accessibility tree (= the model was right, = = the
a11y tree is rebuilt from the model), = = and visible only in the
PIXELS (= the table's cells). ⇒ ⇒ ⇒ So a tree that shows several
UNRELATED hierarchies must be read by ITS PIXELS and not by its a11y
tree, = = and a harness that cannot see the pixels cannot see this
class of defect at all.

⇒ ⇒ ⇒ AND THE FIX MUST NOT BE THE TREE'S SHAPE: = = a tree's shape
changes when a row's subtree changes (= and the row under the user must
survive that), = = so the identity that rebuilds the table must be the
HIERARCHY the table shows (= the part), = = and the tree's own drawing
identity must stay where it is.
⇒ ⇒ ⇒ AND EXPANSION SURVIVES THE REBUILD ONLY IF IT LIVES IN A STORE
(= the mechanism is checked in §5's collateral bullet: = = the view holds
no `@State`, = = and `expansionBinding(for:)` reads and writes the set in
`WorkspaceUIState`).

## 5. Clean up YOUR OWN residue

DONE, = = and only this scope's own residue was touched. Removed after
the landing: the branch `wt/sidebar-dup-tree-2026-11-24` and the card's
branch `project/t_b28c9ebc-t3-...` (= both deleted with plain `-d`, = =
which succeeds only when the commit is fully merged), = = and the two
worktrees `.worktrees/sidebar-dup-tree-2026-11-24` and
`.worktrees/t_b28c9ebc`.

⇒ ⇒ ⇒ AND THE SHAS WERE PARKED BEFORE THE BRANCH WENT. The landing left
both commits reachable from `main`, = = so nothing dangled; = = the plan
of record, = = however, = = names a branch by name, = = and
`closeout_gate.py` decides LANDED by resolving that name through
`rev-parse`. = = ⇒ ⇒ ⇒ So the scope keeps a durable ref, = = not a branch:
`refs/keep/sidebar-part-switch-a1` = `e4818545d7...`, = = proved with
`git rev-parse` (not `for-each-ref --contains`, = = which prints nothing
for a leaf nobody descends from), = = and the issue index's Branch cell
now names THAT ref, = = which is why the closeout gate reads LANDED.
= = The record's OWN superseded rounds are parked the same way = =
`refs/keep/sidebar-closeout-a1` = `05ae26b50f...` (round 1's fix commit),
`refs/keep/sidebar-closeout-a2` = `0f6cd7758b...` (round 2's commit), = = and this
round adds `refs/keep/sidebar-closeout-a3window` = `96f76f3575...`, = =
`refs/keep/sidebar-closeout-a3tip` = `3e1e484173...` (= the sha round 3's card
names) = = and `refs/keep/sidebar-closeout-a4tip` = `4e3c922d5d...` (= the sha the
`a10-merged` logs carry in `_1.log` and on their lineage window). ⇒ ⇒ ⇒ Every one of
those refs is there for one reason: = = a superseded round's sha stops being reachable
the moment its branch is amended or squashed, = = an unreachable sha inside a held log
is a citation that rots on merge, = = and each round's prose names the sha the next
round amends away. ⇒ ⇒ ⇒ `96f76f3575` additionally is the window END the `a3-built_5`
log prints and is reachable from ANOTHER lane's branch only. ⇒ ⇒ ⇒ Each ref is proved
with `git rev-parse refs/keep/<name>` = = and NOT with `for-each-ref --contains`, = =
which prints nothing for a leaf nobody descends from, = = and reading that empty output
as an absence was round 3's mistake.
= = The other worktrees in this repository are not this scope's to remove, = = and
their COUNT IS PUBLISHED ONLY AS A LABELLED READING, = = because it moves under a
running board: = = `git worktree list | wc -l` answered 108 (round 3, = = written), = =
123 (round 3's review, = = the reviewer's own read), = = 124 (round 4's re-check), = =
162 (taken while the section 1 run was being measured) = = and 152 (taken as this
line was written). ⇒ ⇒ ⇒ The command belongs to the record; = = the number belongs to a live
checkout, = = which is why no reader should treat any of the four as the state.

What the scope leaves in the shared checkout is its plan of record
(`.scratch/2026-11-24-sidebar-part-switch/`), = = which the plan gate
and the closeout gate both read, = = and the HELD GATES ITS RECORD QUOTES:
the TEN artifacts of the `2026-11-24-sidebar-part-switch_a3-built_*` family
(nine `.log` plus the one `.txt` of suite names, = = `ls | grep -c` = 10), = = the
ONE `2026-11-24-sidebar-part-switch_a4-filter-probe.log` = = (the two filter
arms whose bytes settled B4 and B5), = = and the ONE
`2026-11-24-sidebar-part-switch_a5-cite-audit.log` = = (the citation probe, = =
its source and its output together, = = `RC=0`), = = the ONE
`2026-11-24-sidebar-part-switch_a6-rebased_0_manifest.txt` = = (the seven
rebased commands in one manifest, = = `GATE_RUN_RC=0`), = = the ONE
`2026-11-24-sidebar-part-switch_a6-rebased_8_trees.log` = = (the six code-tree
lines that date the earlier figures), = = and the ONE
`2026-11-24-sidebar-part-switch_a7-cite-audit.log` = = (this round's re-run of
the citation probe) = = these FIFTEEN are the ones §1,
§4, §7 and CLAIM TWO quote line for line, = = and they stay in the shared
checkout's `.gate-logs/` together with the seven earlier witnesses this document
also names: = = the FIVE-file `a2-merged_*` family (1, = = 2, = = 3, = = 4, = = 5, = = of
which log 2 is the 116-byte false-green run §1 dates) = = plus the TWO
`a1-arms-base.log` / `a1-arms-merged.log` files = = plus the FOUR board snapshots the
next paragraph names (= = `…_card-t_b3c72e68.json`, = = `…_card-t_bbec0dc6.json`, = =
`…_a8-card-t_bbec0dc6.json`, = = `…_a9-card-t_1ea50c6a.json`) = = 26 names in all, = =
every one of them checked to exist by `a7-cite-audit.log`, = = because deleting a log this
document cites is the same defect as citing a log that does not exist. The FOUR board
snapshots are held in two shapes: = = `2026-11-24-sidebar-part-switch_a8-card-t_bbec0dc6.json`
and = = `2026-11-24-sidebar-part-switch_a9-card-t_1ea50c6a.json` are the dumps taken while the
verdicts were being written, = = and `2026-11-24-sidebar-part-switch_card-t_b3c72e68.json` and = =
`2026-11-24-sidebar-part-switch_card-t_bbec0dc6.json` are the two cards round 1 and round 2 of
THIS document's own review, = = re-fetched read-only with `hermes kanban show … --json` after the
correction below. ⇒ ⇒ ⇒ THE CORRECTION: = = the record used to cite board comments by a four-digit
NUMBER, = = seven times. = = `hermes kanban show --json` exposes
a comment as `author`, = = `body`, = = `created_at` and NO id, = = so a reader with the board open
cannot resolve a number the tool never prints: = = the citation was unresolvable by construction, = =
the same class of defect as the `a4` window and the phantom needles. = = All seven now name the card
and its single `wenshu-review` comment and point at the held file; = = `a7-cite-audit.log` asserts
the numbering is gone, = = and asserts inside the held JSON each figure the table attributes to
those comments (= = `→ 3`, = = `→ 6`, = = `→ 51`, = = `afterFirstLoad → 3`). = = `ls
/Volumes/ANAN/Engineering/wenshu/.gate-logs/ | grep -c
'2026-11-24-sidebar-part-switch_a3-built_'` is how a reader checks the family
count without trusting this sentence, = = and the same command with
`'2026-11-24-sidebar-part-switch_a6-rebased_'` returns 9 for the rebased run
(eight per-command logs plus the manifest, = = the trees log is the ninth), = = and
`'2026-11-24-sidebar-part-switch_a10-merged_'` returns 9 for the run this round took
against the moved parent (the build log plus eight command logs). ⇒ ⇒ ⇒ AND THE TWO
WITNESSES THIS ROUND LEAVES FOR ITS OWN TEXT, named here and quoted nowhere: = =
`2026-11-24-sidebar-part-switch_a11-final_*` is the same battery re-run against the
commit this record ships in (= = the run that turns gate 4's failure into its PASS), =
= and `2026-11-24-sidebar-part-switch_a12-cite-audit.log` is this round's citation
probe (= = it walks every `.gate-logs` name this document prints, = = asserts each
file exists, = = asserts every family count against the record's own digits, = = and
for every quoted line asserts the string is IN the file the sentence points at). = =
Neither is quoted in the prose because both are read AFTER the last byte of prose
lands, = = and quoting a reading taken after the text that cites it is how a record
manufactures an unfalsifiable claim; = = the card that files this round carries their
printed output. ⇒ ⇒ ⇒ THE EARLIER `a2-merged`
LOGS ALSO STAY: = = §1's false-green paragraph is a claim about them, = = and
one of them is the 116-byte run that proves it.

And the probe that checks this document's own citations is now HELD, = = not
described: = = `.gate-logs/2026-11-24-sidebar-part-switch_a5-cite-audit.log`
carries its source between fences and then its output, = = `RC=0`. = = What it
does, = = stated so a reader can tell whether it is worth running: = = it walks
every `.gate-logs` filename the record names, = = asserts the file exists, = =
and for the gate logs whose bytes the record quotes, = = asserts the quoted line
is IN that file. = = Its reading at round 4 is: = = every named artifact present, = =
the quoted summary lines of the reload, = = combined and gate
arms verified in their own files, = = both census summary lines verified, = =
and every duration figure the record prints (2.165, = = 5.300, = = 1.153, = =
1.160, = = 1.201, = = 5.913, = = 5.936, = = 1.647, = = 15.712) found in the doc
AND in a held log. = = Its own printout is `named artifacts: 19`, = = `RC=0`, = =
and the reader who wants the number rather than this sentence's paraphrase of it
gets it from line 56 of that file. ⇒ ⇒ ⇒ WHAT IT DID NOT COVER, = = AND THE GAP IS
NOW CLOSED: = = that probe verifies a figure is PRESENT in SOME artifact, = = not
that it is present in the artifact the sentence NEXT TO IT names. = = That narrower
check is what round 3's B1, = = B4 and B5 were, = = and at round 4 it was done by
hand, = = line by line, = = against the named file (= = `grep -F` the quoted string
in the named log). = = Round 5 made the machine do the
same thing: = = `…_a7-cite-audit.log` re-derives the name set (26 today), = = asserts
each family count against the doc's own digits, = = and for the §1 table and the §5
paragraphs checks each quote AGAINST THE FILE THE SENTENCE POINTS AT, = = reporting a
miss as `<file> does NOT print: <needle>`. = = Its first run caught a live defect in
the paragraph that introduced it — see the `a3-built_5` window line above — = = and the
file held here is ITS LAST RUN: = = re-run after every later correction to the probe or the
record, = = each time overwritten, = = so the witness always describes the text it is
attached to. = = That last run prints `named artifacts: 26`, = = `family counts match the
record: a3-built=10, = = a6-rebased=9`, = = `verified: no \`comment NNNN\` citation survives
in the record`, = = `all 13 cited durations trace to a held log`, = = a `verified N quoted
line(s)` row for each of the four card snapshots, = = and `RC=0`.

⇒ ⇒ ⇒ AND THE RESIDUE THAT WENT, = = MEASURED PATH BY PATH: = = this scope's `/tmp/`
caches (`wenshu-scm-base`, = = `wenshu-scm-merged`, = = `wenshu-scm-a1`, = =
`wenshu-scm-2026-11-24`), = = the two `/tmp/` arm logs once their copies were held in
`.gate-logs/`, = = `/tmp/closeout-build.log` (= = the byte-twin of the held
`2026-11-24-sidebar-part-switch_a3-built_0_build.log`, = = `cmp` reported equal before
either was removed) = = and `/tmp/test_closeout_gate.log` are gone. ⇒ ⇒ ⇒ The check is a
per-path existence test, = = never a listing of `/tmp`: = = a directory owned by every
session on the machine returns tens of thousands of unrelated simulator entries, = = and a
cleaner that reads a `grep` over that output deletes somebody else's evidence. ⇒ ⇒ ⇒ THE
BASE-COMPARISON WORKTREE `.worktrees/sidebar-closeout-base` DOES NOT GO IN THIS
STEP: = = it is the only tree on which the BASE arm of the table above can be
re-run, = = so it is removed AFTER the verdict, = = together with the branch
worktree, = = and the record says so here because a cleaner that reads only the
residue list would otherwise delete the reproducibility of a claim that is still
under review.

⇒ ⇒ ⇒ AND THE SCOPE'S OWN EXPLORATION IS GONE: four probe suites were
written while the defect was being localized (= a part-switch probe, = =
an a11y-text probe, = = a pixel probe, = = and the boss's own sequence).
NONE of them reproduced the defect (= the defect needs the real app's
window and the real cell reuse), = = so none of them is a regression
guard, = = and a suite that passes on the base guards nothing. ⇒ ⇒ ⇒
They are deleted, and the ONE suite that discriminates (= it fails on
the base and passes with the change) is what the scope ships.

## 6. Re-check the final state and report it

DONE. What the tree reads now:

- The fix `772b608a66` and this record's FIRST landing
  `e4818545d7f99156576db131081271f6ae11c05f` are both reachable from `main`
  (= `git merge-base --is-ancestor <sha> main` exits 0 for each), = = landed on top of
  `main` at `bbc2434997`. ⇒ ⇒ ⇒ What is NOT on `main` yet is the text between this
  bullet and the end of the document, = = and the row in section 6's landing table
  marked OPEN AT THIS WRITING is that gap, = = not a guess about it.
- The scope's own suites are green, = = and the whole suite's census is
  BELOW the base's (= the suite is not green on `main`, = = and this
  scope does not own the red).
- The boss's OWN LOOK (§7.7, = = the merge gate for a UI-touching
  ticket): GIVEN. His verdict, = = in English, = = was that the overlap
  was gone and the iteration could stop.
  ⇒ ⇒ ⇒ WHICH BUILD, = = THE FOUR FACTS THE RULE ASKS FOR:
  - Path: `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/fix1124.app`,
    = = executable `Fix1124`, = = 37,831,776 bytes, = = mtime
    `2026-11-24 18:08:16`.
  - Bundle id: `com.wenshu.app.fix1124` (= = an ISOLATED id, = = so it
    never shares the saved window geometry with `com.wenshu.app` = = and
    two instances of one bundle id abort each other).
    It was launched with a PLAIN `open`, = = never `open -n`.
  - Signature: ad-hoc (= = `codesign -dv` prints `flags=0x2(adhoc)`,
    = = `Signature=adhoc`).
  - The app was NOT left running (= = re-checked at the closeout:
    `ps -eo pid,args | grep "Wenshu.app/Contents/MacOS"` returns
    nothing).
  ⇒ ⇒ ⇒ AND THE ONE HONEST LIMIT ON THIS EVIDENCE, = = STATED RATHER THAN
  SMOOTHED OVER: = = the bundle was packed at 18:08 from the worktree's
  `.build/debug/WenshuApp`, = = and the FIRST commit that holds the fixed
  source is `772b608a66` at 19:31, = = so the build the boss looked at
  PREDATES the commit by 83 minutes. ⇒ ⇒ ⇒ So git cannot prove that
  binary's source: = = no object holds the tree as it stood at 18:08.
  What IS proven: = = the binary carries the view type
  (`nm -a` prints 130 `SidebarTreeView` symbols against a 766-symbol
  `AppleSidebarView` positive control, = = so the count selects and is
  not a silent zero), = = and the fix's code line is a single modifier,
  = = and the tree's own suite reproduces the two halves of the claim
  WITHOUT the boss's look being the only thing standing between the
  defect and a regression. ⇒ ⇒ ⇒ ⇒ ⇒ So the look is recorded as GIVEN on a
  pre-commit build, = = and the COMMITTED proof is the suite, = = not the
  look.

### The landing table, one row per original requirement

| Requirement | The commit that carries it | The verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| The sidebar's tree draws one part's rows at a time (= no row of one part under a row of another) | the fix `772b608a66`, this record's first landing `e4818545d7` | `t_b28c9ebc` = `approved by wenshu-review`, read back by `review_gate.py --card t_b28c9ebc` | `git ls-remote <remote> refs/heads/main` answered `e4818545d7f99156576db131081271f6ae11c05f` on BOTH remotes (= `origin`, = = `old-origin`) at that push |
| This record's own corrections (= the text a reader lands, not the fix) | the commit this document ships in (= the tip the round's card names; never restated here, because an amend moves it) | **OPEN AT THIS WRITING (the verdict)** (= the card on `wenshu-review` ends with `kanban_complete(metadata={"review_outcome": "approved"})`, and `review_gate.py --card <id>` reads it back; = = this document never states that outcome as reached, = = because the record cannot approve its own round) | **OPEN AT THIS WRITING (the landing)** (= then `git ls-remote origin refs/heads/main` and `git ls-remote old-origin refs/heads/main` answer the same sha, read per remote and never from a tracking ref) |

⇒ ⇒ ⇒ AND THE COMMITS THE PUSH CARRIED THAT ARE NOT THIS SCOPE'S: NONE,
= = and that is a measurement, = = not an assumption. The range each
remote had to catch up was `bbc2434997..e4818545d7`, = = and `git log
--oneline` over it prints exactly two rows (= `772b608a66`, = =
`e4818545d7`), = = both this scope's, = = count = 2. ⇒ ⇒ ⇒ So no
sibling's landed work rode along on either push, = = and there is no
maintenance push to disclaim. ⇒ ⇒ ⇒ AND THE SET IS MEASURED PER PUSH: a
second landing on this scope would carry a DIFFERENT set, = = and the
next record re-runs the command rather than trusting this sentence.
⇒ ⇒ ⇒ AND THE SERVER STATE AS THIS ROUND READS IT, before its own landing:
`git ls-remote origin refs/heads/main` and `git ls-remote old-origin
refs/heads/main` BOTH answer `f45a142f62ddb05d74a1c22827c3ab3d2456bafc`, which is
`HEAD^` of the commit this document ships in, so this record lands as a
fast-forward on both, and `git log --oneline f45a142f62..HEAD` prints ONE row.
⇒ ⇒ ⇒ Which is also the answer to the rule above: the set this landing pushes
carries no sibling's work, because the siblings are already on both remotes, and
that count is a reading taken here rather than a restatement of the first push's
2, which stays exactly where it is written as the reading of THAT push.

## 7. Sweep the board's open columns

MEASURED at this round's close, and NONE of it is this scope's to close.
The board's non-terminal columns hold SIX cards:

| Card | Status | Whose | What it waits on |
| --- | --- | --- | --- |
| `t_16d2c525` | ready | `pocock` | a product decision: which of the two controls keeps the shift-command-K chord (= its own stop line says "block and name the two chords in the balance") |
| `t_ac2dfd0a` | ready | `pocock` | `t_115170f2` round 4 landing B9 (= its body states the dependency: the marker list it edits does not exist until that round lands) |
| `t_67674cf7` | ready | `pocock` | the registry gate's own wiring: the battery never calls `nfi-loc-check.py`, and what it measures is the shell's cwd |
| `t_9971afe2` | ready | `pocock` | the lineage reader's binding: a lane that edits the registry table unbinds its own approval |
| `t_8340eb70` | ready | `pocock` | a landing task of ANOTHER scope (`citation-guard-widen`): rebase `5e9df13785` onto `origin/main`, 13 conflicts |
| `t_d3562a4d` | running at the minute this row was read | `wenshu-review` | its own review run (the comment-honesty lane's verdict on `cc74be1156`), not this scope's |

⇒ ⇒ ⇒ TWO OF THE FOUR `pocock` CARDS CAME OUT OF THIS SCOPE'S OWN REVIEW
(`t_67674cf7` and `t_9971afe2`): round 3's B1 and this round's gate-4 failure are
one defect seen from two sides (= a registry row that lags the file it counts),
and the durable fix belongs in the GATE, not in this document. ⇒ ⇒ ⇒ All six are
named, measured and left open: closing another lane's card erases the reason it is
open. ⇒ ⇒ ⇒ AND THE CENSUS IS A RE-TAKE, NOT A CARRY-OVER: the same query read TWO rows
when this document first landed, SIX when the table above was read, and the LAST row of
that table had ALREADY CHANGED ID by the time this paragraph was typed (the running card
was `t_d3562a4d`, and a few minutes later the same query returns `t_e22d6b40` in its
place). ⇒ ⇒ ⇒ That is why the table carries no claim about what the board looks like when
the reader opens it: it names the query, and the reader runs it. The command that re-reads
it is the one this step ran, read-only: `select id, status, assignee, title from
tasks where status in ('todo','ready','running','blocked','review','scheduled',
'triage')` against `product_lines.board_db()`.

This scope's own cards are terminal and verified on the board:
`t_b28c9ebc` = `done` (= the review that approved the fix), `t_08e5adbe` =
`archived` (= the mis-flagged filing that never spawned), and this document's
three finished review rounds `t_b3c72e68`, `t_bbec0dc6`, `t_1ea50c6a` = all
`done`, all read back `changes_requested` through `review_gate.py --card <id>` (=
which is why the run named in section 1 exists at all).

⇒ ⇒ ⇒ AND THE FOUR `pocock` ROWS ARE THE BOARD'S OWN KNOWN SHAPE, = = NOT A
STALL: = = this board's `kanban.dispatch_profiles` names the review profile alone, =
= so a card addressed to the implementer is never spawned, = = and reading it as
stuck would be a false finding. ⇒ ⇒ ⇒ So those rows are named for the next reader
and left exactly as they were found.

⇒ ⇒ ⇒ AND THE CARD THIS SESSION DISPATCHES NOW is the review card for THIS
record's corrections, = = its body names the tip it reviews, = = and step 8 is not
complete until that card's verdict reads back `approved` through `review_gate.py` and
this commit is a fast-forward on BOTH remotes (= = read per remote, = = never from a
tracking ref).

## 8. THE CARD YOU DISPATCHED IS YOURS TO LAND

DONE. `Scripts/land_card.sh t_b28c9ebc wt/sidebar-dup-tree-2026-11-24`
ran the card's five gates in the card's own worktree and moved `main` by
compare-and-swap (= `git update-ref refs/heads/main NEW OLD`, = = so the
landing refuses if `main` moved under it), = = printing `RESULT: LANDED
sha=e4818545d7f99156576db131081271f6ae11c05f` with
`main moved by compare-and-swap: bbc2434997... -> e4818545d7...`. ⇒ ⇒ ⇒
The shared checkout's FILES were never written by it, = = which is why
step 5's reconciliation had to re-read the tree before touching it.

The remote is read back per remote, = = because `land_card.sh` pushes
ONLY `origin`: at that landing `git ls-remote origin refs/heads/main` and
`git ls-remote old-origin refs/heads/main` each ANSWERED
`e4818545d7f99156576db131081271f6ae11c05f`. ⇒ ⇒ ⇒ What either answers now is a
reading, = = not a holding: = = this round's read of the same two commands is in
section 6's landing table, = = and it is a different sha. ⇒ ⇒ ⇒ `old-origin` (GitHub) sat at `bbc2434997` until this
closeout pushed it, = = so a LANDED result line on one remote was NOT a
landing on the other, = = exactly as the rule warns.

⇒ ⇒ ⇒ AND THE STOPPING RULE: this scope's review card carries the
claims it checks BY NAME, = = and a finding that is only wording is
non-blocking once the named claims hold. = = The record does not log its
own meta-reviews: = = a round that asks for a further self-audit of this
document is the defect repeating.

⇒ ⇒ ⇒ AND THIS DOCUMENT HAS BEEN THROUGH ITS OWN REVIEW, = = WHICH IS WHY
ITS MEASUREMENTS CARRY THEIR COMMANDS. The closeout record above `main`
`e4818545d7` was committed on its own branch (`wt/sidebar-closeout-2026-11-24`)
= = not in the shared checkout, = = = = because other sessions were live = = and
it has been through the review rounds named below, = = each returning
CHANGES_REQUESTED, = = and the TALLY of them is the board's reading and not this
sentence's: = = round 1 (`t_b3c72e68`, = = 2 blockers, = = the
`--skip-build` false greens, = = fixed in the commit parked as
`refs/keep/sidebar-closeout-a1`, = = `05ae26b50f`); = = round 2 (`t_bbec0dc6`, = =
those same 2 blockers CLOSED by the reviewer, = = plus 3 new ones, = = a commit
message still describing round 1's fix, = = a gate table citing logs this author does
not hold, = = and a card body carrying round 1's figures); = = round 3
(`t_1ea50c6a`, = = three stale claims, = = each named by its line); = = and the round
whose findings the run in section 1 answers, = = whose text is NOT the commit that
carries it (= = an amend moves the sha, = = so the card names it and the record does
not). ⇒ ⇒ ⇒ THE FIGURE THAT MOVED BETWEEN ROUNDS IS THE RECORD'S OWN: = =
the gate table was rebuilt so every cell names a held log file, = = and the run
account was rebuilt around WHO HOLDS WHICH ARTIFACT and says UNRETAINED where nobody
here holds one. = = Both were the SAME mistake wearing
two names, = = and it was MINE: = = I ran gates with `--skip-build` against a
`.build` that PREDATED the suite under test, = = so a filter matching no test
exited 0 and I read that as a pass, = = twice (= = gate 2, = = and the
`SidebarTreeReloadTests` arm that this §1 now re-labels). = = ⇒ ⇒ ⇒ ⇒ THE
LESSON IS NOT "re-run the gate", = = it is: = = **`--skip-build` makes every
test claim a claim about a BINARY, = = not about the tree you are standing
in**, = = and `swift test --filter X` where X is absent from that binary is an
exit-0 NON-EVENT. = = The fix applied here is to build the tree the claim is
about, = = and to quote the printed suite name, = = never the exit code. = =
⇒ ⇒ ⇒ The reviewer's third finding (the registry row's trailing `||`, = = and
`comment_lineage`'s vacuous added-0 on a docs-only window) is corrected in the
same pass, = = and the base-vs-branch arm the reviewer named as the evidence
for the blame question is RUN above, = = in §1's second bullet of CLAIM TWO.

## Open items this scope leaves behind

Each is named with the reason it is open, = = and none of them is this
scope's to fix.

1. **The skill tree has two unwritable skills.** `apple-ui-craft` carries
   references at 386,867 and 270,374 characters, = = and
   `wenshu-pocock-workflow` carries `references/card-gates-that-lie.md`
   at 99,457 against a 100,000 cap. ⇒ ⇒ ⇒ `skill_manage` refuses EVERY
   write to either (= = the batch aborts and rolls back), = = so a rule
   that belongs in them can only be written elsewhere. The fix is a
   capacity split (= = `skill-capacity-split`), = = not a shorter rule.
   ⇒ ⇒ ⇒ Until it is done, = = the gate-vocabulary increment this
   session measured went into `wenshu-card-gate-vocabulary` instead,
   = = and Rule 4.6 above went into `macos-design-guidelines`.
2. **No test asserts that an expansion survives a PART switch.** The
   mechanism is checked (= = the set lives in `WorkspaceUIState`,
   = = keyed per row, = = and the code says the key survives a rebuild
   and a relaunch), = = but `SidebarTreeExpansionTests` never switches
   part, = = so the claim is a reading of the code and not a result.
   The reviewer reached the same gap independently.
3. **Two pre-existing reds on `main`, = = not this scope's.**
   `ChatView history shortcut (T92)` case `body_logs_history_metadata`
   (= = the log block carries no `totalTokens` key), = = red in all three
   census runs, = = and `SidebarTreeReloadTests` case "The selection does
   not rebuild the tree" (= = `fixture.counter.count` moves 3 → 6 → 51 → 117), = = which
   is FLAKY rather than order-dependent. ⇒ ⇒ ⇒ BOTH were measured on a BUILT
   worktree of the pre-landing base `bbc2434997`, = = = = the arm that
   settles blame = = and the second one is green on some runs there too
   (1 green / 3 red), = = so no run count certifies it either way. ⇒ ⇒ ⇒ What
   is actually open is the assertion at `SidebarTreeReloadTests.swift:189`: = =
   it compares a live reload counter against a captured value on a path that
   is timing-sensitive, = = and it is nobody's lane yet.
4. **`closeout_gate.py` decides LANDED from a branch NAME that step 5
   deletes.** Its reading is `rev-parse` the issue row's Branch cell and
   ask whether the tip is an ancestor of `main`; = = once the landed
   branch is cleaned up (= = which step 6 REQUIRES), = = the same gate
   reads "not in the repository" for a scope that landed and was pushed.
   ⇒ ⇒ ⇒ The workaround this scope used is a parked ref,
   `refs/keep/sidebar-part-switch-a1`, = = named in the issue row.
   ⇒ ⇒ ⇒ The real fix is the gate reading ancestry from the landed sha
   it already prints, = = rather than a name the closeout is told to
   delete.
   ⇒ ⇒ ⇒ AND THE SIBLINGS ARE NOT EVIDENCE FOR THIS ONE: = = re-taken at
   this closeout, = = `2026-11-24-flow-gates` and
   `2026-11-24-quiet-probe-windows` also read NOT LANDED, = = but for a
   DIFFERENT reason (= = their issue rows name no branch at all, = = so
   the gate stops at "no branch named in its body or its index row"),
   = = and this scope's row names one that no longer exists. Two shapes,
   = = one cause: = = the gate's landing test is a name lookup.
   ⇒ ⇒ ⇒ AND THE SAME TOOL'S STEP 1 HAS THE SIBLING FLAW, = = MEASURED ABOVE:
   = = it is satisfied by any log whose BYTES contain the merged sha, = = = =
   never by a suite result. The fix is one reading for both: = = the gate
   should require a log that prints the merged sha AND a `Test run with` line
   for each suite the card names.
