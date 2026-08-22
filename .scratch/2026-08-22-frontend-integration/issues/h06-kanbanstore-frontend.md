# h06 — KanbanStore (Hermes replica 05) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Kanban/KanbanStore.swift` (done v0.18 ticket 05).
> 1 commit. Leaf-level change only.

## What to build

Wire `KanbanStore` into a new Z-NOVEL right pane view: **Kanban board** (table / status column view).

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/Kanban/KanbanView.swift` (new) — SwiftUI view that reads `KanbanStore` and renders columns
2. Z-NOVEL toolbar config — add `.kanban` icon switch:
   - Icon: `rectangle.split.3x1` (SF Symbol)
   - Click → swap Z-NOVEL content to Kanban board view

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Z-NOVEL toolbar shows kanban icon
- [ ] Click → renders kanban board with columns + cards
- [ ] Add / move / delete card works
- [ ] Code-review 2 axes

## Risks

- Kanban column layout needs SwiftUI scrollable HStack — read Apple HIG pattern