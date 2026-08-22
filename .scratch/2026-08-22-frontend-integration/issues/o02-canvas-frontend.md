# 003 — Canvas / JSON Canvas (Obsidian replica 13) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Canvas/CanvasView.swift` + `JSONCanvasCodec.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire the existing `CanvasView` SwiftUI view into the **Z-NOVEL top toolbar icon switcher** as a fullscreen modal.

## Implementation outline

**Files to touch (leaf only):**

1. Z-NOVEL top toolbar config — add `.canvas` item:
   - Icon: `rectangle.on.rectangle` (SF Symbol)
   - Click → fullscreen modal hosting `CanvasView`
2. `Sources/WenshuApp/Core/Canvas/CanvasView.swift` — bind to current `.canvas` file selection
3. `Sources/WenshuApp/Core/Canvas/JSONCanvasCodec.swift` — already parses / encodes .canvas files; verify on test fixture

**Do NOT touch:** LayoutShellView, App entry, ZoneModule

## Acceptance criteria

- [ ] Z-NOVEL toolbar shows canvas icon
- [ ] Click → fullscreen modal renders canvas with JSON Canvas nodes + edges
- [ ] Open existing `.canvas` file (Obsidian fixture) → renders 1:1
- [ ] Save → file 1:1 round-trip with Obsidian's `jsoncanvas.org` spec
- [ ] No parent modified
- [ ] Code-review 2 axes

## Risks

- Canvas is heavyweight view; fullscreen modal may strain GPU on large vaults. — accept for v0.22, optimize later