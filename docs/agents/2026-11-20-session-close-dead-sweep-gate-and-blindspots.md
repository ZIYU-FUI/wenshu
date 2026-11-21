# Session close — the dead-code sweep audit, its two gate fall-throughs, and the blind-spot branch (2026-11-20)

This document closes one session's scope: the full-repo dead-code and
Apple-API duplicate-implementation audit, the two review-gate defects it
exposed, and the verification branch that fixes the measurement tool's own
blind spots. It is the ledger of the Standard Closeout eight steps for that
scope.

## 1. The requirements and where each one lives

| # | What was asked | Where it went | Verdict trail | Server-side proof |
| --- | --- | --- | --- | --- |
| 1 | Full-repo dead-code + Apple-API-duplication audit, one record | `f16928ec85` (landed in a previous round; the record is `docs/agents/2026-11-16-the-dead-code-and-apple-api-sweep.md`) | reviewed across rounds 1-13; the row's own citation defects were adjudicated on `t_d20b7850` | the record's §A1-§A9 batteries on main; §A10, the cited-sha guard, arrives with the B branch (`grep -c '"A10' Tools/wenshu-devtool/dead-sweep-measure.py` = 0 on main; `dead-sweep-measure.py:1218` on the branch); every live number re-quoted from the tool's own print; the baseline delta is the record's own section "The same gate at the 2026-11-02 baseline (= the delta)" at `docs/agents/2026-11-16-the-dead-code-and-apple-api-sweep.md:149-187` |
| 2 | BUG A: the gate's ViewModifier blind spot | `91df14b600` — `Tools/wenshu-devtool/measure-drill.py` plus `Tools/wenshu-devtool/tests/test_measure_drill.py`, ancestor of main, landed | no review card was bound when that arm landed (none names it); the attribution was corrected and re-verified on `t_d20b7850` | `python3 Tools/wenshu-devtool/tests/test_measure_drill.py` → 6 passed, 0 failed, including the case "a ViewModifier is measured like a View". The earlier `f49184cb8` attribution was wrong (that commit is the AVMediaTools speech-rate fix and touches no devtool), and no §A arm can be this row's proof: `grep -c ViewModifier Tools/wenshu-devtool/verify-dead.py` = 0 |
| 3 | BUG C: the second blind spot (own-file `DECL_PREFIX` skip) | not landed — ships with `project/t_verify-dead-blindspots`. Main's `verify-dead.py:512` still holds `if same_file and line.lstrip().startswith(DECL_PREFIXES)`, so main's own tool still calls the bucket alive | reviewed on `t_d20b7850` (the earlier `750b43d20` attribution was wrong: that commit touches `commit_filter.py`, `install_hook.sh` and `nfi.md`, never `verify-dead.py`) | `git show project/t_verify-dead-blindspots:Tools/wenshu-devtool/verify-dead.py \| grep -c 'startswith(DECL_PREFIXES)'` = 0, vs 1 in main's copy (`grep -c 'startswith(DECL_PREFIXES)' Tools/wenshu-devtool/verify-dead.py`) |
| 4 | BUG B: `verify-dead.py`'s two reachability blind spots *inside the measurement tool* — the fix branch | `project/t_verify-dead-blindspots`, 19 commits over main, tip 10 chars re-read by the two commands in the last cell. The tip is named by ref, never by sha, per §3: the landing rebase rewrites it | round 14 approved by `t_c7ae0796`; round 15 refused by `t_ee09697b` (F1 predicate tested ancestor-of-HEAD not ancestor-of-main, F2 guard FAIL did not reach the exit code, F3 the fixture could not express the shape, F4 card-text claims not run first); round 16 rebased the approved content onto main, flipped the predicate to `origin/main`, fed the exit code and grew case 14 to five shapes, and was refused by `t_8a6029b9` — B1: its card body named a superseded same-subject twin sha, so no verdict could bind and the landing gate read the branch UNREVIEWED; B2: four row-32 live readings were stale (66/185 where that tree prints 67/195). Round 16's F1-F3 code was verified with teeth and stands; its rework is docs plus card body | `git rev-parse --short=10 project/t_verify-dead-blindspots` and `git rev-list --count origin/main..project/t_verify-dead-blindspots` — both re-runnable after the landing rebase |
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
CONTENT, never by sha — and the first document that rule had to be applied
to is this one. Until this revision its row 4 sha-cited three branch-lineage
commits, and §A10 could not see it: the guard's `audit_rec` is hardcoded to
the sweep record, so this closeout sits outside its scope, and no tool was
changed to widen it. Re-implementing the guard over this document's text at
`b183da4069` counted 17 hex tokens of 8-10 chars, 14 ancestors of
`origin/main`, 3 not — and two of those three resolved in no ref at all and
in neither a fresh `--single-branch --no-local` clone of main nor of the B
branch, only in this machine's object store. The three are written as
content now, so this document has zero non-main-ancestor sha tokens in it.

## 4. The eight steps, as executed

1. §7 gates re-run on the merged tree: the six devtool suites present on
   main (`test_merge_preflight` 0 failures, `test_review_gate` every case,
   `test_pre_review_gate` 22/22, `test_ci_change_gate` 19/19,
   `test_agents_gate` 87/87, `test_nfi_loc_check` green).
2. Verdict comments written on the board (`t_15ffe3b7` landing record,
   `t_ee09697b` round-16 findings answer).
3. This document, committed by path, registered in `docs/agents/nfi.md`
   with its own LOC row added last, and its row self-parenting like every
   other session-close row (until this revision the row's Parent column
   named the sibling closeout doc instead of this one).
4. NOT done. The two durable lessons exist as files —
   `/Volumes/ANAN/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/`
   `references/push-verify-and-dispatcher-lessons.md` (this step's earlier
   text named `push-verify-and-dispatcher.md`, a file that does not exist)
   and `/Volumes/ANAN/.hermes/shared/wenshu-skills/wenshu-review-proof/`
   `references/twin-sha-trap-rebased-ancestry.md`, over-correction clause
   and number-move rule included — but neither is indexed. A
   `grep -rl <name> */SKILL.md` over that tree returns 0 hits for both
   names, while the control `standard-closeout` resolves to
   `wenshu-pocock-workflow/SKILL.md`, so the check has teeth and both files
   are orphans: the exact failure mode they document. The cause is the cap
   already tracked as `t_9a40ea5f` — `wc -c` on the two files gives 125,374
   and 106,313 bytes against `skill_manage`'s 100,000 limit, so no index
   line can be added to either until that card's split lands.
5. Own residue only cleaned, by name (this session's card bodies and
   measure prints).
6. Report as the table above.
7. Board sweep: `t_2699b55c` and `t_995f69f0` are the boss's own cards and
   were NOT touched; `t_9a40ea5f` (triage, skill-tree size) waits on a
   human decision; `t_c15ad028`, then a sibling's todo, has since closed on
   the board (`hermes kanban show t_c15ad028` reads status done).
8. This session's dispatched cards: the gate line is landed and commented;
   the round-16 B verdict came back `changes_requested` on `t_8a6029b9`, so
   landing the B branch remains this session's open obligation and now rides
   the B rework, not the round-16 card.

## 5. Open items this closeout does NOT resolve

- The B branch's landing. `t_8a6029b9` came back `changes_requested` on the
  round-16 tip (blockers B1/B2, its verdict comment); its F1-F3 code was
  verified with teeth and stands, so the rework left in the branch is docs
  plus the card body. A fast-forward is off the table — main has moved since
  the round-16 base, re-read with
  `git rev-list --count project/t_verify-dead-blindspots..origin/main`, and
  any rebase rewrites the tip's sha, which is why §1 row 4 names the branch
  by ref only.
- A review card body must name the FINAL PUSHED tip it was written against.
  Round 16's body named a superseded same-subject twin whose tree differed;
  that sha resolves in no ref and in neither a fresh
  `--single-branch --no-local` clone of main nor of the B branch, so
  `review_gate.py` matched no card to the branch tip and
  `Scripts/merge-preflight.sh` read the branch UNREVIEWED even under an
  approving verdict — the twin-sha trap catching the round whose job was to
  close it. Open until the B rework re-points its body at the tip it pushes
  and self-checks the binding.
- The two orphan lesson files stay unindexed until `t_9a40ea5f` splits the
  two oversized `SKILL.md` (§4 step 4).
- A complete `swift test` over the merged tree was not run in this closeout
  (baseline-red suites and timing-sensitive cases are documented; the
  scope's gates are the devtool suites above plus the B battery).
- Whether editing `wenshu-review-proof` (the reviewer-side skill) needs the
  boss's explicit sign-off: the edits added the twin-sha discipline the
  reviewers themselves demanded; flagged for one-word confirmation.
