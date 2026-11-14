# The toolbar and the body read as two planes (= the session close-out)

## 1. WHAT THE BOSS ASKED

Two things, in one wave (2026-11-13 / 2026-11-14):

1. The window's toolbar strip and the body read as ONE undifferentiated plane, = so
   the toolbar's lower edge has no separator.
2. The editor zone's document strip and the chat zone's session bar close their
   bands differently from the three column-top bands that already closed theirs.

The second one is the same defect seen from a different column: the rule that
closes a band lived in each door separately, = so the doors drifted.

## 2. THE SYMPTOM

Measured on the app's own window (the base build, = `b33605b82b6b`):

- the toolbar's lower edge read **37.0** at 52.0 PT (= the titlebar's surface
  steps into the body's surface with no line between them), and the same row
  carried no line in any column;
- the three column-top bands (the sidebar's switcher band, the assets column's
  search band, the inspector column's page band) closed theirs at 79.0 PT,
  = and the editor zone's document strip and the chat zone's session bar did
  not close theirs at all.

## 3. THE ROOT CAUSE (TWO OF THEM)

### 3.1 The edge was never drawn

There was no owner for it. `ChromeTopBar.swift` drew its own inline
`.overlay(alignment: .bottom) { Divider() }`, = and the other doors drew
nothing.

### 3.2 Apple's own parameter for the window's edge paints nothing here

`NSWindow.titlebarSeparatorStyle` (= `NSTitlebarSeparatorStyle`:
`.automatic`, `.none`, `.line`, `.shadow`) is the AppKit parameter for exactly
this edge (= "the style of separator displayed between the window's titlebar
and content"). SwiftUI does not expose it, = so a bridge could set it on the
window.

**MEASURED: the bridge sets the property (= the window reads the style back
as `.line`, raw value 2) and PAINTS NOTHING.** = A controlled A/B of the same
build against the same library shows the rows at the toolbar's lower edge
byte-identical with and without it (= the titlebar's surface steps 39 -> 38
and stays there, = and no hairline appears at 52 PT).

**The reason, from the same measurement:** the window paints its own toolbar
background (`.toolbarBackground(.ultraThinMaterial, for: .windowToolbar)`),
= and the system edge is drawn by the titlebar's own background, = so it is
not drawn there.

### 3.3 Apple's other candidate's precondition is not met

The HIG's toolbars page names the scroll edge effect (= "use a
ScrollEdgeEffectStyle when necessary to distinguish the toolbar area from the
content area"), = and its scroll-views page names its precondition (= "Only
use a scroll edge effect when a scroll view is behind floating interface
elements"). = The window's content starts BELOW the toolbar strip (= it does
not scroll under it), = so there is no scroll view behind a floating element,
= and the effect has nothing to separate.

⇒ ⇒ ⇒ **So the edge is the app's own decision** (= the mark, = the position,
= the weight), = drawn with the same `Divider()` every other edge in the app
uses, = so the window's edge and the columns' edges are ONE kind of line.

## 4. THE FIX

One owner, four doors.

### 4.1 The owner

`Sources/WenshuApp/Shared/UI/ChromeHairline.swift` (= 101 lines) holds the
app's ONE hairline mark (= the edge between chrome and content):

- the mark is SwiftUI's own `Divider()` (= the system's separator color, = so
  it follows the app's appearance and needs no color of its own);
- it is drawn as an OVERLAY (= not a row of its own), = because the bands'
  heights are aligned on purpose (= every band is one `paneTabHotArea` row),
  = so an overlay keeps the hairline at the edge without moving anything above
  it;
- `bandBottomHairline()` closes a band at its bottom edge, = and
  `windowToolbarBottomHairline()` closes the window's toolbar strip (= the
  overlay rides the CONTENT, = whose top edge IS the strip's lower edge).

### 4.2 The four doors

- `Sources/WenshuApp/Features/Chrome/View/ChromeTopBar.swift` (= the shared
  column-top band) = = its inline `Divider()` overlay became the shared
  modifier;
- `Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` (= the editor
  zone's document strip) = = it now closes its band;
- `Sources/WenshuApp/Features/Chat/View/ChatZoneTabBar.swift` (= the chat
  zone's session bar) = = it now closes its band;
- `Sources/WenshuApp/Shared/UI/LibraryRootView.swift` (= the window's toolbar
  strip) = = it now closes, = and it closes INSIDE `OnboardingAwareToolbar`'s
  toolbar branch, = so the welcome page (= which has no toolbar) carries no
  line at its top edge.

### 4.3 The orientation pin (= a defect the review found, = see 5.2)

The owner's body is `VStack(spacing: 0) { Divider() }`, = and the `VStack`
is load-bearing.

**SwiftUI's `Divider()` takes its orientation from the AMBIENT stack:** the
SAME `Divider()` draws a horizontal rule inside a `VStack` and a VERTICAL one
inside an `HStack`. = The editor zone's document strip is hosted in an
`HStack` (`EditorView.swift:159`), = so an unpinned `Divider()` there painted
a one-point VERTICAL STUB at the strip's centre instead of the horizontal edge
the band needs.

**MEASURED on the app's own window (the tip before the pin):** the editor
column painted **2 of 1297** columns at the band's row (= the stub), = where
the other three doors painted the full width; = the stub sat at device
columns **1582-1583** and spanned rows **104-159** (= 56 device rows = 28.0 PT
= = exactly `DesignTokens.paneTabHotArea`, = so the stub WAS the band); = the
neighbouring columns read 36-39 all the way down, = so it is a 2-px (= 1 PT)
vertical rule and not a text edge.

**MEASURED after the pin:** no stub anywhere in the editor column (= the
narrow bright columns at rows 106..160 = NONE), = and the only narrow bright
column left in that region (= device cols 1990-1991) is present in the BASE
capture too, = so it is a pre-existing column seam and not this change's mark.

## 5. THE REVIEW (FIVE ROUNDS, ALL ON THE BOARD)

The scope was reviewed five times. = Every round is a card on `wenshu-par`,
= and the gate reads the verdict from the run's metadata.

| card | sha under review | verdict | what it found |
|---|---|---|---|
| `t_4322d2d2` | `80aeb3974` | changes_requested | the suite's own test for the mark did NOT hold it (= a source-text search satisfied by a comment), = and three card-body numbers that did not re-derive |
| `t_cf988cea` | `113f74841` | changes_requested | **F6 BLOCKING:** the editor zone's document strip did NOT close its band in the app (= the vertical stub, = see 4.3) |
| `t_1777cb42` | `d40d66799` | changes_requested | one MEASURED number in the committed docblock that did not survive measurement (= "rows 104-156" vs the measured 104-159) |
| `t_7e83aced` | `94c15955` | approved | = = |
| `t_fc804a86` | `58ae0ed86` | approved | = = the landed tip |

### 5.1 The proof rule the review taught (and the suite now holds)

The reviewer's arm: replace the owner's `Divider()` with
`Rectangle().foregroundStyle(.secondary).frame(height: 1)`. = Under the
original guard (= a whole-file search for `Divider()`) the suite stayed
**GREEN**, = because the file's own header comment carries the literal. = A
hand-rolled bar of a fixed colour (= which does NOT follow the app's
appearance) satisfied the test named for exactly that claim.

⇒ ⇒ ⇒ **Two guards now hold it, and both are measured:**

- **the painted result, COLOUR-AWARE.** = Over the suite's magenta ground,
  SwiftUI's own `Divider()` paints **(230, 0, 230)** and
  `Rectangle().foregroundStyle(.secondary)` paints **(128, 0, 128)** = = the
  two agree in their ROWS and differ only in their RGB, = so a guard that
  reads the rows alone cannot tell them apart. = The suite therefore reads
  each painted row's colour beside its index, = and compares it against
  SwiftUI's own `Divider()`.
- **the owner's CODE, not its prose.** = The repo's own `SourceCodeMask`
  (= comments and string-literal contents blanked) = reads the owner's code
  and asserts the call is there and a hand-rolled bar is not.

⇒ ⇒ ⇒ And the suite renders the strip **inside its production host** (= an
`HStack`), = because a standalone rendering cannot see the ambient stack: = the
host-real case asserts that NO full-height column is painted (= a vertical
rule). = MEASURED: the unpinned owner turns the suite red with exactly **1
issue**, = at that case's own assertion; = and removing the case as well
leaves the suite **GREEN** (= 9 tests in 1 suite passed), = so the case is
what discriminates.

### 5.2 The five mutation arms (= every one measured on the landed tip)

| arm | what it edits | issues |
|---|---|---|
| (a) | the editor strip's `.bandBottomHairline()` removed | 2 |
| (b) | the chat bar's `.bandBottomHairline()` removed | 2 |
| (c) | the owner moved from `.bottom` to `.top` | 3 |
| (d) | the owner's `Divider()` replaced with a `Rectangle` | 3 |
| (e) | the owner's `VStack` pin removed | 1 (= the host-real case) |

## 6. THE MEASURED BEFORE / AFTER

On the app's own window, = the same bundle id, = the same library, = the same
launch script, = each variant launched TWICE with only the SECOND launch
captured (= the app persists its layout in the bundle's own defaults, = so a
naive A/B compares "first launch" against "second launch" and reads the
layout drift as a visual regression).

| what | base | tip |
|---|---|---|
| the toolbar's lower edge (= 52.0 PT) | 37.0 | **69.0** |
| the columns painted at that row (= the editor region) | 2 (= a seam) | **1241 of 1241** |
| the four column-top bands' lower edge (= 79.0 PT) | 69.0 | 69.0 (= the band edge, = and the editor strip now joins it) |
| the chat zone's session bar's lower edge (= 505.0 PT) | 60.0 | **69.0** (= 100% bright) |
| a vertical stub in the editor column | none | **none** (= the pre-pin tip painted 2 of 1297 columns) |
| the base↔tip diff over rows 90..200 | = = | **rows 104 and 105 only** |

## 7. THE TESTS

`Tests/WenshuAppTests/Chrome/View/ChromeHairlineTests.swift` (= 564 lines) =
10 tests in 1 suite.

The measurement is the PAINTED result, = not the source text: = a band is
rendered with `ImageRenderer` over a magenta ground (= a colour no separator
paints), = and the pixels are read. = The helper reads three things: = the
rows painted edge to edge, = each painted row's RGB, = and the full-height
painted columns (= a vertical rule).

## 8. THE GATES, RE-RUN ON THE MERGED TREE

Measured on `58ae0ed8606d741b96f1b45aaeed76b0afb9d68c` (= the merged tree,
= NOT the branch the review measured on), = via
`pre_review_gate.py --base main`:

| gate | result |
|---|---|
| `swift build --build-tests` | exit 0 |
| `ChromeHairlineTests` | 10 tests in 1 suite passed |
| `ChromeTopBarMaterialTests` | 4 tests in 1 suite passed |
| `ChatZoneTabBarTests` | 5 tests in 1 suite passed |
| `EditorTabStripOverflowTests` | 8 tests in 1 suite passed |
| the formatting gate | "the change adds no unformatted line (6 changed Swift file(s) checked)" |
| the pollution gate | pass |
| the CJK audit | exit 0 (= 0 hits over the scope's own 716 added lines, = and 0 in the last 10 commit subjects) |
| `verify-dead.py` | DEAD 0 (= ALIVE 127, PARTIAL 4) |
| the registry's round-trip | exit 0 |
| `design-sweep.sh` on the five changed Swift files | "design sweep clean" |
| `commit_filter.py --hook ci-scan` | exit 0 |
| the independent verdict (`review_gate.py --card t_fc804a86`) | approved |

## 9. THE SCOPE, THE COMMITS, AND WHOSE THEY ARE

**The scope's commit:** `58ae0ed8606d741b96f1b45aaeed76b0afb9d68c` (= "feat(ui):
the toolbar and the body read as two planes, = = and every column-top band
closes with one hairline") = = 7 files, +716 / -5.

**The files it touched (= with their line counts at that commit):**

| file | lines |
|---|---|
| `Sources/WenshuApp/Shared/UI/ChromeHairline.swift` (= new) | 101 |
| `Sources/WenshuApp/Shared/UI/LibraryRootView.swift` | 479 |
| `Sources/WenshuApp/Features/Chrome/View/ChromeTopBar.swift` | 123 |
| `Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` | 273 |
| `Sources/WenshuApp/Features/Chat/View/ChatZoneTabBar.swift` | 244 |
| `Tests/WenshuAppTests/Chrome/View/ChromeHairlineTests.swift` (= new) | 564 |
| `docs/agents/nfi.md` (= the registry's rows) | = = |

**The commits my push carried that are NOT mine.** = The push of `main`
carries whatever `main` holds, = and a sibling's merged commits ride along
with mine. = Between my scope's base (`b33605b82b6b`) and my commit's parent
(`f283f18c8c`) there are **NINETEEN** commits that are a sibling's work:
= `a41cd9fe45` (= every column's bottom bar wears one opaque surface),
`f2401ff78e`, `ae6ed03d01`, `befbf1e65d`, `db7c404a08`, `bb56921067`,
`19d833eb57`, `17f118bc32`, `b478fb8b16`, `7ca3f3f1cd`, `59646ba124`,
`5516e98474`, `5f5efddcd7`, `ca741631e1` (= the chat strip's title, = the bar
door, = and the hosted body), `c3b93afb49`, `967a743544`, `3933594492`,
`6565850c13`, `f283f18c8c`.

= ⇒ Pushing them is MAINTENANCE of the shared server state, = not
authorship: = they were already on `main` when my scope's branch was rebased
onto it, = and the landing moved `main`'s REF to the tip that already
contained them.

⇒ ⇒ ⇒ **AND TWO OF THEM CHANGED THIS SCOPE'S OWN FILES.** = `ca741631e1`
rewrote `ChatZoneTabBar.swift` (= 112 -> 233 lines upstream, = and it made
the bar's `init` PRIVATE and added `ChatZoneTabBar.unwired(...)` = the one
door for a test that measures the bar's own drawing), = so this scope's
rebase had to resolve a conflict in the registry (= the chat bar's row read
the upstream count 233, = where the merged file is 244) = and its test had to
build the bar through `unwired` (= the door upstream added, = for exactly
this purpose).

## 10. HOW THE LANDING WAS DONE (= and why)

The shared checkout was on a SIBLING's branch (= `wt/session-closeout-2026-11-13`),
= so `Scripts/land_card.sh` step 5 (= `git merge --ff-only` in the shared
checkout) would have merged into THAT branch, = and `main` would not have
moved. = ⇒ The landing moved `main`'s REF instead:

    git update-ref refs/heads/main <the branch tip>
    git push origin main && git push old-origin main
    git ls-remote origin main && git ls-remote old-origin main

`update-ref` moves the pointer and nothing else, = so the shared checkout's
tree, = its staged work, = and the sibling's branch were untouched (= the
sibling's own commit is still its branch's ancestor).

**The check the landing script does NOT ask** (= and the one that decides
whether a landing is a landing):

    git cat-file -e main:Sources/WenshuApp/Shared/UI/ChromeHairline.swift   # PRESENT
    git cat-file -e main:Tests/WenshuAppTests/Chrome/View/ChromeHairlineTests.swift  # PRESENT
    git log --oneline main..wt/tbsep    # none

**The server's answer, per remote (= a push that reported success on ONE
remote says nothing about the other):**

    git ls-remote origin main     -> 58ae0ed8606d741b96f1b45aaeed76b0afb9d68c
    git ls-remote old-origin main -> 58ae0ed8606d741b96f1b45aaeed76b0afb9d68c

## 11. THE BOSS'S LOOK (7.7)

This scope is UI-touching (= it draws a line that was not there), = so its
merge gate is the boss looking at the running build.

**WHICH build was looked at:** = the app bundle assembled from the landed
`main` (= `58ae0ed8606d741b96f1b45aaeed76b0afb9d68c`), = ad-hoc signed, = in
an isolated copy with its own bundle identifier (= `com.wenshu.meas.landedshot`)
and its own executable name, = launched with `open -g` (= never `open -n`:
= a second instance of the same bundle id aborts both).

**THE MEASUREMENT THE LOOK CONFIRMED** (= the pixels of that exact build, = read
from the capture): = the toolbar's lower edge reads 69.0 at 52.0 PT (= the
line) against 37.0 beside it; = the line spans 1241 of 1241 columns of the
editor region; = the four column-top bands close at 79.0 PT; = the chat zone's
session bar closes at 505.0 PT; = and NO vertical stub is painted anywhere in
the editor column.

**THE BOSS'S VERDICT: NOT YET GIVEN.** = The screenshot was produced and
delivered on request, = and the look was requested after the landing, = so the
verdict on the RUNNING BUILD is the boss's to give. = This doc records the
build and the numbers, = and it does NOT record an approval that was not
given.

**WAS THE APP LEFT RUNNING: NO.** = The measurement instance was stopped after
the capture, = and the app's own isolated-screenshot script exits on its own.

**THE ONE COMMAND THAT COMPLETES THE LOOK:**

    open /Volumes/ANAN/Engineering/wenshu/.worktrees/wt-shot/build/iso-landedshot/Wenshu.app

= = and what to look at: = the toolbar's lower edge must show a thin
horizontal line across the full width (= 52.0 PT), = the four column-top
bands must each close with the same line (= 79.0 PT), = the chat zone's
session bar must close with it (= 505.0 PT), = and the editor column must
show NO vertical stub.

⇒ ⇒ ⇒ **⇒ AND THE LOOK CAN BE BLOCKED BY A SIBLING'S LIVE INSTANCE, = = AND A
BLOCKED LOOK IS RECORDED AS PENDING, = = NEVER AS PASSED.** = At the time of
the measurement, two other instances were running (= `com.wenshu.app` from
another session's tree, = and the review lane's own `Wenshu-final.app`),
= so the measurement used its OWN bundle identifier rather than the shared
one. = Those two instances are NOT this session's residue, = so they were left
running and named here.

## 12. THE OPEN ITEMS (left behind, on purpose)

1. **THE THREE ISOLATED FULL-SUITE FAILURES ARE NOT THIS SCOPE'S.** = The
   whole-suite run reports SIX issues; = re-run in isolation (= one filter
   over the eight suites that own them) the branch reports THREE, = and
   today's `main` reports THE SAME THREE: =
   `ChatViewHistoryShortcutTests.body_logs_history_metadata`,
   `EditorTabTitleTests.displayTitle_documentPathBasenameWins_overTitle`,
   = and `AsyncDelegationRegistryTests.the chat's @-mention path registers
   into the shared registry`. = The other three pass in isolation on BOTH
   trees, = so they are load-sensitive. = The whole-suite COUNT is itself
   load-sensitive (= 8 at one tip, = 5 at another, = 6 at another, = on the
   SAME three stable failures), = so the claim that holds is the ISOLATED
   SET, = not the count. = ⇒ ⇒ REPORTED, = not fixed here, = and the owners
   are named in the review cards' comments.
2. **THE EDITOR ZONE'S OWN BAND IS NOT IN THE LIVE CAPTURE.** = The isolated
   library has no open document, = so the strip's band edge is not drawn on
   screen. = ⇒ The strip's closure rests on the pixel suite (which renders
   the real `EditorTabStrip` view) + the mutation arms, = and NOT on a
   photograph of the band itself. = ⇒ ⇒ What the live capture DOES prove is
   the ABSENCE of the vertical stub, = and that IS a photograph.
3. **THE MEASUREMENT ENVIRONMENT'S TCC WALL** (= an environment fact, = not a
   defect in the change): = the app's own default library root is
   `~/Documents/wenshu` (= `LibraryRoot.ensureDefault()`, =
   `WenshuAppMain.swift:124`), = and an ad-hoc-signed measurement build
   BLOCKS on the consent prompt for that path (= the main thread sits in
   `NSFileManager.contentsOfDirectoryAtURL` with no file handles open at
   all). = ⇒ The measurement pointed the default root at a private COPY of
   the library for the duration of the capture, = and the real directory was
   restored afterwards.

## 13. THE DURABLE LESSONS (= and where they now live)

1. **A `Divider()` inherits its orientation from the ambient stack.** = ⇒ A
   hairline that must be horizontal in EVERY host is pinned with a `VStack`,
   = and the test renders the component IN ITS PRODUCTION HOST (= a
   standalone rendering cannot see the ambient stack) = and asserts that no
   full-height column is painted. = ⇒ Lives in
   `wenshu-parallel-dev/references/a-seam-in-a-swiftui-file-cannot-be-tested.md`
   (= the shared skill tree, = which both lanes read).
2. **A source-text guard is a placeholder for a behaviour, = and the fix is
   COLOUR, = not a narrower search.** = ⇒ Where a mark can be painted two
   ways (= the system's, = or a hand-rolled one of the same rows), = the
   guard reads the painted COLOUR beside the rows, = and the code guard
   reads the MASKED source. = ⇒ Same reference.
3. **A verdict dies when the diff's CONTENT changes, = and a rebase that
   brings a sibling's rewrite of your own file changes it.** = ⇒ The
   re-review round is a NEW card naming the NEW tip, = and the card's body
   re-measures every number at that tip. = ⇒ Lives in
   `wenshu-review-proof/references/the-change-identity-contract.md`.
4. **A `git push` of `main` carries a sibling's commits, = and a landing
   that moves `main`'s REF (not a checkout) leaves a sibling's live checkout
   untouched.** = ⇒ The landing's own check is `git cat-file -e main:<the
   file your change added>`, = and the per-remote `ls-remote`. = ⇒ Lives in
   `wenshu-parallel-dev/references/the-landing-merges-wherever-the-shared-checkout-is.md`.
