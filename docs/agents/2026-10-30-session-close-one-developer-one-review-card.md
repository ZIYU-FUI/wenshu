# Session close: one developer, one review card

2026-10-30. A session that retired the `wenshu-dev` lane, rebuilt the
review gate so every path fails closed, and landed the result behind a
chain of review cards. The chain is on the board, and the property that
describes it holds whatever its length: EVERY card this session created
was a review card (= `created_by=pocock` on `wenshu-par`, every one of
them assigned to `wenshu-review`, every one of them naming the sha it
reviews), and every one of them that has closed carries a verdict from
the reviewer.

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

## The nine defects the review rounds found

Each was found by `wenshu-review` on the card under review, fixed as its
own commit, and re-reviewed by the next card. The commit list below is
the whole arc, oldest first.

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

## The repo gates, on the merged tree

`python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0.
`python3 Tools/wenshu-devtool/tests/test_review_gate.py` passes every
case. `bash -n Scripts/merge-preflight.sh` exits 0.
`python3 Tools/wenshu-devtool/verify-dead.py` reports 0 dead
declarations. The CJK audit over the added lines of every commit this session
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
The push was a plain fast-forward (`fda16f70b5..a345524927`, then
`a345524927..3883052470`) and rewrote no byte of the sibling's work,
but the sibling's commits are now on `origin/main` too. They
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
This session's own review worktrees and their branches are gone, but
NOT because the card's close removed them: the BOARD's cleanup defers a
shared workspace, so it can land hours after the close (measured: the
card `t_f51843e8` closed at 16:25 and its worktree was still on disk at
18:37, and the board's own event row says
`workspace_cleanup_deferred_shared`). This session removed its own
cards' worktrees and branches by hand after the fact, so the state a
reader finds is true (= no `.worktrees/` directory and no `wt/<card id>`
branch for a card of this session) even though the board's sweep is what
would have done it, later.
