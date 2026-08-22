# h10 — FileTools (Hermes replica 07) agent toolkit wiring

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Tools/FileTools.swift` (done v0.18 ticket 07).
> 1 commit. Leaf-level change only. **No UI** — agent toolkit.

## What to build

Wire `FileTools` into `WenshuConductor.invokeTool(name, input)` so the AI agent can read / write / patch files.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `FileTools` property + `invokeTool(name, input)` method that dispatches to FileTools

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor exposes `invokeTool("file", ...)` etc.
- [ ] FileTools read / write / patch / search / list all callable from conductor
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Risks

- None — pure backend wiring