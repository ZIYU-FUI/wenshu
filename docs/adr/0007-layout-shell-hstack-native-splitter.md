# ADR-0007: Layout shell pattern — HStack + hand-written NativeSplitter(view)

> Status: accepted
> Date: 2026-08-19
> Decision-maker(s): 老板 (2026-08-19 ticket 005 拍板)
> Supersedes: ADR-0003 (drag-splitter-nsview)

## Context

v0.10 ~ v0.14 LayoutShellView used Canvas redraw (TimelineView(.animation) 60 fps GPU render) + 6 NSView overlay transparent hit areas catching drag events (v0.10 NativeSplitterView NSView path mandated by ADR-0003).

v0.14 introduced `NativeSplitter.swift` (View component, DragGesture + .pointerStyle + hover 4 PT accent capsule, Apple HIG official API), but v0.14.1 regressed back to Canvas + NSView overlay and dropped all hover/drag visuals (老板 2026-08-19 feedback).

老板 2026-08-19 拍板: revert to the Apple HIG truth-source pattern — HStack + hand-written NativeSplitter(view). Reasons:
1. **HSplitView / VSplitView** divider color is not modifiable (publicly known limitation, long-known on StackOverflow)
2. **NavigationSplitView** is the 3-column navigation pattern, doesn't map to the Sketch 6-zone layout
3. **Canvas + NSView overlay** has cursor cross-boundary + drag flicker issues in SwiftUI top-level window (Canvas does not respond to hover, NSView cursor does not propagate to SwiftUI), the root cause of the v0.14.1 regression chain

## Decision

6-zone layout uses the Apple HIG HStack pattern:

```
VStack(spacing: 0) {
    UpperBandZone()  // HStack(spacing: 0) { 4 zone + 3 NativeSplitter(view) }
    NativeSplitter(orientation: .horizontal, ...)  // D_h horizontal drag splitter
    LowerBandZone()  // HStack(spacing: 0) { 2 zone + 1 NativeSplitter(view) }
}
```

- Title bar = macOS `.windowStyle(.titleBar)` 52 PT unified chrome (replaces v0.14.1 Canvas redraw + hand-written TitleBarZone, 老板 2026-08-19 拍)
- Zone components = SwiftUI view tree (ZoneModule = VStack { ZoneTopToolbar; content; ZoneBottomToolbar }), no Canvas redraw
- Drag splitters = `NativeSplitter.swift` v0.14 complete version (1 component + `SplitterOrientation` enum), edit 1 place = all 6 drag splitters respond

## Consequences

- Edit 1 place = all 6 drag splitters respond (NativeSplitter 1 component + orientation parameter)
- hover/drag/cursor visuals fully restored (v0.14.1 dropped hover 4 PT accent capsule + DragGesture + .pointerStyle)
- Title bar double-layer gone (Canvas redraw + macOS chrome double-layer → macOS chrome single-layer)
- Responsiveness = GeometryReader × ratio operator × actual PT (LayoutTokens.bandRatio / toolbarRatio / editorVerticalInsetRatio), adapts 1:1 to any window size
- Apple HIG truth source: PointerStyle.columnResize / .rowResize (macOS 15+) + DragGesture + .drawingGroup() + .clipShape(.capsule) + .shadow(color:opacity:radius:)

## Alternatives considered (historical)

- **HSplitView / VSplitView** (Apple official macOS 10.15+ Split Views) — rejected, divider color not modifiable
- **NavigationSplitView** (Apple official macOS 13+) — rejected, 3-column navigation pattern doesn't map to Sketch 6-zone
- **Canvas + NSView overlay** (v0.14.1 path) — rejected, cursor cross-boundary + drag flicker + hover all dropped
- **NSView + NSEvent.mouseDragged** (v0.10 path) — rejected, same problem as direct Canvas + NSView overlay
- **SwiftUI Layout protocol (custom)** — rejected, over-engineered for the 6-master simple case