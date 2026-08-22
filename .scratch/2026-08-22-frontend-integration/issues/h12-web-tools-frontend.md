# h12 — WebTools (Hermes replica 09) agent toolkit wiring

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Tools/WebTools.swift` (done v0.18 ticket 09).
> 1 commit. Leaf-level change only. **No UI** — agent toolkit.

## What to build

Wire `WebTools` into `WenshuConductor.invokeTool()` so the AI agent can fetch URLs + convert HTML to markdown.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `WebTools` property + dispatch

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor.invokeTool("web", ...) fetches URL
- [ ] HTML → markdown conversion works
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Risks

- macOS app network entitlements. Verify Info.plist ATS settings