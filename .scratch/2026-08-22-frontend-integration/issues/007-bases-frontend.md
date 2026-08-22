# 007 — Bases (Obsidian replica 18) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Bases/BaseParser.swift` + `BaseView.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `BaseView` as alternative Z-NOVEL content view, toggleable via **Z-NOVEL top toolbar icon switcher**.

## Implementation outline

**Files to touch (leaf only):**

1. Z-NOVEL top toolbar config — add `.bases` item:
   - Icon: `tablecells`
   - Click → switch Z-NOVEL content from `BookOutlineView` (cards) to `BaseView`
2. `Sources/WenshuApp/Core/Bases/BaseView.swift` — bind to current `.base` file selection

**Do NOT touch:** ZoneModule (parent switcher), LayoutShellView

## Acceptance criteria

- [ ] Z-NOVEL toolbar shows bases icon
- [ ] Click → Z-NOVEL content switches to Bases database view
- [ ] Click again → switches back to outline view
- [ ] Code-review 2 axes

## Risks

- Toggling content view at parent level = needs to NOT touch `ZoneModule`. If current implementation does, restructure ticket to only modify the toolbar (state stored in a `@State` and propagated via `@Environment`)