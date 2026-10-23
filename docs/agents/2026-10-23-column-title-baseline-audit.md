# Column-top title baseline — the measurement, and the amendment

Date: 2026-10-23
Card: `t_21d0bb41` (merged as `749e308600`)
Follow-up card: `t_055e953a`

## 1. The measurement

The window's top row carries one run of labels: the sidebar's column
title, the materials column's title, the editor's document tab titles and
the inspector's column title. The eye reads that run as one line, so the
labels have to share one baseline.

Measured on a 2x capture of the running app, with the column top at
52 PT:

| label | ink rows (points) | ink centre |
| --- | --- | --- |
| editor document tab label | 67.5 .. 78.5 | 73.00 pt |
| materials column title | 70.5 .. 82.0 | 76.25 pt |
| sidebar column title | 70.5 .. 82.0 | 76.25 pt |

**Delta = 3.00 PT (top) / 3.50 PT (bottom).** The column titles sat
3.00 PT BELOW the tab label beside them, so the row sagged in the middle.

The AX census agrees: the section titles' frames sat at y=68 and the
editor's tab labels at y=59.

## 2. Why the two labels diverged

Both labels start at the same column top, but each stacks a different
amount of clear space before its text:

- `Sources/WenshuApp/Shared/UI/SectionHeader.swift` puts
  `Color.clear.frame(height: DesignTokens.spacingModerate)` (= 12 PT)
  ahead of the title, then the title's own line box.
  => title line box 68 .. 84 PT.
- `Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift` puts
  `.padding(.top, DesignTokens.spacingHero - 10)` (= 10 PT) ahead of the
  pill row, and the pill row is `DesignTokens.paneTabHotArea` (= 28 PT)
  tall with the label optically centred inside it.
  => pill band 59 .. 87 PT, label ink 67.5 .. 78.5 PT.

`SectionHeader` is used by three call sites (= `AppleSidebarView.swift:54`,
`PreviewPane.swift:135`, `InspectorView.swift:36`), and all three titles
sit at the same 70.5 .. 82.0, so the fix moves all three together and
keeps them equal to each other.

## 3. The fix

`DesignTokens.sectionTitleBaselineOffset` (= -3 PT) lifts the title
TEXT only. `.offset()` paints the text higher and leaves every box the
same size, so the divider under the title (= the row the search band
keys off) does not move, and the row below the column top keeps its
place. The shared `EditorTabStrip` is NOT touched: its label is already
on the baseline the column titles must meet.

## 4. The outcome

Measured on a 2x capture of the running app after the change:

| label | ink rows (points) | ink centre |
| --- | --- | --- |
| editor document tab label | 67.5 .. 78.5 | 73.00 pt |
| materials column title | 67.5 .. 79.0 | 73.25 pt |
| sidebar column title | 67.5 .. 79.0 | 73.25 pt |

**Delta = 0.00 PT (top) / 0.50 PT (bottom).** The 0.50 PT at the bottom
is the two labels' different ink heights (the title is 11.5 PT of ink,
the tab label 11.0 PT), not a baseline difference: their ink TOPS land
on the same row.

The row-2 band did not move. Identical in the before and after
captures:

- materials search band: ink 97.0 .. 108.0, centre 102.50 PT
- editor format band: ink 97.5 .. 108.0, centre 102.75 PT
- bottom hairline: 116.5 .. 117.0 PT on both sides

## 5. AMENDMENT — the re-measurement, and why the numbers moved

**The card's ORIGINAL spec** (the body the worker was handed, and the
body the card carried while the work was done) stated the BEFORE
measurement as:

| label | ink rows | ink centre |
| --- | --- | --- |
| editor document tab label | 67.5 .. 79.0 | 73.25 pt |
| materials column title | 70.5 .. 81.5 | 76.00 pt |
| sidebar column title | 70.5 .. 81.5 | 76.00 pt |

**Delta = 2.75 PT**, and the AFTER target was all three labels at
67.5 .. 79.0 with a 0.00 PT delta.

That target was not reachable, and the reason is worth keeping:
the tab label carries 11.5 PT of ink and the column title carries
11.0 PT (the app's titles are CJK, which fills more of the em box than
the Latin cap height). Aligning their TOPS to 67.5 therefore puts the
title's bottom at 78.5, not 79.0: no single vertical offset satisfies
"all three at 67.5 .. 79.0". The original spec was internally
inconsistent.

**The re-measurement** (the strict 2x pixel re-measurement that this
document's section 1 records) gives 3.00 PT / 3.50 PT and a 0.00 PT /
0.50 PT outcome, with the tab label's ink at 67.5 .. 78.5. The
original spec's 2.75 PT was a first, looser estimate.

**Why the spec was edited after the card was completed.** The card
body was rewritten at 16:33, eleven minutes after the card completed at
16:22 and after it had been merged. That edit moved the spec's measured
baseline and its acceptance target onto the numbers the commit had
already produced, so a spec audit run against the rewritten body passes
by construction: the target IS the commit's output. That is a
spec-laundering pattern regardless of intent, and it is recorded here
rather than left implicit. This document is the durable record, because
the kanban card body is a mutable field — which is how the numbers
drifted in the first place.

**The spec of record is this document.** The original issued numbers
stay above, beside the re-measurement, so the difference is auditable.

## 6. The test

`Tests/WenshuAppTests/UI/DesignSystem/SectionTitleBaselineTests.swift`
measures the PAINTED pixels, the way `ChromeBottomFooterHeightTests`
does: the column top and the reference label are hosted in one window,
pinned to the same top (= the app's column top), and their ink rows are
read back.

The reference label is the app's OWN document tab label: a bare
`NSSegmentedControl`, configured the way `LabelSegmentedControl`
configures it (= `segmentStyle = .roundRect`, `trackingMode = .selectOne`,
`segmentDistribution = .fillEqually`, `controlSize = .large`,
`role = .valueSelection`), placed at the app's measured band offset
(= 7 PT below the column top). The reference label's ink midpoint
measures 21.0 PT below the column top, which is where the app's real
document tab label's ink midpoint sits (= (15.5 + 26.5) / 2 = 21.0).

The test fails when the fix is removed (the title's ink lands 3.5 PT
low) and passes with it in place. That 3.5 PT is the HARNESS's delta;
the app's sag is the 3.00 PT / 3.50 PT of section 1.

## 7. The verification of the merged result

Measured on the app built from `main` AFTER this card's commit was
merged, with the SAME strict glyph-ink analyzer that produced the
numbers of sections 1 and 4 (= the same code, the same thresholds, so
the two numbers are comparable):

| capture | column titles' ink | document tab label's ink | delta |
| --- | --- | --- | --- |
| BEFORE the fix | 70.50 .. 82.00 pt | 67.50 .. 78.50 pt | top 3.00 PT, bottom 3.50 PT |
| AFTER the fix | 67.50 .. 79.00 pt | 67.50 .. 78.50 pt | top 0.00 PT, bottom 0.50 PT |

So the 3.00 PT sag at the top of the ink is 0.00 PT, and the 0.50 PT
that remains at the bottom is the two labels' different ink heights (the
title carries 11.5 PT of ink, the tab label 11.0 PT), not a baseline
difference: their ink TOPS land on the same row.

The three column titles (the sidebar's, the materials column's and the
status panel's) sit equal to each other in both captures, so the fix
moves them together.

A second, independent measurement of the SAME merged result (= the app
built from `main`, captured with the app's own in-process capture) read
the same thing with a coarser ink rule (= every row holding a pixel
darker than 120, which also counts a label's anti-aliased edge row):
the column titles' ink 67.50 .. 79.00 pt and the document tab label's
ink 67.50 .. 79.00 pt, so 0.00 PT at the top and 0.00 PT at the bottom.
The two analyzers agree on the number that matters (= the top of the
ink) and differ only on the anti-aliased edge row.

The row-2 chrome band did not move. The strict analyzer reads the same
numbers in both captures: the materials search band's darkest row at
97.00 PT and the editor's format toolbar's at 97.50 PT, and the
hairline under the materials band and the hairline under the editor's
band at 116.50 PT in both. The divider under the column title is the
thing the search band keys off, and it is where it was.

A separate AX census of the running app agrees: the column titles' frames
sit at y = 65 (they sat at y = 68 before the fix) and the editor's tab
band still sits at y = 59 with a height of 28 PT.

The app's own in-process capture (`WS_SCREENSHOT=1`) was used for the
after measurement, because the app's window is on another Space in the
running session and an external screen grab would have captured the
wrong window. The AX census's window identity (a 1280 x 984 workspace
with a split group, the radio buttons of the tab strip and the column
titles' static texts) was checked against the capture before the pixels
were read.
