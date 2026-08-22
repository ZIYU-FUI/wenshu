# h11 — ProcessTools (Hermes replica 08) agent toolkit wiring

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Tools/ProcessTools.swift` (done v0.18 ticket 08).
> 1 commit. Leaf-level change only. **No UI** — agent toolkit.

## What to build

Wire `ProcessTools` into `WenshuConductor.invokeTool()` so the AI agent can run shell processes.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `ProcessTools` property + dispatch

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor.invokeTool("process", ...) runs shell
- [ ] Output captured and returned
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Risks

- Process spawning is sandboxed in macOS app. Verify entitlements