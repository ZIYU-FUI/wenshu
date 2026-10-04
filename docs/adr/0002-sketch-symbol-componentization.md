# ADR-0002: Sketch 6-master componentization mapped 1:1 to SwiftUI

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍 the Sketch SymbolInstance componentization design = 6 master + 13 instance truth source, not the v0.07-style "frame-by-group" scattered layout. The SwiftUI implementation writes one subcomponent per master and uses the subcomponent + .frame(width:height:) per instance to land PT truth 1:1.

## Decision

6 SwiftUI subcomponents (1:1 to 6 masters):
- `TitleBarZone` (1920×39)
- `ZoneTopToolbar` (758×30)
- `ZoneBottomToolbar` (200×30)
- `ZoneModule` (200×472, main container, accepts 6 slots)
- `VerticalDragSplitter` (1×472, centered 1 PT visual line, 6 PT hit area)
- `HorizontalDragSplitter` (1920×1)

`ZoneModule` uses a `ZoneSlot` enum with 6 cases to reuse a single master; each slot switches the content layer.

## Consequences

- Any zone change only affects one switch case in ZoneModule (= ZoneModule / ZoneSlot / ZoneTopToolbar / ZoneBottomToolbar SwiftUI types are absent from the post-v0.72 tree per ADR-0011; = the current layout = AppRootScene + NavigationSplitView + NSSplitViewItem, not the ZoneModule switch-case pattern)
- Splitter changes (= pre-v0.72 = a single NativeSplitter.swift file edit; = post-v0.72 = no Splitter file to edit; = the AppKit NSSplitView provides divider color + thickness + keyboard nav as canonical Apple behavior per ADR-0011)
- On screen resize, AppRootScene + NavigationSplitView = responsive 1:1 to any window width (= the GeometryReader × ratio math ADR-0007 mandated is no longer needed; = NSSplitViewItem autosave handles persistence natively)

## Alternatives considered

- HSplitView / VSplitView — rejected, does not expose cursor / hover / divider color hooks
- NSSplitView (NSViewRepresentable) — rejected, hit area + visual line both hand-drawn, equivalent to hand-drawing NSView directly
- SwiftUI Layout protocol (custom) — rejected, over-engineered for the 6-master simple case