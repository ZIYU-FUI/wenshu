# ADR-0003: Drag splitters via NSView + NSEvent.delta incremental

> Status: **superseded by ADR-0007** (老板 2026-08-19 ticket 005 拍板: change NSView → SwiftUI NativeSplitter(view))
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context (historical)

老板 8/18 拍 "two drag splitters are missing from the landing". Pre-v0.07, the 5 drag splitters (Library/Editor/Inspector/Chat/Console/Status) used SwiftUI NSSplitView, but Apple does not expose divider color / hit-area thickness / cursor hooks, which does not match the 老板 design's 1 PT thin line.

## Decision (historical)

All 6 drag splitters (5 vertical + 1 horizontal) are hand-drawn NSView, bridged to SwiftUI:
- `NativeSplitterView: NSView` (Public AppKit, macOS 27.0 verified) — full mouseDown / mouseDragged / mouseUp + NSCursor.resize* + draw 1 PT black line
- `NativeSplitter: NSViewRepresentable` — SwiftUI bridge
- `VerticalDragSplitter` / `HorizontalDragSplitter` — use-case wrappers, accept height / width via .frame to land PT truth

Drag callbacks use `NSEvent.deltaX` / `NSEvent.deltaY` incremental, not cumulative (no drift). v0.08 stage onDrag is an empty closure (VM drag state not yet persisted); VM integration added in v0.09.

## Supersede (2026-08-19)

See ADR-0007 (Layout shell pattern — HStack + hand-written NativeSplitter(view)). Drag splitters changed from the NSView + NSEvent.delta pipeline to SwiftUI View + DragGesture + .pointerStyle (Apple HIG official API, macOS 15+).

老板 2026-08-19 feedback on v0.14.1 regression: Canvas redraw + NSView overlay transparent hit area dropped all hover/drag visuals (Canvas does not respond to hover, NSView cursor does not propagate to the SwiftUI top-level window). Reverted to Apple HIG SwiftUI pattern.

## Consequences (historical, partially overridden by ADR-0007)

- 6 drag splitters landed 1:1, hit area 6 PT, visual line 1 PT, 老板 can drag — **inherited by ADR-0007, changed to 2 PT static / 4 PT hover accent capsule**
- VM drag state not persisted before v0.09, drag visual would snap back — **wired to VM in v0.10.1, fixed**
- Non-draggable dividers (StaticDivider) use SwiftUI Divider / Color.frame, not coupled to drag splitters — **inherited by ADR-0007**

## Alternatives considered (historical, partially updated by ADR-0007)

- HSplitView / VSplitView (SwiftUI) — rejected, no hook exposed — **inherited by ADR-0007**
- NSSplitView (AppKit) — rejected, hit area / divider color cannot be changed — **inherited by ADR-0007**
- SwiftUI DragGesture — rejected, drag across SwiftUI renders flickers — **2026-08-19 rejection reason withdrawn: v0.14.1 verified that SwiftUI top-level window DragGesture does not flicker, Apple HIG official pattern**