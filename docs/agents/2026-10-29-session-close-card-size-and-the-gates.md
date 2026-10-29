# Session close: the card is sized by what it writes, and the gates read it as it is

2026-10-29. A session that tuned the card flow rather than any one card.

## What the board session actually costs

A board worker rides the Anthropic-wire route to minimax-cn, and the worker
log records **zero `cache_read` tokens**: a board session has no prompt
cache, so every call re-sends the whole history. It also starts from the
card body alone, and Hermes has no cross-run resume, so a card that times
out restarts from zero and pays for its reading again.

Measured: one call's input grew from 26k at the first call to 380k at the
last inside a single session (= 15x), a dev run cost 167 calls and 35.5M
tokens, and the dev lane burns 68M tokens per worker-hour against the
review lane's 7.6M.

**So the cost of a card is its LENGTH, not its difficulty.** A card that
runs long is not a hard card, it is an expensive one.

## The three defects this found

**1. The tier rated the paths the body MENTIONED, not the ones it WRITES.**
The tier's file set came from every path in the body, so a card's CURRENT
STATE section (= what the tree looks like today) charged it for seven files
it never touched. Measured 2026-10-29: card `t_6876ec70` wrote TWO files
and was rated T3 only because its CURRENT STATE described six others, and
`t_dae9ab0d` wrote none and was rated T3 the same way.

**2. The section vocabulary was a guess.** The tier's write set came from a
list of heading names, and the list missed `TESTS`: measured over the 173
real cards, 43 of them carry their test files under a `TESTS` heading, so
those cards were rated by their source files alone and the proof that
comes with them was invisible. Only 20 headings appear in three or more
cards, so any heading list is a long tail that has to be re-guessed for
every new card. The fix is to take the headings from the contract: the
card template's skeleton (`wenshu-parallel-dev/templates/kanban-card-body.md`
= GOAL, WHY, BASE, WHAT TO BUILD, MUST NOT CHANGE, LOCALIZATION, TESTS,
EVIDENCE BUDGET, GATES, ACCEPTANCE, REVIEW HANDOFF), of which the writing
ones are WHAT TO BUILD, TESTS, LOCALIZATION and BASE.

**3. The gate-width gate read 37 of the 173 cards as demanding the whole
test suite, and almost none of them did.** A card wraps its prose at ~70
columns, so "The whole suite is NOT this card's" ended a line and "gate."
started the next, and a line-by-line read saw the phrase and never the
refusal. The body is now read as sentences, and a refusal is recognised as
a refusal.

## What landed

| where | what |
| ----- | ---- |
| `Tools/wenshu-devtool/ticket_tier.py` | the write set comes from the contract's headings, not a guess; an area is a DIRECTORY; a test file is a path with a `Tests/` SEGMENT, not one that starts with `Tests/` (= the packages nest their test target inside the package) |
| `Tools/wenshu-devtool/slice_gate.py` | the new pre-dispatch gate: a card writes a test file and names its suite, or writes source files and carries a test at all |
| `Tools/wenshu-devtool/gate_width_gate.py` | the body is read as sentences; a refusal and a prohibition are not demands |
| AGENTS.md 7.13, OOB.md | the host-slot rule and the two rulings of this session |
| the shared skill tree | the card template (rule 4), `card-body-authoring.md` (rule 9), `wenshu-pocock-workflow/SKILL.md`, and `references/rewrite-a-card-as-an-order.md` (now English) |

## The rule that decides the shape of a card

POCOCK's `to-tickets` says a ticket is a **tracer bullet**: a narrow but
COMPLETE path through every layer, demoable or verifiable on its own,
sized to fit in a single fresh context window.

Two of those three are decidable by a tool and one is not, and the split
matters:

- **verifiable on its own** = the card names the suite that owns each file
  it writes. That is decidable from the card's own words, so it is an
  ERROR.
- **narrow through every layer** = how many features the card spans. That
  needs the repository's own directory semantics (= which directory is a
  feature, which is the host layer, = written down in that repository's
  AGENTS.md), so it is a NOTE: a fact for the author to weigh, not a
  block.
- **fits in a fresh context window** = the body budget, which `ticket_tier`
  already prices.

**A gate that cries wolf is worse than no gate**: the author learns to
ignore it, and the one real finding goes unread too. So a finding that
needs a guess goes in the notes, and only a finding that holds in every
tree is an error.

And the unit is the **vertical slice**, not the file: measured, cards
writing 7+ files land 74% of the time and cards writing 1 file land 0%
(= a card that edits one file without its seam is not verifiable on its
own, and the worker has to rediscover the seam = the 61% of shell calls
that only LOOKED).

## Verification

Over the 173 real cards the new gate reports 95 clean, 61 with an error
and 17 with a note only, and **every one of the 70 "no named proof"
findings was checked against the card's own gates: zero false positives**.
The gate-width gate's false reports fell from 37 to 6, of which one is a
real wide-gate demand and five are cards whose evidence is Chinese past
tense (= the full suite was run and it was red), which is written down in
the tool rather than papered over with patterns.

22/22 devtool test scripts pass. `agents_gate` reports AGENTS.md loads at
19999 of 20000 characters.

## The two repositories

The desktop and the mobile product line share one set of gates, and every
file in each copy carries a deliberate localisation (= the board slug, the
repo root, the package paths, the source directories), so **a method
change is transplanted rule by rule and never copied over a whole file**.
The shared skill tree is one absolute path mounted by all three profiles,
so a rule change in the template or the workflow reaches both lines' workers
without a second edit.

## OPEN ITEMS

- The gate-width gate still reads a Chinese past-tense evidence sentence as
  a wide-gate demand (five cards). The template writes card bodies in
  English, so this limits the old cards rather than the flow.
- The mobile product line's `slice_gate.py` and the two `ticket_tier.py`
  rules land in the next round, together with the gate-width gate fix.
- `t_16407d91`'s branch (`project-2/t_16407d91-t3-the-surfaces-are-the-system-s-glass`)
  carries an unreviewed commit `fa478c0` (= the glass surface gate) and its
  card is gone from the board. Its work is sound (build green, 35/35 tests
  green, the gate's own six tests green) but it has no card and no verdict:
  it needs a decision, not a merge.
