# ADR-0001: 6-zone layout (Z-TITLE / Z-NOVEL / Z-CHAT)

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍板 the wenshu homepage layout = 6 zones as truth source, data source Sketch `AF7B1C87-ADDD-41ED-8208-7CA5549070E2` Artboard `首页` (1920×984 PT, 1 PT = 1 PX macOS 27 1x). No longer the v0.07-era 5-zone (Library/Editor/Inspector/Chat/Console/Status) scratch layout.

## Decision

Homepage = title bar (1 zone) + novel management area + chat management area = 6 sub-zones:
- Z-TITLE (1920×39)
- Z-NOVEL: project management / editor / dedicated tools
- Z-CHAT: chat management / dynamic area

Each band has a 3-column layout, 5 vertical drag splitters + 1 horizontal drag splitter = 6 splitters. Zone content is rendered via SwiftUI subcomponents 1:1 matching Sketch SymbolInstance.

## Consequences

- The 5-zone pre-v0.07 layout is retained as history, no longer active
- LayoutShellView / UpperBandZone / LowerBandZone / ZoneModule etc. are the fixed names for the 6-zone implementation
- Any "5-zone" / "7-zone" proposal needs a new ADR for a fresh 拍板

## Alternatives considered

- v0.07 5-zone (Library/Editor/Inspector/Chat/Console/Status) — rejected, FCP-measured is not true
- 9-zone / 7-zone — rejected, 老板 拍 6-zone
- Old v0.05.x 7-zone (FCP-inspired) — rejected, not Apple HIG standard