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
| 1 | `9ada19911` (= the transcript is one flat list of messages, = = the pin and its grouping type are gone) |

## 2. The trace table (= one row per line the boss gave)

| # | The requirement | The commit that carries it | The independent verdict | The proof |
| --- | --- | --- | --- | --- |
| 1 | 排查 (= diagnose): the user's own message stays pinned at the top of the chat column | `9ada19911` | `t_343b2d1f` (= PENDING) | the RED: the same suite, run against the tree at `84c3a6386` (= this scope's base), FAILS with `Expectation failed: heldRows.isEmpty` (= = the user's card was painted in the viewport's TOP band) |
| 2 | 取消用户发消息置顶的机制 (= cancel the pinning mechanism) | `9ada19911` | `t_343b2d1f` (= PENDING) | `ChatView.swift`'s transcript is a `LazyVStack` with NO `pinnedViews:` argument, and the `onChange` that scrolled the newest user row to `anchor: .top` is gone (= = the two holds, both read off the file). The GREEN: the same suite PASSES against `9ada19911` |
| 3 | 删除相关代码 (= delete the related code) | `9ada19911` | `t_343b2d1f` (= PENDING) | `ChatTurn.swift` (= the grouping type that existed to carry the pin) and `ChatPinnedHeaderBandTests.swift` (= the suite that measured the band it left) are DELETED, and `isLatestUser` (= the per-turn backward scan of `vm.messages`) has no reader left in the tree |

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
| the focused suites (`ChatTranscriptFlatFlowTests`, `ChatUserBubbleReadabilityTests`, `ChatUserBubbleShapeTests`, `ChatSurfaceGeometryTests`, `ChatTranscriptScrollTests`, `RenderPathPerformanceTests`, `StreamingUpdateTests`) | 38 tests in 7 suites, PASS |
| the whole suite | see §5 |
| `ci_change_gate.py --check formatting` | "the change adds no unformatted line (4 changed Swift file(s) checked)", exit 0 |
| `ci_change_gate.py --check pollution` | "the change adds no forbidden vocabulary", exit 0 |
| `nfi-loc-check.py --base 84c3a6386` | "every rewritten file's row carries its own count (1 row(s) checked)", exit 0 |
| `nfi-split.py --check` | PASS |
| `design-sweep.sh` (= the four files this change writes) | "design sweep clean" |
| `verify-dead.py` (= the two files this change writes) | 2 files, 2 ALIVE, 0 PARTIAL, 0 DEAD |

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
