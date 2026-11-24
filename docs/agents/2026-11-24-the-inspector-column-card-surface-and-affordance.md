---
title: "The inspector column's card surface and its clickable affordance"
scope: "the trailing inspector column's shared card (= the todos page, = the sub-agent page, = and the task board's page)"
base: "1ca6aba9a4"
branch: "wt/inspector-card-material-2026-11-24"
commits:
  - "e1b4896a7f  = the card wears the column's own material, = and the colour band is gone"
  - "8e3c3aca77  = the card that opens is a button, = and the whole card answers the pointer"
---

# The inspector column's card surface and its clickable affordance

## 1. SYMPTOM

The trailing inspector column's cards read as dead under the pointer. The
board's card wore a hover wash that could not be seen at all, the status
page's card wore no hover wash whatsoever, and no card told the user it
could be opened: the pointer stayed an arrow everywhere, the words inside
a card answered the pointer with a TEXT cursor (= the user could select
the title, which says "this is a document"), and the board's card's click
target was a tap gesture on a view, so it had no keyboard activation, no
focus ring and no VoiceOver button role.

Underneath the hover question sat a second one: the card's own surface was
Apple's Liquid Glass, and that surface's value TRACKED THE WALLPAPER behind
the window (= 255 on a pale desktop, = 244 on a dark one, = 228 on another).
So the card's tone changed with the DESKTOP rather than with the app, and
the white 30% tint made the card read DARKER than the ground behind it
(= the audit's capture measured the glass card at 228 against the 255 PAGE
ground) = a recessed grey slab instead of a card on the column.

⇒ ⇒ ⇒ AND EVERY MEASUREMENT BELOW NAMES ITS SAMPLING POINT, = = because
this scope's material is TRANSLUCENT (= = it samples whatever is BEHIND it),
= = so the same material reads differently in different places. ⇒ ⇒ ⇒ The
TWO SETS ARE: the card's own interior against the ground right around the
card (= = read in the inspector column's card area), = = and the material's
own value at the column's bottom band (= = read where the band lives, = =
the footer's own numbers, = = in the footer's own file). ⇒ ⇒ ⇒ They are
not two answers to one question: = = they are one material read at two
points, = = and no name in this document points at two values.

## 2. ROOT CAUSE

Three causes, each measured, and none of them the same kind of thing:

1. **THE WASH WAS PAINTED UNDER THE CARD.** The app's shared hover wash
   (= `HoverWash.swift`) paints itself with `.background`, = = which is
   BEHIND the view it is applied to. A card's own surface is an
   `NSVisualEffectView` (= a material, = = and a material is opaque enough
   to bury a wash painted beneath it). ⇒ ⇒ ⇒ So the board's card's wash
   existed and was invisible at the same time.

2. **THE WASH'S OWN SHAPE DID NOT MATCH THE CARD.** The shared wash wears
   `DesignTokens.surfaceCornerRadiusSmallButton` (= 5 PT) and the card's
   corner is `DesignTokens.surfaceCornerRadiusCard` (= 8 PT). ⇒ ⇒ ⇒ A wash
   in a smaller radius floats INSIDE the card's corner instead of
   following it, = = so even a visible wash would have read as a smaller
   rectangle laid on the card.

3. **THE CLICK TARGET WAS A GESTURE, NOT A CONTROL.** The board's card
   carried `.onTapGesture` and the status page's card wrapped the card in a
   `Button` with `.buttonStyle(.plain)` (= which on macOS paints no hover
   fill of its own). ⇒ ⇒ ⇒ So neither card had the system's own answers
   (= the focus ring, = Return, = the VoiceOver button role), = = and the
   words inside a card were selectable text, = = which answers the pointer
   with a text cursor.

⇒ ⇒ ⇒ AND THE WASH'S OWN STRENGTH HAD DRIFTED FROM ITS STATED INTENT.
`HoverWash.swift`'s header names `.quaternary` and Apple's own precedent
(= Settings' sidebar rows, = Mail's message rows, = Finder's toolbar
buttons) = = while the code wore `.tertiary`. MEASURED on this SDK:
`.quaternary` = 9.8% alpha in BOTH appearances, = = `.tertiary` = 25%.
⇒ ⇒ ⇒ So the wash was 2.5x stronger than the file said it was.

## 3. THE FIX

**THE SURFACE.** The card now wears the app's own content-area material
(= `Shared/UI/ContentAreaMaterial.swift`), = = the surface the column's
bottom bar already wears. It is the one material in this app that samples
the app's OWN content behind it (= the within-window blending), = = so the
card shows the column it sits in instead of the desktop behind the window.
The recipe lives in ONE file, = = so the bottom bar and the cards cannot
drift into two greys.

**THE BAND.** The coloured band down the card's leading edge is GONE. It
was the card's loudest element while saying the same thing the state glyph
beside the title already said. ⇒ ⇒ ⇒ The state rides on the glyph and on
the card's own words, = = and the token that carried the band (= a 2 PT
`kanbanCardStatusEdgeWidth`) is deleted, = = because a token with no
caller is dead code.

**THE HOVER.** The card's wash is Apple's own `.quaternary`, painted OVER
the material, = = in the card's own shape (= the card's radius token), = =
and its tracking area hangs on the Button, = = NOT inside the label (= = a
tracking area inside a label is rebuilt when the label re-renders, = = and
the re-render is what the hover state causes, = = so the wash flickers).

**THE CLICK.** A card that opens something IS a button (= `.buttonStyle(.plain)`,
= = so the card draws its own surface and no bezel is added), = = so the
whole card answers the click (= its padding, = its background, = the empty
space beside the body preview), = = and it comes with the system's focus
ring, = = Return, = = and the VoiceOver button role.

**THE POINTER.** The card wears Apple's own `.pointerStyle(.link)`, = = and
its words are no longer selectable text (= = a selectable text answers the
pointer with a text cursor, = = and a text cursor over a card says "this
is a document", = = not "this opens something"). ⇒ ⇒ ⇒ The words stay
selectable where they belong (= = in the sheet the card opens).

**A CARD THAT OPENS NOTHING WEARS NONE OF THIS.** The plan page's card
opens nothing today (= the plan lives in an in-memory store with no
document behind it), = = so it carries no hand, = = no hover wash and no
button. ⇒ ⇒ ⇒ A card that lights up under the pointer and then does
nothing is a lie the user pays for.

## 4. MEASURED BEFORE / AFTER

Every number below is read off the app's OWN window (= the window server's
pixels of the running app), = = and the reader's instrument is a
CoreGraphics decode of the PNG (= never a hand-rolled decoder).

| What | Before | After |
| --- | --- | --- |
| the card's surface | Apple's Liquid Glass with a white 30% tint (= the surface's value tracked the wallpaper: 255 / 244 / 228 on three desktops) | the app's own content-area material (= a translucent surface that samples the app's own content behind it) |
| the card's interior against the ground right around the card (= = read in the inspector column's card area) | the audit's capture: the glass card at 228 against the 255 PAGE ground (= 27 BELOW it = a recessed slab) | 48 against 44 (dark), 234 against 226 (light) (= 4 and 8 ABOVE its own surround) |
| the material's own value at the column's bottom band (= = read where the band lives, = = against the ground AT that band) | unchanged (= = the band already wore it) | 48 against 78 (dark), 222 against 190 (light) (= BETWEEN that ground and the window's bottom edge) |
| the coloured leading band | a 2 PT status bar, = = an unclipped overlay whose square corners protrude past the card's rounded corner | none: the card's surface is greyscale end to end (= saturation 0 at every sampled pixel) |
| the hover wash | painted under the card, = = invisible | painted over the material in the card's own shape: 23 levels over 92% of the card's pixels (= = the whole card answers) |
| the wash's strength | `.tertiary` (= 25% alpha) although the file said `.quaternary` | `.quaternary` (= 9.8% alpha in both appearances) |
| the click target | `.onTapGesture` (= no keyboard, = no focus ring, = no VoiceOver role) | a `Button` (= = the focus ring, = Return, = and the VoiceOver button role come from the system) |
| the pointer over the card's words | a text cursor (= the words were selectable) | Apple's own pointer style (= = no text cursor) |

## 5. THE TESTS

`Tests/WenshuAppTests/Editor/View/InspectorCardTests.swift` holds the
contract as source-text assertions (= the property each one holds is a
property of the CODE, = = so a source-text assertion is the right shape
for it): the card's surface is the shared material and not a glass one, =
the material's recipe is the app's own, = the card carries no colour band,
= the card that opens something is a button, = the pointer says "this
opens", = the hover answers over the whole card, = the wash is Apple's own
and is painted over the material, = and the plan's card (= which opens
nothing) carries no open action.

The focused gate: `swift test --filter InspectorCardTests` (32 tests in
3 suites with the two neighbouring suites, = = and all of them pass).

⇒ ⇒ ⇒ AND THE WHOLE-SUITE VERDICT IS READ AS A SET AGAINST A BASE
CONTROL. Measured: the base's own issue set varies run to run (= 11, = 11,
= 14, = 12 across four runs of the same tree), = = and the branch's set is
otherwise a SUBSET of the base's union across those runs. ⇒ ⇒ ⇒ ACROSS THE
BRANCH'S TWO FULL-SUITE RUNS, = = EACH SURFACED ONE ISSUE THE BASE'S FOUR
RUNS DID NOT, = = AND THEY WERE DIFFERENT ONES: = = a 5-second budget in
`HermesTodoStoreConcurrencyTests`, = = and a streaming-window test in
`StreamBufferChainTests`. ⇒ ⇒ ⇒ BOTH PASS IN ISOLATION (= = the first in
0.06s, = = the second in 11-12s, = = so it misses its window under the
whole suite's parallel load), = = and neither touches any code this scope
wrote. ⇒ ⇒ ⇒ So they are the load-sensitive class, = = and the scope's
verdict rests on the SET: = = every issue the branch's two runs showed
EITHER the base's four runs also produced, = = OR passes in isolation and
touches no code this scope wrote. ⇒ ⇒ ⇒ AND THIS DOC CLAIMS NOTHING
MORE FOR THE TWO THAT ARE NOT IN THE BASE'S FOUR RUNS: = = it records
that they pass alone and that no code in this scope reaches them, = = and
it stops there (= = a claim about what the base's own runs do would be a
claim this doc has not measured).

## 6. THE OPEN ITEMS

1. **The plan page's card opens nothing.** The plan lives in an
   in-memory store (= `HermesTodoStore`, = = a serial queue over an
   array), = = and a plan item names no document, = = so there is nothing
   for a click to open. ⇒ ⇒ ⇒ The card therefore carries no hand, = = no
   hover wash and no button (= = the honest state), = = and the product
   question (= what a plan item should open) is OPEN and is NOT decided
   here.

2. **The hover's own flicker was cleared by construction and confirmed by
   the boss's own look**, = = but the CHANGE THAT KILLED IT could not be
   isolated by an agent: synthetic pointer input does not fire a
   SwiftUI `.onHover` on this machine (= = measured: zero hover events
   from `CGEvent` moves and from warps, = = in an active app), = = and
   `NSCursor.current` is not a valid instrument for a tracking area's
   cursor either. ⇒ ⇒ ⇒ So the flicker check is the boss's mouse, = = and
   the mechanism the fix removes (= = a tracking area inside a label that
   the label's own re-render rebuilds) is held by a source-text test
   instead.

## 7. THE COMMITS

| Commit | What it carries |
| --- | --- |
| `b63fef355f` | the card wears the column's own material (= the shared `ContentAreaMaterial`), = and the coloured leading band is gone (= with its token) |
| `9a2b6fd827` | the card that opens is a button, = = the whole card answers the hover and the click, = = the pointer says "this opens", = = and the words are no longer selectable text |
| `3af38bcb54` | the closure doc and its registry row (= = no production code) |
| `bc993bf06f` | the review round's two findings closed (= = one figure set per file with its sampling point, = = and the registry's tail marker and trailing newline restored) (= = COMMENT ONLY in the code) |
| `12d350873b` | the closure doc's §5 verdict corrected to name BOTH load-sensitive extras (= = no production code) |

⇒ ⇒ ⇒ These are FIVE commits for ONE scope: = = TWO carry the code (= =
the boss's request came in two rounds: = = the surface and the band
first, = = and then the pointer's answers), = = and THREE carry the
record (= = the doc, = = the review's findings, = = and the verdict's own
correction). ⇒ ⇒ ⇒ ⇒ AND THE SHAS ABOVE ARE THE REBASED ONES: = = the
scope was reviewed at `8c23920948`, = = and the branch was rebased onto
a main that another lane had moved (= = 22 commits, = = = = the
flow-gates scope), = = so a rebase rewrote the five shas and NOT the
edit (= = and the card that reviewed the edit still covers the branch).
⇒ ⇒ ⇒ The scope's §9 landing table names them per requirement.

## 8. WHAT WAS NOT TOUCHED

- The card's RADIUS (= 8 PT) is unchanged. The audit's own list names
  Apple's measured card radius (= 16 PT) as a separate item, = = and the
  boss did not ask for it in this scope.
- The three pages' GROUPS (= = the board page's `DisclosureGroup`
  accordions, = = the status page's and the plan page's flat lists) are
  unchanged. ⇒ ⇒ ⇒ The boss asked what Apple's grouping styles are
  available (= = the answer is in the card's body, = = and it is a
  separate scope).
- No third-party Liquid Glass clone was added (= = the repo's own gate
  still holds), = = and no glass was introduced anywhere.

## 9. THE LANDING TABLE

| The requirement this scope carried | The commit that carries it | The proof the tree holds |
| --- | --- | --- |
| the card's background is the column's own bottom-bar material | `b63fef355f` | the card's background is the shared `ContentAreaMaterial`, = and the band wears the same door (= = one recipe, = = two consumers) |
| the coloured leading band is gone | `b63fef355f` | the 2 PT band and its token are deleted, = = and the 16 PT marker column stays |
| the card that opens is a button, = = so the whole card answers the click | `9a2b6fd827` | `Button(action: onOpen)` + `.buttonStyle(.plain)`, = = and the focus ring, = = Return, = = and the VoiceOver role come from the system |
| the whole card answers the hover | `9a2b6fd827` | the wash paints OVER the material, = = wears the card's own corner, = = and covers 92% of the card's pixels (= = and the tracking area is on the control, = = so it cannot flicker) |
| the pointer says "this opens" and the words are not selectable text | `9a2b6fd827` | `.pointerStyle(.link)`, = and `textSelection` = 0 hits in the card and in all three pages |
| the record carries the card's own numbers, = = each with its sampling point | `bc993bf06f` | `markdown-newline` and `nfi-loc-check` exit 0, = = and no name carries two values |

⇒ ⇒ ⇒ AND THE PUSH CARRIED COMMITS THAT ARE NOT MINE. = = The GitHub
mirror was 22 commits behind the primary remote when this scope landed
(= = the flow-gates scope, = = another lane's, = = landed to the primary
remote while this scope was in review), = = so the push to that mirror
carried them too: = =

= = 90afbf444d feat(devtool): add the plan-of-record gate and its suite
= = ed9699e9ce feat(devtool): the verdict is the hand-off, and the process data stays on the data disk
= = a3395fa831 fix(devtool): the two gates read the board slug from product_lines, not a literal
= = 0f24a283b1 feat(tools): the closeout gate fires on the scope's state, not on a keyword
= = 2563d13cb3 feat(devtool): the flow's rules become gates, and the process data stays on the data disk
= = 868f581669 fix(devtool): the two gates read the card's gate the same way
= = 315d1b9103 test(devtool): the gates' agreement about a card's gate is pinned
= = be63281946 fix(devtool): the shared reader reads a wrapped command as one command
= = ab57bbc45c test(devtool): a wrapped command is one command, and it is pinned
= = a7ef754a09 docs(agents): the flow's rules name their gates, and the landing moves main by compare-and-swap
= = 08194f914c feat(devtool): the hand-off contract is on the card's dispatch path
= = f7fee95817 docs(agents): the flow-gates scope's closure record
= = b63cbf6e86 docs(agents): the registry knows this wave's files, and the index finds them
= = 48a915782b docs(agents): the closure record carries the registration's own line
= = f7192ac496 docs(agents): the closure record's own row carries its own count
= = 95a913f662 fix(devtool): the process-data gate watches the scratch that actually happens
= = 76d7b3ebe6 docs(agents): the closure record names the scratch that actually happens
= = fbe3a104b7 docs(agents): three rows carry their files' own counts again
= = 213cd47253 fix(gates): the flow-gates review's three blockers and six findings close here
= = 0d99bbf347 fix(gates): the board has ONE reader, and a refusing lane still reads it
= = 08f100ba18 docs(oob): the boss's three out-of-band rulings of 2026-11-24 enter the register
= = 3c29ff6598 test(gates): the suite battery runs from the tree, one honest exit code per suite

⇒ ⇒ ⇒ They are NOT this scope's work, = = and they touch no file this
scope wrote (= = only the registry, = = whose key-level merge kept both
lanes' rows).
