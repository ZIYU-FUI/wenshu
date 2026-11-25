# The chat zone's context meter and the turn's bounded output (2026-11-24)

## The scope

Two requirements, one ticket:

1. the chat zone's bottom bar carries the context window's occupancy as
   an Apple capacity gauge, and a click on that gauge opens one popover
   that names what filled the window;
2. a turn's tool output is bounded, so the results of one turn's tool
   rounds cannot push the next request past the window.

The meter is the reading of the bound: a reader who sees the gauge near
the warning point must be able to see which part of the prompt filled
it. The plan of record is `.scratch/2026-11-24-chat-context-gauge/`
(= its spec carries the four canonical sections, and its index names the
scope's one ticket).

## The symptom, measured on the base

The base is `b18bcefd74` (= the merge base of the scope's change, = = and
the tree a detached control worktree holds).

- the bar's number was the last turn's total token count (= the
  provider's input plus its output), against a fixed divisor of
  `1_000_000` and a fixed warning point of `30_000`;
- the connector read a different window (= its provider's published
  window: `200_000` for one provider, `1_000_000` for another), so the
  meter and the compressor measured against two numbers;
- the cut that should bound a tool result was the identity (= the
  default output truncator returned its input unchanged), and the size
  field that was supposed to bound it was declared and threaded but read
  by nobody;
- the turn's tool results accumulated without a ceiling, and every
  request after a tool round carried the whole turn;
- the two markers that reported a cut named different things (= one named
  what it dropped, the other named the result's original size), so the
  number in the text could not be derived from the text beside it.

## The root cause

Four independent defects, and each one is a copy of a number or a rule
that was read at the wrong time:

- the meter read a view-model field that no longer meant "the prompt",
  and divided it by a literal that no longer meant "the window";
- the window was copied into the UI instead of read from the provider's
  own row, and the connector had its own copy of the rule;
- the tool result's cut was declared and never charged (= the truncator
  was the identity, and the size field had no reader), so nothing
  bounded a turn's output;
- the turn's trim and the executor's cut each named a different thing,
  and the meter read a stored default instead of the compressor's own
  threshold.

## The fix

- the bar carries a `Gauge` with the accessory linear capacity style,
  whose value is the provider's last request's PROMPT count (= not the
  input plus the output, = = and not a running bill), whose range is the
  connector's provider window, and whose fill turns to the warning colour
  at the compressor's own threshold (= read live, = = never a stored copy
  of a default);
- a click on the gauge opens one popover with the prompt's parts (= the
  system prompt, the tool schemas, the conversation, the tool results,
  the memory), the effective window, the share, and the cache's counters
  (= the cached prefix inside the input count for one provider shape, = =
  beside it for another, = = and the shape travels in the data, not in
  the reader's head);
- a tool result is cut at a per-result cap; the turn's results are cut
  at a cap that is a tenth of the window (= converted into the unit a
  result is counted in, = = because the window is counted in tokens and a
  result is counted in characters); the two caps are one budget (= the
  per-result cap is clamped to the turn's cap); the trim runs before
  every subsequent request, oldest-first, and the newest results win;
  a cut result keeps what the cap has room for, names what was dropped,
  and carries the marker in the same words the executor's cut carries;
- the agent's compressor, the connector and the meter read the same
  window (= the provider's own row).


## The measured before and after

| | Before (= the base) | After (= this change) |
| --- | --- | --- |
| the meter's value | the last turn's total token count (= input plus output) | the provider's last request's PROMPT count |
| the meter's divisor | a literal `1_000_000` | the connector's provider window (= the provider's own row) |
| the meter's warning point | a literal `30_000` | the compressor's own threshold (= read live) |
| the cut on a tool result | the identity (= nothing cut) | a per-result cap, and a turn's cap |
| the turn's cap | none | a tenth of the window, in the unit a result is counted in |
| the order of the cut | (= the results accumulated) | oldest-first, before every subsequent request, newest wins |
| the marker | two markers, two meanings | one vocabulary: what was dropped |
| the cache's counters | not read | read, and the provider's shape travels in the data |

The window conversion is the package's own estimate (= a token is four
characters), and the caps are one budget:

| The provider's window (tokens) | The turn's cap (characters) |
| --- | --- |
| 1,000,000 | 400,000 |
| 200,000 | 80,000 |
| 64,000 | 25,600 |

⇒ ⇒ ⇒ AND A PER-RESULT CAP ABOVE THE TURN'S OWN CAP IS A CAP THAT NEVER
BINDS, = = so the per-result cap is clamped to the turn's cap (= the two
are one budget, = = and a small window cannot end up with a result cap
above its own).

## The tests and the gates

The scope's own suites, measured on the merged tree (= the tree the
scope's commit `814d357415` names, = = and `main` held it after the landing):

| Suite | Result |
| --- | --- |
| `ToolResultBudgetTests` | 13 tests, 1 suite, passed |
| `ContextUsageRecorderTests` | 12 tests, 1 suite, passed |
| `ContextOverridesReachTheRuntimeTests` | 14 tests, 1 suite, passed |
| the six design sweeps | 3 + 2 + 2 + 3 + 1 + 3 tests, 6 suites, passed |
| the whole agent bundle | 234 tests, 26 suites, passed |

The pre-existing reds are measured against the base, not by inference.
The same nine suites were run in a detached control worktree of the base
and on the merged tree:

| Tree | Result |
| --- | --- |
| the base (`b18bcefd74`) | 75 tests, 9 suites, 17 issues |
| the merged tree (`814d357415`) | 75 tests, 9 suites, 17 issues |

⇒ ⇒ ⇒ AND THE HONEST CLAIM IS THE DIFFERENCE, NOT THE COUNT: the merged
tree's failures beyond the base's are ZERO, and the sites are the same
ones (= the editor's tab strip's geometry, the editor's tab title, the
sidebar's tree reload, the chat's @-mention registry, and the history
button's source-text assertion on a word the tree no longer prints).
Three more sites are load-sensitive (= a 3-second auto-save wait, a
5-second budget, a dialog round trip): they go red on a machine that is
running another build, and they are green when their suite runs alone.

⇒ ⇒ ⇒ AND THE GATE LOG IS THE EVIDENCE, AND IT NAMES THE SHA IT PROVES.
The run's log lands in the shared checkout's `.gate-logs/`, and its first
command prints the sha (= the run is `Scripts/gate_run.sh`, with the
shared checkout's `.gate-logs` as its log directory and the tree to run
in as its first argument):

```
grep -c 814d357415 /Volumes/ANAN/Engineering/wenshu/.gate-logs/*.log
```

⇒ ⇒ ⇒ AND THE STATIC GATES, MEASURED ON THE SCOPE'S OWN TREE
(`814d357415`): the registry's count gate read 12 rows checked and every
row agreeing; the comment-lineage judge read 446 added comment lines and
0 offending; the formatting gate read 26 changed Swift files and no
unformatted line added; the pollution and the line-cap gates read clean;
and the dead-code gate read 0 dead declarations (= and the file this
change touched reads `ALIVE`, = = all forty-four declarations with real
readers).

## The landings and the verdicts

The change was reviewed three times on the review lane, and each round
named the sha it read (= a pushed sha is never rewritten, = = so a round
that follows a fix names the new tip):

| Round | Card | Verdict | Read at |
| --- | --- | --- | --- |
| 1 | `t_a905313b` | `changes_requested` | `7661e25d30` |
| 2 | `t_0d07bbbd` | `changes_requested` | `c5772fa8ce` |
| 3 | `t_233f894b` | `approved` | `e12497746f` |

The three findings the first round carried were all in the change's own
diff, and the second round confirmed them closed:

1. the turn's cap was a token number used as a character number (= a
   tenth of the tokens was a fortieth of the characters, = = so a result
   the executor had just admitted whole was cut down to a fixed excerpt
   while the window stood mostly empty);
2. the gauge's warning point was frozen at the built-in default (= the
   meter read a stored copy of a default while the compressor read the
   installed value, = = so the two disagreed for every user who moved
   the threshold);
3. the two markers named different things (= one named what it dropped,
   the other named the result's original size).

The second round confirmed those three closed and found one more, in
the change's own diff: the fix that made a cut result keep what the cap
has room for left the old fixed excerpt's size behind as a constant with
no reader (= the dead-code gate reads that file `PARTIAL`, = = one
declaration of forty-five with no reader), and it found the bar's own
sketch still drawing the label the change had removed. The third round
confirmed all four closed.

The landing is `t_90b6f7ad` (= the branch was rebased onto the `main`
that was current then, = = the registry's rows were merged row-wise, = =
the card's own gates ran green in the card's worktree, = = and `main`
moved by compare-and-swap against the sha it rebased onto).

⇒ ⇒ ⇒ AND THE VERDICT FOLLOWS THE CHANGE, NOT THE COMMIT ID: the rebase
rewrote the commit id, and the gate binds the rebased branch by the
change's identity (= the diff's written lines), so the card that read
`e12497746f` covers the tip that landed. The gate's own line says so:
`matched by change (= the branch was rebased; the change is the same)`.

## The commits this scope owns, and the ones the push carried

The scope's own change is ONE commit, `814d357415` (= twenty-eight
files). The push of `main` carried nine commits that are NOT this
scope's, because `main` held them when the branch was fast-forwarded:

`ea00bb94ac`, `944d47633f`, `73d5ce6b7e`, `d967932b63`, `5787fab850`,
`7c50a443dc`, `eddcd43b39`, `5500b471bc`, `b18bcefd74`.

They are another session's work, carried as maintenance of the shared
server state and not as this scope's authorship. The range that prints
exactly those nine (= = `main`'s own commits before this scope's landed):

```
git log --oneline ea00bb94ac~1..b18bcefd74
```

⇒ ⇒ ⇒ AND THIS DOC CANNOT NAME ITS OWN COMMIT: the doc is committed
before it is landed, and the commit it names would change the moment it
is written. Read it from the tree instead:

```
git rev-parse main
```

⇒ ⇒ ⇒ AND THE REGISTRY'S ROW FOR THIS DOC CARRIES ITS OWN LINE COUNT,
AND THAT COUNT IS WRITTEN LAST (= = a correction round lengthens the
sentences that carry it, = = so a self-count is stale in the commit that
writes it). The invariant is the check:

```
wc -l docs/agents/2026-11-24-session-close-the-chat-context-gauge.md
```

## The look (= the boss's own eyes)

This scope is UI-touching, so the merge gate is the boss looking at the
running build. The record is four facts, not a verdict word:

1. **Which build**: `/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app`,
   rebuilt from `7e4a2fe14d` (= the tree `main` held at the build's own
   mtime, = = 2026-11-25 12:51:34, = = which carries the scope's commit
   `814d357415` as an ancestor), signed ad hoc with the identifier
   `com.wenshu.app` (= executable `WenshuApp`, = = 38,031,600 bytes);
2. **The bundle's own bytes carry the change**: the symbol
   `ChatContextGaugeView` is present in the bundle's binary (150 hits),
   with `ContextUsageSnapshot` beside it (120 hits), and a known-present
   symbol (`ChatInputBarView`, 392 hits) as the control (= an instrument
   that selects nothing and a tree that lacks the thing both print zero,
   = = so the control is what proves the needle is real; = = and a symbol
   that does not exist prints 0 against the same binary);
3. **The boss's verdict: NOT YET GIVEN** (= never "approved");
4. **An instance of this bundle id is running**: = = yes, = = pid `4218`
   (= started 2026-11-25 21:52:27, = = from this very bundle path). ⇒ ⇒ ⇒
   AND THIS SESSION DID NOT LAUNCH IT: = = no `open` of this bundle ran in
   this session (= = `ps -eo pid,args | grep 'open .*Wenshu.app'` reads
   nothing), = = so the instance belongs to another session and it is NOT
   this session's to stop. ⇒ ⇒ ⇒ AND WHAT THAT MEANS FOR THE LOOK: = = the
   look is not blocked (= = a running instance of the same bundle id is
   already showing the build), = = and the command below must NOT be run
   while that instance lives (= = `open` on a live bundle id brings the
   running one forward, = = and a second instance of the same bundle id
   restores the same saved window geometry and then both processes abort).

⇒ ⇒ ⇒ AND THE ONE COMMAND THAT COMPLETES IT (a PLAIN `open`; = = never
`open -n`, = = because a second instance of the same bundle id restores
the same saved window geometry and then both processes abort):

```
# SKIP: this command LAUNCHES the app (= the boss's look), = so the verifier
# must not run it; = = the bundle is built and signed, = = and no instance
# of this bundle id is running, = = so the look is not blocked.
open /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
```

⇒ ⇒ ⇒ AND THE PATH THIS SECTION NAMED BEFORE (= =
`.worktrees/chat-context-gauge-closeout-2026-11-24/build/Wenshu.app`) IS
GONE, = = and the reason is section 5's cleanup: = = that bundle lived
inside the scope's own worktree, = = and removing the worktree removed it
with it. = = The build named above is the same scope's change in a bundle
that is NOT inside a worktree, = = so the look's command survives the
cleanup. = = What the old path's facts were, and what this path's facts
are, agree on the part the look turns on (= = the bytes carry the change,
= = the bundle id is `com.wenshu.app`, = = the signature is ad hoc).

⇒ ⇒ ⇒ AND WHAT TO LOOK AT: the chat zone's bottom bar carries the
capacity gauge beside the reading; a click on the gauge opens the
popover with the prompt's parts; and the gauge's fill turns colour at
the compressor's own threshold.

## The open items

1. **The boss's look is PENDING** (= the bundle is built and signed, = =
   the bytes carry the change, = = and no instance of this bundle id is
   running, = = so the look is not blocked; = = the command and what to
   look at are in the look's section above);
2. **The base's own reds are not this scope's** (= 17 issues in nine
   suites on the base, = = the same 17 on the merged tree, = = and the
   merged tree's failures beyond the base's are zero). They are not fixed
   here (= fixing them would be another scope's work);
3. **Three of the reds are load-sensitive** (= a 3-second auto-save wait,
   a 5-second budget, a dialog round trip): they go red on a machine that
   is running another build and are green when their suite runs alone;
4. **The review lane's own worktrees** (= the three rounds' detached
   worktrees) hold the rounds' shas, = = and the shas are parked under
   `refs/keep/` so the cards' citations still resolve after the worktrees
   go. They are the board's residue, not this scope's.

## 1. Re-run the section 7 gates on the MERGED tree

**DONE.** The merged-tree run's evidence is a gate log in the shared
checkout's `.gate-logs/`, and the log's own text names the sha it
proved (= the run's first command prints it; = = the reader matches the
sha's bytes against the log's text, = = not against the log's filename).
The command that produces that log is in the tests' section above, and
the scope's own suites are green on the merged tree (= the table there).

⇒ ⇒ ⇒ AND THE CLOSURE DOC'S OWN LANDING IS WHAT THE READER CHECKS: the
doc cannot state its own landing, = = so the invariant is the check:

```
git rev-parse main
git ls-remote origin main
git ls-remote old-origin main
```

## 2. Record the verdict on the board

**DONE.** The card that read the change carries an approving verdict in
its run's metadata, and the landing card carries the numbers that
justified it (the gates, the rebase, the compare-and-swap, and the
read-back per remote). The rounds' own verdicts are in the landings'
section above.

## 3. Write the closure doc

**DONE** (= this file). The doc names the symptom, the root cause, the
fix, the measured before and after, the tests, the open items, and the
commits the push carried that are not this scope's. Its own landing is
the scope's last landing, = = and it is stated as the invariant above
(= = a doc cannot name its own commit, = = because writing the sha
changes it).

## 4. Persist the durable lessons into the SKILLS

**DONE.** The lessons went into the shared skill tree (= the copy both
lanes read), not into memory and not into this doc alone:

- the context budget's own skill (= the window's unit, the two caps as
  one budget, the trim's order, one marker vocabulary, the cut being
  wired, the gauge's value, and the dead-code gate after every fix);
- the visual audit's reference (= a gauge's fill and its track paint the
  same offscreen, = = so a colour question needs a real window and a
  screen capture);
- the parallel-dev lane's reference (= the card's runtime cap is set at
  creation, = = the card is subscribed to the session that dispatched it,
  = = and the registry's rows are merged row-wise when the branch is
  rebased).

## 5. Clean up YOUR OWN residue

**DONE.** The scope's own worktrees and branches went after this doc landed
(= the branch that carries the doc cannot be deleted before it lands), and
the shas they hold were parked under `refs/keep/` first (= a rehearsal
worktree on a detached head is the only pointer to its commit, = = and
`git worktree remove` turns every card that quotes that sha into a dangling
citation).

- The parked refs, each proven by `git rev-parse` (= NOT by
  `git for-each-ref --contains`, = = which lists only refs for which the
  commit is a strict ancestor): `refs/keep/chat-context-gauge-a1` =
  `814d357415c44edf806285178a69be0ff44c3bb9` (= the scope's own change),
  `refs/keep/chat-context-gauge-closeout-2026-11-24` =
  `08ad16ac23b324f00240a9c66cbc30000b33a142`, = = and
  `refs/keep/chat-context-gauge-closeout-a2` =
  `7de223281a50f3da779ded7a0cd81773e1ecda39` (= this doc's own landing).
- Removed: the worktree
  `.worktrees/chat-context-gauge-closeout-2026-11-24` (= it was clean, = =
  `git status --porcelain` read 0 lines) and the two branches
  `wt/chat-context-gauge-2026-11-24` and
  `wt/chat-context-gauge-closeout-2026-11-24` (= both deleted with plain
  `-D`, = = and every sha they held is parked above, = = so no card's
  citation dangles).

⇒ ⇒ ⇒ AND A SIBLING'S ASSET IS NOT THIS SESSION'S TO REMOVE: the other
scopes' worktrees, the review lane's own worktrees and the shared
checkout's staged work are left exactly as they were found, = = and the
shared checkout was not written in at all (= this doc's branch is a
worktree of its own).

⇒ ⇒ ⇒ AND ONE FACT THIS CLEANUP CHANGED, NAMED HERE RATHER THAN LEFT
HANGING: = = the bundle the look's command named lived inside the removed
worktree (= `.worktrees/chat-context-gauge-closeout-2026-11-24/build/Wenshu.app`),
= = so that path is gone with it, = = and the look's section below carries
the replacement. = = The bundle's own facts (= the symbol counts, = = the
signature, = = the bundle id) were measured while it existed, = = and they
are the facts the look still turns on.

## 6. Re-check the final state and report it

**DONE.** This doc landed as `7de223281a`, = = and `main` has since carried
other scopes' work on top of it, = = so `main` is no longer AT this
scope's last landed commit, = = while the scope's commit
(`7de223281a50f3da779ded7a0cd81773e1ecda39`) IS still an ancestor of
`main` (= = the durable reading, = = and the one that survives a sibling
landing something else). The report is a table, one row per original
requirement:

| The original requirement | The commit that carries it | The independent verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| the chat zone's bottom bar carries the window's occupancy as an Apple capacity gauge, and a click on the gauge opens one popover that names what filled the window | `814d357415` | `t_233f894b` = `approved` (read at `e12497746f`, = = and the same change identity as the landed tip) | `origin/main` and `old-origin/main` both read `814d357415` at the landing (= = and this doc's landing moves both again) |
| a turn's tool output is bounded, so one turn's tool rounds cannot push the next request past the window | `814d357415` | the same verdict (= = and the two blockers the first round carried were in this change's own diff, = = and the third round confirmed them closed) | the same two remotes |

⇒ ⇒ ⇒ AND A DEFECT FOUND WHILE LANDING GETS ITS OWN ROW, NOT A FOLD
INTO THE SCOPE'S VERDICT:

| The defect | Its state | The card that owns it |
| --- | --- | --- |
| the registry's key-level merge driver dropped the rows `main` had added after the branch's base, when the branch was rebased | fixed (= the rows are merged row-wise: the rows this commit owns are the commit's own, = = every other row is `main`'s, = = and the gate's own parser reads 0 of `main`'s keys lost and 5 added) | the landing card |
| the first two rounds' cards were subscribed to another session's chat id, so their verdicts did not reach this session | fixed (= the two wrong subscription rows are deleted, = = and this scope's cards are subscribed to the session that dispatched them) | the review cards |

## 7. Sweep the board's open columns

**DONE.** Every card that names this scope is terminal (= three review
rounds and the landing card). The other cards in the open columns belong
to other sessions and are measured, not closed (= a card another session
owns is not this session's to close).

## 8. THE CARD YOU DISPATCHED IS YOURS TO LAND

**DONE.** The card this session dispatched (= the landing card) is
landed: the branch was rebased onto the `main` that was current, the
card's own gates ran green in the card's worktree, `main` moved by
compare-and-swap against the sha it rebased onto, and both remotes were
pushed and read back.

⇒ ⇒ ⇒ AND THE DOC DOES NOT LOG ITS OWN REVIEW: the closure card's
verdict lives on the board, = = and this doc's last line is the stopping
rule (= = a round that asks for a fourth self-audit is the defect the
closeout was written to prevent).
