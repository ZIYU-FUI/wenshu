# Session close: a retry inherits the state its dead attempt left

2026-10-30. A session that repaired the board's respawn handoff, measured
what was broken, and left the rule in the plugin and in the skill.

## The symptom, in the board's own words

A card that dies is re-dispatched as the SAME card with a NEW run, and the
new run starts blind. The dispatcher hands the retry a "## Prior attempts on
this task" section naming the outcome, the elapsed time and the cap — and
nothing else. The session id of the attempt that died was on the board
(`task_events` rows of kind `owner_admitted`, 197 of 220 `timed_out` runs and
155 of 167 `crashed` runs carry one, each payload also naming the profile
database that holds that attempt's transcript), and the retry was never told.

Measured 2026-10-30 on board `wenshu-par`: 155 cards had at least one killed
attempt. The handoff the retry received named NONE of them.

The cost was paid in human hours. On card `t_bd6ce8e3` a person wrote four
comments by hand recording what the dead runs had already measured, so the
next run would not measure it again. That hand-written comment thread was the
handoff, and the board's comment cap (= the newest 30) is why it could not be
a machine comment either: a machine comment per death pushes the HUMAN
comments out of the retry's view, which is the opposite of the goal.

## The fix

The carrier is a profile plugin, `respawn-handoff`, installed for
`wenshu-dev` and `wenshu-review` (`~/.hermes/plugins/` and each profile's
`plugins/`). It hooks `pre_llm_call`, reads the board READ-ONLY, reads the
dead attempt's own transcript READ-ONLY, and injects a compact
`[respawn-handoff]` block into the retry worker's own first prompt: the
attempt's outcome and how it died, its SESSION ID (so the worker can pull the
full transcript with `session_search(profile=..., session_id=...)`), where it
stopped (= its last assistant words, skipping the harness's `failed_turn`
interrupt banner), and the files it had already changed.

It writes NOTHING to the board and never resumes a dead session: a kanban
dispatcher transcript must not continue as an ordinary write-capable session.

## The four defects this session found and fixed

The plugin existed and had fired before this session. Measuring it against
the live board found four defects, each quantified before it was fixed.

1. **The newest death can have no transcript, and the whole handoff was
   lost.** The newest killed attempt sometimes has no `owner_admitted` event
   (= it died before the owner admitted it), and the digest was then empty
   even though an OLDER attempt had a full transcript: 15 of the 119 cards
   with a `timed_out`/`crashed` attempt got NO handoff at all. Now every
   killed attempt is tried, newest first, and a card with no transcript
   anywhere still gets a degraded digest (= how it died, and where to look).

2. **A quota wall is a death, and it is the board's most common one.** The
   measured outcome classes on `wenshu-par` are `rate_limited` 1213,
   `timed_out` 225, `completed` 171, `crashed` 167, `reclaimed` 70,
   `review_requested` 59, `blocked` 50. `rate_limited` and `reclaimed` were
   not counted as deaths, so 37 cards were handed off a STALE attempt while
   the newest death went unnamed. A kill is now one of four outcomes:
   `timed_out`, `crashed`, `rate_limited`, `reclaimed`. An attempt that
   STOPPED ON PURPOSE (`completed`, `review_requested`, `blocked`,
   `changes_requested`) already carries a summary and a comment thread, and
   this plugin does not repeat it.

3. **"Your worktree inherits them" was false for two out of three paths.**
   Of the 110 paths the plugin reported as "already changed", 75 were the
   profile's own scratch notes, which the retry's worktree does NOT contain.
   The paths are now three groups: IN YOUR WORKTREE (relative, inherited),
   OUTSIDE YOUR WORKTREE (absolute, still on disk, not part of the card),
   and a separate WARNING for a path in ANOTHER card's worktree — which
   breaks the one-writer-per-card isolation rule (AGENTS.md 1.12) and is
   called out on its own rather than filed under "scratch notes". Measured on
   the live board: card `t_23df617e` had a dead attempt that wrote into
   card `t_10607e80`'s worktree. That card is archived and both worktrees
   are gone, so the finding is historical — and no LIVE card carries a
   cross-card write today.

4. **The write-tool set named tools that do not exist.** It listed
   `edit_file` and `multi_edit`, and missed `edit`. The real write tools
   measured on this board are `patch` 2266, `write_file` 2687, `edit` 10.

Two defects were found in the repair itself, before it shipped:

5. **The digest's tail was being cut, and the tail is the instruction.** A
   1600-character cap truncated 35% of digests, and what it cut was the
   closing "check git log and git status there" line — the one line that
   tells the retry the worktree still holds the dead attempt's commits. The
   budget is now 2200, the file lists give way first, and the guidance
   never goes.

6. **A card with no killed attempt re-scanned the board on EVERY turn.** The
   empty result was not cached. It is now.

## The gates, measured after the fix

`respawn-handoff`'s own regression suite (21 checks, run against every
installed copy) passes, and the numbers it pins are the numbers above:

    cards with a killed attempt                 155
    -> NO handoff                                 0   (was 15 of 119)
    -> names an OLDER attempt than the newest    0   (was 37)
    -> every session id is one the board knows   0 bad
    -> digests losing the guidance               0
    -> digests hard-truncated                    0
    -> digests over the budget                   0

The suite lives at `~/.hermes/plugins/respawn-handoff/test_respawn_handoff.py`
and pins the defect classes, not the numbers: the numbers move with the
board, the classes do not.

End to end, through the real hook path (`invoke_hook('pre_llm_call', ...)`
with the card body `build_worker_context` actually delivers), both lanes
inject a correct handoff, and the plugin loads with no error in a fresh
worker process of both lane profiles.

## The repo gates

`swift build` exits 0 on `main` at `336d56c512`. The devtool suites that own
the tools this session touched: `test_review_gate` 29 cases, `test_ticket_tier`
and `test_product_lines` all pass, 0 failures. `verify-dead.py` reports 0
dead declarations.

## Where this is (the durable fact)

The plugin is not in this repository: it lives in the Hermes profile tree
(`~/.hermes/plugins/` and `~/.hermes/profiles/<lane>/plugins/`), which is
not a git repository. The rule it encodes is in the shared skill tree, at
`~/.hermes/shared/wenshu-skills/wenshu-parallel-dev/references/respawn-hands-over-its-state.md`.
This document is the tracked record of the measurement; the skill reference
is what the next session reads.

## The open items, on purpose

**A card that reads `done` can still be UNLANDED.** Sixteen branches are
unmerged on `main`. Most are not this session's work and are not this
session's to land, but two are measured here because they decide whether a
card's work is on `main` at all:

- `project/t_e59bcf0c-...` (card `t_e59bcf0c`, `done`, an approving verdict
  from `wenshu-review` on the record) CONFLICTS with `main` in three devtool
  files, and its rebase onto `main` conflicts too. Its subject — the review
  gate recognising a review card — HAS ALREADY LANDED on `main`, by a
  different commit (`20450b88c4`), with a strictly stronger implementation:
  `main`'s `is_review_card` is narrower (it fires only together with the
  card's declared kind) and `main`'s `contract_errors` takes the kind as
  well. The branch carries six test cases `main` does not have, all of which
  test the branch's own wider semantics. The branch is therefore SUPERSEDED,
  not merely unlanded: landing it would replace a stronger implementation
  with a weaker one. It is left in place and named here, because the six
  test cases are the one thing in it that `main` does not carry, and
  deciding whether they belong on `main` is a card, not a cleanup.
- `wt/t_586a2c50` (card `t_586a2c50`, `done`) is refused by
  `merge-preflight.sh` as UNREVIEWED, and the gate is right: the reviewer
  run's metadata carries `reviewer_checks` but no `review_outcome` key. A
  verdict in a summary is not a verdict (AGENTS.md 7.9). The branch is
  behind `main` by 104 commits and clean.

**A card's worktree outlives its worktree-less branch unless someone
deletes it.** This session created and removed no worktree and no branch; the
`.worktrees/` directory holds 30+ directories, most of them belonging to
cards that are `done` and already merged. Cleaning them is a separate sweep
with its own ownership check (a sibling session's live worktree is not
yours to remove), and this session leaves them alone.

**`project/t_devtool-two-lines` is spent** (= its content is on `main` by
patch-id), and `backup-t_4e97b95f`, `marker-card`,
`pocock/deadcode-20261025`, `pocock/notifications-20261025`, `sibling-nfi`
and `hermes-subagent/subagent-sa-0-9624075f` each carry commits that are
NOT on `main` by patch-id. None of them belongs to a card this session
dispatched, so none of them is this session's to land or to delete.
