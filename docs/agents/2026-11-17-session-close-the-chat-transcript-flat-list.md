# Session closeout: the chat transcript stops holding the user's own row at the top

## 1. The scope

The boss named three lines: **排查** (= diagnose) the user's own message
staying pinned at the top of the chat column, **取消用户发消息置顶的机制**
(= cancel the mechanism that pins it), and **删除相关代码** (= delete the
code that carries it). A fourth topic (= the material bar) came in the same
message and was **cancelled by the boss before it was investigated**: it was
sent to the wrong session, and no source was read for it.

**What the diagnosis found.** The user's own message was the SECTION
HEADER of a turn, and the turn stack was built with
`LazyVStack(alignment: .leading, spacing: .standard, pinnedViews:
[.sectionHeaders])`, so SwiftUI held that header at the viewport's top edge
while the conversation scrolled under it. A second trigger
(`.onChange(of: vm.messages.last(where: { $0.source == .user })?.id)`)
scrolled the newest user row to `anchor: .top` on its own. The row the user
had just written therefore stayed nailed to the top of the column, cut off
by the panel's own title area, while the reply that was arriving slid away
below it.

**⇒ ⇒ ⇒ AND THE SCOPE'S OWN COMMIT IS ONE, = = BECAUSE THE THREE LINES
ARE ONE EDIT** (= = the pin, the grouping that carried it, and the code
that removed them are the same hunk):

| # | The commit |
| --- | --- |
| 1 | `9ada19911` (= the transcript is one flat list of messages, = = the pin and its grouping type are gone; = = the tip on `origin` carries this and the round-2 and round-3 commits on top) |
| 2 | `9ebe8c30a` (= the guards now measure the production path, = = after round 1 found that the control did not control and the identity claims measured a copy) |

## 2. The trace table (= one row per line the boss gave)

| # | The requirement | The commit that carries it | The independent verdict | The proof |
| --- | --- | --- | --- | --- |
| 1 | 排查 (= diagnose): the user's own message stays pinned at the top of the chat column | `9ada19911` | `t_343b2d1f` (= CHANGES REQUESTED, round 1) and the round-2 card | the RED: the same suite, run against the tree at `84c3a6386` (= this scope's base), FAILS with `Expectation failed: heldRows.isEmpty` (= = the user's card was painted in the viewport's TOP band) |
| 2 | 取消用户发消息置顶的机制 (= cancel the pinning mechanism) | `9ada19911` | `t_343b2d1f` (= CHANGES REQUESTED, round 1) and the round-2 card | `ChatView.swift`'s transcript is a `LazyVStack` with NO `pinnedViews:` argument, and the `onChange` that scrolled the newest user row to `anchor: .top` is gone (= = the two holds, both read off the file). The GREEN: the same suite PASSES against `9ada19911` |
| 3 | 删除相关代码 (= delete the related code) | `9ada19911` | `t_343b2d1f` (= CHANGES REQUESTED, round 1) and the round-2 card | `ChatTurn.swift` (= the grouping type that existed to carry the pin) and `ChatPinnedHeaderBandTests.swift` (= the suite that measured the band it left) are DELETED, and `isLatestUser` (= the per-turn backward scan of `vm.messages`) has no reader left in the tree (= = measured: a repo-wide grep for all three names returns only the documentation rows that RECORD the removal) |

## 3. What was NOT measured, and the claim that does not rest on it

**The boss's own look at the running app is a verdict this doc records, and
it is PENDING.** The proof here is a PIXEL measurement of the real
`ChatView` hosted in a window over a background the app never paints (= = a
hosted view, = = not the app's own window), and that is not the same thing
as the app the boss looks at.

**What the pixel measurement does NOT cover.** It reads the transcript's
viewport in isolation (= = the hosted `ChatView`, = = no library, = = no
session, = = no live reply), and it reads the card's own colour to name it.
It does not read the app's title area, and it does not read the composer.
So the claim "the row that was cut off by the panel's title area is now
fully drawn" rests on the transcript's own geometry, not on a capture of
the panel's title area.

**The whole-suite claim rests on the SAME failing set on the base tree, = =
not on a green run alone.** One run of the whole suite on THIS tree
(= `37a645b9d`) failed SIX sites: `ChatViewHistoryShortcutTests.swift:35`,
= = `EditorTabTitleTests.swift:60`, = =
`AsyncDelegationRegistryTests.swift:104`, = =
`WenshuConductorToolRegistryWiringTests.swift:237`, = =
`HermesTodoStoreConcurrencyTests.swift:268` and = =
`EditorPersistenceTests.swift:253`. ⇒ ⇒ ⇒ AND A WHOLE-SUITE RUN'S FAILING
SET IS LOAD-DEPENDENT (= = the run above ran on a machine that was not
quiet, = = so the three LOAD-SENSITIVE sites appear in it), = = and the
house has already measured those three: = = the wiring test has a
10-SECOND warm-up deadline (= = a loaded machine reads an empty dict), = =
the todo-store test asserts `judged.elapsed < 5.0`, = = and the editor test
waits 3 s. ⇒ ⇒ ⇒ SO THE COMPARISON IS THE HOUSE'S OWN: = = the six
candidate sites, run ALONE, on BOTH trees, = = read out of the log's own
file:line. **Measured, = = and the two runs are IDENTICAL** (= = three
failures each, = = the same three sites):

| the site | this tree (`37a645b9d`) | the base tree (`84c3a6386`) |
|---|---|---|
| `ChatViewHistoryShortcutTests.swift:35` | **FAIL** (= = the assertion that the history's metadata block names the token count) | **FAIL** (= = the same assertion, the same line) |
| `EditorTabTitleTests.swift:60` | **FAIL** (= = the assertion that a real document's name wins over the tab's title) | **FAIL** (= = the same assertion, the same line) |
| `AsyncDelegationRegistryTests.swift:104` | **FAIL** (= = "Expectation failed: mentionsReported") | **FAIL** (= = the same assertion, the same line) |
| `WenshuConductorToolRegistryWiringTests.swift:237` | PASS | PASS |
| `HermesTodoStoreConcurrencyTests.swift:268` | PASS (= = 0.100 s) | PASS (= = 0.064 s) |
| `EditorPersistenceTests.swift:253` | PASS | PASS |

= = 26 tests in 4 suites on each tree, = = ONE failure each, = = the same
one. ⇒ ⇒ ⇒ AND THAT SITE IS NOT THIS SCOPE'S: = = it builds a
`ChatViewModel` and calls `routeInput()` (= = the model's mention path, = =
not the transcript's row structure), = = and it fails the same way with the
chat transcript's OWN code reverted. = = The deterministic core of the
suite is therefore the same set on both trees (= = the house's own §7.2
contract, = = `docs/agents/2026-11-14-session-close-the-performance-audit.md`).

**The HIG sentence is about SCROLLING, not about pinning.** The quoted
sentence rules out an automatic jump the user did not ask for (= = the
newest-user-row trigger). It does NOT say anything about a held row, and
the corpus carries no article that does (= = "pinned" and "sticky" = = 0
occurrences across all 173 English articles). So the shape this scope
lands = the app's own decision, and the numbers that go with it (= = the
row rhythm) are the app's own = measured.

**The row rhythm's measurement is a layout probe, not a capture.** The
probe put the rows at the same y positions in both arrangements (= = 8, 44,
72, 108, 144, 172), which says the flattening moves no pixels. It is a
probe over the real stack, not a screenshot of the running app.

## 4. The §7 gates, RE-RUN ON THIS TREE

| Gate | Result |
|---|---|
| `swift build --build-tests` | exit 0 |
| the focused suites (`ChatTranscriptFlatFlowTests`, `ChatUserBubbleReadabilityTests`, `ChatUserBubbleShapeTests`, `ChatSurfaceGeometryTests`, `ChatTranscriptScrollTests`, `RenderPathPerformanceTests`, `StreamingUpdateTests`) | 39 tests in 7 suites, PASS |
| the whole suite (`swift test`, = = every target) | RED WITH A PRE-EXISTING BASELINE (= = this tree's run reds at SIX sites; = = the DETERMINISTIC ones among them (= = the three that fail on BOTH trees when run ALONE) are `ChatViewHistoryShortcutTests.swift:35`, = = `EditorTabTitleTests.swift:60` and = = `AsyncDelegationRegistryTests.swift:104`; = = the other three are LOAD-SENSITIVE; = = none of the six is this scope's; = = see §3) |
| `ci_change_gate.py --check formatting` | "the change adds no unformatted line (4 changed Swift file(s) checked)", exit 0 |
| `ci_change_gate.py --check pollution` | "the change adds no forbidden vocabulary", exit 0 |
| `nfi-loc-check.py --base 84c3a6386` | "every rewritten file's row carries its own count (1 row(s) checked)", exit 0 |
| `nfi-split.py --check` | PASS |
| `design-sweep.sh` (= the four files this change writes) | "design sweep clean" |
| `verify-dead.py` (= the two files this change writes) | 2 files, 2 ALIVE, 0 PARTIAL, 0 DEAD |

## 4a. The review round (= what round 1 found, and what this scope did about it)

**Round 1's verdict** (`t_343b2d1f`, on `095cf85be`): **CHANGES
REQUESTED**. The production change was confirmed correct (= the hold is
really gone, the bottom anchor and the scroll-to-bottom trigger are
intact, `ChatTurn` / `isLatestUser` / the deleted suite are fully
removed, the registry rows are honest, every gate is green at the tip).
**But the two suites that were supposed to HOLD it did not**, and both
defects were reproduced by mutating the tree, not by reading it.

**F1 (= BLOCKING): the control case did not control.** The flat-flow
suite's control scanned the whole bitmap for the card's colour. The
composer's own bar wears that colour on the LEADING side (= 295 pixels,
measured, and present with an EMPTY conversation), so the control was
satisfied by the chrome. Worse, in that fixture the user's bubble was
**not on screen at all** (the user's message was first, and the
transcript rests at the bottom, so the row had scrolled away): the
suite's own probe measured 0 card pixels in the trailing region. ⇒ ⇒ ⇒
**AND THE MEASURED GEOMETRY THAT SETTLES IT** (the probe's own numbers,
= = the same probe on both trees):

| the measurement | this tree | the base tree (`84c3a6386`) |
|---|---|---|
| the user's message FIRST, at rest | trailing card pixels = **0** (= the row has scrolled away) | trailing card pixels = **28605**, at bitmap rows **16–87** (= the viewport's TOP band = = the pin, caught) |
| the user's message LAST, at rest | trailing card pixels = 28605, at rows 744–815 | the same |
| an EMPTY conversation | leading = **295** (= the composer's chrome), trailing = **0** | the same |

⇒ ⇒ ⇒ SO THE FIXED INSTRUMENT READS THE **TRAILING** REGION (= the
composer's chrome never reaches there), and the control is POSITIONAL
(= the user's card must paint the trailing region of the transcript's
visible rows, = = a transcript that never rendered the user's row paints
nothing there and cannot pass). The two fixtures are separate on
purpose: the claim needs the conversation scrolled PAST the user's row,
and the control needs that row ON SCREEN.

**F2 (= BLOCKING): the identity claims measured a copy.** The rewritten
identity assertions called a test-local helper (`rows(from:)`) that
returned its input unchanged, so the assertions compared an array with
itself and `ChatMessage.id` with `ChatMessage.id`. The production rule
lived only in the production file, and the test measured a copy of it.
⇒ ⇒ ⇒ **⇒ ⇒ AND MEASURED: THE APPKIT VIEW TREE IS NOT A VALID PROXY**
(= = the first fix I tried = = counting the row views' object
identities across a body pass = = was measured to be **blind** to the
mutation on the production tree): the row views are torn down and
rebuilt by SwiftUI before AppKit sees them, so the count of surviving
`NSView`s does not move.

⇒ ⇒ ⇒ **SO THE FIXED ASSERTION MEASURES THE PRODUCTION PATH TWICE
OVER**:
(1) the WIRING is read from the production source through the house's
`SourceLocator` (= the repo-root reader, = = the view's whole group),
so a broken production identity breaks the test; and
(2) the BEHAVIOUR that rule produces is measured on the REAL hosted
`ChatView`: the row views' object identities across a body pass (= the
model's newest message changes, = = the streaming reply's own path).
**Measured: with the rule in place every row view survives and none is
replaced (= 13 kept, 0 new); with the identity broken (= a fresh id per
render) TEN new row views appear.**

**⇒ ⇒ ⇒ AND THE THREE VERIFICATIONS, ON THE FIXED SUITES** (= = the
reviewer's own two mutations, plus the base tree):

| the tree | the result |
|---|---|
| this tree | **GREEN** (= = 14 tests in 2 suites) |
| the base tree `84c3a6386` (= = the old pinned code) | **RED** (= = 4 assertions, = = including `Expectation failed: heldRows.isEmpty`) |
| the user's row NEVER rendered (= = the reviewer's mutation) | **RED** (= = 3 assertions) |
| every row given a FRESH identity per render (= = the reviewer's mutation) | **RED** (= = 3 assertions, = = including the behavioural `replaced == 0`) |

### Round 2's verdict (`t_edc19eec`, on `fb084e0ee`): CHANGES REQUESTED

**Round 1's two findings are CLOSED**, and the reviewer confirmed it
first-hand (= = the base tree and BOTH mutations re-run on the
production tree, = = the geometry re-derived by its own probe, = = the
two suites run three consecutive times without flaking).

**But the commit failed a gate its own closeout listed as green, and one
published number did not re-derive.** Both are this scope's own
bookkeeping, = = not the production change:

- **F3**: the formatting gate was RED at the tip (= = a stray blank line
  at the end of the flat-flow suite, = = which the round-2 test commit
  introduced), and §4's table still carried the ROUND-1 tree's results
  (= = its formatting row and its suite count). ⇒ ⇒ ⇒ So §4 is now
  RE-RUN on this tree, and the blank line is gone.
- **F4**: §4a published "eleven new row views"; the measured number is
  **ten** (= = the mutation's own failure message says `replaced → 10`,
  = = and the reviewer's probe counted the same). ⇒ ⇒ ⇒ The number in
  §4a now reads TEN.

## 5. The registry's rows, and the merge they had to survive

**The registry is APPEND-ONLY, and its merge driver merges at the KEY
level.** The driver was MEASURED, not assumed, on this scope's own rows:

- a row DELETED on one side and UNCHANGED on the other = **the deleting
  side's deletion is REVERTED** (= = the surviving side's row wins);
- a row CHANGED on one side and unchanged on the other = the changed row
  wins.

So a row cannot be deleted here. The house's own convention for a file
that goes away is therefore what this scope did: **the row stays and its
text says the file is deleted** (= = the same shape the 2026-10-30 window
cleanup used for its seven deleted store classes, = = "(deleted pattern
source)"). Two rows carry that mark (= `ChatTurn.swift` and
`ChatPinnedHeaderBandTests.swift`), and `nfi-split --check` PINS the
`ChatTurn.swift` key (= = it is one of the 30 keys the split check
verifies) = = so deleting it would have failed the gate as well.

**And the six edits SURVIVED the landing rebase.** Measured on a scratch
clone: the branch rebased onto `main` (= 41b82a8fa) with the key-level
driver, and all six edits came through (= = the two deleted-file rows, the
two parent counts, the render-path row's count, and the new row), with
`main`'s own rows intact (= 414 rows after the rebase = 413 on main + 1
added).

## 6. The server-side proof, = = and what the push carried

| What | Where |
|---|---|
| the branch | `wt/chat-unpinned-user-row-2026-11-17` on `origin` (= pushed, = = the branch is on the remote, = = so the work is not only in this worktree) |
| the commit | `9ada199113366e3e34d1c658ea320a5171d3cae2` |
| the worktree the reviewer reads | `/Volumes/ANAN/Engineering/wenshu/.worktrees/chat-unpinned-user-row` |
| the review card | `t_343b2d1f` (= `wenshu-review`, = = T3, = = the tier DERIVED from the body) |

**⇒ ⇒ ⇒ AND THE DOCS THAT DESCRIBED THE REMOVED MECHANISM WERE AMENDED,
NOT REWRITTEN.** The 2026-11-11 chat-band closeout keeps its measurements
and gains a dated amendment (= = its third gate row now names the suite
that REPLACED the deleted one), and the 2026-11-13 render-path sweep keeps
its two findings and gains a section naming the code they measured (= = B4's
`isLatestUser` scan and B5's `turns` array).

## 7. What the boss's OOB record says

`OOB.md` carries the directive as one line (= = the house's format): the
chat transcript stops holding the user's own message at the top.

## 8. Out of scope, = = reported and not fixed

- **The material bar was sent to the wrong session.** The boss cancelled it
  in the same message, so no source was read for it and nothing about it
  changed in this scope.
- **`ChatView.swift` is 342 LOC, and its siblings' rows say so.** The
  registry's two parent counts were corrected because this scope rewrote
  those files (= = the registry's own rule: "a row is corrected when the
  same change rewrites the file").
