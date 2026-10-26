# Session close — 2026-10-26 — the dev-process output is Chinese, and the workflow skill has one source

> Boss directive 2026-10-26: "let the Hermes dev-process output use Chinese too;
> was English agreed somewhere before, fix it."
> The question was answerable: English WAS agreed, in two places, and they
> did not conflict with the directive. What was missing was that the rule
> never reached the profiles that do the work.

## The symptom

The boss asked for the R&D process to speak Chinese. The rule that should
have done it existed, in two places:

- `AGENTS.md` 1.1 = "English-only in code, comments, commits, prompts, all .md"
- the workflow skill, pitfall 32 = "Report the final conclusion in the boss's
  language" (= the CHAT SUMMARY is Chinese; code, commits, docs and card
  bodies stay English)

So the intent was already there. But the workers still reported in English,
and the reason was not a missing rule — it was that **the skill that carries
the rule had three divergent copies, and the two the workers read had drifted
away from the one the boss reads.**

## The root cause

`wenshu-pocock-workflow` existed as a local copy in each of the three
profiles, and each copy was edited independently (the curator writes the
local copy; the ledger shows agent-driven patches to `wenshu-dev`'s copy on
2026-10-23 and 2026-10-25, and to `wenshu-review`'s `sdlc-review` on
2026-10-26).

| copy | bytes | md5 | numbered pitfalls | carries the Chinese-report rule |
| ---- | ----- | --- | ----------------- | ------------------------------- |
| `pocock` | 92218 | `a0ffdcfdc4` | 67 | yes |
| `wenshu-dev` | 31012 | `85a83c93f3` | 30 | **no** |
| `wenshu-review` | 31012 | `85a83c93f3` | 30 | **no** |

Two things had gone wrong, and the second is the one that matters:

1. **The content diverged.** `pocock`'s copy had grown 37 pitfalls the other
   two never received, including pitfall 32 (the Chinese-report rule), the
   `## Parallel Development` section (= the whole board/worktree contract),
   and the `wenshu-parallel-dev` load-chain pointer. The other two had
   sections `pocock`'s copy lacked: `## Card tier` and `## Verification`.
   Neither file was a superset of the other.

2. **The pitfall NUMBERS slid out of alignment.** `pocock`'s 16 was
   "Restoring a feature another session deleted"; `wenshu-dev`'s 16 was
   "Trusting a source-text assertion test's file path". A worker that read
   its own copy and cited "pitfall 16" was citing a different lesson from
   the one the boss meant.

A worker following its own copy had no rule telling it to report in Chinese.
That is the whole defect.

## The fix

### One source, mounted by all three profiles

Both wenshu skills now live in ONE shared directory:

```
~/.hermes/shared/wenshu-skills/
  wenshu-pocock-workflow/   (SKILL.md + references/ + scripts/)
  wenshu-parallel-dev/      (SKILL.md + references/ + scripts/ + templates/)
```

Each profile reaches it through `skills.external_dirs` (the mechanism Hermes
already ships, and the one all three already used for
`~/.hermeslink/hermes-skills`). The three local copies are removed, so the
local tier can no longer shadow the shared one — measured: local > external
in `locate_skill`, so a surviving local copy would have kept winning and
kept drifting.

**The mechanism also removes the drift permanently.** The curator treats an
external skill as read-only ("external skills are read-only to the curator",
`tools/skill_usage.py`), so it can no longer fork a per-profile copy. The
cause is closed, not just the symptom.

The merged file is `pocock`'s copy (the complete one) plus the two sections
it lacked, taken from `wenshu-dev`'s copy verbatim.

| | before | after |
| --- | ------ | ----- |
| files | 3 divergent local copies | 1 shared source |
| bytes | 92218 / 31012 / 31012 | 95078 |
| md5 | `a0ffdcfdc4` / `85a83c93f3` / `85a83c93f3` | `083f6f1e3c` |
| numbered pitfalls | 67 / 30 / 30 | 67, identical for every reader |
| pitfall numbers | slid out of alignment between copies | one numbering |
| Chinese-report rule | only in `pocock`'s copy | in every reader's copy |

### The language split, written down

Pitfall 32 was rewritten from "report the final conclusion in the boss's
language" (= the closing summary only) to a rule that covers the whole
process, and the split is **by where the text lands, not by how important
it is**:

- **Chinese (= the process talking):** every chat reply; a card's `summary`
  and handoff text; a card's comments; a review verdict and its reasoning; a
  session's closing report; the boss-facing verdict.
- **English (= the repository talking):** the code; the code comments; the
  commit subject and body; the tracked `.md` documents; the card BODY; file
  paths; identifiers; command lines.

**The line between them is the commit.** Anything that lands in the
repository is English; anything that stays in the process is Chinese.

### Why the card BODY stays English (= a machine requirement)

This is not a style preference; the tools parse a card:

- `wave_gate.SECTION_RE` = `^(?:#{1,3}\s*)?([A-Z][A-Z0-9 /()\-]{2,45})\s*:?\s*$`
  — ALL-CAPS ENGLISH headers only. Measured: a Chinese-headered body
  (`## 一、顶栏`) parses to **ZERO** sections, so the collision gate reports
  a clean bill of health for every card on the board.
- `ticket_tier.review_contract_errors` reads the `## REVIEW HANDOFF`
  heading by name and the `reviewer="<profile>"` token by regex.

So the body is the contract, and it is English. The Chinese goes where no
tool parses. Both facts are now written into the skill
(`wenshu-parallel-dev` SKILL.md and the card-body template), so the next
session does not re-derive them.

### The dangling pointers

Moving the skills broke the paths AGENTS.md hardcoded, and §0 / §9 are the
load chain every wenshu turn walks. All of them were repointed at the
shared source. One of them was already broken before this session:
`wenshu-parallel-dev` pointed at `skills/wenshu-parallel-dev/SKILL.md` while
the real path was `skills/wenshu/wenshu-parallel-dev/SKILL.md`. Measured
after the change: **0 broken skill pointers** in AGENTS.md (was 5).

## The tests

- `Tools/wenshu-devtool/tests/test_ticket_tier.py` — all cases passed
- `Tools/wenshu-devtool/tests/test_review_gate.py` — every case passed
- `review_gate.py --check` against the live board — 147 cards, 12 under the
  review contract, 1 break it, 11 owe a verdict (the 1 break is a card
  currently IN review, whose assignee is already the reviewer)
- `locate_skill` for both skills under all three profiles — resolves to the
  shared path, `status=unique` (= no same-name shadowing)

## The commit

`0649caa076` — `docs(wenshu): the dev-process output is Chinese, the
committed artifacts stay English`. Three files: `.hermes.md` (item 3 now
names the split), `AGENTS.md` (§0 + §9 repointed), `OOB.md` (the directive,
one row, English because OOB.md is a tracked `.md`).

## OPEN ITEMS

1. **`devops/sdlc-review` still has three divergent LOCAL copies**
   (`pocock` `5cd15d3f3b`, `wenshu-dev` `fe8d3248e0`, `wenshu-review`
   `a72e3253cc`). This session converged the two WENSHU skills; the review
   skill is a bundled vendor skill and was left alone. It carries the same
   defect class, and `wenshu-review`'s copy is the one the review lane
   actually force-loads (`kanban_db_dispatch` adds `sdlc-review` to every
   review run). The review-specific lessons that `pocock`'s copy lacks
   ("compare against the merge-base, not the moving tip"; "a bare
   `git show main:<file>` copy is not a runnable baseline"; "a delegated
   child fence can masquerade as a tool defect") are exactly the ones the
   reviewer needs. **Owning lane: the next session that touches the review
   lane.** Note that `hermes skills reset <name>` exists for bundled skills,
   and `hermes skills list-modified` reports the drift.
2. **`.hermes/cjk_comment_audit.txt` does not exist.** AGENTS.md 1.1 and 7.5
   name it as the enforcement for "no CJK", and it was never committed
   (`git log` on the path is empty; only `.hermes/SPECS/` is tracked). The
   hook that actually runs is `Tools/wenshu-devtool/commit_filter.py`, and it
   blocks xianxia vocabulary only — with `老板 文枢 拍 拍板 ※` explicitly
   allowed. So 1.1's "no CJK" has never been tool-enforced. This does not
   change the language decision (the repository is still English by rule),
   but the rule cites a non-existent enforcer. **Owning lane: the boss, if a
   real CJK audit is wanted** (= it would raise the bar on every commit).
3. **11 cards owe a verdict and 1 breaks the review contract.** Pre-existing,
   not caused by this session. `review_gate.py --check` names them; the
   4 newest T3 cards (`t_1b4dd85c`, `t_04dda2f8`, `t_10d248f4`,
   `t_3f147de7`) were created under the review contract and carry a
   `## REVIEW HANDOFF` naming `wenshu-review`. **Owning lane: the review
   lane**, which is working (1 card in `review` right now).
4. **The role-orchestration work from the earlier part of this session is
   not finished.** `wench` was deleted (backed up) and the role map was
   measured, but the remaining wiring was not completed. **Owning lane: the
   next session**, and its own closure doc.

## The rollback

The three deleted local copies are backed up at
`~/.hermes/profiles/pocock/cache/scratch/skill-backup-wenshu-workflow/`
(`pocock-wenshu-pocock-workflow/`, `pocock-wenshu-parallel-dev/`,
`wenshu-dev-wenshu-pocock-workflow/`, `wenshu-review-wenshu-pocock-workflow/`).
To roll back: copy the profile's directory back into that profile's
`skills/` and remove the shared dir from its `skills.external_dirs`.

> First line fact: the dev-process output is Chinese; the committed
> artifacts are English; the split is by where the text lands.
> Last line fact: the workflow skill and the parallel-dev skill are ONE
> shared source at `~/.hermes/shared/wenshu-skills/`, and the curator cannot
> fork an external skill.
