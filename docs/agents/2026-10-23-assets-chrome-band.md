# The assets column's chrome band — the two chrome recipes, and the band that was still short

Date: 2026-10-23
Card: `t_ab16914b` (merged as `505a066b2d`)
Follow-up card: `t_885b180a` (merged as `ab0de05659`)

## 1. What was wrong

The materials column's top chrome and the editor column's top chrome were
two DIFFERENT recipes, and the boss's screenshot showed the two column tops
not reading as one horizontal band.

- The materials column drew its own chrome through
  `EditorHeaderView` (an overlay hairline, no material).
- The editor column used the shared `ChromeTopBar` (a layout-row
  `Divider`, `.bar` material).

On top of that, the materials search row was pinned by an alignment guide:

```swift
.alignmentGuide(vertical: .lastTextBaseline) { _ in ... }
```

That guide was calibrated against the editor's TITLE TEXT baseline, and the
editor's title band was deleted in an earlier refactor (`EditorView.swift`
now passes `header: nil`). The guide therefore anchored to a band that no
longer existed, and the search row sat about 3.3 PT off.

`ChromeTopBar.swift` states the rule this column was breaking: any new
column-top chrome row MUST go through this component.

## 2. The first fix, and what it did not fix

The first card routed the materials search row through `ChromeTopBar` and
removed the dead `.lastTextBaseline` guide. The content centre aligned:

| | before | after |
| --- | ------ | ----- |
| assets content centre | 106.00 PT | 102.50 PT |
| editor content centre | 104.00 PT | 102.50 PT |
| delta | 2.00 PT | 0.00 PT |

But the boss's eye still saw the two bands at different heights, and the
measurement agreed: the materials `.bar` surface ran `95..110` (16 PT)
inside a 28 PT slot, while the editor's ran `89..116` (28 PT). The
materials band's bottom edge was 5-6 PT above the editor's, with bare
background where the material should have been.

**A content-centre measurement cannot see this.** A short band centred in
its slot has the right centre, so the centre metric said PASS while the
band was visibly wrong. The gate that caught it measured the band SURFACE
(= the material) as well as the content.

## 3. Why the band was short

`ChromeTopBar` paints its surface on a `VStack` that is only as tall as the
content it is given:

```
VStack { content; Divider() }.background(.bar)
```

The editor row's content is 28 PT tall (its format buttons are 28x28), so
its band is a full 28 PT. The materials row's content was a 16 PT tall
search `HStack`, so its band was 16 PT.

The call site reserved the right slot:

```swift
.frame(height: DesignTokens.paneTabHotArea)   // 28 PT
```

but that frame wraps the `ChromeTopBar` from the OUTSIDE, so it allocated
the slot without stretching the `.background(.bar)` and the `Divider()`
inside it. The frame allocated the space; the material filled only the
content.

The fix gives the inner content an explicit height, so the material covers
the whole band. It is at the CALL SITE, not in `ChromeTopBar`: the shared
component's other callers depend on its current behaviour, and the editor
column is already correct with the same component.

## 4. The outcome

Measured per column on a 2x capture of the running app, before and after:

| | before | after |
| --- | ------ | ----- |
| materials band surface | `94.5..110.0` (16.5 PT) | `88.5..116.0` (28.5 PT) |
| editor band surface | `88.5..116.0` (28.5 PT) | `88.5..116.0` (28.5 PT) |
| band top delta | 6.00 PT | 0.00 PT |
| band bottom delta | 6.00 PT | 0.00 PT |
| content centre delta | 2.00 PT | 0.25 PT |

One file changed in each card:
`Sources/WenshuApp/Features/Editor/View/AssetsPane.swift`.
`ChromeTopBar.swift`, `EditorFormatToolbar.swift`, `EditorHeaderView.swift`,
`PreviewPane.swift` and `SectionHeader.swift` are untouched.

## 5. The measurement, and the two ways it lied

The gate is
`Tools/wenshu-devtool/probes/column_chrome_band.py` (= the repository's
probe registry, so the next card that needs the number reads it instead of
writing the probe again).
It measures THREE independent things, because each catches a different
defect:

| dimension | what it catches |
| --------- | --------------- |
| content centre | the content is in the wrong place |
| band surface top | the band starts too low (= a bare gap above) |
| band surface bottom | the band ends too high (= a short band) |

Two traps in building it, both worth carrying forward:

**The PNG decoder was wrong.** It used a one-byte left offset for the
Sub/Up/Average/Paeth filters, but a non-palette RGBA image needs the
offset to be the pixel's byte width (`bpp = 4`). The wrong pixels still
produced plausible row medians, so the band measurement reported two
bands as equal when the capture plainly showed them 6 PT apart. It was
found by writing a THIRD decoder from the PNG spec and comparing all
three byte-for-byte: two decoders agreeing proves nothing if they share
the same misunderstanding.

**The gate was a rubber stamp.** It had only ever passed, which proves
nothing about its discriminating power. `--selftest` now builds three
synthetic fixtures (level, 4 PT content offset, and a SHORT band whose
centre agrees) and asserts the gate rejects the last one.

## 6. What the dead `.lastTextBaseline` guide really was

A historical anchor, not a layout decision. It was introduced on 2026-10-16
to calibrate the search row against the editor's title text baseline, and
the editor's title band was later removed (`EditorView.swift` passes
`header: nil`; `editorChromeHeader` no longer has a render path). What
remained was a pin to nothing.

## 7. Not done, deliberately

- **The section title and the tab label are NOT on one text baseline.** The
  materials column's "materials" section title and the editor's document
  tab label differ by about 3.0 PT in text baseline. Their hairline is
  already on the same Y. They carry DIFFERENT semantic roles (a section
  title vs a tab label), so forcing a shared baseline would be a design
  change, not a fix for this defect. It was left alone.
- **The dead code was not swept.** `EditorHeaderView`, `editorChromeHeader`,
  `EditorSurface.header` and the `WenshuMarkdownEditor` header forwarding
  are dead-code candidates. `AGENTS.md` 7.6 gives them their own card,
  because deleting them is a separate change with its own blast radius,
  not part of a visual fix.
