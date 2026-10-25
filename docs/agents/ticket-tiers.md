# Ticket difficulty tiers

Every card carries a difficulty tier. The tier is derived from the work the
card describes, and it decides how much clock, how many attempts, and how wide
a gate the card gets.

**The tier changes the cost of a card. It never changes the quality bar.**

## The three tiers

| Tier | Means | Runtime cap | Retry budget | Body budget | Gate |
| ---- | ----- | ----------- | ------------ | ----------- | ---- |
| T1 | trivial | 15m | 2 | 4000 chars, 7 sections | `swift build` + ONE filtered suite that owns the touched file |
| T2 | standard | 25m | 3 | 8000 chars, 9 sections | `swift build` + a filtered suite per touched area; a baseline compare only where the baseline is red |
| T3 | deep | 45m | 5 | 32000 chars, 12 sections | the full gate set, incl. a red-baseline comparison and a visual proof |

Read the contract with the tool:

```bash
python3 Tools/wenshu-devtool/ticket_tier.py --plan
```

## How a card is rated

The tier is DERIVED, never hand-set. `Tools/wenshu-devtool/ticket_tier.py`
reads the card body and decides:

- **T3** if the card touches persistence (`@Model`, `ModelContainer`, a
  migration), a new subsystem, a package boundary, six or more source files,
  three or more areas of the tree, or inlines 3000+ characters of code.
- **T1** if the card touches at most one source file and two files overall,
  inlines under 800 characters of code, and names none of those surfaces.
- **T2** otherwise.

The tier is a BLAST-RADIUS rating, not a guess about how long a card takes.
It reads the files the card WRITES: a file it names only to forbid is not its
work, so a card that says "do not touch `Package.swift`" is not a
package-boundary card. The tool reports that distinction.

A live-app proof (a screenshot, an AX census) is NOT a deeper tier. It is
extra evidence to gather on a card of whatever tier, and the tool says so in
a note.

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
- It does not decide who reviews a card. The independent verdict (AGENTS.md
  rule 1.14) is owed by a card that writes CODE, and that is derived from the
  work the body describes, never from the tier. A T1 code card and a T3 code
  card owe the same verdict; a prose card owes none. The tier changes the
  cost of a card, never the quality bar.
- It does not skip a required gate. A T1 card still proves its change; it
  proves it with the cheapest command that covers the touched file.
- It does not mark a test as skipped. Rule 7.2 stands.
- It does not read the body's length as difficulty, and it does not read the
  gate the body asks for. Both would be circular: the tier changes the cap
  and the gate, so a tier derived from either would be self-referential.

The one section the tier does NOT charge against the body's budget is the
routing section (`## REVIEW HANDOFF`), because it names who reviews the card
rather than describing work: 46 of the board's bodies carry exactly 9
sections and T2 buys exactly 9, so charging the handoff section would push 8
T2 bodies over their own budget and make the tier wrong for cards that did
nothing wrong. The paths a routing section names are not files the card
writes either.

## Why this exists

Measured on board `wenshu-par` over the 43 done cards, 2026-10-22.

**The time went into repeated attempts, not into verification.**

- 35.7 h of worker time in 126 runs, and only 43 of those runs COMPLETED. 37
  timed out, 28 were reclaimed, 9 crashed, 7 blocked. The cards averaged 2.93
  runs each, and **83.5% of the time sits in a run that did NOT finish**. Of
  that, 57.6% sits in timed-out runs alone, at a median of 30.3 min each.
- The gates are not the cost. An incremental `swift build` is 0.73 s, the full
  suite is 66 s, `Tools/devtool/double-axis.sh` is 0.36 s. None of them
  explains 29.2 h.
- 22 of the 43 cards had at least one timeout. A card that times out is not
  slow, it is mis-sized: the cap did not match the work, so the worker spent
  the whole budget and the card was re-dispatched to spend it again.
- The worst card burned 11 runs and 153.7 m. It had a 45m cap, and it used it
  five times over.

**A BIGGER CAP MAKES IT WORSE, and that is the result that decides the
design.** Measured by the cap each card was actually given: the cards on a
45-minute cap burned 100.8 min per card over 4.80 runs; the cards on a
30-minute cap burned 43.8 min per card over 2.71 runs. A cap does not buy
fewer attempts, it buys more expensive ones. So the tier's cap is sized to
NOT KILL the work (= it sits above the longest run that finished in that
tier), and the tier takes its time out of the GATE and the BODY instead.

**What predicts the cost, as the correlation with minutes per card:**

| Signal | r |
| ------ | - |
| the number of body sections | +0.589 |
| the body length | +0.406 |
| a wide gate (the whole suite, or a baseline comparison) | +0.402 |
| a live-app proof | +0.175 |
| the number of files the card touches | +0.068 |
| the number of areas the card touches | +0.021 |

**The file count does NOT predict how long a card takes.** What it predicts is
whether a NARROW gate is SAFE. That is the tier's real job: it is a
blast-radius rating, and it decides how many suites have to prove the card.

**The body's SHAPE is the timeout loop.** Grouped by the number of sections
the body carries, inside one tier:

| Sections | Cards | Runs per card | Timeouts per card | Minutes per card |
| -------- | ----- | ------------- | ------------------ | ---------------- |
| < 9 | 8 | 2.12 | 0.25 | 25.3 |
| 9-11 | 20 | 3.05 | 1.10 | 59.5 |
| 11+ | 4 | 4.50 | 1.25 | 93.3 |

The same split holds across tiers, and it is not the tier talking: measured
as timeouts per card, a 9+ section body runs 1.21 against 0.20 for a shorter
one, while the number of files the card touches runs 0.96 against 0.75. A
body that also carries the rationale, the alternatives, the architecture and
the edge cases makes the worker re-derive all of it, and the run times out.

**Inside one tier the gate is the whole difference.** A card whose body demands
the whole suite against a red baseline ran 3.44 times for 65.7 min per card; a
card whose body named no suite ran 2.00 times for 17.6 min per card. Same
tier, same cap, same reviewer: the difference is the gate the body asked for.

**A body that names its gate narrowly is a card that lands.** The cards on the
board already written to the tier spec (a short body, one filtered suite)
averaged 1.8 m over 1.23 runs. And the fast lane is worth having: T1 and T2
cards cost 34.3 min per card today, T3 cards cost 55.2, and a body under 4000
characters costs 8.9 min per card with 0.2 timeouts.

## The numbers, and where they come from

**The caps** are fitted to the measured duration of a run that FINISHED, per
tier, so a card doing the work never loses to its own cap:

| Tier | Longest successful run measured | Cap | Headroom |
| ---- | ------------------------------ | --- | -------- |
| T1 | 10.5 m | 15m | 1.43x |
| T2 | 15.9 m | 25m | 1.57x |
| T3 | 39.2 m | 45m | 1.15x |

A cap that is too small does not save time, it moves the work to a human.
Replayed against every historical card, a 25m T3 cap blocked 7 cards that used
to land, and a 30m T3 cap blocked 2. So T3's cap stays above its measured
maximum.

**The retry budgets** are the board's `--max-retries`, which trips the breaker
when the CONSECUTIVE failure count reaches it (a success resets the count).
They are fitted to the longest failure streak the board has actually produced
per tier, plus margin: measured worst streaks were T1 1, T2 2, T3 3, so the
budgets are 2 / 3 / 5. Replayed, these budgets block ZERO cards that used to
succeed.

Note the breaker counts only `timed_out`, `crashed` and `spawn_failed`. A
`reclaimed` run does not consume the budget.

**The body budgets** are measured, not guessed. The body SHAPE is what
predicts the timeout loop: the cards whose bodies carry fewer than 9 sections
ran 2.12 times for 25.3 min per card with 0.25 timeouts, the 9-11 section
cards ran 3.05 times for 59.5 min with 1.10 timeouts, and the 11+ section
cards ran 4.50 times for 93.3 min with 1.25 timeouts. So the tier bounds the
body in both characters and sections, and the tool reports a body over either
budget.

A body over its tier's budget is a body that should be TWO cards, not a body
the worker should be given more clock.

## How to write a body that lands in the fast lane

The tier does not ask for less precision. It asks for the RECIPE instead of
the ANALYSIS. A precise body can be short:

```
GOAL            one line, business language
WHAT TO BUILD   the exact files, the exact edits
MUST NOT CHANGE the exact list
TESTS           the exact suite
GATES           the exact command
ACCEPTANCE      observable facts
```

Seven sections, under 4000 characters, and the worker writes in its first
minute. What costs the time is a body that also carries the rationale, the
alternatives, the architecture and the edge cases: the worker re-derives all
of it, and the run times out. Measured, a body under 4000 characters costs
8.9 min per card with 0.2 timeouts; a body of 9000+ costs 59.7 min per card
with 1.04.

## What the tier is worth

Be precise about this, because the honest number is smaller than the story
the tier tells.

Replayed against every historical card, the tier contract (cap + retry budget)
alone accounts for about 5% of the 35.7 h the board has spent, and blocks no
card that used to land. The cap is not where the money is; that is the
measured result.

The saving comes from the two things the tier DOES enforce on the body:

1. **The gate.** A card authored to its tier's spec carries a narrow gate, and
   the narrow-vs-wide gap inside one tier (17.6 m over 2.00 runs against
   65.7 m over 3.44 runs) is what the tier is for. The tool reports the gate
   width a card brought, so the parent agent can see the expensive shape
   before dispatching, and it rejects a T1 card that asks for the whole suite.
2. **The body's shape.** A body under 4000 characters costs 8.9 min per card
   with 0.2 timeouts; a body of 9000+ costs 59.7 min per card with 1.04. The
   tier bounds the body, so the fast lane is reachable rather than aspirational.

On this board the tier re-rates 11 of the 43 cards into the fast lane. The
cards already written to the tier spec (a short body, one filtered suite)
averaged 1.8 m over 1.23 runs.

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
