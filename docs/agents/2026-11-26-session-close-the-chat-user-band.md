# Session close: the chat user's own band wears the content-area surface

Date: 2026-11-26

Scope: the boss's 2026-11-26 requirement, as written in the plan
directory `.scratch/2026-11-26-user-bubble-band/` (= = its `spec.md` and
its `issues/001-user-band-surface.md`; = = `.scratch/` is untracked, so
those two files live in the checkout that wrote them, not in this tree).
This closeout covers that requirement's scope only.

Landed state (= = the state this record measured, = = and `main` may have
moved on since):

- `main` = `a87a90f1b23f0bb4fbd6cc1b1a05e2e82390adc1`
- the lane's four landed commits, oldest first:
  `4a54bceae4` (the band's surface and margin),
  `4c9f543f9a` (the record stops claiming one outline for two surfaces),
  `16f157cba2` (the radius cap is 36 PT),
  `a87a90f1b2` (the radius is read off the shape's own path)
- that sha is an ancestor of the branch this record lives on (= =
  `git merge-base --is-ancestor a87a90f1b2 HEAD` exits 0), and an ancestor
  of `origin/main` (= = the same command against `origin/main` exits 0)

⇒ ⇒ ⇒ **AND THE COMMITS THE PUSH CARRIED THAT ARE NOT THIS SCOPE'S.** The
push that carried this scope carried exactly the four commits above (= =
`git log --oneline dfcaeefeff..a87a90f1b2` lists those four and nothing
else). No sibling's commit rode along with it, and no sibling's work is
named in this record.

## The symptom, measured on the base

`Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift`, the `isMine`
branch, painted a liquid-glass capsule straight onto the chat column's
edges:

- `capsuleStyle` applied `.glassEffect(.regular.interactive(), in: shape)`
  with zero horizontal inset, so the band touched both column borders;
- a glass material is a blur, and the blur is the most expensive view in
  the transcript (= = the per-frame cost the boss reported);
- the readable text sat inside a nested `DesignTokens.chatBubbleMaxWidth`
  cap (360 PT), so a short message floated a 360-point window inside a
  600-point column instead of reading as a row, and the ink's leading
  edge moved with the message instead of sitting on the column's own edge.

## The fix

One layer of `ContentAreaMaterial.surface` (= = Apple's content-area
material, a flat non-blurring background, as opposed to `.regular`, which
is a blur), inset 20 PT off each column edge, with the ink on the band's
own leading edge and no stroke of its own:

- the horizontal inset is `DesignTokens.spacingStandard` (8 PT, the
  transcript stack) plus `DesignTokens.spacingModerate` (12 PT, the band's
  own row) = = 20 PT off each edge. The 20 PT is not typed in twice: the
  stack insets 8 PT and the band adds 12 PT on its own row only.
- the corner radius is `DesignTokens.surfaceCornerRadiusCard` (8 PT);
- no hairline is drawn: a step in material tone carries the edge, so
  `DesignTokens.dividerHeight` stays with the rules that separate two
  panes rather than a row from its column.

⇒ ⇒ ⇒ **AND NO NEW NUMBER ENTERS THE VIEW: = = EVERY VALUE ABOVE IS ONE THE
APP ALREADY READS.**

### The shape that reads the radius

`ChatSurfaceShape` is the outline the chat input field wears, and it is
shared with the inspector's output sheet. Its radius tracks half the
surface height, so a surface at the resting chat height reads as a
capsule; the cap binds above 72 PT, and the composer field's own
five-line ceiling (= = 80 PT) is above it. The outgoing message band is
not one of these surfaces.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE CAP IS 36 PT, = = `DesignTokens.controlHeightLarge`,
= = AND THE GEOMETRY TEST READS THE RADIUS OFF THE SHAPE'S OWN PATH
INSTEAD OF RESTATING THE TOKEN.** A test that computes the expected
radius from the same token the shape reads is satisfied by any cap,
including a wrong one; the geometry suite instead compares the shape's
own `Path` against the rounded rectangle it claims to draw, so a
mutated cap makes it fail.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE BAND'S OWN CORNER IS NOT THAT SHAPE.** The
band is clipped by a `RoundedRectangle` at
`DesignTokens.surfaceCornerRadiusCard`, so the two surfaces do not wear
one outline.

## What is proven, and by what

- **geometry**: `ChatTranscriptFlatFlowTests` hosts a real `ChatView` and
  reads the laid-out view tree. The band's painted box measures 20.0 PT
  leading and 20.0 PT trailing in a 600 PT column and spans 560 PT of
  it, exactly one realized row carries a material surface, and that row
  is the bottom-most one, so a reply carries no surface of its own.
- **material**: no `glassEffect(` call site remains in
  `ChatMessageView.swift`. Two remain in the app's sources outside the
  transcript path (= = the composer field and the scroll-to-bottom
  button), and one component doc names the API.
- **edge**: no hairline. `outgoing_bubble_draws_no_stroke` already owns
  that rule in this repo, so a stroke would have been a second answer to
  the same question.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE READINGS ARE RE-TAKABLE IN THE TREE THIS
RECORD LIVES IN.** The command blocks below are the record's own test
suite: run them from the tree the reader stands on.

## The measurements, re-taken

The commands below read the tree the reader stands on (= = the tree this
record was measured in). Every figure this record publishes comes from one
of them.

```bash
git rev-parse HEAD
git grep -c 'glassEffect(' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift || echo '(0 call sites in the transcript path)'
git grep -n 'ContentAreaMaterial.surface' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'surfaceCornerRadiusCard' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'spacingStandard' -- Sources/WenshuApp/Features/Chat/View/ChatView.swift
git grep -rn '\.interactive()' -- Sources Mobile
git grep -n 'ContentAreaMaterial.surface' -- Sources/WenshuApp/Shared/UI/InspectorCard.swift
```

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE COUNT EACH COMMAND PRINTS IS A READING OF
THE TREE, = = NOT A NUMBER THIS DOCUMENT FREEZES.** The macOS app's glass
call sites outside the transcript path are two (the composer field and
the scroll-to-bottom button), one component doc names the API, and the
mobile app carries one of its own; the next landing that changes any of
them changes the count.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE GEOMETRY SUITE IS THE ONE THAT MEASURES THE
BAND, = = SO IT IS THE SUITE THIS RECORD NAMES.** Run it at the tip:

```bash
swift test --skip CSSearchableIndexSearchTests --filter 'ChatTranscriptFlatFlowTests|ChatUserBubbleReadabilityTests|ChatSurfaceGeometryTests|ChatSurfaceShapeTests|ChatUserBubbleShapeTests'
```

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE FIVE SUITES ABOVE ARE THE SCOPE'S OWN, = = NOT
EVERY SUITE IN THE TREE.** The lane's suites are the ones this change
touched or added.

## The review, and where the record's numbers came from

The change went through six review rounds on the board; the last two both
bound the same sha and both returned APPROVED:

- `t_33171d10` (= = created by `user`) and `t_ba00ce99` (= = created by
  `pocock`) are **two cards for the same thing**: the same sha, the same
  spec, both APPROVED. They are not two rounds; a later reader must not
  count them as two.
- the approved sha was `b3d6d52d8712a5d49ce8812cb7fcfc14596945f2`, and the
  lane was rebased twice while the reviews ran, so the landed tip is a
  different sha. The identity that survives a rebase is the change's
  written lines, and `git patch-id --stable` reads the same for the
  approved sha and for the landed tip.
- the review's own blockers were about the RECORD, not about the band: a
  renamed test case still stated a radius cap inside itself, and a shape
  header still said the cap could not bind. Both were fixed in the
  commits this record names.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE BAND'S OWN CORNER AND THE INPUT FIELD'S CAPSULE
ARE TWO DIFFERENT SURFACES, = = AND THE RECORD USED TO SAY OTHERWISE.**
`ChatSurfaceShape` is the input field's outline; the band is clipped by a
`RoundedRectangle`. A reader who takes one radius for both will mis-size
one of them.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE CAP'S VALUE IS 36 PT, = = NOT 18.** The cap is
`DesignTokens.controlHeightLarge`, and the radius is half the height until
the cap binds: a 36 PT surface reads 18, a 72 PT surface reads 36, and a
100 PT surface reads 36.

## What this scope does NOT claim

- **No per-frame cost figure for either state.** The 16 ms in the scope's
  plan is Apple's hitch lane for scrolling (8-16 ms, depending on the
  display's refresh rate), quoted as the yardstick the old capsule sat
  against; it is not a measured cost of that capsule, and the plan's own
  probe printed no numbers for it. Dropping the per-row blur from the
  transcript path is a structural fact (= = no `glassEffect(` call site
  remains in the transcript path), not a measurement, and this record does
  not claim it as one.
- **No claim about the band's radius being 8 PT in every rendering.** The
  band's own clip is `DesignTokens.surfaceCornerRadiusCard`; the input
  field's outline is a separate shape whose radius follows its height.

## Open item this scope did not fix

The scope's plan also notes a control pill in the right column, still
wearing `glassEffect(.regular.interactive())` and inset 10 PT, as the odd
one out against this scope's 20 PT. **That pill is not in this tree**: the
right column here is the trailing inspector column, and its cards already
wear the content-area surface (= = the same material and the same corner
radius as this scope's band) with `DesignTokens.spacingStandard` of
padding, and the editor feature carries no glass site at all. The only two
glass sites outside the transcript path are the composer field and the
scroll-to-bottom button, both in the chat column. The pill's figure
belongs to the lane that owns that tree, and this record states no number
for it here.

## The stopping rule for this record

This review lives on the board; the doc does not log it. The scope's
substance is finished at the landed state named above, and a further round
that asks only for a wording change is not a blocker. Any finding about
the RECORD's substance (= = a measurement it publishes, a claim it makes)
is fixed in the substance and not by adding an entry here.
