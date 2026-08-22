# h13 — VisionTools (Hermes replica 10) agent toolkit wiring

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Tools/VisionTools.swift` (done v0.18 ticket 10).
> 1 commit. Leaf-level change only. **No UI** — agent toolkit.

## What to build

Wire `VisionTools` into `WenshuConductor.invokeTool()` so the AI agent can OCR text from images + classify images.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `VisionTools` property + dispatch

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor.invokeTool("vision", ...) OCRs image
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Risks

- Apple Vision framework availability on macOS 27 — verify