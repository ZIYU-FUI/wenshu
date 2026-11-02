# Session close: one developer, one review card

2026-10-30. A session that retired the `wenshu-dev` lane, rebuilt the
review gate so every path fails closed, and landed the result behind a
chain of review cards. The chain is on the board, and the property that
describes it holds whatever its length: EVERY card this session created
was a review card, and every one of them that has closed carries a
verdict from the reviewer.

**HOW TO FIND THIS SESSION'S CARDS.** Not by `created_by`: the parallel
session runs under the same `pocock` profile, so that column carries its
build cards too. The shape tells them apart. A card of this session has
`## WHAT TO BUILD` and a `## REVIEW HANDOFF` that names NO reviewer
(= a card written by the one developer IS the review, so there is no
implementer to hand off from); the parallel session's build cards name
a reviewer. That shape selects exactly this session's chain. The cards
up to the card under review are:

```
t_cf48e2ec  t_fd3551fe  t_0e9e9d5f  t_bf5f3894  t_cd4230dc
t_20bd6cbf  t_f51843e8  t_a1e41861  t_de63e367  t_7d718554
```

and the card that reviews this record is the last of them.

## The symptom, in the board's own words

The board had two lanes. `wenshu-dev` implemented a card in its own
worktree, `wenshu-review` reviewed it, and the branch was then merged by
nobody: a card had three endings and only two of them were automatic
(= the worker finishes, the reviewer approves, the branch lands on `main`
= nobody does it for you). The lane cost a full extra agent per ticket,
and the cost was measured, not assumed: 14 cards sat `done`, reviewed,
and still unmerged, every one of them CLEAN at `merge-preflight.sh` and
BEHIND `main` by 4 to 76 commits. That is a SNAPSHOT, taken at the tree
this session started from: those branches are gone from the repo now
(= at the tree this record was written at, the only `wt/` branches left
belonged to this session's own review cards), so the range is a past
measurement and not a live count.

The lane also failed open. `merge-preflight.sh` answered "will this
conflict" and REFUSED an unreviewed merge — but a card the board did not
carry, a board that could not be read, and a gate file that was missing
all read as "no verdict" rather than as a refusal, so a branch that
carried nothing could pass. `review_gate.py --branch X` matched ANY
review card on the board when no sha was given, so one card's approval
could clear a branch it had never seen.

## The fix

**The lane is retired.** `pocock` is the only developer: it finds the
problem, writes the code and commits, all in its own session and its own
worktree, and creates NO card while it works. After the commit it
creates exactly ONE card, assigned to `wenshu-review`, whose body names
the sha under review, the files it touches and the gates to run. The
`wenshu-dev` profile is deleted and the dispatcher's claim allowlist is
`wenshu-review` alone, so a card assigned to any other profile never
spawns a worker.

**The verdict is machine-readable.** The reviewer ends its run with
`kanban_complete(metadata={"review_outcome": "approved"})` or, to reject,
a `kanban_comment` carrying the finding followed by
`kanban_complete(metadata={"review_outcome": "changes_requested"})`. NOT
`kanban_request_changes`: the board refuses it for a card the reviewer
owns, because it needs a `review_requested` handoff event that this flow
never creates. A verdict written only in the summary is NOT a verdict
(AGENTS.md 7.9) — `review_gate.py` reads the run metadata's
`review_outcome` field.

**The gate resolves a branch by the branch's OWN tip.** A card body that
names an old sha gets a verdict on the old tree, so the reviewed sha must
be the branch tip, and a branch whose tip no card names is UNREVIEWED.

**AND BY THE CHANGE IT CARRIES.** A branch that fell behind main is
rebased before it lands, and a rebase rewrites the commit id. So the
gate also accepts the card whose sha the branch used to point at, when
the two carry the same EDIT.

**WHAT "THE SAME EDIT" MEANS, PRECISELY.** The identity of a change is
the diff from where the branch left main, produced with NO CONTEXT
(`-U0`), with the hunk headers dropped (= the line numbers move in a
rebase) and the +/- lines kept VERBATIM (= the whitespace is the meaning;
in Python the indent IS the meaning). Measured 2026-10-31: a branch
rebased onto a newer main changed sha (e103538d -> 0040c704) and tree,
and its edit did not move.

**AND THE BLOB HASH IS KEPT, PER FILE SECTION, FOR A BINARY FILE.** Git
renders a binary diff as one constant line, so the blob hash is the
only thing in the section that says WHICH payload it is. Dropping it
gave two different PNGs one identity, and the gate cleared a branch
carrying a different image. So the `index` line is dropped for a TEXT
file (= the +/- lines carry the content) and kept for a BINARY file.
Three details, each measured:

* WHICH half survives depends on the direction. An ADD or a MODIFY
  keeps the NEW blob (= the payload); a DELETE keeps the OLD one (= the
  new half is all zeros, so keeping it gave every deleted file of that
  path one identity).
* BINARY is detected the way git prints it (= a line that STARTS with
  "Binary files "), not by a substring over the section. A text file
  whose CONTENT says "Binary files ..." was read as binary, and then
  its identity depended on the whole file.
* The rule is read PER SECTION, because git prints `index` BEFORE the
  "Binary files" line, so a line-order check reads the wrong answer.

**AND THE DECODE IS LOSSLESS, IN BOTH PLACES THAT COULD LOSE A BYTE.**
A diff can carry bytes that are not text (= a file git reads as text
because it holds no NUL byte, and it is not UTF-8). Replacing them made
two different payloads hash the same (= a fail-open collision where the
crash had been a fail-closed one), so the bytes are captured and
decoded HERE (= not by `text=True`, whose universal newlines translate
`\r\n` into `\n` DURING the decode) with a surrogate escape that
round-trips them exactly.

And the diff is split on `\n` ONLY: `str.splitlines()` also splits on
`\r` (and on eight more separators), so a lone `\r` inside a line was
dropped and the line cut in half. A CRLF payload and an LF payload are
different payloads, and the identity now says so.

**WHAT IT IS NOT.** `git patch-id --stable` is NOT the identity of a
change: it strips whitespace (= two different programs share an id) and
it hashes the context lines (= a landing near the change moves it). The
review round measured both, and the gate uses the diff instead.

**AND THE VERDICT IS DATED BY THE RUN THAT CARRIED IT.** A run that
carried no verdict (a crash, a superseded attempt) is not a verdict, and
its timestamp must not make an OLD approval look newer than a newer
refusal. The ordering reads the verdict's own run, the same one
`verdict_from_doc` reads.

**AND THE ORDER IS THE AUTHORITY.** When several cards cover a branch,
the card naming the CURRENT sha governs it, and among those the later
verdict governs (= a later refusal voids an earlier approval). Without
this, an old approval of a pre-rebase tree shadowed a newer refusal of
the current tree, and the branch landed.

## The nine defects the review rounds found

Each was found by `wenshu-review` on the card under review, fixed as its
own commit, and re-reviewed by the next card. These nine are the defects
of the ORIGINAL contract (= the sha contract, the card-absent contract
and the exit codes). The change-based verdict that replaced them found
more, and those are in the section below. The commit list is oldest
first.

1. **`92e8dafbd6`** — `ticket_tier.py`'s review-card contract did not
   match what `review_gate.py` actually reads, so a card the tier script
   called valid was refused by the gate.
2. **`dadf624c0e`** — `--branch` without `--sha` matched any review card
   on the board. It now resolves the branch's own tip (`_git_tip()`).
3. **`e36a0057f2`** — the card body is not always TEXT: the board stores
   some of them as a BLOB, and a NULL for the cards created without one.
   Both are decoded now, so a review card with a body is never skipped
   for having an unreadable one. The wrapped document is what the
   classification reads, not the raw row.
4. **`4e14379fd2`** — the run metadata is JSON TEXT, and the code only
   accepted a dict, so an approving verdict was invisible. And
   `merge-preflight.sh` treated "no card found" as `continue`, which is a
   fail-open: a branch no card named was skipped instead of refused.
5. **`0f3e04e8a9`** — the gate refused every branch it could not clear:
   a board that does not exist, a card that does not exist, a sha no card
   names, and a verdict still pending.
6. **`a3271ccb5d`** — `if ! cmd; then rc=$?` reads the status of the
   NEGATION, which is 0 when the command failed. A failed check read as a
   success, so the board-unreadable case was reported as a plain miss.
7. **`5faec5d268`** — the gate file was checked AFTER the lookups ran, so
   a gate that could not be opened read as "the board could not be read",
   and the `NO GATE` diagnostic was unreachable.
8. **`1fa94e89d8`** — a card that is ABSENT is not a board that is
   UNREADABLE. The CLI writes "no such task" to STDERR, so a check that
   read only stdout could not tell the two apart. An absent card is now
   `card_absent` (exit 4), an unreadable board stays `board_unreadable`
   (exit 2), and the merge script tells them apart.
9. **`cbf944e7e4`** — the sha lookup runs inside a command substitution,
   so a variable it set never reached the caller: the script read "no
   review card names the sha" where the truth was "the board could not
   be read". The exit code now travels through a file the EXIT trap
   removes. The gate's board reader returned an empty list for a board it
   could not read AND for a board that holds no cards; `None` now means
   unreadable (exit 2) and `[]` means readable and empty.

## The measured result

The merge gate prints six labels, and this is the whole set (read off the
script's own `echo` lines, not from memory):

```
CLEAN                              exit 0   the branch is reviewed
UNREVIEWED                         exit 3   no verdict names it
UNREADABLE                         exit 3   the board could not be read
NO GATE                            exit 3   the gate file is missing
CONTRACT                           exit 3   the card's body breaks the contract
CONFLICT                           exit 1   the branch conflicts with main
```

`CONFLICT` is a merge conflict rather than a verdict failure, so the
five VERDICT paths are the ones that matter here, and they carry four
causes (`UNREVIEWED` covers two of them):

```
board unreadable               -> exit 3  UNREADABLE
sha no card names              -> exit 3  UNREVIEWED
gate file missing              -> exit 3  NO GATE
verdict still pending          -> exit 3  UNREVIEWED
the card breaks the contract   -> exit 3  CONTRACT
reviewed branch, card approved -> exit 0  CLEAN
```

A card id in a branch name is a CLAIM, not a verdict: when the board
does not carry that card the script discards the claim and lets the SHA
decide, so a card-id branch whose sha no card names refuses with the
second path's cause (= "no review card names the sha this branch points
at"), and a card-id branch whose sha IS named by an approving card
passes (= that branch IS reviewed). Measured on the tree under review:
`review_gate.py --card t_ffffffff` reads `card_absent` (exit 4), while
`merge-preflight.sh` on a branch named after that card exits 0 when an
approved card names its sha.

**WHEN SEVERAL CARDS COVER A BRANCH, THE FIRST ONE THE GATE PRINTS IS
THE ONE THAT GOVERNS.** The merge script takes the first `CARD` line,
so the gate prints them in the order of authority (= the card naming the
current sha first, and within that the later verdict first). Measured
2026-10-31: the board hands the cards over in creation order (= oldest
first), so an old approval used to shadow a newer refusal.

The four states of the gate are distinct, and the gate's own exit codes
say which is which (each measured on the tree under review):
`card_absent` (4), `board_unreadable` (2), an unapproved verdict (3), an
approved card (0).

The reviewer's own matrix, comparing the reviewed tree against its
parent, found the fail-open it had come for. Reproduced here on the
branch the earlier card used (a branch whose NAME embeds a card id the
board does not carry):

```
4e14379fd2  (the parent)   exit=0  CLEAN           <- passed with no verdict
0f3e04e8a9  (the fix)       exit=3  UNREVIEWED      <- refuses
```

The `CLEAN` on the first line is the per-branch CONFLICT status, not the
verdict: at that tree the gate found no card naming the sha and simply
continued, so the branch landed with nothing on the record. Every verdict
path above is `exit=3` with its cause named.

## WHAT THE CLOSEOUT'S OWN GATES FOUND

The closeout re-ran the ten merge-blocking gates (§7) on the MERGED tree,
and three of them found things this session's own work had broken or
left behind. They are in their own commits, each reviewed by its own
card.

**§7.5 = the fixtures had added CJK to a modified file.** The card
titles in the test fixtures carried the board's Chinese type tag,
written out by hand, and the fixtures took
`tests/test_review_gate.py` from zero CJK characters to ten. The tag is
load-bearing (= it is what DECLARES a card's kind), so the fixture now
asks the TOOL for it (`ticket_tier.TYPE_TAG_NAMES["review"]`): the file
stays English and the fixture cannot drift from the map the tool reads.

**§7.6 = a dead function.** `review_gate.py` carried
`_approving_runs`, which nothing called (= `_verdict_runs` is the live
reader, and it accepts a refusal as well as an approval). Restoring it
changed nothing, which is how it was proven dead.

**§7.2 = a case that wrote the cap down, and nobody ran it.** The
over-cap fixture was built at 30,225 chars (= over the 20,000 floor the
gate used before). The cap is now the pinned 500,000, so the fixture was
UNDER it, the gate accepted it, and TWO CASES FAILED. The fixture now
measures the cap the gate itself reports, so it is over the cap
whatever the cap is.

The lesson is not the three fixes: it is that the session had been
running FIVE devtool suites, and the sixth (= the one holding the
regression) was not among them. The tree's suites are the tree's gates:

```bash
for s in Tools/wenshu-devtool/tests/test_*.py; do
  python3 "$s" >/dev/null || echo "RED: $s"
done
```

## WHAT THE CLOSEOUT'S OWN GATES FOUND (the second round)

The ten merge-blocking gates (§7) were run on the MERGED tree, and three
of them found things that were NOT this session's cap work.

**§7.8 = the CI lint job rejects the repo's own commit subjects.** Its
regex demanded the scope to be EXACTLY `(wenshu)`, while the repo's own
commits use many scopes (= `(gate)`, `(close)`, `(editor)`, ... = 97
distinct scopes over main's history, counted under the same anchored
convention) and its own pre-commit hook (= the rule's other reference)
accepts every one of them.

Measured at tree `50f325e848`, with the job's OWN regexes (= read out of
the workflow files at `57be84050a` and at the tip, not restated here),
over the 5,602 commits `57be84050a..50f325e848`:

```
git log --format=%s 57be84050a..50f325e848 | grep -vE '<the rule>'
```

**ONE SCOPE CONVENTION FOR BOTH ROWS** (= a scope is `^\w+\([^)]*\):`,
ANCHORED at the subject's head, so a subject that carries one is counted
as scoped whatever its type):

- the OLD rule (= the scope must be `(wenshu)`) rejected **1,215** of
  them. Of those, **650 carry a scope** (= 585 with a scope other than
  `(wenshu)`, and 65 with scope exactly `(wenshu)`), and **565 carry no
  scope at all**. The 650 sum with the 565 to the 1,215.
- the CURRENT rule (= an optional free-form scope) rejects **656**, of
  which **91 carry a scope** and **565 carry no scope at all**. Of the
  91, **88 carry a scope the CI's own charset accepts** (= they are
  rejected for their TYPE, because `merge`, `style`, `ref`, `tool`,
  `debug`, `i18n`, `spec`, `revert` and `cleanup` are not among the nine
  conventional types), and **3 carry a scope the charset rejects** (= a
  scope with a space in it).

**SO WHAT THE FIX ACTUALLY CHANGED.** `(wenshu)` IS one of the repo's
own 97 scopes, so the OLD rule rejected **650** of the subjects that
carry one of the scopes the repo actually writes. The CURRENT rule
rejects **91** of them, and every one of those 91 is rejected for
something OTHER than the scope's shape (= 88 for its type, 3 for a space
inside the scope). So the fix stopped the scope's CONTENT from being
the reason, and it did not stop the scope's EXISTENCE from being
accepted: **the current rule accepts a subject whose scope is one of
the repo's own**, which is what the old rule refused to do.

**THE COUNTS ARE NAMED WITH THEIR TREE, THEIR COMMAND AND THEIR
CONVENTION, BECAUSE A COUNT WITHOUT THOSE IS A CLAIM.** Three earlier
readings of this record got this wrong, and each one changed the
glosses rather than the numbers: the first counted with a regex the
record wrote itself (809); the second wrote "650 of those carry a
scope (= every one a scope != `(wenshu)`)" (= false: 65 of the 650
carry scope exactly `(wenshu)`) and "656 ... NONE of those carries a
scope" (= false: 91 of them do); and the third wrote "none carries a
scope the CI's own charset accepts" (= false: 88 of the 91 do) and
paired the two rules' counts as "1,216 and 651" (= 651 is the OLD
rule's scoped count at that tree, not the CURRENT rule's rejection
count). So the rows are now ONE convention, and every clause in them is
true under it.

**AND THE NUMBERS MOVE WITH THE TREE, SO THE TREE IS NAMED.** The
counts above hold at `50f325e848`. The rule that reads them is
`git log --format=%s 57be84050a..<the tree> | grep -vE '<the rule>'`, so
the count is over the commits that exist AT the tree:

- at `50f325e848`: 5,602 commits, the OLD rule rejects 1,215 (= 650 of
  them carry a scope), and the CURRENT rule rejects 656;
- at `d058fee233`: 5,603 commits, the OLD rule rejects 1,216 (= 651 carry
  a scope), and the CURRENT rule still rejects 656.

So the OLD rule's counts move with the tree (every commit since carries
a scope the old rule refuses), and the CURRENT rule's do not (= the
commits since are `docs(close): ...`, which it accepts). The pair that
moves is named per rule.

**THE TABLE NAMES TWO FIXED TREES, NOT THE TREE THAT CARRIES IT.** A
row for the carrying commit would be a row that changes every time the
record is committed, so the numbers would never settle. The rule that
reads them is the command above, so a reader runs it at the tree they
care about; and the two rows here are trees that will not move.

**AND THE JOB READS ONLY THE LAST 10 SUBJECTS, SO ITS VERDICT IS A
VERDICT ON THOSE 10.** Measured with the OLD rule over the last 10
subjects at the tree this session's cap work started from
(`fda16f70b5`), the OLD rule rejects **4 of the 10**; at the base the
Swift section names (`0beb37b910`) and at the tip, it rejects **10 of
the 10** (= the last 10 subjects carry the scopes `fix(gate): ...` and
`docs(close): ...`, and the OLD rule refuses any scope other than
`(wenshu)`).

**AND THE OLD RULE WAS NOT RED ON MAIN THE WHOLE TIME, AND IT WAS RED
FOR TWO REASONS.** The OLD rule refuses a subject when either:

1. its scope is not `(wenshu)` (= the reason this session's fix
   addressed), or
2. it has no conventional prefix at all (= the `Merge ...` titles and
   the plain English ones, which the old rule refused for their SHAPE),
   or its type is not one of the nine conventional types. The nine are
   `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `perf`, `build`
   and `ci`, and the types outside that set which the repo's own
   history writes with a scope are `merge`, `style`, `ref`, `i18n`,
   `tool`, `spec`, `debug`, `revert`, `cleanup` and `review`.

So the job was red on main in WINDOWS, not in every window: a window of
ten subjects that all carry `(wenshu)` passes (= measured at
`00c1df5008` the OLD rule rejects 0 of the 10). And only the first of
the three reasons is a scope question, so the fix changed that one.

**THIS PARAGRAPH CARRIES NO COUNT OVER THE WHOLE HISTORY, AND THAT IS
THE POINT.** An earlier reading of this record carried the window
statistics (= how many windows of ten the old rule let through, and how
many it refused). Every such count is over the commits that exist at
the tree, so it moves as the tree moves (= three review rounds measured
it at three trees and each one produced a different gloss for the same
number). So the paragraph now states the CAUSES (= what the rule
refused and why) and the ONE count that belongs to a fixed tree (= the
4 of the 10 at `fda16f70b5`), and the reader's command is in the
paragraph above for anything else.

**THE TREE IS NAMED BECAUSE THE FIGURE BELONGS TO ONE TREE.** An earlier
reading of this record said "4 of the 10 at this session's base", and
"this session's base" names two different trees in this record (= the
Swift section's base is `0beb37b910`, and the 4-of-10 figure is
`fda16f70b5`).

**§7.10 = a review card's gate section must name the suite in the FORM
the gate-width gate reads.** This session's card named it as a shell
glob over the test directory (= `for s in .../test_*.py; do python3
"$s"`), which names the same suites but is not the shape the regex
reads (= `python3 .../test_*.py`). The card's body now names the
commands directly.

**§7.2 = the Swift suite's baseline is RED, and it stays RED.** And the
count is a fact about a RUN, not about a tree.

**THE STABLE FACT: THE TWO TREES CARRY IDENTICAL SWIFT SOURCES.**

```
git diff --name-only 0beb37b910 50f325e848 -- '*.swift'    -> empty
```

No `.swift` path differs between the session's base tree and the tip,
and the last commit that touched a `.swift` path on main (`2ddbc764be`)
is an ancestor of the base tree. So **no Swift test result can be
attributed to this session's work** (= the whole diff from the session
base to the tip touches no `.swift` path), and any difference between
two runs of the two trees is the machine's load, not the code.

**THE COUNT MOVES, BECAUSE THE SUITE IS LOAD-SENSITIVE.** Measured with
the same command and the same counting convention (= the distinct
`Test "..." failed` and `Suite "..." failed` lines, with the timings
stripped and the run's own summary line excluded), on three SOLO runs
of each tree:

```
the base tree    41 / 41 / 41
the merged tree  39 / 43 / 41
```

So the count is a fact about one run under one load, and it is not
stable on either tree. And the SETS differ by whole tests in two of the
three pairings (= the `WSMemoryProvider` suite and the `sync adds a
memory entry` test fail on the base tree and not on the merged one in
one pairing; the replicated-kanban suite and the `T10: tool_use JSON`
test fail the other way in another). The isolated probes confirm the
cause: `swift test --filter WSMemoryProvider` in the base worktree
exits 0 (= it passes alone) while the same suite fails inside the
base tree's whole-suite runs.

**AND THE SWEEP FAILS ON THE BASE TREE ON ITS OWN.**

```
swift test --filter AccentTintOpacitySweepTests   (on the base tree)
  Test "DesignTokens.accentTintOpacityHero usage covers kanban sites" FAILED
```

**THIS CORRECTS TWO EARLIER READINGS OF THIS RECORD.** The first said
"22 on the base, 22 on the merged tree, three of them new on the merged
tree", and blamed the sibling's `KanbanView.swift` for the three. The
second said "39 on both trees, and the two sets are the same set". Both
were wrong, and the second was wrong because its runs shared the machine
with other `swift test` processes (= the reviewer measured the same
trees SOLO and got 41/41/41 and 39/43/41).

**THE ATTRIBUTION IS REFUTED BY A BLOB HASH, NOT BY AN ARGUMENT.**

```
git rev-parse 0beb37b910:Sources/WenshuApp/Features/Kanban/View/KanbanView.swift
git rev-parse main:Sources/WenshuApp/Features/Kanban/View/KanbanView.swift
```

give ONE hash, so the file is the same blob in both trees, and no sweep
can differ because of it.

**THE LESSON IS THE ONE THE SKILL ALREADY CARRIES, PLUS THE ONE THIS
ROUND ADDED.** A number that moves is a fact about a tree, and a fact
measured once under one convention is a CLAIM until it reproduces. So
this record now names the tree, the command and the counting convention
for every number it carries. **AND A COUNT MEASURED WHILE THE MACHINE
IS BUSY IS A COUNT OF THE MACHINE, NOT OF THE CODE** (= the base tree
is 41 in every solo run, and 39 when another `swift test` shares the
machine). So the honest form of this claim is the one that does not
carry a count: the two trees carry identical Swift sources, and the
suite is red on both.

## WHAT THE STANDARDS AUDIT FOUND (the delegated read of the diff)

An independent sub-agent read the whole diff against the repo's own rules
(= §7's Standards axis). It found six things; three were real, and two
of them were MY OWN regressions.

**THE GATE READ THE PIN WITH A REGEX, SO IT COULD BE LOOSER THAN THE
LOADER.** `agents_gate.py` matched the pin with a regex over the text,
while the loader parses the config. The two rules disagree in both
directions, and the disagreement is a fail-OPEN:

| the config | the gate said | the loader said | |
| --- | --- | --- | --- |
| a plain pin | 500,000 | 500,000 | agree |
| a pin with a trailing comment | 49,152 | 500,000 | a false red |
| **a DUPLICATE key** | **500,000** | **49,152** | **FAIL-OPEN** |
| a quoted pin | 49,152 | 49,152 | agree |

The duplicate key is the dangerous one: the loader's parser REJECTS the
file (= it falls back to its dynamic cap), the regex took the FIRST
match (= 500,000), so the gate accepted a file the loader truncates in
the middle = the one failure this gate exists to prevent. And the fix is
not a better regex: the gate now reads the config with the LOADER'S OWN
PARSER, so the two can never disagree.

AND THE FIRST FIX AT THAT WAS NOT ENOUGH. `_yaml_load` (= the reader the
gate already had for the frontmatter) is a CHAIN, and when the loader's
strict parser REJECTS a file the chain fell through to plain PyYAML,
which takes the LAST value of a duplicate key = 400,000 where the loader
says 49,152. So the fail-open was reopened by the fallback. The gate now
reads the config with the loader's parser and NOTHING ELSE: a file that
parser rejects carries no pin (= the loader is on its dynamic cap, so
the gate's fallback is the right answer).

And it was REACHABLE on this machine: the third interpreter in the gate's
own search path has PyYAML 6.0.3, and there the lax link answered. So
the case now runs in EVERY interpreter the gate would use (= 116 cases),
each measured against the loader's own answer in the same interpreter.

**AND THEN THE REVIEW FOUND THE CASE ITSELF WAS MEASURING THE WRONG
FILE.** The per-interpreter case imported the gate from a HARDCODED
absolute path to the MAIN checkout, so the suite measured two files and
the split was invisible in the output. Three mutations that the case
claimed to catch were NOT caught: the in-process lax link, the chain
revert, and the in-process branch itself (= the system python3 cannot
import `hermes_cli`, so it never reached the branch that could carry the
fail-open).

So the case now imports the gate from THE TREE UNDER TEST (`TOOL.parent`,
which is this file's own directory), the oracle runs in the SAME
interpreter as the gate under test (= before, the oracle looped the
interpreters and returned the first that worked, so every comparison
used interpreter #1's answer while the gate ran elsewhere), and the gate
asks the INTERPRETERS where the loader's package lives instead of
carrying a hardcoded root. All three mutations now go red.

**AND THEN THE NEXT REVIEW FOUND THE HARDCODE SURVIVING IN THE GATE'S
OTHER READER.** The cap reader was pointed at the discovered roots, but
the FRONTMATTER reader (`_yaml_load`) still asked a hardcoded checkout
(= a live git worktree on an actively-worked branch, so an edit there
changes this gate with no commit in this repo), and the hardcoded path
SHADOWED the interpreter's own install (= the two readers read two
different copies of the same package). So both readers ask the
interpreters now, and `grep -n "/Volumes/\|/Users/"` finds **no
absolute path left in the gate**.

No answer differed at the time (= the parser file the frontmatter reader
uses is byte-identical at the checkout and at every discovered root), so
this was a latent split rather than a live fail-open. But it is the
split the commit said it closed.

**A LATER REFUSAL WAS SHADOWED BY AN EARLIER APPROVAL.** The gate's
order put the card naming the current sha first and compared the time
only WITHIN a group. Every card in that list covers the SAME EDIT (= the
sha group names the sha the branch points at, and the change group names
a sha the branch used to point at whose change identity agrees), so the
group cannot outrank the time: an approval at t=100 on the current sha
shadowed a refusal at t=500 on the same change under its pre-rebase sha,
and the branch landed on a change the reviewer had refused. The order is
now the LATER verdict first, with the group as the tie-break.

**AND A SECOND PIECE OF DEAD CODE** (`PATH_PREFIXES` in
`agents_gate.py`, whose only occurrence was its own assignment).

**AND THEN THE REVIEW FOUND THE CASE NEVER EXERCISED THE GATE'S
SUBPROCESS FALLBACK.** The gate's reader has two branches: it asks the
loader's package IN-PROCESS when that package is importable, and it
falls back to a SUBPROCESS when it is not. Every interpreter the gate
would use can import that package, so every case ran the IN-PROCESS
branch and the subprocess branch was NEVER exercised = a defect in it
was invisible. Measured: with the subprocess branch restored to fall
through to a lax parser, the suite stayed **116/116 green** (= the
fail-open was NOT caught), while the same gate under `python3 -E -s`
(= the loader's package not importable, so the subprocess branch IS
taken) answered **400,000** where the loader answers 49,152.

So the case now runs the gate with the loader's package made
unimportable, and compares with the loader's own answer (= six more
cases, 122 in all).

**A BRANCH NO CASE EXERCISES IS A BRANCH NO CASE CAN SEE.** The suite's
green was true of the branch it ran, and silent about the branch it did
not.

The audit also CLEARED two hypotheses it could not reproduce: the
identity collision from the `diff --git ` marker split (= a content line
beginning with that marker would be cut into a fake section, but no two
different changes collide), and CI running no devtool suite (= true, and
pre-existing: which is why the cap regression was invisible to CI).

## The repo gates, on the merged tree

`python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0.
It checks the file against the CONTEXT-FILE CAP, and the cap is a FIXED
NUMBER: 500,000 chars (= 0.5 MB), pinned in the Hermes config as
`context_file_max_chars`. The gate reads that ONE line from the ONE
file the loader reads (= $HERMES_HOME/config.yaml), so the two are the
same number by construction.

AND WHEN A HOME PINS NO CAP, THE GATE USES THE FALLBACK (= 49,152 = the
loader's cap at the smallest window this project runs). A profile that
does not carry the pin (a fresh one: `hermes profile create` does not
copy it) falls back to the loader's dynamic cap (= 49,152 at a
204,800-token model), so a gate that always said 500,000 would be
LOOSER than the loader there (= it would accept a file the loader
truncates in the middle, which is the one failure this gate exists to
prevent).

THE FALLBACK IS NOT THE LOADER'S FLOOR (= 20,000 = the smallest cap the
loader can ever use), because the AGENTS.md is 19,949 chars: against
the floor it would sit 51 chars away from a false red in every home
that pins no cap, and it had been creeping up against that floor (TWO
commits, one char each: `74568d4819` and `830cb5d2c8`). The suite
checks the fallback against the LOADER'S OWN answer for every live
home, so a home that needs a smaller cap turns the suite red instead of
passing silently.

AND THE CI CARRIES THE PIN (= the workflow writes the config before it
runs the gate), so the CI checks the file against the SAME cap the
developers' loader uses, instead of against the fallback.

The suite compares the two for EVERY home (= the root and every profile
directory, including the ones with no config of their own), against the
LOADER'S OWN answer, because a line-based read cannot tell a pin the
loader honors from one it ignores (= a quoted value, or a duplicate key,
leaves the loader on its dynamic cap). It also states the MARGIN under
each home's cap (= 480,051 chars under a pinned home, 29,203 under an
unpinned one), because a margin of 51 chars is a fact the reader needs,
not a number to guess at.

AND NO CASE READS THE AMBIENT: the gate reads $HERMES_HOME, so every
case that calls it runs under a NAMED home (the root), and the suite is
green under every live home as the ambient. A home that cannot be read
is a FAILURE, never a skip.

**WHY ONE LINE, AND WHAT IT COST TO LEARN IT.** The loader's own dynamic
cap MOVES with the model's window (= 49,152 at a 204,800-token model,
240,000 at 1M), so a gate that computed it had to resolve the model's
window AND the config's own rules (= which key, which level, which file,
what type, a duplicate key, a value in (0,1), a file the parser
rejects). Each of those was a place where the gate could come out
LOOSER than the loader (= it accepts a file the loader truncates in the
middle, which is the one failure this gate exists to prevent), and the
review rounds found one of them per round. So the gate does NOT compute
the cap: it reads ONE line (= the cap the config pins) from the ONE
file the loader reads, and where a home pins no cap it uses the
loader's floor. The number is fixed (= 0.5 MB) in every config that
carries it.

AND THE SUITE CHECKS EVERY HOME, BECAUSE A HOME IS A PLACE THE GATE CAN
BE LOOSER. A profile that does not carry the pin (a fresh one: `hermes
profile create` does not copy it) falls back to the loader's dynamic
cap, so the gate uses the floor there. The suite compares the gate's
number with the LOADER'S OWN answer for the root and for every profile
directory (including the ones with no config of their own), and it
compares the config's CLAIM with the loader's answer, so "no pin" and "a
pin the loader ignores" (= a quoted value) are different answers (= a
broken pin is visible). A home that cannot be read is a FAILURE, never a
skip.

The loader truncates the WHOLE file, not the body: the number that
decides truncation is the file's length plus its label, and the loader
keeps the head and the tail and drops the middle (= so the rules in the
middle of a long file silently vanish).
`python3 Tools/wenshu-devtool/tests/test_review_gate.py` passes every
case. `bash -n Scripts/merge-preflight.sh` exits 0.
`python3 Tools/wenshu-devtool/verify-dead.py` reports 0 fully dead
files. Its summary line reads `PARTIAL (= some decls dead): 4`, but the
per-file verdicts behind that line are 103 ALIVE, 3 PARTIAL and 1
EMPTY: the tool files a file with NO top-level declarations into the
same bucket, so the summary counts 4 while only THREE files hold a dead
declaration (`ChatReasoningPartView.renderMarkdown`,
`SidebarService.dividerSentinelId` and `LibraryMigrationPanel.RowState`).
Every one of those three is a pre-existing Swift view, and this session
documents under `docs/agents/`.

The CJK audit over the added lines of every commit this session made
reports **16 new characters, in two test fixtures** (= 10 in
`Tools/wenshu-devtool/tests/test_review_gate.py` and 6 in
`Tools/wenshu-devtool/tests/test_ticket_tier.py`), and the distinct
characters are four: the board's own two kind tags (the review tag and
the build tag, as `Tools/wenshu-devtool/ticket_tier.py` spells them = it
maps them to `review` and `build`). So they are the tool's own vocabulary
and not a comment, and rule 1.1's subject check (which the CI lint job
runs) is clean: every commit subject is English with a conventional
prefix.

**AND THE COUNT IS MEASURED AT THIS TREE, WITH THE COMMIT SET NAMED.**
It was 6 in one fixture at the trees up to `41e0b78961`; three later
commits of this session added the other 10 to a SECOND fixture
(`8d899234b5` +2, `74568d4819` +2, `4a1cb222a0` +6), so the two
readings disagree only because they were taken at different trees. And
§7.5 above says the same thing about the one file it names (= the file
went "from zero CJK characters to ten"), so the two sections now agree.

## Where this is (the durable fact)

Every commit this session made is an ancestor of `main` on BOTH remotes
(`origin` = `gitcode.com:ZIYU1983/wenshu`, `old-origin` =
`github.com:ZIYU-FUI/wenshu`), checked with `git merge-base
--is-ancestor` against each remote's tracking ref. The session's commits
are the ones whose subject names the gate, the workflow, the closeout
record, the tier or the NFI registry (= `fix(gate):` `refactor(workflow):`
`docs(close):` `docs(tier):` `docs(nfi):` `fix(tier):`); the parallel
session's are the ones that name the inspector, the todo page, the board
or the editor. The dispatcher's
configuration is not in
this repository: it lives in the Hermes tree
(`/Volumes/ANAN/.hermes/config.yaml`
for the dispatcher allowlist, `~/.hermes/profiles/pocock/` for the
profile's own defaults and credentials). The rules are in
`AGENTS.md` (the SSOT), `.hermes.md` (the session entry point),
`docs/agents/parallel-development.md` (the review loop), and the shared
skill tree `~/.hermes/shared/wenshu-skills/` (the procedure). This
document is the tracked record; the skills are what the next session
reads.

## The open items, on purpose

**BOTH REMOTES CARRY THE WORK.** `origin` (`gitcode.com:ZIYU1983/wenshu`)
and `old-origin` (`github.com:ZIYU-FUI/wenshu`) both read back at the
same sha, and every commit this session made is an ancestor of `main` on both
(= `git merge-base --is-ancestor` against each remote's tracking ref). The
push to each was a plain fast-forward and rewrote no byte.

**THE PUSH CARRIED A SIBLING'S COMMITS.** This session's commits and the
parallel session's commits are INTERLEAVED on one `main` history, so a push
of `main` cannot carry one without the other.
Every push of this session's work was a plain fast-forward and rewrote
no byte of the sibling's work, but the sibling's commits are now on
`origin/main` too. The FIRST push that carried any of this session's
commits differs per remote, so it is named per remote: on `origin/main`
it was `fda16f70b5..ca51ff184f`, and on `old-origin/main` it was
`fda16f70b5..a345524927` (= `ca51ff184f` was never pushed to that
remote on its own). They
belong to a sibling session and are named here because the boss reads
the landing table and needs to know who owns each row.

**THE SIBLING'S OWN CARD IS NOT CLEAN.** `t_6a672e62` (`done`, assignee
`wenshu-review`) is refused by `review_gate.py` with a contract error:
its `## REVIEW HANDOFF` names the implementer profile, and a card cannot
be reviewed by the profile that implemented it. That card is the
sibling's, so it is measured here and not closed.

**`old-origin`'s worktree branches are not this session's.** Every
worktree still on disk that belongs to the parallel session, and every
branch it owns (`feat/todo-kanban-ui`, `pocock/coltop`,
`project/t_6a672e62-...`), was left untouched, rebased and undeleted.
A card's close does NOT remove its worktree: the board DEFERS the
removal of a workspace it cannot prove is free. It scans every board
for another live task using the path, and when it cannot tell it refuses
to delete and records why. The board's own event row for `t_f51843e8`
says `workspace_cleanup_deferred_shared` with the reason `unknown` (= it
could not tell), so the close left the directory on disk: measured, the
card closed at 16:25 and its worktree was still on disk at 18:37.

This session therefore removed its own cards' worktrees and branches by
hand, card by card, as each one closed (= no `.worktrees/` directory and
no `wt/<card id>` branch for a card this session swept). A card that
closes AFTER this record is written leaves its worktree until the
board's deferred sweep runs it, which is the mechanism above: so the
newest card's worktree is the board's to clear, not this session's.
