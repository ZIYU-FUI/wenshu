# The flow's rules become gates (flow-gates, 2026-11-24)

The scope `2026-11-24-flow-gates` = six process rules the boss ruled on,
plus a seventh the board measured while the wave was in flight. Each rule
was prose; each is now a gate a card cannot pass by prose.

The plan of record is
`/Volumes/ANAN/Engineering/wenshu/.scratch/2026-11-24-flow-gates/spec.md`,
and its seven issue bodies are under that plan's `issues/` directory. The
scope's tickets all rode ONE branch (`wt/flow-gates-2026-11-24`), so the
wave was reviewed by one card.

## 1. Re-run the section 7 gates on the MERGED tree

The gates below were re-run on the merged tree, not on the branch tip. The
log that names the merged sha is under `.gate-logs/`.

- `python3 Tools/wenshu-devtool/comment_lineage.py --base main --head HEAD --repo .`
  = 0 offending rows / 0 files (= P0=0, P1=0) over the branch's whole
  window.
- `python3 Tools/wenshu-devtool/comment_lineage.py --base 48cfabe115 --head e01689b8a1 --repo .`
  = the OOB register's PUBLISHED window, reprinted = `76 rows / 25 files`
  and `P0=10, P1=66`. The published census did not move, because the
  severity axis (= P0 = the row carries a CJK character) is unchanged.
- `python3 Tools/wenshu-devtool/ci_change_gate.py --base main --check pollution`
  = 0. `--check formatting` = 0. `--check markdown-newline` = 0.
  `--check loc-cap` = 0.
- `python3 Tools/wenshu-devtool/agents_gate.py` = the file is loadable and
  true.
- `python3 Tools/wenshu-devtool/nfi-loc-check.py --base main` = 21 rows
  checked (= 17 this change added, = 4 whose named file it rewrote), every
  row carrying its own count.
- Every suite under `Tools/wenshu-devtool/tests/` exits 0 (= 17 suites,
  including the five this wave adds).

## 2. Record the verdict on the board

The review card is `t_ae96d17c` (= `[T3][审核]`), and it ends its run with
`kanban_complete(metadata={"review_outcome": "approved"})`. The verdict
field is what `review_gate.py` reads (= a verdict word in the summary alone
is no verdict, = rule 7.9).

The card's body names the sha under review in the first paragraph of its
`## WHAT TO BUILD` section (= the shape `review_gate.reviewed_sha` parses),
and the branch's tree is byte-identical to the review worktree's.

## 3. Write the closure doc

This file.

## 4. Persist the durable lessons into the SKILLS

The lessons live in the shared skill tree, in
`wenshu-pocock-workflow/references/six-rules-become-gates.md` (= the eight
lessons this wave measured), and the pointer to it is in
`wenshu-parallel-dev/references/parallel-dev-reference-catalog.md`.

⇒ The tree's own `SKILL.md` was NOT grown: it carries 124,421 characters
against `skill_manage`'s 100,000 cap, so a new lesson goes in a
`references/` file (= the tree's own convention, = and a file the catalog
names) and not in the skill body.

## 5. Clean up YOUR OWN residue

The wave's own residue, and only its own:

- The three delegation lanes (`hermes-subagent/subagent-sa-0-fe626b4e`,
  `-sa-1-f9f29a0d`, `-sa-2-d38baa9a`) are gone, and their shas are PARKED
  at `refs/keep/flow-gates-sa{0,1,2}-2026-11-24` before the branches were
  removed (= a rehearsal worktree on a detached HEAD is the only ref for
  its commit, = so removing the ref first would turn every card quoting
  that sha into a dangling citation).
- The wave's own worktrees and branches go when the scope's last landed
  commit is on `main`.

⇒ NOT cleaned, because they are NOT the wave's: the repo's pre-existing
untracked `wt/` directory, and every other session's worktree, branch and
scratch directory on this board.

## 6. Re-check the final state and report it

The scope's last landed commit is on `main`, and `main` is at it.

## 7. Sweep the board's open columns

Every card that names this scope is terminal. The board's other open
columns are another lane's business (= the sweep names them, = it does not
close a sibling's card).

## 8. THE CARD YOU DISPATCHED IS YOURS TO LAND

The branch landed on `main` by compare-and-swap (= the ref moved, = and no
file in the shared checkout was written). The landing's own suite is
`Tools/wenshu-devtool/tests/test_land_card_cas.py`, and it proves three
properties on a fixture: a clean landing moves `main`'s ref and nothing
else; a `main` that moves under the landing makes the swap FAIL (= the ref
is not changed) instead of overwriting the other session's landing; and the
retry lands the card ON TOP of the other session's commit.

## The trace, one row per original requirement

| Requirement | The commit that carries it | The verdict that cleared it | The proof |
| --- | --- | --- | --- |
| 1. A new requirement arrives, a plan of record MUST exist before code | `90afbf444d` (= `plan_gate.py` + its suite), wired at `2563d13cb3` | `t_ae96d17c` | `plan_gate.py --scope 2026-11-24-flow-gates` prints the spec, its 4 of 4 sections, its 7 issue rows and its resolved edges; `test_plan_gate.py` exits 0 |
| 2. When the plan's whole scope has landed, the closeout eight steps MUST run | `0f24a283b1` (= `closeout_gate.py` + its suite) | `t_ae96d17c` | `test_closeout_gate.py` = 47 cases, every one of the eight steps named and its evidence read; the gate fires on the scope's STATE (= a ticket's branch tip is an ancestor of `main`), not on a keyword |
| 3. The CJK and other two-arm audits become ONE judge | `2563d13cb3` (= `comment_lineage.py` holds the only reader; `pre_review_gate.py` calls it and holds no second arm) | `t_ae96d17c` | the published window `48cfabe115..e01689b8a1` reprints `76 rows / 25 files` and `P0=10, P1=66` with the same finding set; `test_comment_lineage_gate.py` and `test_pre_review_gate.py` exit 0 |
| 4a. The landing moves `main` and nothing else | `2563d13cb3` (= `land_card.sh`'s compare-and-swap) | `t_ae96d17c` | `test_land_card_cas.py` = the ref moves and the shared checkout's files are not written; a `main` that moves under the landing makes the swap fail, and the retry lands on top of it |
| 4b. The merge driver travels with the repo | `2563d13cb3` (= `Scripts/install-merge-drivers.sh` + `merge_drivers.py`'s remedy) | `t_ae96d17c` | `test_merge_drivers.py` = a fresh clone audits UNWIRED, the installer wires it, and the wired clone merges two catalog keys with BOTH surviving |
| 4c. Two cards writing one file are refused before dispatch | `2563d13cb3` (= `ownership_gate.py` + the card contract) | `t_ae96d17c` | `test_ownership_gate.py` = 8 cases; `test_card_contract_gates.py` proves the wiring reaches `ticket_tier.find_contract_errors` |
| 5. The review lane hands work back by VERDICT, never by a card | `ed9699e9ce` (= `review_handoff_gate.py`), `08194f914c` (= its contract on the dispatch path) | `t_ae96d17c` | `review_handoff_gate.py` prints the 41 cards a review lane created for an implementer, naming each one's creator, assignee and the verdict of the review card it answered; `test_review_handoff_gate.py` exits 0 |
| 6. Every byte of process data goes to the data disk | `2563d13cb3` (= `process_data_gate.py` + its suite), `868f581669`'s sibling `6f2c1e9ab4` (= the row's pattern and its size) | `t_ae96d17c` | `process_data_gate.py` prints every process path with the volume the MOUNT TABLE says it is on; 15 paths measured, = = the flow's OWN fourteen all on the data disk, = = and the fifteenth (= the scratch under a hardcoded `/tmp`) naming 28060 directories on the system disk, = = which is the defect in the row below |
| 7. The two gates that read a card's GATES answer the same way | `868f581669` + `be63281946` + `315d1b9103` (= `card_gate_command.py`) | `t_ae96d17c` | `test_card_gate_command.py` = 16 cases; over the board's 981 cards the width gate raises NO new finding and 18 false ones are withdrawn |
| (rule 1.7, = the registration the seven rows above owe) | `b63cbf6e86` (= 17 registry rows + the devtool README's six sections) | `t_ae96d17c` | `nfi-loc-check.py --base main` = `21 row(s) checked: = 17 the change added, = 4 whose named file the change rewrote and did not add`, exit 0; the registry gate scopes itself to the keys the change ADDED, = so an unregistered file is invisible to it, = and only the registry itself closes that hole |

## A defect found while landing, in its own row

| What it is | Its state | Who owns it |
| --- | --- | --- |
| The TREE builds a `/tmp/wenshu-<name>-<UUID>` scratch root on every run and never removes it. Measured 2026-11-24: 28060 such directories, 633 MiB, on the system disk. The first account of it named the wrong owner (= the app's six runtime fallbacks in `Sources/WenshuApp/Features/Agent/Service/`, = = which match ZERO of the 28060); = = the directories come from 67 sites in 44 files under `Tests/WenshuAppTests/`, = = and the app's six are the same defect in a smaller number. | TRACKED (= the path is named by the process-data gate's row, = and the row watches the family's REAL shape, = = so the gate exits 1 while any match remains), NOT FIXED (= the fix is Swift, = and this wave's acceptance says no Swift) | The card `006-the-tree-leaves-no-scratch-on-the-system-disk` in this scope's plan, blocked by `005` |
