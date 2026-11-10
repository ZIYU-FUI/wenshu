# Session close: the book-level style sheet and the export presets

Date: 2026-11-10

Scope: the boss's 2026-11-05 requirement, as written in
`.scratch/2026-11-05-book-style-sheet/spec.md` (278 lines). This closeout
covers that requirement's DIRECT functional scope only.

Landed state (= = the state this record measured, = = and `main` has moved
on since (= = most of the engineering-depth work in section 8 landed after
it)):

- `main` = `461910783d0435e1d174ae7681baa7c7a4801cd4`
- `origin/main` (gitcode) = the same sha
- `old-origin/main` (github) = the same sha

= = ⇒ These three shas are the SNAPSHOT this record was measured on, = =
and they are still the tree's own history (= = `461910783d` is an ancestor
of `main`), = = but `main` itself now points further along. = = ⇒ So a
reader who wants TODAY's `main` reads it from the repository (= = `git
rev-parse main`), = = and this record's shas say WHICH tree the numbers
below were measured on.

The engineering-depth work that grew around this requirement (the file
splits, the split pre-check tool, the stylesheet call-site guard, the
landing-script fix) is engineer-facing and is NOT part of this scope. It
is listed in section 8 so nothing here reads as a claim over it.

## 1. The requirement, row by row

One row per requirement. The carrier column is the commit on `main` that
carries the requirement. The card column is the review card that ruled on
it. The proof column is an ANCESTRY fact, not a tip: the carrier commit is
an ancestor of the sha that approved card ruled on, so the ruling covers
the carrier.

| # | Requirement (business language) | Carrier on `main` | Author | Approved card | Reviewed sha | Proof |
|---|---|---|---|---|---|---|
| 1 | A book's style is BOOK-level: one style set runs through the whole book, and it lives with the book | `c89fc3bcc930` | Hermes Agent | `t_fd3551fe` | `4e14379fd21d` | carrier is an ancestor of the reviewed sha |
| 2 | Presets are grouped by TARGET, the way Final Cut Pro groups export presets | `4800d2394f05` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 3 | Fine tuning stays, but every adjustment acts on the whole book | `21bd08c36d09` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 4 | Few choices beat many: the format page is a style table plus a few knobs, not a row of commands | `21bd08c36d09` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 5 | The web-novel platform VISUAL preset is NOT built (no platform specifies a font, a size or a line spacing) | `4800d2394f05` | S | `t_782a9e47` | `8a9163b1a144` | `BookStylePreset` has two cases only (`printBaseline`, `general`); no platform case exists |
| 6 | Reading experience inside Wenshu is guaranteed: the book-level style sheet IS built | `21bd08c36d09` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 7 | Connecting to the platforms' open APIs is a future direction, not an immediate requirement | — | — | — | — | nothing in the tree calls a platform API; no card claims it |
| 8 | The engine must take five document-level knobs | `21bd08c36d09` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 9 | Two current values contradict the print baseline (the heading ladder, the segment spacing) | `21bd08c36d09` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 10 | The export half: per target, the manuscript's SHAPE (chapter-title field, segment indent, blank line between segments, word count) | `4c7f4fb7f137` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 11 | The export must NOT clean the full-width spaces away (the Jinjiang indent lives in the content) | `bc0e6160bfd6` | pocock | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |
| 12 | The `ideas` folder defect (the reverse map and the three seeding sites omitted it) is fixed in the same card | `16ed443763c1` | S | `t_782a9e47` | `8a9163b1a144` | carrier is an ancestor of the reviewed sha |

Two carriers sit outside the table's carriers because they were reviewed
on their own card: the footnote marker fix (`c40ea90dddc9`, pocock) and
the frontmatter encoding fix (`77635be75656`, probe) were both ruled
`approved` on `t_09f36dca` at the sha `77635be75656`, which is itself on
`main`.

**Commits in this scope that are NOT mine.** The commits above were
written by three identities and only two are the `pocock` profile:
`S` (the `wenshu-dev` profile) wrote `4800d2394f05`, `21bd08c36d09`,
`4c7f4fb7f137` and `16ed443763c1`; `probe` (the review profile) wrote
`9caefe4edb2d`, `71e03456b02a` and `77635be75656`; `Hermes Agent` wrote
`c89fc3bcc930`. The `pocock` profile wrote `bc0e6160bfd6`, `c40ea90dddc9`
and `4e14379fd21d`. A reader who asks "who landed this" should read the
author column, not the reviewer.

## 2. What was measured, before and after

Before: the book carried no style of its own, the format page was a row of
document commands, and the export wrote one shape for every platform.

After, measured on the merged `main`:

| Fact | Where it was measured | Value |
|---|---|---|
| The book carries a style of its own | `Sources/WenshuApp/Features/Library/Model/Book.swift` | field `styleSheet` |
| The style set is stored with the book, not in the paragraphs | `Book.swift` (`CodingKeys` case plus `decodeIfPresent ?? the default`) | one optional field |
| The book's row and the rows under it resolve to the SAME book | `AppleSidebarView+Nodes.swift`, `SidebarItem.swift` | one key, not two |
| Switching books reloads the style | `ChatZoneView.swift` (`onChange` to `setCurrentBookID`, then `loadHistory`) | the repo's own pattern |
| The `ideas` folder is in the reverse map and in all three seeding sites | `AppleSidebarView+Nodes.swift`, `LibraryBootstrapper.swift`, `LibraryMigrator+HelpDoc.swift`, `SidebarServiceMutation.swift` | the defect is gone; `BookFolderCatalog` still declares it |
| The sheet's own values reach the engine | `WenshuMarkdownEditor.adjustedConfiguration` | `headings.fontName`, `headings.fontMultipliers`, `paragraph`, `blockquote`, `footnotes`, `captions` |
| The editor remounts when the book changes | `EditorView.swift:422` | "REMOUNTED when the book changes" |
| The knobs have fixed positions and no free numbers | `BookStyleSheet.swift` | `BookBodySize` 3, `BookLineSpacing` 3, `BookFirstLineIndent` 2, `BookSegmentSpacing` 2, `BookBodyFamily` 4, `BookHeadingLadder` 3 |
| The presets are the two the study measured | `BookStyleSheet.swift` | `BookStylePreset.printBaseline`, `BookStylePreset.general` |
| The export's shape is per target | `ManuscriptTarget.swift` | the platform targets, with the full-width indent written as U+3000 |
| The export writes the file the resolver gave | `ChapterExportEngine.swift` | the resolver's URL, not a rebuilt one |

## 3. Four places where the landed shape differs from the spec's wording

The spec's INTENT is met in all four. The API shape is not always the
shape the spec's paragraph described, and a reader comparing the spec to
the tree should know where.

1. **Heading sizes are still multipliers.** The spec asked the engine for
   ABSOLUTE per-level sizes, because "relative multipliers cannot express
   two presets whose heading sizes differ". The landed shape keeps the
   engine's multiplier API and computes the multipliers FROM each preset's
   absolute ladder (`EngineStyleSheetBridge.headingMultipliers(for:)`).
   Two presets with different heading sizes therefore do express
   themselves; the engine still takes multipliers.

2. **The body font family is not an engine configuration field.** The spec
   asked the engine to expose one. The landed shape sets the base font
   where the engine takes it: the app hands `fontName:` and `fontSize:`
   to `NativeTextViewWrapper`. The engine's configuration carries only the
   HEADING font family (`HeadingStyle.fontName`). The comment above
   `adjustedConfiguration` says so in the tree.

3. **The segment spacing is not a global 0.3.** The spec named
   `ParagraphStyle.spacingFactor = 0.3` as a value that contradicts the
   print baseline. The landed shape makes the whole paragraph style a
   function of the sheet
   (`EngineStyleSheetBridge.paragraphStyle(for: styleSheet)`), so the
   segment spacing follows the preset instead of sitting at one global
   value.

4. **The engine still does not write the configuration back.** The spec
   recorded that `NativeTextViewWrapper.updateNSView` does not write back
   `headings`, `paragraph` or `theme`, and DECIDED that the app remounts.
   The landed shape is the decided one: `EditorView.swift:422`.

## 4. The spec's three open items, and their landed answers

The spec's section 7 left three questions for the boss. Two of them were
decided during the work; one is still open and is section 5.

| Open item | Landed answer |
|---|---|
| Do the print and general sets ship as TWO presets or one? | TWO. `BookStylePreset` has `printBaseline` and `general`. |
| Is general's 1.5 line spacing one position or two? | Neither: line spacing is a three-position ladder (`tight`, `standard`, `loose`), so no preset carries a 1.5 position of its own. |
| Do the export preset and the style sheet belong on the same page or on two? | TWO pages. The style sheet is the format page; the export preset is the export sheet's target panel. |

## 5. What is still open

**The third set the study measured is not built.** The spec's section 4.1
measured THREE visual sets: the print baseline, a classic-literature set
whose heading face differs, and the general set. The tree ships TWO
(`printBaseline`, `general`). The boss's own decisions in the spec's
section 1 name only the print set and the general set, and the spec's
section 7 asks explicitly whether the second set ships at all. So this is
an open DECISION, not a gap that was quietly skipped:

- decide whether a third preset ships, and if it does, which face its
  headings wear.

Two further items are open but are engineering depth, not requirement
scope, and are listed in section 8.

## 6. The gates, and how to re-run them

Run from the repository root, on `main`. Every number below was measured
on the merged tree on 2026-11-10.

```sh
swift build
swift test --filter "BookStyleSheetTests|BookStyleSheetWriteBackTests|EngineStyleSheetBridgeTests|StyleSheetWiringTests"
python3 Tools/wenshu-devtool/verify-dead.py
```

| Gate | Result on the merged tree |
|---|---|
| 7.1 `swift build` | `Build complete!` (1.40s) |
| 7.2 the four style-sheet suites | 59 cases, 0 failures (= 36 XCTest cases across the write-back, engine-bridge and wiring suites, = and 23 Swift Testing cases in the model's own suite) |
| 7.6 `verify-dead.py` | ALIVE 121, PARTIAL 4, DEAD 0 (= = the tree this record measured; = = on today's `main` it reads ALIVE 122, = = because the tree grew one live file) |

### 7.6's count moved with the tree

The 121 above is the count on the tree this record measured (= = measured
again on `461910783d` it reads ALIVE 121, = = PARTIAL 4, = = DEAD 0, = = and
the tool's own summary line reads "Summary: 125 files"), = = and on today's
`main` it reads ALIVE 122, = = PARTIAL 4, = = DEAD 0 (= = "Summary: 126
files"). = = ⇒ The unit is FILES, = = not declarations: = = the three
counts partition the scanned files (= = 121 + 4 + 0 = 125, = = and
122 + 4 + 0 = 126), = = and what grew is one live FILE. = = The DEAD 0 is
the load-bearing half (= = nothing is fully dead), = = and the ALIVE count
is a property of the tree, = = not of this scope.

### 7.2's count was re-measured, because the wiring suite grew

The 54 this record first wrote was the count on the tree it measured (= = the
wiring suite held 6 cases then); = = the wiring suite holds 11 now (= = the
pattern-binding scope cases were added), = = and the count is **59**. = = The
table's 59 was measured on 2026-11-10 on `main` at `90e272a51b`, with:

```sh
swift test --list-tests | grep -E \
  'WenshuAppTests[.](BookStyleSheetTests|BookStyleSheetWriteBackTests|EngineStyleSheetBridgeTests|StyleSheetWiringTests)/' \
  | sed 's|.*WenshuAppTests[.]||; s|/.*||' | sort | uniq -c
```

= = which printed `23 BookStyleSheetTests`, = = `10 BookStyleSheetWriteBackTests`,
= = `15 EngineStyleSheetBridgeTests` and `11 StyleSheetWiringTests` (= = 59 in
all). = = The per-suite counts are read from the LIST, = = not from a filter's
output (= = the filter's own line is where the count goes stale, = = and the
list is the population).

The four suite names in the filter are the ones that cover this scope:
the model's own suite (`BookStyleSheetTests`, 23 Swift Testing cases), the
write-back suite (`BookStyleSheetWriteBackTests`, 10 XCTest cases), the
engine bridge suite (`EngineStyleSheetBridgeTests`, 15 XCTest cases) and
the wiring suite (`StyleSheetWiringTests`, 11 XCTest cases) = 59 cases in
all. Count them with `swift test --list-tests`, and read each suite's own
line out of a filtered run: = `swift test --filter StyleSheetWiringTests`
prints one `Executed 11 tests` line for the suite AND one `Executed 0
tests` line for each of the OTHER bundles it starts as well, = = so the
count a reader gets depends on WHICH line they read. = = Take the line
that follows `Test Suite 'StyleSheetWiringTests' passed`, = = not the
last `Executed` line in the output. On the merged tree the full run
printed `Test run with 208 tests in 24 suites passed` for the Swift
Testing half, the three XCTest suites above each printed `passed` with 0
failures, and NO line in the whole log carried a non-zero failure count.

A reader who wants the whole 7.2 gate must run `swift test` without a
filter. That full run was measured on this tree on 2026-11-10 with zero
failures, on `main` and on the style-sheet branch alike.

## 7. The board record

The verdict is recorded on the board as a comment on `t_782a9e47` (the
approved card whose reviewed sha `8a9163b1a144` covers seven of the
carriers), naming the commits that landed and the gate numbers above. The
reviewer's own conclusion is not restated there.

## 8. Not in this scope

These are the engineer-facing items that grew around the requirement. They
are live, several are still in review, and none of them changes the
statement above.

- the file splits (ExportSheet, WSChatRepository, ImportSheet, and the
  editor view that is not started)
- `Tools/wenshu-devtool/split_pre_check.py`, the split's own pre-check
- the stylesheet call-site guard and its shape matrix
- `Scripts/land_card.sh` and `Scripts/land_worktree.py`, the landing
  script's workspace resolution
- the gate matchers' handling of a split file's `+` in its name

## 9. The lessons that outlive this scope

These went into the skills the readers actually load, not into this
document alone.

1. **A content anchor, not a patch-id, is the ancestry proof.** A
   rebase rewrites the sha and the patch, so both the sha and the
   patch-id of a landed commit can be absent from the tree while the
   content is present. `git log -S <identifier>` finds the commit that
   introduced the content, and that commit is the ancestor to cite.
   Measuring the other way round -- comparing a commit's own diff
   against `origin/main` -- proves nothing about a rebase.
2. **`git cherry` prints full 40-character shas.** Matching its output
   against a short sha yields no output, which reads as "not landed" and
   is wrong. Match on full shas, or use `git log -S`.
3. **A fix that makes the process work must not live in a shared
   checkout's uncommitted state.** The matcher fix that made the `+`
   paths visible was needed for the landing to succeed, but it stayed
   uncommitted in the shared checkout and was invisible to the next
   session. Move such a fix into its own branch and commit it.
4. **A shape-matrix cell that fails to compile is a broken fixture, not
   a finding.** Two cells came back BROKEN because the fixture bound a
   `Book` where the call site wanted a `UUID`. Fix the fixture's types
   and re-run before reading anything into the result.
5. **A verifier is not a defect report.** It reports a difference; a
   difference is a defect only when the intent says so. The tool that
   checks a split must not charge a vendored tree for its formatting
   while still charging it for its lint.
