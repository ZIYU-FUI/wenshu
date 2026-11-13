#
#  2026-11-13 — the window's bottom edge reads as ONE line
#
#  The boss reported that one bottom bar's colour differed from every other
#  bottom bar's, in BOTH the light and the dark appearance, and that all of
#  them should be a solid colour rather than a material. = The second half of
#  the same request was for an empty bottom bar in the right column.
#
#  THE SYMPTOM. = The window's bottom edge was made of several different
#  greys. MEASURED on the base build's own capture, the bottom row read
#  27 / 28 / 28 / 28 / 28 / 26 / 26 across the width in the dark appearance,
#  and 254 / 194 / 210 / 210 / 210 / 250 / 250 in the light one. = The right
#  column read 26 while the bars beside it read 28, = = because it was the
#  ONE column whose bottom edge had no bar at all.
#
#  THE ROOT CAUSE. = The shared `ChromeBottomFooter` painted its surface with
#  `.background(.bar)`. = `.bar` is a MATERIAL, = = a material is
#  TRANSLUCENT, = = and a translucent surface paints whatever is BEHIND it.
#  = This window is translucent (= one behind-window material at the root),
#  = = so each column's bar sampled a DIFFERENT patch of the desktop and
#  every bar came out a different grey. = = And every one of those values
#  moved when the desktop moved.
#
#  THE FIX. = The shared footer now paints the system's own OPAQUE control
#  background (= `NSColor.controlBackgroundColor`), = = so one appearance
#  gives every bar the SAME value (= the desktop can no longer reach it),
#  = = and the light and dark appearances each resolve to their own (= the
#  bar follows the theme). = = The right column now ends on that SAME shared
#  chrome, = = with an EMPTY content slot.
#
#  EVERY NUMBER BELOW IS MEASURED. = The A/B captures are the app's own
#  `WS_SCREENSHOT` hook's bitmaps (= the window's content view, = = not the
#  screen), = = and they are attached to the review card `t_cfd431b0` with
#  their attachment ids.
#

## 1. THE MEASURED BEFORE / AFTER

The A/B is controlled: = = the base bundle at `main` and the tip's bundle,
= = the same library, = = the same launch, = = each captured by the app's
own hook.

| what was read | base | tip |
| --- | --- | --- |
| the bar row's modal colour's coverage of the window's WIDTH (= dark) | **66%** | **100%** |
| the right column's own pixels at that row (= x 2198-2737) | (26, 26, 26) | (28, 28, 28) |
| the dark bottom row, across the width | 27 / 28 / 28 / 28 / 28 / 26 / 26 | 28 everywhere |
| the light bottom row, across the width | 254 / 194 / 210 / 210 / 210 / 250 / 250 | 255 everywhere |
| the inspector's own column (= the corner crop) | (26, 26, 26) at EVERY row | (26, 26, 26) down to y 147, = = a white separator at y 148-151, = = then (28, 28, 28) |

⇒ ⇒ **⇒ THE BAR ROW'S COVERAGE IS THE ONE-LINE PROOF: = = 66% of the
width on the base (= the right column painted its own ground there) = = and
100% on the tip (= one surface across the whole bottom edge).**

## 2. WHY AN OFFSCREEN PIXEL TEST CANNOT PROVE THIS

An `NSHostingView` rendered offscreen paints `.bar` as an OPAQUE FALLBACK
(= the window has no real desktop behind it), = = so the rendered pixels
alone read the SAME for a material and for an opaque fill. = = ⇒ ⇒ **⇒ So
the surface is asserted from the CODE** (= the component's own source, = =
with the comments stripped, = = because the comment beside a surface quotes
the recipe and would otherwise satisfy a naive whole-file search), = = and
the rendered pixels carry the GEOMETRY and the THEME instead.

## 3. THE TESTS

`Tests/WenshuAppTests/Chrome/View/ChromeBottomFooterSurfaceTests.swift`
(= 379 lines, = = 6 tests, = = all green at the tip):

1. the shared footer paints an opaque system surface, = = not a material
   (= the source read, = = comments stripped);
2. every column's bottom bar renders through the shared component
   (= the five call sites);
3. the bar's surface follows the appearance (= aqua vs darkAqua, = = the two
   painted values differ);
4. the bar's surface does not carry the ground behind it (= two grounds, = =
   one reading);
5. the right column ends on a bottom bar (= a bottom safe-area inset);
6. the right column's empty bar still paints the shared bar's height
   (= 32 PT, = = the canonical token).

⇒ ⇒ **⇒ AND THE SUITE BITES: the two production files were restored from
git (= the suite kept) = = and the suite reported 5 issues across 3 tests.**
⇒ ⇒ ⇒ ⇒ With the change in place the same suite reports 6/6.

## 4. THE GATES

`swift build` = = green. = `swift test --filter ChromeBottomFooterSurfaceTests`
= = 6/6. = `swift test --filter ChromeBottomFooterHeightTests` = = green.
= `swift test --filter SweepTests` = = 42 tests in 17 suites passed.
= `ci_change_gate.py --check formatting` = = "the change adds no unformatted
line (3 changed Swift file(s) checked)"; = = the same with `--check
pollution` = = "the change adds no forbidden vocabulary"; = =
`nfi-loc-check.py` = = "every rewritten file's row carries its own count
(1 row(s) checked)"; = = `commit_filter.py --hook ci-scan` = = exit 0;
= = `design-sweep.sh` on the three changed files = = "design sweep clean";
= = the nine greps = = **0 each** over the changed file set.

⇒ ⇒ **⇒ AND THE NINE GREPS ARE 0 OVER THE CHANGED FILES, = = while the whole
tree has ≈ 20 hits that are all PRE-EXISTING COMMENT lines** (= =
`IconStyles.swift:349` and `:366` quote `.font(.system(size:))` in prose,
= = `WindowOpenButton.swift:11` and `:21` quote `Image(systemName:)` in
prose, = = `EditorPaperCanvas.swift:41`, `:118` and `:139` quote
`.padding(72)` in prose). = = ⇒ ⇒ That is the house reference's own lesson
(= "a sweep that counts by text also counts your text"), = = and it is a
property of the tree, = = not of this change.

## 5. THE FULL-SUITE COMPARISON (= and what is NOT this change's)

The branch's whole-suite run (= `swift test --skip CSSearchableIndexSearchTests`)
reports **6 issues**; = = `main`'s reports **6**. = = The three sites
present in BOTH runs (= `AsyncDelegationRegistryTests.swift:104`, = =
`ChatViewHistoryShortcutTests.swift:35`, = = `EditorTabTitleTests.swift:60`)
are pre-existing. = = The tip-only sites (= `HermesTodoStoreConcurrencyTests.swift:268`,
= = `LongRunningGoalButtonTests.swift:98`, = = and the 49-issue
`PromptCachingE2ETests`) are LOAD-SENSITIVE: = = the SAME filter over
those three suites reports "**11 tests in 3 suites passed**" on the tip when
it runs alone, = = and the same on `main`. = = ⇒ ⇒ **⇒ THE MEASURED CAUSE:
the two whole-suite runs were executed CONCURRENTLY, = = so the tip's run
carried the base's build and test load.** ⇒ ⇒ ⇒ ⇒ The proof is a pair of
isolated runs on the tip: = = the first (= still under the load) reported
"11 tests in 3 suites failed with 1 issue" (= the timing assertion
`judged.elapsed < 5.0`, = = after 99 s), = = and the second (= the same
tree, = = the same filter, = = nothing else running) reported "**11 tests in
3 suites passed**" in 28 s.

## 6. THE REVIEW

Card `t_cfd431b0` (= `wenshu-review`), = = sha
`a41cd9fe45a13a8cf86e36f04d8ad6a8753a3aa8`, = = branch `wt/footer-solid`.
= = The verdict field reads **approved** (= `review_gate.py --card t_cfd431b0`
prints "approved by wenshu-review"), = = and all thirteen claims were
checked.

⇒ ⇒ **⇒ THE FIRST ROUND BLOCKED, = = AND ITS THREE FINDINGS WERE ABOUT THE
CARD, = = NOT ABOUT THE CODE:** = = (a) it could not perform the A/B
captures in its own session (= the fix: = = the captures are attached to the
card, = = with their attachment ids, = = and the launch path is named);
= = (b) claim 5's command was too narrow (= `grep -rln "ChromeBottomFooter("`
returns 2 files, = = because three of the five call sites spell it
`ChromeBottomFooter {`; = = the corrected command returns 5); = = (c) claim
11's sweep was run over the whole tree (= = where a pre-existing COMMENT
matches it; = = the changed file set is 0). = = ⇒ ⇒ ⇒ The card's body was
corrected while it sat BLOCKED (= not running), = = so no reviewer read a
body that then changed underneath it, = = and the sha never moved (= = so
the same card still matches its branch by sha).

## 7. THE LANDING

`Scripts/land_card.sh t_cfd431b0 wt/footer-solid …` re-ran the card's own
gates (all PASS) and then stopped at the fast-forward with
`NOT_FF_AFTER_4_ATTEMPTS`. = = ⇒ ⇒ **⇒ THE REASON IS NOT A DIVERGENCE:**
the shared checkout was on a SIBLING's branch (= `wt/probe-registry`), = =
so the script's `git merge --ff-only` (= which runs in the shared checkout)
merged into that branch instead of into `main`. = = `main` itself was still
at the branch's base, = = and `main` was checked out in no worktree, = = so
the ref was moved with `git update-ref` (= = no checkout, = = = = the
shared checkout's tree and branch untouched). = = ⇒ ⇒ ⇒ Both remotes were
then pushed (= `origin` and `old-origin`), = = and the SERVER's own answer
(= `git ls-remote`, = = not the local ref) reads `a41cd9fe4` on both.

⇒ ⇒ **⇒ THE PUSH CARRIED NO SIBLING'S COMMIT:** = = `origin/main`'s
history is `a41cd9fe4` (= this change) = = on `b33605b82` (= the base),
= = and the diff against the base names ONLY this change's four files.

## 8. THE OPEN ITEMS

- **The right column's bar carries no function.** = = The user has not
  decided what it holds, = = so the slot is empty on purpose (= = the bar is
  the row's shape, = = not a placeholder for a feature), = = and the suite
  pins its height. = = ⇒ ⇒ The next thing placed there is a NEW scope.
- **The `open --env` path of `Scripts/wenshu-shot-isolated.sh` does not
  deliver the capture variables on this machine** (= = the app runs, = =
  never captures, = = and never exits either). = = ⇒ ⇒ The captures were
  taken by launching the bundle's executable directly with the variables in
  its own environment. = = ⇒ ⇒ ⇒ That is a defect in the script, = = and it
  is its own scope (= = not this change's).
- **The light appearance's editor canvas is dark** (= = the app's own
  existing behaviour, = = and it is the same on the base and the tip). = = ⇒
  ⇒ It is not this change's.
