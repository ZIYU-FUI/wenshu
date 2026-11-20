# Session close: no verdict without a teeth run

Date: 2026-11-20 (Asia/Shanghai). Lane: `pocock` (verification / respecification). Board: `wenshu-par`.

This session landed **no repository code**. What it produced is measurement: every inbound review verdict was
re-derived inside the commit it reviewed, three of my own earlier claims were retracted on evidence, two open
cards were rewritten so the next worker cannot execute a vacuous instruction, and one gate defect was found in
the landing path that neither review round had looked at. Nothing was written to the shared skill tree or to the
`wenshu-review` profile.

## 1. Original requirements, and what carries them

| Requirement as given | Outcome | Where it is on the record |
| --- | --- | --- |
| Check the result of `t_27bb198b` (visual-audit split, 133,481 over cap) | Split confirmed replayable; one structural defect found in its own gates (gate 4 compared two copies of one artifact, so it could never see the live tree) | comment on `t_27bb198b`, incl. a partial retraction of my own drift accusation |
| pocock's own copy of that skill is also over cap, nobody owned it | Owned by me and fixed: 133,481 to 50,687 chars, then 50,928 after the lesson write; sha `de31d31048d3e21c` to `8bc603727211457e`; writability proved by real `skill_manage` calls in both directions | `t_492cddbd` (done, run 4764) |
| Check `t_5c51345b` (4 cleanup items the split could not move) | All four independently recomputed from the diff: 0 of the 388 deleted lines carried a real word; the shortened PNG file is a byte-exact prefix of the original; `description:` 60 chars; 0 hardcoded script paths | comment on `t_5c51345b` |
| Check `t_874d1142` (scripts/ 19 vs 24) | Names and contents now identical across both forks (24/24, sha equal); the asymmetry that remained was the **mode bit** on one `.sh`, on my side, closed after `bash -n` passed (0644 to 0755, bytes untouched) | comment on `t_874d1142` |
| Check `t_cf516ed6` (instruments, changes_requested) | All three blockers reproduced by my own mutants, plus a fourth: the delivered file does not declare the five flags a successor card was told to pass (each exits rc=2) | `t_2699b55c`, comment on `t_cf516ed6` |
| Check `t_1496fea8` (same tip, deeper) | B2+ and B4 confirmed as written; **B5's classification sent back** (it exits rc=1, loud-but-wrong, not a silent green) | `t_2699b55c` acceptances 6 to 9, comment on `t_1496fea8` |
| Check `t_863c9848` (registry rows round 2) | Three blockers confirmed inside `ce7b456945` itself; the reviewer's proposed remedy for one of them is insufficient, and the reason is measurable | comment on `t_863c9848`, `t_995f69f0` rewritten |
| Keep the skill files writable | The rule "a measurement belongs to a moment, not to a deliverable" is now a skill reference with 7 rules, index bidirectional, 0 dangling | `references/proving-the-live-tree-not-a-copy.md` |

## 2. Findings worth more than this session

**The landing path's last gate decides on a sentence (`t_2699b55c` B6).** `Scripts/land_card.sh:66-70` reads
`merge-preflight.sh`'s output and greps for the literal text `a card that writes code needs one approving
verdict`; `$?` appears **0 times** in that segment. Measured on `fix/report-instruments-into-repo`: the preflight
exits **rc=3** (a real refusal) and its output **also contains a line starting with `CLEAN`**. Replaying the
three decision greps against the captured output:

| wording of the veto sentence | land_card's step 1 |
| --- | --- |
| as shipped | `exit 11 NO_VERDICT`, refused |
| one synonym substituted | **passes, proceeds to rebase and push** |
| deleted | **passes, proceeds to rebase and push** |

The un-approved tip in front of us is blocked only because that line has not been retyped since `3aa733ac95`
(2026-10-30), and this card's own B2+ fix asks for text to be added to those messages. That is why B6 is on the
same card as B2+: fixed separately, one of them creates the other. `git log -S` finds no other consumer of the
sentence, so no test covers it either.

**A driver whose suite never asserts it ran.** In `ce7b456945`'s test suite the identifiers `driver_ran`,
`invocation`, `wrapper`, `DRIVER_LOG` each appear **0 times**, and `driver_ran` appears 0 times in `docs/agents/
nfi.md` at that tip. Case 18 now fires the driver but claims nothing, so "add an assertion to case 18" is not
yet an assertion. Separately `git ls-files -- '*ReaderViews*'` returns **0 paths** and `git log --all -S
ReaderViews` hits **`ce7b456945` itself** first: the commit that fixed a fabricated path introduced a new one.

**Three ways an instrument reports green after its measurement died**, all reproduced: an empty result set
scored as a pass (`qualifier-gate.py`, `hits: 0 / unqualified sites: none`, rc=0); a pipeline whose exit code is
only its last stage (`git show <dead sha> | wc -l` with `--expect-output 0` passes while stderr carries
`fatal: invalid object name`); and an external tool checked only by `which` (a `exit 6` pandoc stub on PATH
produced `PASS 0 rendered lines carry **` where the truth was 7).

## 3. Retractions I owe the record

1. "The reviewer published a number no gate reproduces" (50,412). Retracted: that count was true at the moment
   it was measured; `t_5c51345b` later removed 22 characters by shortening `description:`. What stands is only
   that gate 4 compared two copies of the same artifact.
2. "The lint caught a second dangling pointer both forks missed." Retracted on measurement: both targets exist
   in the shared tree; the lint resolves pointers only inside one skill directory, so cross-skill references are
   systematically false positives. "Fixing" them would have deleted real citations.
3. "2 tools documented as `./x` cannot run" and "53 tools missing from scripts/". Retracted: one is a repo path,
   one is a compiled artifact, and most of the 53 are Swift sources the prose cites as evidence, not tools.
4. My first pass at the round-2 claims read `main` through a silent fallback (`src = WT if exists else REPO`,
   and the worktree did not exist), invalidating three numbers before I re-measured them with
   `git show <commit>:<path>`.

## 4. Gate states at close (read-only, current tree)

| check | result |
| --- | --- |
| `git rev-parse main` / `origin/main` | `834b37db1f`, equal, working tree clean |
| `merge-preflight fix/report-instruments-into-repo` | **rc=3**, `CLEAN … behind main by 1 commit(s)` + verdict refused |
| `review_gate --branch fix/report-instruments-into-repo --sha e589837044` | `CARD t_1496fea8`, `verdict: changes_requested` |
| registry branch `ce7b456945` (+ parent `f1646a0c43`) | round 2 `changes_requested`, not landed |
| board open columns | 4 cards, `blocked = 0`: `t_2699b55c` ready, `t_995f69f0` ready, `t_c15ad028` todo (gated), `t_9a40ea5f` triage |
| skill capacity | 6 files over the 100,000-char cap: 5 in the shared tree (needs `t_9a40ea5f`), 1 in my own profile (`wenshu-board-mechanics`, 100,943, needs no authorisation) |

Both card-gates run against the rewritten bodies returned rc=0 with `hits: 0 / unqualified sites: none` and 0
extracted commands, because an implementation body contains neither claim phrases nor `grep … <this body>`
commands. Reported as vacuous, not counted as green.

## 5. Where the round stops

Two tickets stay open and both are **mine to execute, not to dispatch**: the board's
`dispatch_profiles: [wenshu-review]` means an `@pocock` card never spawns. They are specified to the point where
every acceptance names its command and its expected number.

* `t_2699b55c` - fix the instruments so a dead measurement cannot report green (B1 to B5 plus B6), each with a
  red-on-revert mutant. Includes the 2-line `land_card.sh` fix that makes future message edits safe.
* `t_995f69f0` - driver rework under the tip: a suite case that fires the driver **and asserts it fired**, plus
  the fabricated-path and `origin/review/<sha10>` prose fixes.

After those, the instruments branch needs a rebase onto `main` and the new tip needs its **own** review card,
opened when the commit exists. Durable lessons from this round went to `mem0` and to my own profile's skill; the
shared-tree copy is blocked on `t_9a40ea5f`, and a refused authorisation is not routed around. No commit in this
range is anyone else's: `main` was not advanced by this session, and the only commit it adds is this document
plus its registry row.
