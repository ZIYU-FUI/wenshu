# Ticket difficulty tiers

Every card carries a difficulty tier. The tier is derived from the work the
card describes, and it decides how much clock, how many attempts, and how wide
a gate the card gets.

**The tier changes the cost of a card. It never changes the quality bar.**

## The three tiers

| Tier | Means | Runtime cap | Retry budget | Body budget | Gate |
| ---- | ----- | ----------- | ------------ | ----------- | ---- |
| T1 | trivial | 15m | 2 | 4000 chars | `swift build` + ONE filtered suite that owns the touched file |
| T2 | standard | 25m | 3 | 10000 chars | `swift build` + a filtered suite per touched area; a baseline compare only where the baseline is red |
| T3 | deep | 45m | 4 | 32000 chars | the full gate set, incl. a red-baseline comparison and a visual proof |

Read the contract with the tool:

```bash
python3 Tools/wenshu-devtool/ticket_tier.py --plan
```

## How a card is rated

The tier is DERIVED, never hand-set. `Tools/wenshu-devtool/ticket_tier.py`
reads the card body and decides:

- **T3** if the card touches persistence (`@Model`, `ModelContainer`, a
  migration), a new subsystem, a package boundary, six or more source files,
  a runtime surface (AppKit, AX census, a screenshot, a launch), or a catalog
  rewrite.
- **T1** if the card touches at most one source file and two files overall,
  inlines under 800 characters of code, and names none of those surfaces.
- **T2** otherwise.

The title carries the rating, so `hermes kanban list` shows it at a glance:

```
[T1] Editor tab strip: hide the horizontal scroll indicator
```

Check a card body before dispatching it:

```bash
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md
python3 Tools/wenshu-devtool/ticket_tier.py --check          # every card
```

## What the tier does NOT do

- It does not skip the dual-axis review (AGENTS.md rule 1.10). Every tier gets
  the two-axis read.
- It does not skip a required gate. A T1 card still proves its change; it
  proves it with the cheapest command that covers the touched file.
- It does not mark a test as skipped. Rule 7.2 stands.
- It does not read the body's length as difficulty, and it does not read the
  gate the body asks for. Both would be circular: the tier changes the cap
  and the gate, so a tier derived from either would be self-referential.

## Why this exists

Measured on board `wenshu-par` over 41 done cards, 2026-10-22.

**The time went into repeated attempts, not into verification.**

- 34.4 h of worker time. 6.9 h (20%) sat in a run that finished. The other
  27.5 h (80%) sat in runs that timed out, were reclaimed, or crashed.
- The gates are cheap. An incremental `swift build` is 0.73 s, the full suite
  is 66 s, `Tools/devtool/double-axis.sh` is 0.36 s. None of them explains
  27.5 h.
- 46 runs hit the 30-minute cap and were killed. A card that times out is not
  slow, it is mis-sized: the cap did not match the work, so the worker spent
  the whole budget and the card was re-dispatched to spend it again.
- The worst card burned 11 runs and 153.7 m. It had a 45m cap, and it used it
  five times over.

**Two signals separate the work from the prose.**

- A body demanding a red-baseline comparison averaged 83.1 m over 4.00 runs
  against 52.4 m over 2.97 runs for a body that does not. This is measured
  WITHIN one tier, so it is not a proxy for the work size.
- A body naming a runtime surface is a card that cannot be proven by a build
  alone, and it belongs in T3 whatever its file count.

**A body that names its gate narrowly is a card that lands.** The cards on the
board already written to the tier spec (a short body, one filtered suite)
averaged 1.8 m over 1.23 runs.

**The card body length does not predict the time.** Buckets of 0-2000, 2000-4000,
4000-8000, 8000-14000 and 14000+ characters show no stable relationship, so
length is a budget, never a rating.

## The numbers, and where they come from

**The caps** are fitted to the measured duration of a run that FINISHED, per
tier, so a card doing the work never loses to its own cap:

| Tier | Longest successful run measured | Cap | Headroom |
| ---- | ------------------------------ | --- | -------- |
| T1 | 10.5 m | 15m | 1.43x |
| T2 | 16.0 m | 25m | 1.56x |
| T3 | 39.2 m | 45m | 1.15x |

A cap that is too small does not save time, it moves the work to a human.
Replayed against every historical card, a 25m T3 cap blocked 7 cards that used
to land, and a 30m T3 cap blocked 2. So T3's cap stays above its measured
maximum.

**The retry budgets** are the board's `--max-retries`, which trips the breaker
when the CONSECUTIVE failure count reaches it (a success resets the count).
They are fitted to the longest failure streak the board has actually produced
per tier, plus one: measured worst streaks were T1 1, T2 2, T3 3, so the
budgets are 2 / 3 / 4. Replayed, these budgets block ZERO cards that used to
succeed.

Note the breaker counts only `timed_out`, `crashed` and `spawn_failed`. A
`reclaimed` run does not consume the budget.

**The body budgets** are the measured body length per tier plus headroom.

## What the tier is worth

Replayed against every historical card, the tier contract (cap + retry budget)
alone accounts for about 6% of the 42.7 h the board has spent, and blocks no
real work.

The larger saving is the one the tier enables rather than enforces: a card
authored to its tier's spec carries a narrow gate, and a narrow gate is what
the 83.1 m-vs-52.4 m gap measures. The tool reports the gate width a card
brought, so the parent agent can see the expensive shape before dispatching.

## Dispatching a card

```bash
cd /Volumes/ANAN/Engineering/wenshu
hermes kanban create "[T2] <title>" \
  --assignee wenshu-dev --workspace worktree --project project \
  --body-file card.md \
  --model "MiniMax-M3.1-Flash" --provider minimax-cn \
  --max-runtime 25m --max-retries 3
```

The tier in the title, the cap and the retry budget all come from
`ticket_tier.py --body card.md`. The worker reads the tier from the card
title and sizes its verification to it.

## Files

- `Tools/wenshu-devtool/ticket_tier.py` — the classifier and the contract.
- `Tools/wenshu-devtool/tests/test_ticket_tier.py` — its test suite.
