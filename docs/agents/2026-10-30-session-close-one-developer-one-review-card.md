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

**§7.8 = the CI lint job has been red on main since it was added.** Its
regex demanded the scope to be EXACTLY `(wenshu)`, while the repo uses 33
different scopes (= `(gate)`, `(close)`, `(editor)`, ...) and its own
pre-commit hook (= the rule's other reference) accepts every one of
them. Measured: 1,063 of the commits since the job was added carry a
subject that regex rejects, and the job reads only the last 10 (= 4 of
the 10 were rejected at this session's base, and all 10 are now). The
regex accepts an optional free-form scope, so the job passes on main's
window again.

**§7.10 = a review card's gate section must name the suite in the FORM
the gate-width gate reads.** This session's card named it as a shell
glob over the test directory (= `for s in .../test_*.py; do python3
"$s"`), which names the same suites but is not the shape the regex
reads (= `python3 .../test_*.py`). The card's body now names the
commands directly.

**§7.2 = the Swift suite's baseline is RED, and it stays red.** The base
carries 22 failing tests, and the merged tree carries 22 (= three
different ones fail on each side, all of them timing-dependent). The
three that are new on the merged tree are the design-system sweeps over
the SIBLING's `KanbanView.swift` (= the sibling's file, not this
session's work: this session touched no Swift file at all).

THE ATTRIBUTION IS MEASURED, NOT ASSUMED. The sweep over
`KanbanView.swift` was run twice on the merged tree: once with the
BASE's `KanbanView.swift` put back in place (= GREEN) and once with the
sibling's file (= RED). So the failure follows the file, and the file is
the sibling's.

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
that pins no cap, and it had been creeping up against that floor (three
commits, one char each). The suite checks the fallback against the
LOADER'S OWN answer for every live home, so a home that needs a smaller
cap turns the suite red instead of passing silently.

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

The CJK audit over the added lines of every commit this session
made reports 6 new characters, all of them the board's own two kind tags
(the review tag and the build tag, as `Tools/wenshu-devtool/ticket_tier.py`
spells them = it maps them to `review` and `build`), in one test fixture,
used the way that file already used the same tags twice before. So they
are the tool's own vocabulary and not a comment, and rule 1.1's subject
check (which the CI lint job runs) is clean: every commit subject is
English with a conventional prefix.

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
