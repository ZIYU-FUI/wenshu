# Session close: the chat user's own band wears the content-area surface

Date: 2026-11-26

Scope: the boss's 2026-11-26 requirement, as written in the plan
directory `.scratch/2026-11-26-user-bubble-band/` (= = its `spec.md` and
its `issues/001-user-band-surface.md`; = = `.scratch/` is untracked, so
those two files live in the checkout that wrote them, not in this tree).
This closeout covers that requirement's scope only.

Landed state (= = the state this record measured, = = and `main` may have
moved on since):

- the scope's landed tip: `a87a90f1b23f0bb4fbd6cc1b1a05e2e82390adc1`
  (= = the commit `main` carried when this record was measured)
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

The base of this scope is the commit its first commit sits on (= =
`dfcaeefeff`), and the block below reads that tree. The plan's own
"Current state" section names the branch `isMine` and the helper
`capsuleStyle`, and says the band touched both column borders; the base
tree carries none of those (= = the branch is `isOutgoing`, the shape is
`ChatSurfaceShape()`, and the band never reached an edge), so the
readings below use the tree's own facts.

`Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift` at the base:

- the outgoing branch is `isOutgoing` (= = `message.source == .user`), and
  the row's own horizontal padding was zero for it (= = the assistant row's
  was 10 PT). The transcript stack's own `spacingStandard` (8 PT) already
  stood between the row and the chat view's column edge.
- the band's surface was `.glassEffect(.regular, in: ChatSurfaceShape())`
  (= = Apple's blurring regular variant, the non-interactive one), and the
  frame around it was `.frame(maxWidth: DesignTokens.chatBubbleMaxWidth,
  alignment: .trailing)` (= = a 360 PT cap, trailing-aligned).
- so the band's surface was laid on the words themselves and only then
  bounded and trailing-aligned (= = the base's own comment: "the cap is a
  bound and not a width, so the glass is laid on the words themselves and
  the cap then bounds the result"). The user's words therefore sat at the
  trailing edge of the column, in a capsule that never spanned it, and the
  ink's leading edge moved with the message instead of sitting on the
  column's own edge. The base's own comment records the measurement (= =
  "short = long = 360.0 PT inside a 723 PT column, so the bubble never
  spans the chat column").
- a glass material is a blur, and the band asked for one on every realized
  outgoing row (= = the per-frame cost the boss reported); this record
  publishes no figure for it.

```bash
git grep -n 'isOutgoing ? 0 : 10' dfcaeefeff -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'glassEffect' dfcaeefeff -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'chatBubbleMaxWidth' dfcaeefeff -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git diff --name-only dfcaeefeff..a87a90f1b2
```

## The fix

One layer of `ContentAreaMaterial.surface` (= = Apple's content-area
material, a flat non-blurring background, as opposed to `.regular`, which
is a blur), inset 20 PT off each column edge, with the ink leading-aligned
inside the band and no stroke of its own:

- the horizontal inset is `DesignTokens.spacingStandard` (8 PT, the
  transcript stack) plus `DesignTokens.spacingModerate` (12 PT, the
  outgoing row's own padding) = = 20 PT off each edge. The 20 PT is not
  double-counted: the stack insets 8 PT and the row adds 12 PT of its
  own; the band's own 12 PT inner inset sits inside the surface and
  changes neither margin.
- inside the band, the card's own `DesignTokens.spacingModerate` (12 PT)
  is that inner inset, so the ink's leading edge sits on a fixed rail
  (= = the surface's leading edge plus 12 PT) instead of moving with the
  message.
- the corner radius is `DesignTokens.surfaceCornerRadiusCard` (8 PT);
- no hairline is drawn: a step in material tone carries the edge, so
  `DesignTokens.dividerHeight` stays with the rules that separate two
  panes rather than a row from its column.

⇒ ⇒ ⇒ **AND NO NEW NUMBER ENTERS THE VIEW: EVERY VALUE THE BAND READS IS
ONE THE APP ALREADY READS (= = `spacingStandard`, `spacingModerate`,
`surfaceCornerRadiusCard` and `controlHeightLarge` were all in
`DesignTokens` before this change, and that file is not among the files
this change touched; = = no new token and no literal).**

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
  reads the laid-out view tree. The band's painted box keeps 20 PT on the
  leading side and 20 PT on the trailing side of the column the suite
  measures (= = the scroll view's content width; = = the suite holds each
  margin within 1 PT) and spans the column between those margins (= = the
  suite holds the band's width at the column's width minus 40 PT, within
  1 PT), exactly one realized row carries a material surface, and that row
  is the bottom-most one, so a reply carries no surface of its own.
- **material**: no `glassEffect(` call site remains in
  `ChatMessageView.swift`. Two remain in the app's Swift sources outside the
  transcript path (= = the composer field and the scroll-to-bottom
  button), one component doc in the app names the API, and the mobile app
  carries one Swift call site of its own (= = its own glass surface
  helper; = = the mobile app's rule doc names the API too).
- **edge**: no hairline. `outgoing_bubble_draws_no_stroke` already owns
  that rule in this repo, so a stroke would have been a second answer to
  the same question.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE READINGS ARE RE-TAKABLE IN THE TREE THIS
RECORD LIVES IN.** The command blocks below are the record's own test
suite: run them from the tree the reader stands on.

## The measurements, re-taken

The commands below read the tree the reader stands on (= = the tree this
record was measured in). Every figure this record publishes about this
tree comes from one of this record's commands, and the token values are
read by one of them too:

```bash
git rev-parse HEAD
git grep -c 'glassEffect(' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift || echo '(0 call sites in the transcript path)'
git grep -n 'ContentAreaMaterial.surface' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'surfaceCornerRadiusCard' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'padding(.horizontal, DesignTokens.spacingStandard)' -- Sources/WenshuApp/Features/Chat/View/ChatView.swift
git grep -n 'padding(.horizontal, isOutgoing ? DesignTokens.spacingModerate : 10)' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -n 'padding(.horizontal, DesignTokens.spacingModerate)' -- Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift
git grep -rn '\.interactive()' -- Sources Mobile
git grep -n 'glassEffect(' -- 'Sources/WenshuApp/**/*.swift'
git grep -ln 'glassEffect(' -- 'Sources/WenshuApp/**/*.md'
git grep -n 'glassEffect(' -- Mobile/Sources
git grep -n 'right-hand inspector column' -- Sources/WenshuApp/Features/Editor/View/InspectorView.swift
git grep -n 'ContentAreaMaterial.surface\|surfaceCornerRadiusCard\|spacingStandard' -- Sources/WenshuApp/Shared/UI/InspectorCard.swift
git grep -rn 'glassEffect' -- Sources/WenshuApp/Features/Editor || echo '(the editor feature carries no glass site)'
git grep -n 'spacingStandard\|spacingModerate\|surfaceCornerRadiusCard\|controlHeightLarge\|chatInputBarHeight\|chatBubbleMaxWidth' -- Sources/WenshuApp/DesignTokens.swift
```

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE COUNT EACH COMMAND PRINTS IS A READING OF
THE TREE, = = NOT A NUMBER THIS DOCUMENT FREEZES.** The macOS app's glass
call sites outside the transcript path are two (the composer field and
the scroll-to-bottom button), one component doc in the app names the API,
and the mobile app carries one Swift call site of its own (the mobile
app's own rule doc names the API as well); the next landing that
changes any of them changes the count.

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE GEOMETRY SUITE IS THE ONE THAT MEASURES THE
BAND, = = SO IT IS THE SUITE THIS RECORD NAMES.** Run it at the tip:

```bash
swift test --skip CSSearchableIndexSearchTests --filter 'ChatTranscriptFlatFlowTests|ChatUserBubbleReadabilityTests|ChatSurfaceGeometryTests|ChatSurfaceShapeTests|ChatUserBubbleShapeTests'
```

⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE FIVE SUITES ABOVE ARE THE SCOPE'S OWN, = = NOT
EVERY SUITE IN THE TREE.** The lane's suites are the ones this change
touched or added.

## The review, and where the record's numbers came from

The band's own change went through six review rounds on the board; the
last of them was reviewed by two cards, both of them bound the same sha,
and both of them returned APPROVED:

- `t_33171d10` (= = created by `user`) and `t_ba00ce99` (= = created by
  `pocock`) are **two cards for the same thing**: the same sha, the same
  spec, both APPROVED. They are not two rounds; a later reader must not
  count them as two.
- the approved sha was `b3d6d52d8712a5d49ce8812cb7fcfc14596945f2`, and the
  lane was rebased twice while the reviews ran, so the landed tip is a
  different sha. The identity that survives a rebase is the change's
  written lines, and `git patch-id --stable` reads the same for the
  approved sha and for the landed tip.
- the review's own blockers were about the code's written text, not about
  the band's geometry: a renamed test case still stated a radius cap
  inside itself, and a shape header still said the cap could not bind.
  Both were fixed in the commits this record names.

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
right column here is the trailing inspector column, and the cards that
column's pages draw are `InspectorCard`s (the todo page's steps, the
status page's rows, and the task page's board rows), which already wear
the content-area surface (= = the same material and the same corner
radius as this scope's band) with `DesignTokens.spacingStandard` of
padding; the format page draws no card at all. The editor feature
carries no `glassEffect(` call site at all. The macOS app's only two
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
