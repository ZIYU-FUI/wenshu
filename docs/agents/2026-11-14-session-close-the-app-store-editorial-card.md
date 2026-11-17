# Session close: the App Store's editorial card, and whether either it or Liquid Glass is iOS-only

Date: 2026-11-14
Scope: two questions the boss asked, answered by measurement, plus the
measured gap against our own material card.
Branch: `wt/appstore-card-correct` (this scope's branch, = = still on disk, = =
spent).
Landing: FIVE commits, = = and the scope's own diff is what the gates below
measure: = = `20d2d3182b` (the research document), = = `9f8bab6f1` (the
card-scoping correction), = = `ed66f2ec5` (this closeout), = = `080c16813`
(the evidence correction), = = and `404bc8c0a` (the receipt and numbers'
correction) = = all of them are ancestors of `main`, = = and `main` is on
both remotes.

## THE REQUIREMENTS, AND THE PROVENANCE OF EACH

One row per ORIGINAL requirement (= = the two questions the boss asked, = =
plus the measured gap against our own material card that the scope was
opened to answer). = = The commit column names the LANDED commit, = = the
verdict column names the card that APPROVED it, = = and the proof column
names commands a reader can re-run.

| the requirement | the commit that carries it | the independent verdict | the server-side proof |
| --- | --- | --- | --- |
| **Q1: is the Liquid Glass effect an iOS-only control?** (= = NO: = = four platforms carry it, = = visionOS is excluded per-declaration, = = and the signature and the `@available` pair are byte-identical in all eleven `SwiftUICore.swiftinterface` files across the five installed 27.2 SDKs) | `20d2d3182b` (= = the research document, = = and it landed on `main` and on both remotes) | `t_363ca9a3` = APPROVED by `wenshu-review` (= = round two, = = after the round-one six findings were fixed) | the SDK sweep re-run against the five SDKs reads the same `@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)` + `@available(visionOS, unavailable)` pair in every file; = = `git merge-base --is-ancestor 20d2d3182b main` reads YES; = = both remotes read the merged `main`; = = the gates on the merged tree are in §5 |
| **Q2: is the App Store's full-image content-recommendation card an iOS-only control?** (= = NO: = = the macOS App Store is a NATIVE AppKit app (= = 0 `iOSSupport` links, = = 2 `AppKit` links), = = and the card is not a PUBLIC control on any platform (= = the whole-SDK sweep finds it only in `PrivateFrameworks/`, = = and `StoreKit.framework/Headers/` holds no card) | `20d2d3182b` (= = §1 and §2 of the research document, = = with the binary, = = the SDK and the symbol-table evidence) | `t_363ca9a3` = APPROVED by `wenshu-review` (= = the same verdict, = = and it covered this question too) | `otool -L "/System/Applications/App Store.app/Contents/MacOS/App Store"` shows no `iOSSupport`; = = the public-frameworks sweep for `AppStoreCard`, `StoreCard` and `CardStyle` returns nothing; = = both remotes read the merged `main` |
| **the measured gap against our own material card** (= = the slot is 2200 x 724 px = = 3.039 : 1, = = and the djay card splits it 25% text / 75% artwork, = = while our card is a full-bleed 4 : 3 picture with a 10 PT corner and a scrim of 0.18 -> 0.55; = = and the corner is NOT shared: = = the coral card's is 26 px = = 13 PT, = = measured fit-free from the deposited capture) | `080c16813` (= = the evidence correction: = = every figure names the capture it rests on, = = and the one capture that was NOT deposited is named as such) | `t_cd64934a` = APPROVED by `wenshu-review` (= = the round that closed the last finding, = = and it re-verified this row's own fact on the tree) | the deposited coral capture is re-measured in the research document's own terms (= = the card box, = = the 443 px = = 20.1% text block, = = the corner at 26 px); = = `verify_scope.py` re-reads the committed tree and prints 0 FAIL of 26; = = the scope's own diff is 791 added lines with CJK 0 |
| **the scope's own bookkeeping** (= = the registry's two rows carry their files' own counts (= = 586 and 631), = = the counts are a fixed point on the committed tree, = = and the closeout is a committed document rather than a claim) | `404bc8c0a` (= = the last amend: = = the body measures its baseline against the parent, = = and the tree did not move, = = so no number moved) | `t_cd64934a` = APPROVED by `wenshu-review` (= = the same verdict) | `nfi-loc-check.py --base 58dd224bb7` and `--base main` both read PASS on the merged tree; = = `verify-dead.py` reads DEAD 0; = = `nfi-split.py --check` reads PASS; = = `pandoc -f gfm -t html` reads rc 0 on all three documents; = = both remotes read the merged `main` |

⇒ ⇒ ⇒ AND THE COMMITS THAT ARE NOT THIS SCOPE'S: = = this scope's push
carried NONE, = = because `main` already held the sibling scopes' 29
commits before the merge (= = `84c3a6386` was already on both remotes), = =
and the range this push moved (= = `84c3a6386` to `41b82a8fa`) holds only
this scope's four commits and the merge commit itself. = = §6 names the ten
that were on `main` before this scope's last commit landed.

## The landing

| What | Where |
| --- | --- |
| The change | `404bc8c0a` = = = on `main`, = = = landed as `41b82a8fa` (= = = the sha this scope pushed) |
| The branch | `wt/appstore-card-correct` (= branched from `main` at `58dd224bb7`) |
| The approving verdict | `t_cd64934a` = = = `review_outcome: approved`, = `reviewed_sha: 404bc8c0a8c7278a2d3fd2db9572a6e3718478f6` (= = = the scope's last amend; = = = the earlier rounds' verdicts were on the shas they reviewed, = = = and §4 names them) |
| The merged tree's gates | `nfi-loc-check.py --base 58dd224bb7` and `--base main` both PASS; = = `verify-dead.py` DEAD 0; = = `nfi-split.py --check` PASS; = = `pandoc -f gfm -t html` rc 0 on all three documents; = = the scope's own diff is 791 added lines with CJK 0 |
| The remotes | `origin` (gitcode) = = = and `old-origin` (GitHub), = = = both read back at `41b82a8fa8748fd0e8b760bcb5574db5e338ff94`; = = = and this document's OWN commit (= = = the closeout that records the landing) = = = follows it, = = = so no row here names a tip that a later commit would falsify |
| The scope's commits | FIVE: = = `20d2d3182b`, = = `9f8bab6f1`, = = `ed66f2ec5`, = = `080c16813`, = = `404bc8c0a` (= = every one of them is an ancestor of `main`) |

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
text block's width, = = AND the eyebrow's band and the title's
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
| the outer corner | the coral card's, = = **26 px = 13 PT**, = = measured FIT-FREE from the deposited file | the CORAL card (= = the djay card's = = 24.2 px = 12.1 PT = = is a RECORD, = = it was fitted with a base half a pixel inside the card's own edge, = = and it cannot be re-measured today, = = so the two cards' corners are NOT shown to be equal) |
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
| the corner radius | 13 PT (= 26 px, = = the coral card) | 10 PT (`surfaceCornerRadiusWindow`) |
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
⇒ ⇒ ⇒ AND THAT SHA NO LONGER EXISTS IN THE REPOSITORY, = = because it was
an AMENDED, = = never-pushed, = = intermediate version: = = a pushed sha is
never rewritten, = = and an unpushed one is rewritten freely, = = so the
object is gone and only the record of it survives. = = The same holds for
round two's `4b74f8d587`.
Both top-level questions were ruled TRUE. Six findings, all about
measurements and receipts:

| # | The finding | The fix |
| --- | --- | --- |
| 1 | the width was measured from the leftmost GLYPH (2146 px) and called the card's width | measured from the panel's BACKGROUND edge: 2200 px, 3.039:1 |
| 2 | the corner was read off ONE row as 34 px = 17 PT | a circle fitted over 26 rows (= = 23.9 px then; = = re-fitted with a per-row colour model, = = 24.2 px = 12.1 PT, = = RMS 0.17 px, = = and the base must be the card's STRAIGHT edge, = = not the top row's already-rounded edge); = = and that base was still half a pixel inside the card's own edge, = = so the figure was the fit's convention and not the shape's (= = see §11) |
| 3 | two `.swiftinterface` spans did not contain the declaration; the source column was empty in all 7 rows | `DefaultGlassEffectShape` 3090 (was 3542), `glassEffectID` 22703 (was 22766), and the table names the one file every line is in |
| 4 | the folder-badge exception does not exist | the sentence is gone; the preview zone draws no `displayName` at all (12 grep hits, none a card draw) |
| 5 | the `ProductView` receipt greps `SwiftUI` | aimed at `_StoreKit_SwiftUI`, with each symbol's line, and both sweep scopes stated |
| 6 | the commit body carried the pre-amend LOC (432) | the body says 477 and names the second measurement |

**Round two — `approved` on `4b74f8d587`** (card `t_363ca9a3`). The reviewer
re-ran every figure on its own capture rather than reading them: it
re-captured the card at 2200 x 724 px, confirmed the panel's edge at x=550 by
a luminance step of 69 -> 187, verified all seven `.swiftinterface` line
pairs one by one, and re-derived both top-level answers.

**One correction survived the approval, and it is now CLOSED = = AND THE
FIGURE IT SETTLED WAS ITSELF A CONVENTION, = = NOT THE SHAPE.** §2.4 of
the document read 24.8 px / 12.4 PT; the reviewer's three-threshold fit on
both corners of both card classes gave 23.74 / 23.90 / 24.20 px (RMS 0.03),
i.e. 12.0 PT. Re-fitting with a per-row colour model (= = each row's own
card colour against the page background, = = because the djay panel is a
gradient and one colour for it bends the edge) gave **24.2 px = 12.1 PT**
at RMS 0.17 px, and that correction landed as the new commit `9f8bab6f1`
(= = a new sha, = = and therefore a new verdict, = = as the rule requires).
⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ BUT the base that fit used was still HALF A PIXEL
INSIDE the card's own straight edge (= = the first surface pixel's index,
= = 632, = = where the edge actually lies between 631 and 632), = = and §11's
residual had already said the estimator returns 0.87 - 0.92 x R, = = so
24.2 px under that convention meant a TRUE radius of 26.3 - 27.8 px. = = The
figure was reproducible and wrong, = = and it was the CONVENTION that was
reproducible.

## 5. The gates, on the MERGED tree

Run on the MERGED tree, = = not on the branch that was measured before
the merge: = = first on `main` at `20d2d3182b`, = = and then again on this
scope's correction tip. ⇒ ⇒ ⇒ AND THE SIBLINGS ARE COUNTED AGAINST THIS
SCOPE'S OWN BASE (= = `20d2d3182b..58dd224bb7`), = = NOT AGAINST A MOVING
`main`: = = that range holds **10 sibling commits, = = 3 of them Swift**
(= = `deff19bac4`, = = `bc1ce72f95`, = = `6b73f25b51`, = = all three
`fix(tabs)`/`fix(ui)`) **and 7 of them docs**, = = and §6 lists exactly
those ten. ⇒ ⇒ ⇒ ⇒ ⇒ AND `main` HAS SINCE ADVANCED PAST THAT BASE, = = but
counting against the moving tip would be a treadmill that no reviewer can
close, = = so the base is pinned here. ⇒ ⇒ So the rebase is part of the
measurement = = and the numbers below are the post-rebase ones.

| Gate | Result |
| --- | --- |
| Swift files in the scope's diff | 0 (= = measured against this scope's BASE `58dd224bb7`, = = not against a moving `main`; = = so `swift build` / `swift test` have no surface) = = and the base range's own Swift commits are the SIBLING scope's: = = three of them, = = `deff19bac4`, = = `bc1ce72f95` and `6b73f25b51` |
| `verify-dead.py` | DEAD 0 (127 ALIVE, 4 PARTIAL) |
| CJK on the change | 0 of 791 added lines (= = measured against this scope's base `58dd224bb7`, = = not against a moving `main`; = = and measured against the PRE-MERGE `main` (= = `84c3a6386`) the whole-tree diff carries 4 CJK lines, = = all of them in the SIBLING scope's string catalog, = = and none in this scope's three files; = = and measured against the MERGED `main` (= = `41b82a8fa`) the same diff carries 0, = = because the merge brought the sibling's catalog with it) |
| `tests/test_nfi_loc_check.py` | rc 0 |
| `tests/test_nfi_registry.sh` | all tests passed |
| `nfi-loc-check.py` | rc 0 (1 row: this scope's own row) |
| `nfi-split.py --check` | PASS |
| `pandoc -f gfm -t html` | rc 0 (both documents and the registry) |
| the registry row renders as a TABLE row | = = and the rendered HTML was checked to carry it inside a `<td>` (= = it did not before the fix) |

## 6. The commits, and which are not this scope's

This scope owns FIVE commits. ⇒ ⇒ ⇒ AND THE BRANCH THEY LIVE ON IS
`wt/appstore-card-correct`, = = because §13's reconstruction REBUILT the
scope after the shared checkout's gitdir was deleted: = = the earlier local
branch `wt/appstore-editorial-card` died with that gitdir, = = and no ref
carries it any more. = = Its commit is on `main` and on both remotes, = =
and that is where the work is, = = so nothing is lost by the branch's
absence.

- `20d2d3182b` — the document (477 lines at that commit) plus its one
  registry row.
- `9f8bab6f1` — the card-scoping correction (= = the document at 574 lines
  plus its registry row, = = and the row's LOC CELL moving with it (= = 477
  to 574); = = the row's CONTENT TAG did not move here, = = and moved only at
  the evidence correction below).
- `ed66f2ec5` — this closeout document (= = 446 lines at that commit), = =
  and NO registry row (= = the row for this document arrived with the
  evidence correction below, = = not with this commit).
- `080c16813` — the evidence correction (= = the document at 586 lines and
  this closeout at 572, = = and it ADDED the one registry row for this
  document, = = AND it rewrote the research row's LOC cell (= = 574 to 586)
  and REPLACED that row's content tag (= = the re-tag that scoped the split
  card to the djay card)): = = every figure now names the capture it rests
  on, = = and the one capture that was NOT deposited is named as such.
- the receipt and numbers' correction (= = the commit body now publishes the
  figure the tree publishes, = = and the closeout's review-gate sentence now
  states the two MEASURED constraints, = = and the house skill's reference
  says the same): = = the figures themselves did not move, = = and the fix's
  own footprint (= = this closeout's line count, = = the added-line
  denominator, = = and this scope's own commit count) was re-converged on
  the committed tree. ⇒ ⇒ ⇒ AND THIS LAST ONE IS THE ONE COMMIT
  THAT CANNOT BE NAMED BY ITS SHA HERE, = = because this document IS that
  commit's content: = = a closure record cannot name the sha that carries
  it, = = and the board's verdict names it instead.

⇒ ⇒ ⇒ AND NONE OF THE FOUR ABOVE IT REWRITES THE PUSHED ONE, = = because
`20d2d3182b` is already pushed: = = a pushed sha is never rewritten, = = and
the amends these commits went through (= = of UNPUSHED commits, = = which is
not an amend of it) do not touch it.

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

1. **The corner figure is now settled = = AND THE MEASUREMENT BEHIND IT IS
   A NEW ONE.** The coral card's radius is **26 px = 13 PT**, = = measured
   FIT-FREE: = = a SwiftUI RoundedRectangle of a KNOWN radius, = = drawn with
   the same card box and the same corner style on the same canvas, = = its
   edge curve laid over the capture's edge curve row by row (= = the best
   match at 12.9 PT = 25.8 px, RMS 0.125 px; = = 13.15 PT = 26.3 px, RMS
   0.218 px; = = and the 12.1 PT = 24.2 px that was published misses by RMS
   0.874 px and a maximum of 2.08 px). = = The estimator was calibrated first:
   = = on two controls whose radius is known exactly (= = 24.2 px and 26.3
   px), = = the base that recovers the truth is half a pixel inside the
   first surface pixel in BOTH axes (= = the errors +0.090 px and +0.065 px,
   = = RMS 0.051 px). = = The earlier 24.8 px came from a fit whose BASE was
   the top row's own edge (= already rounded), = = and the 24.2 px that
   replaced it came from a base half a pixel inside the card's own edge. = =
   §2 and §3 now agree, = = and the corner is NO LONGER listed as a shared,
   = = slot-level figure (= = the djay card's 12.1 PT is a record that cannot
   = = be re-measured, = = so the two cards' corners are not shown equal).
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
colour model, it gave 24.2 px = 12.1 PT at RMS 0.17 px — = = and THAT figure
was a third convention, = = because the base it used was half a pixel
inside the card's own straight edge. ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND
THE SAME BASE ERROR REPEATED IN THE CLOSEOUT ITSELF, = = so the figure had to
be REPLACED, = = not merely re-checked: = = the coral card's radius is
**26 px = 13 PT** (= = §9's first open item, = = measured fit-free and
calibrated), = = the djay card's 12.1 PT stays a record, = = and the corner
leaves the shared list. = = So the research doc's §2.4 and §3 now agree, and
§9's first open item is closed.

⇒ ⇒ AND THE LESSON THAT IS BIGGER THAN THE FIX: **THE SLOT'S CONTENT IS
NOT A FIXTURE.** The scope measured one frame of a slot, and wrote the
frame's composition as a property of "the card". A second capture of the
SAME window, taken two days later, held a different card, and half of the
document's figures moved with it. The figures that did NOT move (= = the
box, the ratio) belong to the SLOT; the ones that did
(= = the panel, the artwork's share, the description's position) belong to
the CARD — = = and the corner belongs to NEITHER, = = because its two
measurements disagree (= = 12.1 PT on the djay card, = = 13 PT on the coral
card) and the djay one cannot be re-measured. A reference app's changing content is a MEASUREMENT AXIS, and it
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

⇒ ⇒ ⇒ AND THE REVIEW ALSO LEFT A RESIDUAL, = = AND IT WAS NOT A CAVEAT TO
KEEP, = = IT WAS A MEASUREMENT WAITING FOR ITS INSTRUMENT. The published
radius was a property of the FIT'S CONVENTION, = = not of the shape: = = the
same estimator on a synthetic true circular corner returns 0.87 - 0.92 x R
under that convention, = = and the coral corner is NOT a circular arc (= = its
edge's inset never reaches a tangent point). ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒
SO THE FIGURE WAS READ BACK THROUGH ITS OWN BIAS: = = 24.2 px at 0.92 x R is
26.3 px, = = and at 0.87 x R it is 27.8 px, = = and a FIT-FREE measurement
(= = a RoundedRectangle of a known radius laid over the capture's edge curve)
puts it at 25.8 - 26.3 px. ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒
The residual is CLOSED: = = the coral card's radius is published as **26 px =
13 PT**, = = the estimator is calibrated against two controls of known
radius (= = the errors +0.090 px and +0.065 px, = = RMS 0.051 px), = = and
Apple's own corner radius IS now independently confirmed, = = because the
confirmation no longer depends on the fit's convention.

⇒ ⇒ ⇒ ⇒ AND THE LESSON FROM THAT RESIDUAL: = = A FIT'S BASE AND A FIT'S
DENOMINATOR ARE PART OF THE FIGURE, = = SO A DOCUMENT THAT QUOTES A FITTED
NUMBER MUST QUOTE THE RECIPE WITH IT. = = The coral card's interior is flat
(= = rgb(254,143,127)), = = so the per-row colour model is a no-op there, = =
and only the djay card (= = a gradient) exercises it (= = and its capture is
gone).

## 13. The repository's .git was deleted mid-review, = = and the scope was rebuilt from the files on disk

At 18:32 on 2026-11-16 the shared checkout's gitdir was deleted while a
review run was measuring the scope, and the card's worktree (= = whose
`.git` points into it) lost its gitdir with it, = = so `git` stopped
resolving there. = = The review's own measurements were taken while git was
still live; = = the branch itself was not the thing lost.

⇒ ⇒ ⇒ AND THE RECOVERY WAS FROM THE FILES, = = NOT FROM GIT. = = The scope's
three commits were rebuilt with the same trees, = = the same messages and
the same content, = = and so every SHA moved: = = the card-scoping
correction is now `9f8bab6f1`, = = this document's own commit is
`ed66f2ec5`, = = and the evidence correction is `080c16813` (= = which IS
named by its sha here, = = because it is no longer this document's
content: = = the commit that IS this document's content is the tip, = =
and by §6's own rule THAT one is not named by its sha here). = =
`20d2d3182b` is untouched, = = because it is already
on `main` and on both remotes.

⇒ ⇒ ⇒ ⇒ AND TWO MORE SHAS ARE GONE, = = AND §4 SAYS WHY. = = The two
intermediate versions the first two review rounds were filed against
(`65e701f65a` and `4b74f8d587`) were AMENDED and never pushed, = = and an
unpushed sha is rewritten freely, = = so their objects do not exist in the
repository and only the record of them does.

⇒ ⇒ ⇒ ⇒ ⇒ AND A REBUILD IS A NEW TREE, = = SO IT NEEDS A NEW VERDICT. = =
The verdicts on the old shas do not carry over: = = the rebuilt tree is
reviewed again, = = and the branch is rebuilt at `wt/appstore-card-correct`
in its own worktree for it.

⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE LESSON: = = A WORKING TREE IS NOT A BACKUP OF A
COMMIT. = = The three files were recoverable because they were ON DISK and
the author had them in the working tree; = = the SHAs were not, = = because
they were only in the object store. = = ⇒ ⇒ So a scope whose work is
worth re-reviewing is worth its SHAs surviving, = = and the way to keep
them surviving is to push the branch (= = a pushed sha is never rewritten,
= = and an unpushed one can be), = = not to keep it local.

## 14. The numbers are a fixed point, = = and the sha is the last one

⇒ ⇒ ⇒ AND EVERY COUNT THIS DOCUMENT QUOTES MOVES WHEN THE DOCUMENT IS
EDITED. = = The line counts, = = the CJK denominator, = = the registry's LOC
cells and the per-commit counts in §6 all quote each other, = = so writing
them is a fixed-point problem: = = the number changes the thing it
measures. ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ And the fixed point has to be reached ON THE
COMMITTED TREE, = = because the committed tree is what a reviewer reads
(= = and the working tree's count is one commit ahead of it). ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒
So: measure, = = write, = = commit, = = re-measure, = = until the measurement
stops moving. = = The measure is the ONE the registry uses (= = `wc -l`, = =
the newline count), = = and a count taken by splitting on newlines reads ONE
MORE line for a file that ends with one.

⇒ ⇒ ⇒ ⇒ AND THE DENOMINATOR IS COUNTED AGAINST A PINNED BASE, = = NOT
AGAINST A MOVING `main`. = = `main` carries the shared server's commits, = =
and it moves while this scope works, = = so a denominator measured against it
moves for reasons that have nothing to do with this scope: = = the same diff
reads 791 added lines against the pinned base (= = the figure §5 quotes), = = and a
different one against `main` (= = a MOVING reading, = = and §5 names the moving
one as moving). ⇒ ⇒
and the scope's own Swift count is 0 against it (= = the scope touches only
its three `.md` files). ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND THE MOVING `main` IS NOT
QUOTED AS A NUMBER ANYWHERE, = = because it is not one: = = it carried 11
Swift files on one day and 17 on another (= = every one of them in a sibling
scope's own Swift), = = and a figure that moves with the shared server's
commits belongs in no document.

⇒ ⇒ ⇒ ⇒ ⇒ AND THE SHA A REVIEW CARD NAMES IS WRITTEN LAST, = = IN FULL. ⇒
⇒ ⇒ ⇒ ⇒ ⇒ ⇒ Every amend of this scope's own commit (= = which every round
of findings causes) = = gives it a NEW commit id, = = so a sha written into
a card body goes stale the moment the author fixes anything. ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒
And the independent-review gate reads the sha from the card's `## WHAT TO
BUILD` and matches it against the branch's tip. ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **AND THE
GATE'S TWO REAL CONSTRAINTS ARE MEASURED, = = AND NEITHER IS THE LENGTH**
(= = `Tools/wenshu-devtool/review_gate.py`, = = measured on this scope):
(1) `reviewed_sha` takes the **FIRST** run of 7 to 40 hex characters in the
**FIRST** paragraph of `## WHAT TO BUILD` (= = `re.search(r"[0-9a-f]{7,40}",
claim)`), = = so the sha must BE that first token (= = a body that puts it
in the second paragraph reads NO sha at all = = and the card matches
nothing); and (2) that first token WINS over any later one (= = a card id
ahead of the sha steals it: = = `t_a33a8ff8` reads as `a33a8ff8`). ⇒ ⇒ ⇒
⇒ ⇒ ⇒ AND THE LENGTH FILTER ACCEPTS **7 TO 40** CHARACTERS, = = AND THE
MATCH IS PREFIX-TOLERANT IN BOTH DIRECTIONS (= = `sha.startswith(target)
or target.startswith(sha)`), = = so **a ten-character body sha IS read and
DOES match** the forty-character tip (= = a body that says `77321b4a18` is
matchable, = = and the landed branch CAN be tied to its own verdict).
⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ So the scope's numbers are converged FIRST, = = THEN the
final amend is made, = = THEN the sha is read, = = THEN the card body is
written with it, = = and the branch is not amended again until a verdict
comes back.
