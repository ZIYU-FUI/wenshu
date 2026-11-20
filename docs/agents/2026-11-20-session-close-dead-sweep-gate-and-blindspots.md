# Session close — the dead-code sweep audit, its two gate fall-throughs, and the blind-spot branch (2026-11-20)

This document closes one session's scope: the full-repo dead-code and
Apple-API duplicate-implementation audit, the two review-gate defects it
exposed, and the verification branch that fixes the measurement tool's own
blind spots. It is the ledger of the Standard Closeout eight steps for that
scope.

## 1. The requirements and where each one lives

| # | What was asked | Where it went | Verdict trail | Server-side proof |
| --- | --- | --- | --- | --- |
| 1 | Full-repo dead-code + Apple-API-duplication audit, one record | `f16928ec85` (landed in a previous round; the record is `docs/agents/2026-11-16-the-dead-code-and-apple-api-sweep.md`) | reviewed across rounds 1-13 | the record's §A1-§A10 batteries; every live number re-quoted from the tool's own print (row 32 lists the delta) |
| 2 | BUG A: the gate's ViewModifier blind spot | `f49184cb8`-era fix, landed | reviewed | §A2/§A3 arms on every tree since |
| 3 | BUG C: the second blind spot (own-file `DECL_PREFIX` skip) | `750b43d20`-era fix, landed | reviewed | §A4 `own-file-use` bucket print |
| 4 | BUG B: `verify-dead.py`'s two reachability blind spots *inside the measurement tool* — the fix branch | `project/t_verify-dead-blindspots`, 19 commits, tip `dd86f66f09` | round-14 `2739ea0b7e` approved by `t_c7ae0796`; round-15 `a348f374ba` refused by `t_ee09697b` (F1 predicate tested ancestor-of-HEAD not ancestor-of-main, F2 guard FAIL did not reach the exit code, F3 the fixture could not express the shape, F4 card-text claims not run first); round-16 `dd86f66f09` rebases the approved content onto main, flips the predicate to `origin/main`, feeds the exit code, grows case 14 to five shapes, and re-quotes every tree-dependent number from one battery print | under review on the round-16 card |
| 5 | The landing gate's fall-through (exit 4 `card_absent` was waved through by `merge-preflight.sh`) | `Scripts/merge-preflight.sh` + `test_merge_preflight.py` — the six-commit gate lineage landed on main through `f697a2ced0` ("merge: the landing gate's scope onto main") with round 7 tip `8b57ff0b15` reviewed approved by `t_15ffe3b7` | rounds 5 (`t_ed4d88b3` refused B1-B5), 6 (`t_939254fd` refused R1), 7 (`t_15ffe3b7` **approved**) | `git merge-base --is-ancestor 8b57ff0b15 origin/main` = true; `git diff 8b57ff0b15 origin/main -- Scripts/merge-preflight.sh` = 0 lines |

## 2. Commits on main that are NOT this session's

The gate scope was replayed and pushed by the concurrent orchestrator
session, not by this worker. Named for the record: `f697a2ced0` (the merge
of the landing gate's scope), `5cd1037d13` (the gate reads a card's sha from
its claim), `c2ac96d52c` (the gate's own closeout), `5aa65b57d3` (the
ViewModifier-blind-spot note), `4aa3ffe4bb` (a verification round's closeout
that landed no code), `75ce6bcc53`, `b96d3f7cb5`, `88127c8a14`, `834b37db1f`
and `b47493102d` (the registry, ruler and guards work of sibling cards), and
the roughly ninety production and documentation commits between the B
branch's round-15 base and today's `origin/main` that this session never
touched. This session's only direct hand in main is the gate-lineage content
under review carried by those commits; nothing else here is ours.

## 3. What the twin-sha trap cost, and what now prevents it

The gate line lost rounds 5 and 6 to citing, in prose meant to fix a stale
citation, shas that its own rebased branch no longer carried. The B line's
round 15 lost a card the same way one gate younger. The prevention is now
mechanical and lives in the B branch: `dead-sweep-measure.py` §A10 audits
every 8-10-hex token the record cites and fails (with the battery's exit
code) on any token that is not an ancestor of `origin/main`; case 14 of
`test_dead_sweep_measure.py` pins all five shapes (main-ancestor, dropped,
branch-local-but-HEAD-ancestor, blob, typo). The guard caught three live
citations the first time it ran, and caught round-16's own prose — citing a
vanished sha while describing the trap — with rc 1 before that prose was
rewritten. Citations of branch-lineage commits are therefore written by
CONTENT from now on, never by sha.

## 4. The eight steps, as executed

1. §7 gates re-run on the merged tree: the six devtool suites present on
   main (`test_merge_preflight` 0 failures, `test_review_gate` every case,
   `test_pre_review_gate` 22/22, `test_ci_change_gate` 19/19,
   `test_agents_gate` 87/87, `test_nfi_loc_check` green).
2. Verdict comments written on the board (`t_15ffe3b7` landing record,
   `t_ee09697b` round-16 findings answer).
3. This document, committed by path, registered in `docs/agents/nfi.md`
   with its own LOC row added last.
4. Durable lessons in the shared skills (`wenshu-pocock-workflow`
   `push-verify-and-dispatcher.md`; `wenshu-review-proof`
   `twin-sha-trap-rebased-ancestry.md` incl. the over-correction clause and
   the number-move rule).
5. Own residue only cleaned, by name (this session's card bodies and
   measure prints).
6. Report as the table above.
7. Board sweep: `t_2699b55c` and `t_995f69f0` are the boss's own cards and
   were NOT touched; `t_9a40ea5f` (triage, skill-tree size) waits on a
   human decision; `t_c15ad028` is a sibling's todo.
8. This session's dispatched cards: the gate line is landed and commented;
   the B line awaits the round-16 verdict — landing it remains this
   session's open obligation and is handed to the round-16 card.

## 5. Open items this closeout does NOT resolve

- The round-16 B verdict (`t_8a6029b9` on `dd86f66f09`) and the ff-landing of
  `project/t_verify-dead-blindspots` after it.
- A complete `swift test` over the merged tree was not run in this closeout
  (baseline-red suites and timing-sensitive cases are documented; the
  scope's gates are the devtool suites above plus the B battery).
- Whether editing `wenshu-review-proof` (the reviewer-side skill) needs the
  boss's explicit sign-off: the edits added the twin-sha discipline the
  reviewers themselves demanded; flagged for one-word confirmation.
