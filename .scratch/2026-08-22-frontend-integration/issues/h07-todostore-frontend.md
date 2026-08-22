# h07 — TodoStore (Hermes replica 06) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Todo/TodoStore.swift` (done v0.18 ticket 06).
> 1 commit. Leaf-level change only.

## What to build

Wire `TodoStore` as a new **Z-CHAT right pane** view (modal or sidebar): today's todo list with add/complete/edit actions.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/Todo/TodoListView.swift` (new) — SwiftUI view reading `TodoStore`
2. Z-CHAT top toolbar config — add `.todo` icon switch:
   - Icon: `checklist`
   - Click → toggle right pane showing TodoListView

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Z-CHAT toolbar shows todo icon
- [ ] Click → right pane shows today's todos
- [ ] Add / complete / delete todo works
- [ ] Code-review 2 axes

## Risks

- Z-CHAT right pane already has ContextUsage binding (per ChatZoneContextBinding v0.21 ticket 40). Add TodoListView as additional tab