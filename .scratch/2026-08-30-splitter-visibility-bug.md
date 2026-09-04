# Splitter Visibility Bug — Boss 2026-08-30 OOB

## Boss observation
"项目管理区和素材预览区之间的拖拽线, 素材预览区和编辑器之间的拖拽线,
与其他拖拽线实现的不同, 盘查一下"

## Pixel-level analysis (upper band Y=640, content area)

| Divider | Position (PT) | Visible brightness | Status |
|---|---|---|---|
| D_v1 (sidebar/preview) | x≈180 | 33-63 | **INVISIBLE** (= same as background) |
| D_v2 (preview/editor) | x≈535 | 62 | **INVISIBLE** |
| D_v3 (editor/tools) | x=1089 | 145-167 | **VISIBLE** ✓ |
| D_v5 (chat/dynamic) | x≈1380 | 51-77 | **INVISIBLE** |

## Root cause

All 4 vertical dividers (D_v1/D_v2/D_v3/D_v5) use the same
`VSplitter` View which wraps `NativeSplitter`. `NativeSplitter`'s
unhovered line uses Apple `.separator` ShapeStyle (round 26 fix).

In macOS 26 Tahoe dark mode with Liquid Glass tint backgrounds
(.regularMaterial @ default 50% opacity slider), Apple's
`.separator` ShapeStyle renders too faintly (= ~30-50 brightness)
to be visible against the tinted pane backgrounds.

D_v3 happens to be at a position where the editor pane (lighter)
transitions to the tools pane (darker) — that natural gradient
makes the divider visible by accident. D_v1/D_v2/D_v5 are at
positions where the panes have similar gradients and the divider
disappears into the background.

## Evidence

- NativeSplitter.swift line 209-215: unhovered returns
  `AnyShapeStyle(.separator as SeparatorShapeStyle)` (= Apple's
  canonical Liquid Glass separator, designed for Apple Pages / Mail
  in macOS 26 Tahoe, but very low contrast on dark mode with glass
  tint backgrounds).
- All 4 VSplitter calls in App.swift use the same `VSplitter` View
  = identical implementation, but only D_v3 is visible because of
  its background gradient position.
- macOS 26 dark mode `.separator` bug: Apple's own toolbar tint
  issue documented at reddit r/SwiftUI "macOS 26 toolbar has wrong
  tint color sometimes in Dark Appearance".

## Fix

Replace `.separator` with an explicit color
(`Color(nsColor: .separatorColor).opacity(0.6)`) for better
visibility in dark mode with Liquid Glass tint backgrounds.

- Static dividers (StaticDividerHorizontal/Vertical) also use
  `.separator` — same fix applies.
- Hover state already uses `.controlAccentColor.opacity(0.25)` =
  not affected.

## Acceptance criteria

1. All 4 vertical splitters (D_v1, D_v2, D_v3, D_v5) visible at
   brightness 80+ (compared to background 30-60).
2. All splitters look identical (same color, width, style).
3. Static dividers (between region tab bar and content, between
   content and status bar) visible at brightness 80+.
4. Splitter hover state (3 PT accent capsule) unchanged.

## Files to modify

- `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` line
  209-215: replace `.separator` with explicit color
- `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` lines
  175-195: update StaticDividerHorizontal/Vertical