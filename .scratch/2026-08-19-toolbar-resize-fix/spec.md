# Spec — Toolbar width stretched by VStack stretch to fill zone actual width (v0.16 ticket 01)

> Date: 2026-08-19
> Truth source: wenshu-pocock-workflow skill Q20 + macOS-only dead principle

## Problem Statement

老板 2026-08-19 拍 "zone module components have implementation issues, top bar / bottom bar placed inside zone module, varies with zone module size"

Current: NativeSplitter uses parent band full width `totalW` (LayoutShellView passes in), but each zone actual width is different (200/400/520/794/1518/400 PT) — toolbar draws across splitter overflows to adjacent zone.

## Solution

Business-language description:
- Top bar / bottom bar no fixed width, no width parameter
- Use macOS system SwiftUI VStack sub-view default stretch full width, auto stretch to zone actual width
- Toolbar height still 30 PT hard-coded, ICON 18 PT / placeholder text 13 PT / divider 2 PT all preserved

## User Stories

1. As 老板, I want top bar / bottom bar independently render inside each zone module, not draw across splitter
2. As 老板, I want when dragging D_v to change zone width, top bar / bottom bar scale accordingly
3. As 老板, I want toolbar visual (height / font size / divider) all preserved

## Implementation Decisions

- ZoneTopToolbar / ZoneBottomToolbar delete `totalW: CGFloat` parameter
- Internal no `.frame(width:)` (let VStack sub-view default stretch)
- Height 30 PT / 18 PT ICON / 13 PT placeholder text / 2 PT divider all preserved

## Implementation

- Sources/WenshuApp/App.swift: ZoneTopToolbar change to `iconNames: [String]`, ZoneBottomToolbar change to `var body: some View`
- Sources/WenshuApp/App.swift: LayoutShellView VStack call `ZoneTopToolbar(iconNames: [...])` + `ZoneBottomToolbar()`, no pass totalW
- Sources/WenshuApp/App.swift: UpperBandZone / LowerBandZone / ZoneModule caller unchanged (ZoneModule still receives totalW passes to toolbar)

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app to verify

## Out of Scope

- Do not rewrite NativeSplitter
- Do not change toolbar height 30 PT
- Do not change ICON 18 PT / placeholder text 13 PT / divider 2 PT
- Do not touch macOS chrome / LayoutTokens / bandH

## Further Notes

- v0.16 ticket 01 commit `ae5bbf82e` + `4d9b2968e` (comment cleanup) already implemented
- 老板 8/19 verified pass