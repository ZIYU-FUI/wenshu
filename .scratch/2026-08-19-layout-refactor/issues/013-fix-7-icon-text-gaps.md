# 013 Fix v0.15 vs 老板 2026-08-19 Sketch truth 7 differences

> 老板 2026-08-19 拍板: use MCP to read Sketch truth, 1:1 pixel implementation
> Truth source: mcp__sketch__run_code (`AF7B1C87-ADDD-41ED-8208-7CA5549070E2`, page 文枢-组件化, Artboard home)

## Dead principle

`52 (macOS chrome) + 465 (upper band) + 2 (D_h) + 465 (lower band) = 984 PT` ✓

## Current implementation vs 老板 Sketch truth 7 differences

| # | Item | 老板 Sketch truth | Current implementation | Fix |
|---|---|---|---|---|
| 1 | Top bar icon start y | **6 PT** | vertically centered (toolbarHeight/2 = 15) | ZoneTopToolbar.body HStack add `.padding(.top, 6)` |
| 2 | Top bar icon spacing | **27 PT** (18→45→72, diff 27) | `LayoutTokens.iconSpacingRatio = 18/1920` | Change `LayoutTokens.iconSpacingRatio = 27/1920` (or hard-code) |
| 3 | Top bar placeholder text | **x=220, y=8** (52×16, fontSize 13) | not drawn | ZoneTopToolbar body add Text placeholder text, top-right |
| 4 | Top bar divider | **y=28, h=2** (bottom 2 PT) | h=1 (bottom 1 PT) | Change `.frame(height: 2)` |
| 5 | Bottom bar placeholder elements | **2 placeholder texts** (left x=18 + right x=130, y=8) | 1 text + 1 icon | ZoneBottomToolbar.body change: left Text + right Text, delete right icon |
| 6 | Splitter | **2 PT** (master "拖拽线-竖" frame = 2×2) | 1 PT (ticket 009 changed to 1, wrong) | NativeSplitter.lineThickness change back to 2 |
| 7 | Bottom bar divider | **y=0, h=2** (top 2 PT) | h=1 | Change `.frame(height: 2)` |

## Untouched

- macOS chrome 1920×52 (老板 2026-08-19 拍 A paradigm)
- 6-zone layout regions (200/520/794/400 upper band + 1518/400 lower band, ticket 012 already correct)
- D_h y=517 ✓
- Top/bottom bar 30 PT (ticket 008 already correct)
- Editor 4 PT inset double layer (ticket 005 already correct)
- VSplitter / NativeSplitter(view) hover/drag paradigm (ticket 006 already correct)

## Acceptance

- `swift build` clean
- `swift run` + Quartz screencapture -l true screenshot
- Top bar icon start y=6, spacing 27, placeholder text top-right x=220
- Bottom bar left/right each placeholder text, distance from bottom 6
- Top/bottom divider 2 PT
- Splitter 2 PT static + 4 PT hover accent
- Overall match Sketch `AF7B1C87` 1:1 pixel

## Risk

- 老板 2026-08-19 repeatedly changed decisions: previously 拍 1 PT splitter (I changed), now Sketch master shows 2 PT
  Q21 reverts v0.15 ticket 009 "1 PT splitter" 拍板
- Top bar icon start y=6 vs current vertical center, after change icon may not align with toolbar top/bottom
- Top bar placeholder text and bottom bar placeholder text font size 13 PT (Apple HIG body), consistent with bottom bar "placeholder text"