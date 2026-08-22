# 02 — Splitter / divider visual reach edge (off-by-1-pixel fix, 老板 2026-08-19 19:00 拍)

**What to build:**
老板 2026-08-19 19:00 feedback "splitter doesn't reach edge, looks like off by 1 pixel; divider is the same, handle together".

After change:
- NativeSplitter body Rectangle frame change to hitAreaThickness (6 PT) visually fill hit area
- Splitter D_h spans full window width, D_v fills zone height
- StaticDividerHorizontal / Vertical Rectangle frame change to fill split region

**Blocked by:** None
**Status:** ready-for-agent → impl done → waiting for 老板 verify

## Known root cause

- `NativeSplitter.swift` L155-160: Rectangle `.fill(...) .frame(width: lineFrame.width, height: lineFrame.height)` — Rectangle frame is lineFrame (2 PT static / 4 PT hover), centered inside hit area (6 PT)
- Hit area (6 PT) transparent NSView overlay, visual Rectangle (2/4 PT) centered inside, **1-2 PT blank top/bottom or left/right**
- 老板 sees "off by 1 pixel" = visual Rectangle doesn't 100% occupy hit area width, with 1-2 PT blank top/bottom or left/right

## Sketch AF7B1C87 truth

- D_h (horizontal splitter) truth: x:0, y:517, w:1920, h:2 (spans full window width, 1920 PT 1:1)
- D_v (vertical splitter) truth: x:200/720/1244, y:52, w:2, h:465 (full band height, 2 PT wide)
- Truth both 100% fill region, off by 0 pixel

## Fix direction

老板 拍 A:
- Option A: Rectangle frame change to hitAreaThickness (6 PT) visually fill hit area, splitter reaches edge
- Option B: Rectangle frame keep 2 PT but NSTrackingArea bounds exactly equal Rectangle visual area
- Option C: 1 PT adjust (e.g. Rectangle frame +1 PT = 3 PT visual) to resolve off-by-1-pixel

Per Apple HIG truth + Sketch 1:1 truth (D_h / D_v 100% fill region) — option A most stable, matches 老板 original intent "reach edge".

## Acceptance criteria

- [ ] NativeSplitter Rectangle frame change to hitAreaThickness (6 PT) visually fill hit area
- [ ] D_h splitter spans full window width (1920 PT)
- [ ] D_v 5 vertical splitters fill zone height (zone bandH)
- [ ] StaticDividerHorizontal Rectangle frame fills split region
- [ ] StaticDividerVertical Rectangle frame fills split region
- [ ] Splitter / divider visual 1:1 matches Sketch AF7B1C87 (off by 0 pixel)
- [ ] Hover blue glow (Apple system bright color `.controlAccentColor.opacity(0.25)`) all preserved
- [ ] Splitter / divider hover 4 PT thicker preserved
- [ ] Splitter drag / hit area / 6 PT hit area unchanged
- [ ] macOS chrome 52 PT unchanged
- [ ] LayoutTokens / bandH / toolbar width unchanged
- [ ] `swift build` exit 0

## Business-language description (老板 understands)

- Splitter visual reaches edge (off by 0 pixel, not like previously off by 1 pixel)
- Divider same (horizontal/vertical both reach edge)
- 1:1 match Sketch AF7B1C87 (老板 Sketch truth)