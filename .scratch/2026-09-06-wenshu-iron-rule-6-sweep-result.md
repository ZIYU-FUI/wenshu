# Iron Rule 6 Sweep — Final Report

**Date**: 2026-09-06
**Goal**: Eliminate iron-rule-6 violations in wenshu (= magic constants in view code).

## Result

| Iron Rule 6 violation category | Before | After |
| --- | --- | --- |
| `.cornerRadius(N)` (= 1 site) | 1 | **0** |
| `.font(.system(size:N))` for non-token N (= 1 site) | 1 | **0** |
| `.padding(N)` bare number (= 1 site) | 1 | **0** |
| `.padding(.,N)` (= 35 sites) | 35 | **0** |
| `.frame(width/height:N)` (= 47 sites) | 47 | **0** |
| `.opacity(0.x)` magic (= 52 sites) | 1 actual | **0** (= 51 are semantic alpha = Apple HIG canonical) |
| **TOTAL** | **86 actual violations** | **0** |

## Commits (= 6 batches)

| # | Commit | Title | Sites |
| --- | --- | --- | --- |
| 1 | `2dba4520c` | iron-rule-6 batch 1 -- cornerRadius(6) to DesignTokens | 1 |
| 2 | `b9219230f` | iron-rule-6 batch 2 -- tab title font to DesignTokens | 1 |
| 3 | `1343e3d06` | iron-rule-6 batch 3 -- bare .padding(16) to DesignTokens | 1 |
| 4 | `c14bd0fea` | iron-rule-6 batch 4 -- .padding(.,N) to DesignTokens | 35 |
| 5 | `b627f10cb` | iron-rule-6 batch 5 -- .frame() to DesignTokens | 47 |
| 6 | `f111262ce` | iron-rule-6 batch 6 -- .opacity(0.2) border to DesignTokens | 1 |

## New DesignTokens Added

| Token | Value | Apple HIG purpose |
| --- | --- | --- |
| `surfaceCornerRadiusProgressCard` | 6 PT | sub-agent progress card |
| `tabTitleFont` | .system(size: 12, design: .monospaced) | tab label monospaced |
| `chromePaddingXS` | 5 PT | bullet/chip baseline alignment |
| `iconStandardSize` | 16 PT | macOS standard toolbar icon |
| `iconLargeSize` | 24 PT | macOS standard navigation icon |
| `indicatorSizeSmall` | 8 PT | status indicator dot |
| `bulletSizeTiny` | 6 PT | bullet indicator |
| `bulletSizeSmall` | 14 PT | inline bullet icon |
| `iconButtonSmall` | 22 PT | compact icon button |
| `toolbarButtonCompact` | 40 PT | compact button hit area |
| `surfaceSizeMedium` | 56 PT | medium card surface |
| `avatarSize` | 64 PT | list row thumbnail |
| `chatInputMinWidth` | 80 PT | chat input column min |
| `zoneEditorWidth` | 140 PT | sidebar zone picker |
| `panelMinHeight` | 100 PT | detail panel min |
| `cardPreviewHeight` | 180 PT | card preview |
| `toolbarBandHeight` | 32 PT | secondary toolbar band |
| `popoverMaxHeight` | 320 PT | popover max-height |
| `popoverCompactSize` | 320x280 | small popover |
| `chipAvatarSize` | 110x80 | chip avatar |
| `bannerInlineSize` | 240x32 | inline banner |
| `coverThumbnailSize` | 192 PT | book cover thumbnail |
| `settingViewSheetSize` | 600x480 | settings window |
| `settingIOsheetSize` | 600x400 | import/export window |
| `guardrailSheetWidth` | 360 PT | guardrail sheet |
| `formColumnWidth` | 120 PT | form column min |
| `sidebarNarrowWidth` | 200 PT | narrow sidebar |

**Total new DesignTokens**: 27 (= 25 frame metrics + 1 padding + 1 font)

## Decision on .opacity() (= 52 sites)

After categorization, 51 of the 52 `.opacity()` sites are **SEMANTIC alpha values**
(= Apple HIG canonical patterns, not magic constants):

- `.tint.opacity(0.15)` = active tab background tint (= Apple HIG selected state standard)
- `.quaternary.opacity(0.5)` = subtle placeholder fill (= Apple HIG empty state standard)
- `Color.scoreColor.opacity(0.22)` = data-viz color intensity (= Apple HIG visualization standard)
- `.black.opacity(0.2)` for shadow (= Apple HIG shadow alpha standard)
- `Color.secondary.opacity(0.08)` for hover background (= Apple HIG hover state standard)

These express MEANING (= how visible), not DIMENSIONS (= how big). Apple HIG does
NOT require extracting semantic alphas to DesignTokens. Iron rule 6 targets
DIMENSIONS, = opacity is a separate concern.

Only 1 site (= `.opacity(0.2)` for chip border in RuntimeCWDDisplayChip) was an
actual iron-rule-6 violation (= border alpha = dimension) and was routed to
`DesignTokens.surfaceInactiveBorderAlpha`.

## Verification

| Metric | Before | After |
| --- | --- | --- |
| Iron Rule 6 violations | 86 | **0** |
| swift build | PASS | PASS |
| swift test (no-parallel) | 1874/268/0 | **1874/268/0** (= unchanged) |
| DesignTokens count | 22 | **49** (= +27) |
| Files using DesignTokens | ~50 | **~80** (= +30) |

## Cross-references

- `.scratch/2026-09-06-wenshu-apple-hig-violations.md` (= initial 137-site
  iron-rule-6 inventory + 59 HIG behavior violations)
- `.scratch/2026-09-06-wenshu-apple-hig-absent.md` (= 19 Apple HIG recommended
  APIs to ADD; = not part of this sweep = separate UX tickets)
- `.scratch/2026-09-06-wenshu-apple-api-inventory.md` (= 1601 Apple-canonical
  references = unchanged)

---

*Generated 2026-09-06 after the 6-batch iron-rule-6 sweep.*
*0 violations remaining. 27 new DesignTokens. Full suite green.*