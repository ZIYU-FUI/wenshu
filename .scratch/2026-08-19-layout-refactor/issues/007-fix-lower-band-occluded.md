# 007 Fix LayoutShellView lower band being occluded + splitter invisible

> 老板 2026-08-19 拍板: fix
> Dead principle: 52 (macOS chrome) + upper + splitter + lower = 984 PT, do not touch

## Current state (commit `65611e7` true render)

- Title bar macOS chrome single layer 52 PT ✅
- Upper band 4 columns + top bar 3 SF Symbol ✅
- Editor 4 PT inset double layer + left/right flush ✅
- **Lower band 2 zones top/bottom bar "placeholder text" visible, but middle large blank**
- **D_h horizontal splitter (y=519) invisible**
- **D_v5 splitter (x=1519) invisible**

老板 feedback: "lower half zone seems to be blocked by something, splitter invisible"

## Dead principle

`52 (macOS chrome) + upper + splitter + lower = 984 PT` — do not touch

## Fix direction (don't touch dead principle)

1. **Verify NSWindow.contentLayoutRect true size** — LayoutShellView GeometryReader should get NSWindow content view full height (already deducts macOS chrome), not full window frame
2. **See what contentH actually computes** — LayoutShellView VStack exceeds view frame will cause lower band to be cut off
3. **Don't touch LayoutTokens.bandRatio = 465/984 = 0.4726** (老板 8/18 拍)
4. **Don't touch `.windowStyle(.titleBar)`** (老板 2026-08-19 拍 macOS official)
5. **Don't touch LayoutShellView VStack structure** (TitleBarZone not in VStack, uses macOS chrome)

## Scope (minimum change)

LayoutShellView.body geometry calculation:
- `let totalW = proxy.size.width`
- `let contentH = proxy.size.height`  ← verify whether = 932 (984 - 52 macOS chrome)
- `let bandH = contentH * LayoutTokens.bandRatio`  ← compute 932 × 0.4726 = 440 PT

VStack: UpperBandZone + D_h + LowerBandZone (total 880 + 1 = 881)
52 chrome + 881 = 933 ≈ 932 ✓

If LayoutShellView GeometryReader reports 984 instead of 932, VStack expands 984 + chrome 52 = 1036 > 984 window, lower band expands outside window and gets cut off

## Acceptance

- `swift build` clean
- `swift run` + screencapture -l true screenshot
- Lower band middle can see AI chat / AI dynamic
- D_h horizontal splitter (y=519) clearly visible
- D_v5 splitter (x=1519) clearly visible
- Dead principle number-pair 52+465+2+465=984 ✓

## Risk

- If macOS chrome actually isn't 52 PT (I misjudged) → change `LayoutTokens.titleBarHeight` doesn't count as touching dead principle
- If LayoutShellView VStack internal calculation wrong → fix geometry doesn't count as touching dead principle

## Untouched

- `LayoutTokens.bandRatio / toolbarRatio / editorVerticalInsetRatio` (老板 8/18 拍)
- `.windowStyle(.titleBar)` (老板 2026-08-19 拍)
- LayoutShellView VStack structure (Upper + D_h + Lower)
- ZoneModule / ZoneTopToolbar / ZoneBottomToolbar / NativeSplitter / VSplitter
- ADR-0007 + spec §5.2 S1