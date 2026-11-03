# Session close: the card board client, and the two reference teardowns

## The scope

Two rulings, in order:

1. Read the two reference projects before writing anything, and if a replica
   is written, do NOT put it in the desktop app: give it its own client and
   its own directory, sharing the data and model layer.
2. The infinite canvas is the thing worth borrowing from Freeform. It is not
   open, so the client writes it itself.

The scope was the client's directory, its engineering docs and the two
reference teardowns. It was NOT the client feature work.

## What landed

| The requirement | The commit |
| --- | --- |
| feat(board): the card board gets its own client, and the reference model comes with it | `ec0a039ed` |
| docs(board): the client's engineering docs, and the two reference teardowns inside it | `fbcda83f1` |
| feat(board): the infinite canvas, built from the pieces Apple ships | `86ca11c35` |
| docs(board): the two references, dug to the source | `73d21fd41` |
| docs(board): the reference, run for real | `f1486cdfa` |
| docs(board): the reference's collision engine, and its action vocabulary | `3ad141537` |
| docs(board): the reference's method bodies, and the numbers in them | `a324e5ab6` |
| docs(board): the dot grid's spacing, the snap tolerance's curve, and the action payloads | `64550286d` |
| docs(board): the dot grid gap, closed rather than left open | `e2bd4e7fe` |
| docs(board): the grid ratio, stated as an observation and not a fact | `8cda2b350` |
| docs(board): the layout node, in full | `9d9700b6a` |
| fix(board): the review's eight findings, and the two files the index never got | `7ba659086` |
| fix(board): the false SDK claim survives in two places, and the deferred CI job needs a record | `0e5fcbc63` |

Thirteen commits on one branch (`wt/board-client`), rebased onto `main`
before the third review and landed as a fast-forward. The review cards are
`t_9b08c011`, `t_91055532` and `t_486bb483` (assignee `wenshu-review`); the
third one carries the approving verdict the merge gate reads.

The durable fact of the landing is an ancestry, not a tip: the merge commit
and this record are ancestors of each remote's `refs/heads/main`. The tips
move as other lanes land, so read them from the remote rather than from
here.

The client's own SSOT is `Board/AGENTS.md` (10 sections), and the root
`AGENTS.md` changed by TWO lines (6.8 and 6.10): `Board/` joins the root
tree.

## The two teardowns, and what they decided

Both are measurements, not opinions. Every number in them carries its
source: a value read off a live system, a line quoted from the reference's
own source, or a named method.

**Milanote** (`Board/docs/milanote-card-model.md`):

- One element envelope for a board, a column and a card alike; 19 element
  types; one `location` carrying both placement regimes (a free canvas with
  x/y plus an order score, and an ordered list with an ordinal plus an order
  key).
- The order key's step is 65536; a card above the head takes a negative rung;
  a batch insert splits the gap by (n + 1); an insert with no room asks for
  a rebalance instead of writing a colliding key.
- One write endpoint: `POST {apiRoot}/api/actions`, body
  `{ action: { type, ... } }`, one action per call; 22 element actions;
  the create carries no id (the server assigns it), the delete carries the
  element's type and its parent.
- The location is a tagged union discriminated by which keys are present,
  not by a tag field: 6 position variants and 6 sections.
- The collision engine is a grid-quantised column cascade, and it runs in a
  Worker in GRID units (the card's measured size is divided by the grid size
  before it is placed).

**Apple Freeform** (`Board/docs/freeform-card-model.md`):

- macOS ships no infinite canvas and macOS 27 adds none; the public pieces
  are `SwiftUICore.Canvas`, `MagnifyGesture`, `DragGesture`,
  `ScrollGeometry`, `zIndex` and `drawingGroup`, so the client writes the
  canvas itself.
- The board is a LAYOUT TREE, not a flat list. The layout node answers its
  geometry in four spaces (natural / pure / info / root), its place in the
  draw order, the guides it offers, its children, a culling rectangle, a
  clipping path and its place in the dependency graph. The root space is
  composed, never stored.
- The dependency graph is NOT the tree: a layout depends on its parent's
  dependents and on board items registered with the canvas controller, which
  are not its descendants.
- Live edit is a per-gesture triple (begin / take-from-tracker / end) and
  the commit clears three pieces of state, so a drag is not a write.
- Measured constants: the dot spacing is 25 points in unscaled coordinates;
  the guide snap distance is 7 points and the ceiling is
  `snapDistance / (tanh(viewScale - 1) + 1)`; the autoscroll's base step is
  60 unscaled units per tick, divided by (26 - count) as the ramp eases.
- 2,415 method bodies were decompiled (11.2% of the 21,580 reachable
  Objective-C methods). Every class that holds the geometry, the guides, the
  snapping, the autoscroll, the zoom and the positioning is at 100%.

## The code that came with it

- `Board/Sources/WenshuBoardKit/` = the card model: the element envelope, the
  order key, the viewport arithmetic as a pure function, and the reader that
  takes a chapter from the FILE tier (the SwiftData chapter row holds zero
  rows on a live library).
- `Board/Sources/WenshuBoardApp/` = the executable: the card column, the
  infinite canvas view, and an offscreen `ImageRenderer` proof.
- `Board/Tests/` = 32 tests in 4 suites.

The client READS a library. It never writes one (ADR-0035), and the desktop
app's target, views, icon factory and design tokens are not dependencies of
it (ADR-0034).

## The gates, on the rebased tree and again on the merged tree

| Gate | Result |
| --- | --- |
| `swift build` in `Board/` | Build complete |
| `swift test` in `Board/` | 32 tests in 4 suites, 0 failures |
| `agents_gate.py --file Board/AGENTS.md` | loadable and true |
| `agents_gate.py --file AGENTS.md` | loadable and true |
| `design-sweep.sh` | no changed Swift files in the desktop tree |
| CJK audit over the diff | the only CJK is the forbidden-vocabulary tables in `Board/AGENTS.md` and the boss's quoted rulings in `OOB.md` (= exempt) |
| `merge-preflight.sh wt/board-client` | CLEAN, after the review verdict |
| the root package's own `swift build` | Build complete (= `Board/` is a separate package and does not touch the desktop build) |
| the same gates, re-run on the MERGED tree | all green |

## The review, and what it found

The client branch went through three independent reviews, all by a profile
that did not write it. The first two returned changes_requested, and every
finding in both was fixed before the next round:

- Round one (8 findings): the Freeform teardown's method table was a
  byte-identical copy of the Milanote one; the `PKCanvasView` position was
  stated wrongly in three places; the client's SSOT did not carry the rule
  that stops the canvas becoming a data migration; the README and the plan
  described a client that did not exist yet; three cross-references pointed
  at a section the document does not have, and one of them asserted a scope
  decision the branch had already reversed; a cited source path had never
  existed in any branch; two numbers did not reproduce (a filtered test
  count recorded as the whole run, and a total recorded as a subset); and two
  index rows carried counts the files never had.
- Round two (4 findings): the false SDK claim survived in the two places
  round one did not touch; the renumbering that fixed round one's dangling
  references turned one loose pointer into a dangling one; the index row
  for the file the change rewrote was left stale; and the deferred CI job
  was recorded nowhere on the branch while the client's SSOT advertised it.
- Two gaps the reviews did not name, found while fixing theirs: the index
  never registered two of the branch's added files, and the client's SSOT
  advertised a CI job the workflow does not have.

The lesson the reviews demonstrated is about the KIND of defect, not the
count: every finding was a claim that was true in one place and false in
another. A teardown that grades itself against the wrong method, an SDK fact
that survives in the copy nobody re-read, an inventory that describes the
tree before the last commit touched it. A document that says a thing twice
has to be checked twice, and the second place is the one that gets missed.

## The open items

1. The client's own feature work is not started: the card column renders one
   column of cards, and the canvas is a prototype.
2. The client has no icon factory. The desktop app's factory is in its own
   target and is not consumable, so the client needs its own answer
   (`Board/AGENTS.md` 5.3, Open).
3. The Freeform teardown's unit grid comes in three tiers and which tier the
   canvas sits in is not resolved.
3a. The client has no CI job. The repository's runner (`macos-14`, Xcode
   15.4) is behind the repository's own macOS 27 floor, so a job for `Board/`
   would be red on arrival; the client's build and test gates are manual
   until a runner that can build the floor exists. This is recorded in the
   client's own SSOT (7.1, 7.2) and as decision 8 in the plan, so the branch
   carries it.
4. Milanote's `/api/actions` path table is not in the bundle (it is fetched
   at runtime); the wire protocol itself is established from the capture and
   from the server's own error message.
5. Apple's `.board` package is unreachable on this machine: the Freeform
   container is empty (everything is in CloudKit) and no sample exists
   anywhere on disk. This is a CLOSED question, not an open one.
6. The pure-Swift half of Freeform's canvas (its implementation bodies) was
   not decompiled. The Objective-C surface was mined to 100% on the classes
   that carry the model, and the Swift core was reached only for its names
   and its exposed constants.

## The residue

Kept, because the next session reads it: the Ghidra project with the
decompiled corpus (`/Volumes/ANAN/Engineering/ghidra-projects/ffproj`), the
method map and the decompiled bodies under the REA skill's `references/`.

Removed: this session's scratch probes, and the Freeform instance this
session launched.

## Addendum — the dual-axis audit, run after the landing

The scope landed with three independent review rounds behind it, 32 green
tests, and an approving verdict. The dual-axis dispatch that
`Board/AGENTS.md` §7.4 names as a merge-blocking gate had never run on it.
Run after the landing, it returned CHANGES_REQUESTED on both axes, and it
found three defects that every earlier pass had passed.

### What it found, and what changed

| # | Finding | Fix |
| --- | --- | --- |
| 1 | The pan gesture measured its delta from the start of the drag and handed it to an additive viewport, so every event re-sent the whole displacement: the world accelerated away from the cursor. | `BoardViewport.panned(from:to:)` measures the increment, and the gesture tracks the previous point. A test pins ten ten-pixel events to a hundred pixels of travel. |
| 2 | The magnify gesture's magnification is a ratio that starts at 1, and it was handed to an absolute-scale API: the first callback reset the board to 1.0, and every later frame tracked the raw ratio. | `BoardViewport.zoomed(by:about:)` multiplies, and the gesture applies it to the viewport the gesture STARTED from (= applying it to the current viewport compounds the zoom on every frame). |
| 3 | `location.section` was never read, so the client's central claim (= one record, two regimes) was true in the documents and false in the code. | `BoardElement.isOnCanvas` and `isInList` decide which regime reads which fields, the order key now exists only in the list regime, the canvas draws the canvas records and the column lists the list records, and the demo is ONE record set read by both. |

The findings that were true and cheap are fixed too: the batch insert rule
the documents promised and the Kit did not have (it does now, and it is the
reference's `(n + 1)` division), the title that only looked at the first
line, the `orderedCards` the app never called, the unused imports, the magic
numbers in the app target, the dot grid attributed to the reference that has
no canvas dot grid, the dot period stated as two different numbers in one
document, and three claims in the client's own SSOT that the code did not
support (the sort rule, the list of canvas pieces, the layout tree).

### The lesson the three rounds missed

The review rounds compared the code against the rules, and the tests compared
the viewport's arithmetic against the viewport's arithmetic. Nobody compared
the code against the user's hands. A test that pins `panned(by:)` proves the
additive contract, not that the caller sends an increment, and the gestures
were wrong in the two ways a gesture can be wrong while 32 green tests said
nothing about either.

**A test pins the thing it measures.** The fix therefore moves the gestures'
shape into the Kit, where a test can reach it: 17 new tests, 49 in 8 suites.

### The by-rule inventory (§8.5)

Thirteen rule families, run over the landed scope: twelve clean. The two
non-zero lines are not violations: the client's own SSOT names the forbidden
words (= rules 1.3 and 1.4 list them), and the same kind of CJK appears in
23 of the desktop's 35 ADRs. The one that IS a finding is the scope's shape:
the Board client is one scope in fourteen commits, and rule 1.10 says one
ticket = one commit.

### The spec, and how it came back

The ticket's 4-section spec was written to the card worktree's untracked
`.scratch/`, and `git worktree remove --force` deleted it with no commit and
no trace: §8.3 had no artifact, and nothing in the repository said the spec
had ever existed. It was recovered byte-for-byte (245 lines, 15,607 bytes)
from the session database, then corrected: three of its claims were wrong
(the production model, the file tier, `PKCanvasView`), and its scope had
been re-scoped twice by the boss's own rulings, so it now carries a banner
and ADR-0036 records what was built.

### Left open, on purpose

- The desktop app's document order and the client's order do not agree (= UUID
  order against newest-first). Neither is a chapter number, and no tie-break
  is promised.
- A card's identity is still derived from its position in the chapter, so an
  insert renames the cards after it. That is the design question in
  `Board/docs/board-plan.md` §10 decision 3, and it is the boss's to answer.
- The client still has no icon factory of its own (§5.3), no CI job (§7.1),
  and no write channel (ADR-0035).
- The shared skill tree's two central skills are over the runtime's
  100,000-character cap, so `skill_manage` can no longer patch them, and the
  tree is not a git repository, so there is no version control behind it
  either.
