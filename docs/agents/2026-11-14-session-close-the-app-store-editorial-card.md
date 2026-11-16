# Session close: the App Store's editorial card, and whether either it or Liquid Glass is iOS-only

Date: 2026-11-14
Scope: two questions the boss asked, answered by measurement, plus the
measured gap against our own material card.
Branch: `wt/appstore-editorial-card` (landed; = = the branch is still on
disk, = = spent but NOT deleted, = = and this document does not claim
otherwise), = = and `wt/appstore-card-correct` (this scope's correction
branch, = = still on disk).
Landing: `20d2d3182b` on `main`, on both remotes, = = and on top of it this
scope's card-scoping correction `e0c06f55ed`.

## 1. The questions, and the answers

**Q1 — is the Liquid Glass effect an iOS-only control? NO.**

The SwiftUI glass surface is one API with four platform availabilities and
one exclusion. All seven declarations the document names carry the same pair
of lines in every one of the eleven `SwiftUICore.swiftinterface` files across
the five installed 27.2 SDKs (iOS 1, macOS 4, tvOS 2, watchOS 3, visionOS 1):

```
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@available(visionOS, unavailable)
```

The visionOS SDK's OWN interface carries `visionOS, unavailable`, so the
exclusion is per-declaration, not per-SDK. There is no platform on which the
signature or the annotation differs.

**Q2 — is the App Store's full-image content-recommendation card an iOS-only
control? NO, and it is not a public control on ANY platform.**

- The macOS App Store is a NATIVE AppKit app: `otool -L` shows **0**
  `iOSSupport` links and **2** `AppKit` links, `file` reports
  `arm64e`, and `LC_BUILD_VERSION` reports `platform 1`. It is not a
  Catalyst app, so the card drawn on macOS is macOS's own, not iOS's.
- No public symbol draws it. The whole-SDK sweep for
  `AppStoreCard|StoreCard|CardStyle` returns 1 file across public frameworks
  (CoreTelephony, unrelated) and 11 files across all of `System/Library`
  (10 of them under `PrivateFrameworks/`). `AppKit.framework/Headers/` has
  zero `AppStore`/`StoreKit` hits. `StoreKit.framework/Headers/` holds 28
  entries (27 `.h` plus one `.apinotes`) and none is a card.
- StoreKit's SwiftUI views (`ProductView` :1252, `StoreView` :1337,
  `SubscriptionStoreView` :453, `ProductViewStyleConfiguration` :1623) live
  in `_StoreKit_SwiftUI`, and that interface holds **zero** hits for
  `editorial`, `artwork`, `card` and `Card`.
- The six private frameworks the card's UI lives in are not on disk (dyld
  cache only), so nothing there is linkable by a third-party app.

## 2. What the card actually is, measured on the running app

The capture: the App Store window at 1400 x 900 points,
`screencapture -x -l <window id>`, read at 3024 x 2024 pixels (2x).

**⇒ ⇒ ⇒ THE FIRST THING EVERY FIGURE BELOW BELONGS TO: THE SLOT'S CONTENT
IS NOT A FIXTURE, = = SO EACH FIGURE IS ONE CARD'S, = = NOT THE SLOT'S.**
Two captures of the SAME window (= = the same window id, = = the same
bounds, = = the same size) held DIFFERENT cards: = = the djay card on
2026-11-14, = = and a coral card on 2026-11-16, = = whose words sit at the
TOP LEFT of one flat surface, = = with an illustration beside them, = = and
with NO description band at the bottom. Both cards were measured with the
same instrument, and what is SHARED is named below (= = the OUTER box, the
corner, the text block's width, = = AND the eyebrow's band and the title's
first line's band, = = which land in the same place on both cards, = = to
same START), while what DIFFERS is one card's: = = the panel, the
artwork's share, the description's position, and the number of bands.

⇒ ⇒ ⇒ AND THE MECHANISM IS NOT CLAIMED, = = BECAUSE IT WAS NOT MEASURED:
= = 34 further captures of the same window over 19 minutes held the SAME
card throughout (= = 33 of them byte-identical), = = so the slot does not
advance on its own; = = it shows hover paging chevrons at its edges, = = so
it is PAGED. = = What the two captures two days apart establish is the
narrower fact this document relies on: = = the slot's content is not a
fixture, = = so a figure measured from one capture does not carry to
another. = = What changed in between was NOT observed, = = and this
document does not say what.

The djay card (2026-11-14):

| Measurement | Value | Which card |
| --- | --- | --- |
| the card | 2200 x 724 px = **3.039 : 1** (1100 x 362 PT) | both |
| the text panel | 550 px = **25.0%** of the card (275 PT) | the djay card only |
| the artwork | 1650 x 724 px = **75.0%** of the card, itself 2.279 : 1 | the djay card only |
| the outer corner | a circle fitted to the sub-pixel edge: **24.2 px = 12.1 PT** (RMS 0.17 px) | both (= = the coral card fits at 24.22 px, RMS 0.17 px) |
| the text tiers | eyebrow 13.4-16.6%, title 21.7-28.5%, title line 2 30.5-35.5%, description 90.2-93.4% down | the eyebrow's and the title's first line's bands START in the same place on both cards (= = to within 0.1%); = = title line 2 and the description's position are the djay card's |
| the coral card's tiers | eyebrow 13.4-16.4%, title 21.7-28.5%, description 33.8-37.2% down, = = and NOTHING in the lower 63% | the coral card (= = its description is here, at 33.8%) |

**⇒ ⇒ THE STRUCTURAL FACT, CORRECTED: THE DJAY CARD IS A SPLIT CARD, = = AND
ONE CARD IN THE SLOT IS NOT.** On the djay card the words live in their own
panel beside the image, and the description is pinned to the panel's BOTTOM
while the eyebrow and title sit at its TOP. On the coral card there is NO
panel (= = its surface colour is rgb(253,141,128) at the far left AND at
the far right, and its luminance is continuous across the djay card's old
boundary), the three tiers STACK at the top, and the card's lower 63%
carries nothing. So "the Apple card is a split card" is a statement about
ONE card in the slot, = = not about the slot. The AX tree agrees
independently about the tiers themselves: one `AXStaticText` per card whose
value joins three comma-separated fields, and the class metadata carries
`headingField`, `titleField`, `descriptionField` on `ArticleCardTextView`.

## 3. The gap against our material card

| Dimension | Apple's editorial card | Wenshu's material card |
| --- | --- | --- |
| where the words live | a separate panel (25% of the width) = = ON THE DJAY CARD; = = the coral card's words sit on one flat surface | ON the image, bottom left |
| the image's share | 75.0% (= = the djay card) | 100% (the picture IS the card) |
| the card's ratio | 3.039 : 1 | 4 : 3 (`coverTileRatio`) |
| the corner radius | 12 PT | 10 PT (`surfaceCornerRadiusWindow`) |
| the description | yes, pinned to the panel's bottom | **none** |
| the eyebrow (the category) | yes | **none** |
| the scrim over the words | none needed | a black wash, 0.18 -> 0.55 |

Three gaps, named:

1. **The summary is never drawn.** `CardSource.summary` exists and the model
   carries the text; a repo-wide grep for `source.summary` outside its own
   definition returns zero. One line to close.
2. **The category's NAME is never drawn.** `EntityType.displayName` exists;
   the card draws only its icon. One line to close.
3. **The words sit on the image.** This is the settled 2026-10-23 decision,
   taken against this same reference, and the document does not reopen it.

## 4. How the work was cleared

Two review rounds, both by `wenshu-review`, on two shas, and then a third
round on THIS document (= = the closeout's own review), which found four
defects in it and one in the registry row it had added. Those were fixed
before this document landed; the corrections are listed in §11.

**Round one — `changes_requested` on `65e701f65a`** (card `t_d2f6a55c`).
Both top-level questions were ruled TRUE. Six findings, all about
measurements and receipts:

| # | The finding | The fix |
| --- | --- | --- |
| 1 | the width was measured from the leftmost GLYPH (2146 px) and called the card's width | measured from the panel's BACKGROUND edge: 2200 px, 3.039:1 |
| 2 | the corner was read off ONE row as 34 px = 17 PT | a circle fitted over 26 rows (= = 23.9 px then; = = re-fitted with a per-row colour model, = = 24.2 px = 12.1 PT, = = RMS 0.17 px, = = and the base must be the card's STRAIGHT edge, = = not the top row's already-rounded edge) |
| 3 | two `.swiftinterface` spans did not contain the declaration; the source column was empty in all 7 rows | `DefaultGlassEffectShape` 3090 (was 3542), `glassEffectID` 22703 (was 22766), and the table names the one file every line is in |
| 4 | the folder-badge exception does not exist | the sentence is gone; the preview zone draws no `displayName` at all (12 grep hits, none a card draw) |
| 5 | the `ProductView` receipt greps `SwiftUI` | aimed at `_StoreKit_SwiftUI`, with each symbol's line, and both sweep scopes stated |
| 6 | the commit body carried the pre-amend LOC (432) | the body says 477 and names the second measurement |

**Round two — `approved` on `4b74f8d587`** (card `t_363ca9a3`). The reviewer
re-ran every figure on its own capture rather than reading them: it
re-captured the card at 2200 x 724 px, confirmed the panel's edge at x=550 by
a luminance step of 69 -> 187, verified all seven `.swiftinterface` line
pairs one by one, and re-derived both top-level answers.

**One correction survived the approval, and it is now CLOSED.** §2.4 of
the document read 24.8 px / 12.4 PT; the reviewer's three-threshold fit on
both corners of both card classes gave 23.74 / 23.90 / 24.20 px (RMS 0.03),
i.e. 12.0 PT. Re-fitting with a per-row colour model (= = each row's own
card colour against the page background, = = because the djay panel is a
gradient and one colour for it bends the edge) gives **24.2 px = 12.1 PT**
at RMS 0.17 px, and the coral card fits at 24.22 px at RMS 0.17 px. So the
radius is 12 PT, the two sections now agree, and the correction landed as
the new commit `e0c06f55ed` (= = a new sha, = = and therefore a new
verdict, = = as the rule requires).

## 5. The gates, on the MERGED tree

Run on the MERGED tree, = = not on the branch that was measured before
the merge: = = first on `main` at `20d2d3182b`, = = and then again on this
scope's correction tip (= = which sits on top of a sibling's Swift commit,
= = `deff19bac4`, = = and of 7 sibling doc commits, = = so
the rebase is part of the measurement = = and the numbers below are the
post-rebase ones).

| Gate | Result |
| --- | --- |
| Swift files in the scope's diff | 0 (so `swift build` / `swift test` have no surface = = the one Swift commit in the tree is the sibling's) |
| `verify-dead.py` | DEAD 0 (127 ALIVE, 4 PARTIAL) |
| CJK on the change | 0 of 569 added lines |
| `tests/test_nfi_loc_check.py` | rc 0 |
| `tests/test_nfi_registry.sh` | all tests passed |
| `nfi-loc-check.py` | rc 0 (1 row: this scope's own row) |
| `nfi-split.py --check` | PASS |
| `pandoc -f gfm -t html` | rc 0 (both documents and the registry) |
| the registry row renders as a TABLE row | = = and the rendered HTML was checked to carry it inside a `<td>` (= = it did not before the fix) |

## 6. The commits, and which are not this scope's

This scope owns THREE commits (= = and the branch
`wt/appstore-editorial-card` is still on disk: = = its commit is already on
`main` and on both remotes, = = so the branch is spent, = = but it was NOT
deleted, = = and this document does not claim it was):

- `20d2d3182b` — the document (477 lines at that commit) plus its one
  registry row.
- `e0c06f55ed` — the card-scoping correction (= = the document at 574 lines
  plus its registry row, = = the row's LOC cell and content tag moving with
  it).
- the evidence correction (= = the document at 574 lines and this closeout
  at 446, = = plus their two registry rows): = = every figure now names the
  capture it rests on, = = and the one capture that was NOT deposited is
  named as such.

⇒ ⇒ ⇒ AND THE LAST TWO ARE NEW COMMITS AND NOT AMENDS, = = because
`20d2d3182b` is already pushed: = = a pushed sha is never rewritten.

The push of `main` carried 10 commits that are NOT this scope's
work. They were on `main` before this scope's last commit landed,
and pushing them was maintenance of the shared server state, not
authorship:
- `58dd224bb7` — docs(agents): the scope's trace table, = = one row per commit with its verdict (sibling scope)
- `02721fd93f` — docs(agents): the final tree's gates, and the registry's count for it (sibling scope)
- `887146c3b4` — docs(agents): the registry rows carry the band's new counts and the blank title's rule (sibling scope)
- `3c9a7d0ee3` — docs(agents): the band fix's audit, the review round, and the blank title's rule (sibling scope)
- `6b73f25b51` — fix(tabs): a blank title is a character, and never the wide marker (sibling scope)
- `bc1ce72f95` — fix(tabs): a title with nothing in it is the marker, not an empty label (sibling scope)
- `4e701c3264` — docs(agents): the closeout names the two reference files the lessons landed in (sibling scope)
- `8c4a2b0ba0` — docs(agents): the strip's registry rows carry the new widths, = = and the closeout's own line count (sibling scope)
- `f32d61ed30` — docs(agents): the band regression is closed, = = and the round's gates are on the record (sibling scope)
- `deff19bac4` — fix(ui): the pane tab strip divides its column in the clamp band (sibling scope)

## 7. A lane defect found while landing, and its fix

The review lane produced **ten runs and no verdict** before it could be
cleared: one run timed out at 5422 s against a 5400 s cap, one was rate
limited after 3433 s, and eight died in about 60 s each with `exit 75` and
`rate_limited` (`owner admission settled failed`). The `minimax-cn` account
refuses a third concurrent worker while a sibling review and the authoring
session hold slots, so the card never got a turn long enough to read the
tree.

The fix is a board operation, not a work change:
`hermes kanban set-model t_d2f6a55c opencode-zen-free/deepseek-v4.1-flash-free
--provider magpie` repoints a card at the local gateway's free pool, which
has quota. The repointed run survived past the 60-second wall and produced a
verdict. Nothing about the reviewed subject changed: same branch, same sha,
same worktree, same eight checks.

**And a second lane defect, on the landing side.** `land_card.sh` step 1 can
print

```
UNREADABLE <branch>
         the review gate could not read the board
RESULT: SKIP (<card>) reason=NO_VERDICT
```

where `UNREADABLE` means the gate never looked at a verdict at all, so the
`NO_VERDICT` under it is an artefact of the failed read. The first invocation
of the landing printed exactly that and skipped; an identical foreground
re-run landed the branch. The lesson is in
`wenshu-pocock-workflow/references/landing-a-behind-branch.md`.

## 8. What was NOT measured

- **WHICH card was up in the slot.** This is the axis that voids §2, and it
  is obtainable in the SAME frame, SAME window, SAME size: the slot's
  content is not a fixture, and two captures two days apart held two
  different cards. Two cards were measured (the djay card and the coral
  card), and they differ inside the box, so the 25% panel and the
  bottom-pinned description are ONE card's, not the slot's. A third card
  may differ again. = = ⇒ ⇒ AND WHAT MOVED THE CONTENT WAS NOT OBSERVED:
  = = 34 captures over 19 minutes held the same card, = = and the slot
  shows hover paging chevrons (= = it is PAGED, = = not auto-advancing), = =
  so the change between the two days is a fact about the slot's content and
  not a claim about a mechanism.
- **THE DJAY CAPTURE WAS NOT KEPT, = = SO ITS FIGURES CANNOT BE RE-
  MEASURED.** The coral capture is a file (= =
  `wenshu-visual-audit/references/appstore-editorial-coral-card-2026-11-16.png`,
  = = in the `wenshu-visual-audit` skill's `references/`), = = and the coral
  figures were re-measured from that file after the fact (= = the card box,
  = = the text block's width, = = the three ink bands, = = the corner). The
  djay capture (2026-11-14) was a scratch file and was NOT deposited, = = so
  the djay half of §2 (= = the 25% panel, = = the artwork's 75% share, = =
  the title's second line, = = the bottom-pinned description) is the RECORD
  of that measurement and cannot be re-derived today. ⇒ ⇒ So a reader can
  re-run the coral half and must take the djay half on trust, = = and the
  doc's own figures now say so.
- The card's behaviour while scrolling, while a video card plays, and
  while the slot is PAGED to the next card. The captures are static frames.
- The card's appearance in the light appearance. The captures are the dark
  appearance.
- The card's geometry at a second window width. Apple's numbers move with the
  page's width, and one measurement cannot say whether 3.039:1 is a constant
  or a consequence of the 1400-point window.

So the OUTER ratios are ONE measurement at ONE size (= = and they repeat on
the two cards measured), the INNER figures are TWO cards' layouts, and a
decision to widen the tile must not rest on them alone.

## 9. Open items

1. **The corner figure is now settled**: re-fitted with a PER-ROW colour
   model (each row's own card colour against the page background, because
   the djay panel is a gradient and one colour for it bends the edge), the
   radius is **24.2 px = 12.1 PT** with RMS 0.17 px, and the coral card
   fits at 24.22 px with RMS 0.17 px. The earlier 24.8 px figure came from
   a fit whose BASE was the top row's own edge (= already rounded), so it
   measured the arc's span, not the radius. §2 and §3 now agree.
2. **Two cosmetic notes from the round-two reviewer**: the quote of the
   settled decision inserts an "and" the source line does not have, and
   `:4706` in the `SwiftUI` interface is the extension carrying
   `.glassProminent` rather than the member line.
3. **The three product questions the boss has not answered**: are the
   description and the category tier wanted (one line each), and is a wider
   tile or a circular variant wanted (a product decision, not a repair).
4. **The djay card's own capture is gone, = = so its figures are the record
   of one measurement and not a re-runnable one.** The slot is PAGED, = = so
   the djay card can be brought back (= = it is Apple's own content, = = not
   ours), = = and when it is, its capture should be deposited beside the
   coral one so both halves of §2 can be re-measured. Until then the
   asymmetry is stated in the research doc itself.

## 10. Lessons that went into the skills

- **`UNREADABLE` from the preflight is a board-read failure, not a verdict**,
  and the same command lands on the retry with nothing else changed.
  `wenshu-pocock-workflow/references/landing-a-behind-branch.md`.
- **A card in an Apple app is not a control**: verify the reference app's
  provenance (`otool -L` for `iOSSupport`/`AppKit`) before claiming a card is
  iOS-only, and check the interface the symbol would actually live in
  (`_StoreKit_SwiftUI`, not `SwiftUI`).
  `wenshu-apple-api-first` pitfall 23 and
  `references/a-reference-app-is-not-an-api.md`.
- **A width is measured from the surface's edge, not from its first glyph.**
  Measuring from the leftmost ink drops the panel's own leading padding
  (54 px here) and reproduces a figure that is not the card's width. Fit a
  circle for a corner radius rather than reading one row.
- **A MEASUREMENT WHOSE SOURCE IMAGE WAS NOT DEPOSITED CANNOT BE RE-RUN,
  = = AND A REVIEW THAT ASKS FOR A LIVE RE-MEASUREMENT CANNOT CLOSE.** The
  fifth review round ran eighteen times without a verdict, = = because its
  first check asked the reviewer to re-measure the LIVE slot, = = and the
  slot's content had moved on to a third card (= = Apple's, = = not ours).
  ⇒ ⇒ So the check must name the FILE to measure, = = and every capture a
  figure rests on must be deposited where the next reader looks (= = the
  skill's `references/`, = = not a scratch directory that gets pruned).
  `wenshu-visual-audit/references/a-carousel-is-not-a-fixture.md` and
  `hermes-kanban-dispatch-mechanism/references/a-card-that-never-gets-a-turn.md`.
- **A TIMED-OUT RUN IS A LOST RUN, = = AND WHAT IT MEASURED HAS TO BE
  CARRIED FORWARD BY HAND.** A review card's first run ended at
  `elapsed 5402s > limit 5400s` (= = two seconds over the cap) and was
  requeued; = = the fresh run had NO memory of it, = = so it began
  re-deriving the same measurements from scratch with the clock already
  spent. ⇒ ⇒ The board renders the comments into the worker's context ONCE,
  at spawn, = = so a comment written while a run is live reaches the NEXT
  run, = = not the one that is running. ⇒ ⇒ ⇒ So the handover comment must
  carry FOUR facts: = = the tip the last run measured (= = and the tip now),
  = = the artefacts the last run left (= = the paths), = = the NUMBERS that
  changed since (= = the denominators, = = the line counts, = = the counts
  a moving branch invalidates), = = and which checks are not that card's.
  `hermes-kanban-dispatch-mechanism/references/a-card-that-never-gets-a-turn.md`.

## 11. The third round, and what it found

This document was itself reviewed (`t_b2e7de05`), and the review came back
**CHANGES REQUESTED**. Four of its eleven checks failed, and the review
found a fifth defect that was not on its list. All five were confirmed
against the tree before anything was changed, and all five were fixed
before this document landed.

| # | The finding | The fix |
| --- | --- | --- |
| 1 | **the central claim was card-dependent**: a fresh capture of the same window held a DIFFERENT card (= = a coral one with no panel and no bottom description band), so "the Apple card is a split card" and the 25%/75% split describe ONE card, not the slot | §2 now names the card each figure belongs to, and carries the second card's own measurements (= = the same box, the same corner, a different inside) |
| 2 | **§8's list of unmeasured axes missed the one that voids §2**: which card was up | §8 now names it first, and says it is obtainable in the same frame, same window, same size |
| 3 | **§7's run counts were wrong**: the board records TEN runs with no verdict, and EIGHT of them at 60-61 s | §7 now says ten, and separates the 5422 s timeout, the 3433 s rate limit, and the eight 60 s deaths |
| 4 | **the branch claim was false**: the document said the branch was "landed and deleted", and it was neither deleted nor ever landed under that name | the header and §6 now say the branch is on disk, spent, and NOT deleted |
| 5 | **the registry row it had added did not render as a table row**: the row was appended AFTER the end-of-table comment, so `pandoc` rendered it as a paragraph of literal pipes (= = and no gate sees it: `nfi-loc-check.py` and `nfi-split.py` are line-based) | the row now sits as the last row of the table, before the comment, and the rendered HTML was checked to contain it inside a `<td>` |

And one thing the review did NOT find, which the re-measurement surfaced:
the corner figure was wrong in the ORIGINAL research doc, and the fix
itself was still wrong. The first fit took the top row's own edge as the
base (= = that row is already rounded), so it measured the arc's span
rather than the radius; the second fit fixed the base and still used one
colour for a gradient panel, which bends the edge. Fitted with a PER-ROW
colour model, the radius is **24.2 px = 12.1 PT** at RMS 0.17 px, and the
coral card fits at 24.22 px at RMS 0.17 px. So the research doc's §2.4 and
§3 now agree, and §9's first open item is closed.

⇒ ⇒ AND THE LESSON THAT IS BIGGER THAN THE FIX: **THE SLOT'S CONTENT IS
NOT A FIXTURE.** The scope measured one frame of a slot, and wrote the
frame's composition as a property of "the card". A second capture of the
SAME window, taken two days later, held a different card, and half of the
document's figures moved with it. The figures that did NOT move (= = the
box, the ratio, the corner) belong to the SLOT; the ones that did
(= = the panel, the artwork's share, the description's position) belong to
the CARD. A reference app's changing content is a MEASUREMENT AXIS, and it
belongs in the list of what was not measured, next to the scroll and the
appearance.

⇒ ⇒ ⇒ AND THE MECHANISM WAS NOT MEASURED, = = SO IT IS NOT CLAIMED:
= = 34 further captures of the same window over 19 minutes held the same
card (= = 33 byte-identical), = = and the slot shows hover paging chevrons,
= = so it is PAGED rather than auto-advancing. = = The fact the two
captures two days apart establish is the narrow one: = = the slot's content
is not a fixture. = = The review that caught this also caught the two
figures that were stale for the same reason (= = §5's CJK denominator and
the skill copies' drift), = = and all three are the same defect: = = a
number or a claim that was not re-read after the thing it describes
moved.

## 12. The fifth round, and the two values it found

The fifth review round (`t_c82584bb`) ran EIGHTEEN times without a verdict,
and the reason was in the card rather than in the review: its first check
asked the reviewer to re-measure the LIVE slot, = = and the slot's content is
Apple's and PAGES, = = so by then it held a third card (= = the MacBook Neo
one) and the djay card was not in it at all. = = The check was unclosable by
construction. = = So the round was replaced by two cards that measure the
DEPOSITED capture (`t_940ad123` and `t_5124c149`).

The first of them came back **CHANGES REQUESTED**, and its two blocking
findings were both real, = = and both were defects this scope had introduced:

1. **The scope published TWO values for the same coral description band**:
   `33.7% - 37.0%` in the table and `33.9% - 37.2%` in the paragraph that
   says those figures were re-measured from the deposited file. = = The
   reviewer's instrument (= = the longest run of rows whose max blue is at
   least 190 inside x 660..1201, = = read against the card's own 724 px)
   gives rows 537..561 = = **33.8% - 37.2%**, = = and it reproduces the
   eyebrow and the title with the SAME rule. = = The scope now publishes that
   one value, in the paragraph, in the table, and in this document.
2. **The scope published TWO text-block widths**: `20.0%` in the paragraph
   and `443 px = 20.1%` in the table. = = The file's block is **443 px =
   20.1%** under the rule the table's own x-range implies (= = a column
   counts when it carries at least four near-white pixels in the title rows),
   = = and no near-white threshold ends the block anywhere else. = = The
   scope now publishes that one value in both places.

Two further findings were consistency notes and are also fixed: the shared
bands' "to within 0.1%" is now said to be about the bands' START (= = the
eyebrow's ends differ by 0.2pp), = = and the djay title band is `21.7% -
28.5%` in BOTH documents (= = one of them said 28.6%).

⇒ ⇒ ⇒ AND THE REVIEW ALSO LEFT A RESIDUAL, = = WHICH IS RECORDED HERE
RATHER THAN FIXED, = = BECAUSE IT IS NOT A DEFECT OF THIS SCOPE'S FIGURES:
the published radius is a property of the FIT'S CONVENTION, = = not of the
shape. = = The same estimator on a synthetic true circular corner returns
0.87 - 0.92 x R under this document's convention, = = and the coral corner
is NOT a circular arc (= = its edge's inset never reaches a tangent point),
= = so "the radius is 12 PT" is a statement about the recipe, = = and
Apple's own corner radius cannot be independently confirmed from the
capture. = = The figure itself reproduces (= = 24.233 px at RMS 0.159), = =
so the round's check PASSED it.

⇒ ⇒ ⇒ ⇒ AND THE LESSON FROM THAT RESIDUAL: = = A FIT'S BASE AND A FIT'S
DENOMINATOR ARE PART OF THE FIGURE, = = SO A DOCUMENT THAT QUOTES A FITTED
NUMBER MUST QUOTE THE RECIPE WITH IT. = = The coral card's interior is flat
(= = rgb(254,143,127)), = = so the per-row colour model is a no-op there, = =
and only the djay card (= = a gradient) exercises it (= = and its capture is
gone).
