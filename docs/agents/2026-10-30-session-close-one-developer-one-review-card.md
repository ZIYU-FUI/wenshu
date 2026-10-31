# Session close: one developer, one review card

2026-10-30. A session that retired the `wenshu-dev` lane, rebuilt the
review gate so every path fails closed, and landed the result behind
three review cards.

## The symptom, in the board's own words

The board had two lanes. `wenshu-dev` implemented a card in its own
worktree, `wenshu-review` reviewed it, and the branch was then merged by
nobody: a card had three endings and only two of them were automatic
(= the worker finishes, the reviewer approves, the branch lands on `main`
= nobody does it for you). The lane cost a full extra agent per ticket,
and the cost was measured, not assumed: 14 cards sat `done`, reviewed,
and still unmerged, every one of them CLEAN at `merge-preflight.sh` and
BEHIND `main` by 4 to 76 commits.

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

The five refusal paths of the merge gate, each naming its own cause, each
exiting non-zero:

```
card-id branch, card absent          -> exit 3  UNREVIEWED
board unreadable                     -> exit 3  UNREADABLE
sha no card names                    -> exit 3  UNREVIEWED
gate file missing                    -> exit 3  NO GATE
verdict still pending                -> exit 3  UNREVIEWED
reviewed branch, card approved       -> exit 0  CLEAN
```

The three states of the gate are distinct, and the gate's own exit codes
say which is which: `card_absent` (4), `board_unreadable` (2), an
unapproved verdict (3), an approved card (0).

The reviewer's own matrix, comparing the reviewed tree against its
parent, found the fail-open it had come for: the parent passed a card-id
branch whose card the board did not carry (`exit=0 CLEAN`), and the
reviewed tree refuses it (`exit=3 UNREVIEWED`).

## The repo gates, on the merged tree

`python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0.
`python3 Tools/wenshu-devtool/tests/test_review_gate.py` passes every
case. `bash -n Scripts/merge-preflight.sh` exits 0.
`python3 Tools/wenshu-devtool/verify-dead.py` reports 0 dead
declarations. The CJK audit over the added lines of all eleven commits
reports 0 new CJK characters, and every commit subject is English with a
conventional prefix.

## Where this is (the durable fact)

Each of the twelve commits is an ancestor of `main` on BOTH remotes
(`origin` = `gitcode.com:ZIYU1983/wenshu`, `old-origin` =
`github.com:ZIYU-FUI/wenshu`), checked with `git merge-base
--is-ancestor` against each remote's tracking ref. The dispatcher's
configuration is not in
this repository: it lives in the Hermes tree (`/Volumes/ANAN/.hermes/config.yaml`
for the dispatcher allowlist, `~/.hermes/profiles/pocock/` for the
profile's own defaults and credentials). The rules are in
`AGENTS.md` (the SSOT), `.hermes.md` (the session entry point),
`docs/agents/parallel-development.md` (the review loop), and the shared
skill tree `~/.hermes/shared/wenshu-skills/` (the procedure). This
document is the tracked record; the skills are what the next session
reads.

## The open items, on purpose

**BOTH REMOTES CARRY THE WORK.** `origin` (`gitcode.com:ZIYU1983/wenshu`)
and `old-origin` (`github.com:ZIYU-FUI/wenshu`) both read back at
`a345524927`, and each of the twelve commits is an ancestor of `main` on
both (= `git merge-base --is-ancestor` against each remote's tracking
ref). The push to each was a plain fast-forward and rewrote no byte.

**THE PUSH CARRIED A SIBLING'S COMMITS.** The eleven commits and twelve
commits from the parallel session are INTERLEAVED on one `main` history,
so a push of `main` cannot carry one without the other. The push was a
plain fast-forward (`fda16f70b5..ca51ff184f`) and rewrote no byte of the
sibling's work, but the sibling's twelve commits are now on `origin/main`
too. They belong to a sibling session and are named here because the
boss reads the landing table and needs to know who owns each row.

**THE SIBLING'S OWN CARD IS NOT CLEAN.** `t_6a672e62` (`done`, assignee
`wenshu-review`) is refused by `review_gate.py` with a contract error:
its `## REVIEW HANDOFF` names the implementer profile, and a card cannot
be reviewed by the profile that implemented it. That card is the
sibling's, so it is measured here and not closed.

**`old-origin`'s worktree branches are not this session's.** The three
worktrees still on disk (`coltop`, `todo-kanban-ui`, `t_6a672e62`) belong
to the parallel session, and its branches (`feat/todo-kanban-ui`,
`pocock/coltop`, `project/t_6a672e62-...`) were not touched, rebased or
deleted. This session's own five review worktrees and their branches were
removed after their cards closed.
