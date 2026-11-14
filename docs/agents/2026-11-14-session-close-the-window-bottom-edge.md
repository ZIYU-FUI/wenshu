#
#  2026-11-14 — the window's bottom edge reads as ONE line
#
#  The closeout of the scope that began with the boss reporting that one
#  bottom bar's colour differed from every other bottom bar's, in BOTH the
#  light and the dark appearance, and that all of them should be a solid
#  colour rather than a material. = The second half of the same request was
#  for an empty bottom bar in the right column.
#
#  Every number in this doc is measured, and every one of them names the
#  command that produces it.
#

## 1. WHAT THE BOSS ASKED

Two requirements, in one request:

1. **Every bottom bar wears the SAME colour**, = = in both the light and the
   dark appearance, = = and the colour is a SOLID one (= = not a material).
2. **The right column gets a bottom bar of its own**, = = and it carries NO
   function yet (= = the user had not decided what it holds).

## 2. THE SYMPTOM

MEASURED on the base build's own capture, the window's bottom row read
**27 / 28 / 28 / 28 / 28 / 26 / 26** across the width in the dark
appearance, = = and **254 / 210 / 210 / 210 / 210 / 250 / 250** in the
light one. = = The right column read 26 while the bars beside it read 28,
= = because it was the ONE column whose bottom edge had no bar at all.

= = ⇒ ⇒ ⇒ **⇒ AND THE COLOURS MOVED WHEN THE DESKTOP MOVED, = = BECAUSE
THE SURFACE UNDER THEM WAS TRANSLUCENT.**

## 3. THE ROOT CAUSE

The shared `ChromeBottomFooter` painted its surface with `.background(.bar)`.
= = `.bar` is a MATERIAL, = = a material is TRANSLUCENT, = = and a
translucent surface paints whatever is BEHIND it. = = This window is
translucent (= = one behind-window material at the root), = = so each
column's bar sampled a DIFFERENT patch of the desktop, = = and every bar came
out a different grey.

= = ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ AND A PIXEL TEST CANNOT CATCH THIS ALONE.** = = An
`NSHostingView` rendered offscreen paints `.bar` as an OPAQUE FALLBACK
(= = the window has no real desktop behind it), = = so the rendered pixels
read the SAME for a material and for an opaque fill. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒
**⇒ So the surface is asserted from the CODE** (= = the component's own
source, = = with the comments stripped, = = because the comment beside a
surface quotes the recipe and would otherwise satisfy a naive whole-file
search), = = and the rendered pixels carry the GEOMETRY and the THEME
instead.

## 4. THE FIX

- The shared footer now paints the system's own **OPAQUE** control background
  (= = `NSColor.controlBackgroundColor`), = = so one appearance gives every
  bar the SAME value (= = the desktop can no longer reach it), = = and the
  light and dark appearances each resolve to their own (= = the bar follows
  the theme).
- The right column now ends on that SAME shared chrome, = = with an EMPTY
  content slot.

= = ⇒ ⇒ ⇒ **⇒ AND THE RIGHT COLUMN'S BAR IS A `safeAreaInset`, = = NOT A
ROW OF ITS OWN**, = = so it is the same component = = and it cannot drift
from the others.

## 5. THE MEASURED BEFORE / AFTER

The A/B is controlled: = = the base bundle and the tip's bundle, = = the
same library, = = the same launch, = = each captured by the app's own
`WS_SCREENSHOT` hook.

| what was read | base | tip |
| --- | --- | --- |
| the bar row's modal colour's coverage of the window's WIDTH (= dark) | **66%** | **100%** |
| the right column's own pixels at that row (= x 2198-2737) | (26, 26, 26) | (28, 28, 28) |
| the dark bottom row, across the width | 27 / 28 / 28 / 28 / 28 / 26 / 26 | 28 everywhere |
| the light bottom row, across the width | 254 / 210 / 210 / 210 / 210 / 250 / 250 | 255 everywhere |
| the inspector's own column (= the corner crop) | (26, 26, 26) at EVERY row | (26, 26, 26) down to y 147, = = a white separator at y 148-151, = = then (28, 28, 28) |

= = ⇒ ⇒ ⇒ **⇒ AND THE BAR ROW'S COVERAGE IS THE ONE-LINE PROOF: = = 66% of
the width on the base (= = the right column painted its own ground there)
= = and 100% on the tip (= = one surface across the whole bottom edge).**

= = ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ AND THE SAMPLE GRID IS NAMED, = = BECAUSE A ROW OF
MEASURED PIXELS WITHOUT ITS GRID IS NOT A RE-DERIVABLE CLAIM.** = = The
seven sample points are **x = 0, 456, 912, 1368, 1825, 2281, 2737**,
= = and the dark row's string reproduces exactly on them.

## 6. THE TESTS

`Tests/WenshuAppTests/Chrome/View/ChromeBottomFooterSurfaceTests.swift`
(= = 379 lines, = = 6 tests):

1. the shared footer paints an opaque system surface, = = not a material
   (= = the source read, = = comments stripped);
2. every column's bottom bar renders through the shared component
   (= = the five call sites);
3. the bar's surface follows the appearance (= = aqua vs darkAqua, = = the two
   painted values differ);
4. the bar's surface does not carry the ground behind it (= = two grounds,
   = = one reading);
5. the right column ends on a bottom bar (= = a bottom safe-area inset);
6. the right column's empty bar still paints the shared bar's height
   (= = 32 PT, = = the canonical token).

= = ⇒ ⇒ ⇒ **⇒ AND THE SUITE BITES: = = the two production files were
restored from git (= = the suite kept) = = and the suite reported 5 issues
across 3 tests.** = = With the change in place the same suite reports 6/6.

## 7. THE GATES, RE-RUN ON THE MERGED TREE

MEASURED on the merged `main` (= = the tree as it stands after every
commit landed, = = not on the branch the work was measured on before the
merge):

| gate | result |
| --- | --- |
| `swift build` | exit 0 (= = "Build complete!") |
| `swift test --filter "ChromeBottomFooterSurfaceTests\|ChromeBottomFooterHeightTests"` | **11 tests in 2 suites passed** (= = 4.9 s) |
| `design-sweep.sh` on the three changed view files | "design sweep clean" |
| `verify-dead.py` | 127 ALIVE, 4 PARTIAL, **0 DEAD** |
| the CJK audit over this scope's six commits | **0** CJK added in each |
| the closure doc itself | **0** CJK characters |
| `nfi-loc-check.py` | "every rewritten file's row carries its own count" |
| `ci_change_gate.py --check formatting` | "the change adds no unformatted line" |
| `ci_change_gate.py --check pollution` | "the change adds no forbidden vocabulary" |
| `commit_filter.py --hook ci-scan` | exit 0 |

## 8. THE REVIEW (SIX ROUNDS, ALL ON THE BOARD)

**The production change** (= = card `t_cfd431b0`) = = **approved**, = = all
thirteen claims checked. = = Its FIRST round blocked, = = and its three
findings were about the CARD, not the code: = = (a) the reviewer could not
perform the A/B captures in its own session (= = the fix: = = the captures
are attached to the card, = = and the launch path is named); = = (b) claim
5's command was too narrow (= = `grep -rln "ChromeBottomFooter("` returns 2
files, = = because three of the five call sites spell it `ChromeBottomFooter
{`; = = the corrected command returns 5); = = (c) claim 11's sweep was run
over the whole tree rather than over the changed files. = = The card's body
was corrected while it sat BLOCKED (= = not running), = = so no reviewer
read a body that then changed underneath it, = = and the sha never moved.

**The closure doc** took three further rounds of its own, = = and every one
of them found a REAL DEFECT IN THE DOC'S OWN WORDS:

| card | the defect | the fix |
| --- | --- | --- |
| `t_bb63dc45` | the light bottom row's string was sampled on a DIFFERENT GRID, = = so `254 / 194 / 210 / …` did not re-derive (= = the 194 is a 1-px column-divider seam at x = 400 and x = 2197 only) | the seven sample points are named beside the row |
| `t_bb63dc45` | §4's attribution was wrong (= = `.font(.system(size:))` occurs ONCE, = = and `:366` quotes the DIFFERENT literal `.font(.system(size:weight:))`; = = and the "about 20 hits" figure was not reproducible) | each prose string carries its own command and its own count |
| `t_7c41cc66` | §4 claimed "the whole tree has hits that are all PRE-EXISTING PROSE", = = and the reviewer's own count over `Sources` gave **102** hits = = **32** in comments + **70** in REAL CODE | name the scope and drop the universal |
| `t_d17ed027` | the tree scope's partition read **308 = = 108 + 200**, = = and the split under the doc's OWN named command is **308 = = 112 + 196** (= = the two halves of one sentence had been split on two different bases, = = and four prose rows were charged to "real code") | the one number pair, = = and the rule that produces it (= = a row is PROSE when its line, after the leading whitespace, starts with `//`) |
| `t_b64df6e4` | §6's lead-ins said "TWO ERRORS … BOTH ARE NOW CORRECTED" above FOUR numbered findings, = = and the numbering ran (1), (2), (4), (3) | move the (4) block below the (3) block, = = make the lead-ins say FOUR, = = and move the closing sentence after the last finding |
| `t_81df67d5` | **approved** | = = |

= = ⇒ ⇒ ⇒ **⇒ AND THE THREE DOC ROUNDS WERE ONE CLASS: = = A CLAIM IN THE
DOC'S PROSE THAT DID NOT MATCH THE ARTIFACT IT DESCRIBED.** = = ⇒ ⇒ ⇒ ⇒ ⇒
⇒ ⇒ ⇒ **⇒ AND THE DOC REFUTED ITSELF IN THE FIRST OF THEM: = = the
universal sat thirteen lines above the doc's own sentence naming the one
real-code hit.**

## 9. THE SCOPE, THE COMMITS, AND WHOSE THEY ARE

**This scope's own commits** (= = all six are on `main` and on both remotes):

| # | the requirement | the commit that carries it | the independent verdict that cleared it |
| --- | --- | --- | --- |
| 1 | every bottom bar wears one opaque surface, = = and the right column ends on an empty one | `a41cd9fe45a13a8cf86e36f04d8ad6a8753a3aa8` | card `t_cfd431b0` = = **approved** (= = thirteen claims) |
| 2 | the closure doc that records it | `c3b93afb49` + `967a743544` | card `t_bb63dc45` = = **changes requested**, = = then its two findings closed |
| 3 | the doc's tree scope, = = scoped and counted | `3933594492` | card `t_7c41cc66` = = **changes requested**, = = its one finding closed |
| 4 | the doc's partition, = = 112 + 196 | `6565850c13` | card `t_d17ed027` = = **changes requested**, = = its one finding closed |
| 5 | the doc's review history, = = (1) (2) (3) (4) | `f283f18c8c` | card `t_b64df6e4` = = **changes requested**, = = its one finding closed |
| 6 | the doc's history, = = read in order | `f283f18c8c` | card `t_81df67d5` = = **approved** |

**The commits the PUSH carried that are NOT this scope's** (= = pushed as
maintenance of the shared server state, = = not authorship):

- `ca741631e1` (= = `feat(chat)`: the strip title, the bar door, and the
  hosted body), = = `5f5efddcd7`, = = `5516e98474`, = = `59646ba124`,
  = = `7ca3f3f1cd`, = = `b478fb8b16`, = = `17f118bc32`, = = `19d833eb57`,
  = = `bb56921067`, = = `db7c404a08`, = = `befbf1e65d`, = = `ae6ed03d01`,
  = = `f2401ff78e` (= = a sibling session's performance-order and
  render-path scope).

= = ⇒ ⇒ ⇒ **⇒ AND THE `old-origin` PUSH CARRIED ALL OF THEM, = = because
`old-origin` was still at the production change when this scope's five doc
commits were pushed.** = = The `origin` push carried only this scope's five
commits.

= = ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ AND THE DOC CANNOT NAME ITS OWN TIP**: = = the
commit that adds this doc sits ON TOP of the sha the doc names, = = and a
record that contained its own sha would change the sha it names. = = So
this doc names SNAPSHOTS and ANCESTRY, = = and the reader runs
`git rev-parse main` for the tip.

## 10. HOW THE LANDING WAS DONE (= and why)

= = ⇒ ⇒ ⇒ **⇒ THE LANDING SCRIPT'S FAST-FORWARD RAN WHEREVER THE SHARED
CHECKOUT WAS, = = AND IT PRINTED A FALSE SUCCESS.**

`Scripts/land_card.sh` step 5 is `cd "$REPO"` (= = the shared checkout)
followed by `git merge --ff-only "$BRANCH"`. = = The shared checkout was on
a SIBLING's branch, = = so the merge landed THERE and `main` never moved,
= = and the script then printed

    RESULT: LANDED (t_81df67d5) sha=ca741631e

= = = = where that sha was `git rev-parse main` = = = = the sha that was
ALREADY there. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ SO "LANDED" WAS NOT A LANDING: = =
THE SHA IT PRINTED WAS THE ONE THAT DID NOT CHANGE.**

= = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ The fix is the one §7 of the closure doc records: = =
`main` was checked out in NO worktree, = = so its ref could be moved
WITHOUT a checkout:

```bash
git update-ref refs/heads/main f283f18c8c6e2c6d4457d593744a3e2aa24c9756
git push origin main && git push old-origin main
```

= = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ = = and then the question the script did not ask: = = is
the change in `main`?

```bash
git cat-file -e main:docs/agents/2026-11-13-window-bottom-edge-one-line.md
git log --oneline main..wt/footer-solid     # = = empty
```

= = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ = = both answer, = = and `git ls-remote` reads
**`f283f18c8c6e2c6d4457d593744a3e2aa24c9756`** on **both** remotes.

= = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ AND THE SIBLING'S BRANCH WAS FAST-FORWARDED BY THE
SCRIPT'S MERGE, = = SO ITS OWN WORK WAS CHECKED: = = its own commit is still
its ancestor, = = and its files are byte-identical.**

## 11. THE BOSS'S LOOK (7.7)

This scope is UI-touching (= = the bottom edge's colour and the right
column's new bar are both visible), = = so the merge gate is the boss
looking at the running build.

- **Which build.** The bundle was rebuilt from the merged `main`
  (= = `Scripts/build-app.sh` at `8f6ae2579c`, = = ad-hoc codesigned), = =
  and launched with a PLAIN `open` (= = never `open -n`, = = a second
  instance of the same bundle id aborts both).
- **What was measured.** The boss asked for a capture, = = and the app's own
  `WS_SCREENSHOT` hook took it on the rebuilt bundle. = = The bottom row
  reads **28 / 28 / 28 / 28 / 28 / 28 / 28** in the dark appearance and
  **255 / 255 / 255 / 255 / 255 / 255 / 255** in the light one, = = at the
  seven sample points named in §5.
- **The boss's verdict.** GIVEN: the boss accepted the work (= = "OK") and
  asked for the session closeout.
- **The app was left running.** NO (= = the capture hook exits the app when
  it has its frame, = = and no instance of `com.wenshu.app` was left
  holding the bundle id).

## 12. THE OPEN ITEMS (left behind, on purpose)

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
- **The landing script's fast-forward target is a defect in the script.**
  = = It merges into whatever the shared checkout holds, = = and it reports
  "LANDED" with a sha that did not move. = = ⇒ ⇒ That is the script's own
  scope (= = not this change's), = = and it is recorded here so the next
  session that lands a branch does not trust the script's word.

## 13. THE DURABLE LESSONS (= and where they now live)

= = ⇒ ⇒ ⇒ **⇒ ALL SIX WENT INTO THE SHARED SKILL TREE** (= = the tree both
lanes read), = = not into memory and not into this doc alone:

- `references/a-universal-over-a-measurement.md` (= = the six rules this
  scope's three doc rounds each taught: = = a sentence that quantifies over a
  set must name the set; = = a count is not a number until its UNIT and its
  COMMAND are named; = = "pre-existing" must be CHECKED and not asserted;
  = = a tree-wide claim must be read against the doc's own per-grep table;
  = = a PARTITION must share ONE basis with its total; = = a section's
  lead-in is a claim about the section).
- `references/the-landing-merges-wherever-the-shared-checkout-is.md` (= = the
  false "LANDED", = = the question the script does not ask, = = and the
  `update-ref` fix).
- `references/parallel-dev-reference-catalog.md` (= = both entries indexed).

= = ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ AND THE MEASUREMENT-GRID RULE WAS ALREADY IN THE TREE**,
= = as `a-blocked-review-round.md`'s own note on the sweep's SCOPE.

## 14. WHERE THE EVIDENCE IS

- The closure doc: `docs/agents/2026-11-13-window-bottom-edge-one-line.md`
  (= = 273 lines, = = zero CJK, = = registered in `docs/agents/nfi.md` with
  LOC = = 273).
- The production files:
  `Sources/WenshuApp/Features/Chrome/View/ChromeBottomFooter.swift`
  (= = the opaque surface) and
  `Sources/WenshuApp/Features/Editor/View/InspectorView.swift`
  (= = the right column's bottom `safeAreaInset`).
- The suite:
  `Tests/WenshuAppTests/Chrome/View/ChromeBottomFooterSurfaceTests.swift`.
- The A/B captures (= = four full 2738x1968 app captures and two 1176x276
  corner crops) are attached to the review cards `t_cfd431b0`,
  `t_7c41cc66`, `t_d17ed027`, `t_b64df6e4` and `t_81df67d5`.
