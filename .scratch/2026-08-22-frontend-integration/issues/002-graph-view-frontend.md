# 002 — Graph view (Obsidian replica 14) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Graph/GraphView.swift` + `GraphBuilder.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire the existing `GraphView` SwiftUI view into the **Z-TITLE top toolbar icon switcher** (the title bar has 6+ slots; graph is a "primary view" feature = title bar placement).

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/ZoneModule/ZoneTopToolbar/ZTitleToolbarConfig.swift` (or equivalent) — add new `.graph` toolbar item:
   - Icon: `circle.grid.cross.fill` (SF Symbol)
   - Click → present `GraphView` as fullscreen modal (Apple HIG Spotlight pattern, see `QuickSwitcherWindow` for reference)
2. `Sources/WenshuApp/Core/Graph/GraphView.swift` — already exists; bind to current vault document set

**Do NOT touch:**
- `LayoutShellView.swift`, `WenshuApp.swift`, `ZoneModule.swift`

## Acceptance criteria

- [ ] `swift build` exit 0
- [ ] Z-TITLE toolbar shows new graph icon
- [ ] Click → fullscreen graph overlay renders node relationship graph
- [ ] Local Graph follows current selected document (1-hop / 2-hop sub-graph)
- [ ] No parent component modified
- [ ] Code-review 2 axes

## Risks

- Fullscreen modal pattern: see `QuickSwitcherWindow` (issue 008) for the same paradigm; reuse the modal hosting code