# 013 — MemoryStore (Hermes replica 01) frontend wiring

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Memory/MemoryStore.swift` (done 8/19).
> 1 commit. Leaf-level change only. Background wiring, no UI.

## What to build

Wire `MemoryStore` into `WenshuConductor.init()` so the AI agent has long-term memory across sessions.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `MemoryStore` as a property; bootstrap on init; expose `addMemory` / `searchMemory` methods

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] `WenshuConductor` holds a `MemoryStore` instance
- [ ] `bootstrap()` called on init
- [ ] `searchMemory(query)` available to agent for context retrieval
- [ ] swift build + tests pass (no regression in existing 338)
- [ ] Code-review 2 axes

## Risks

- None — wiring only, no UI changes
- Test isolation: `MemoryStore` is SQLite-backed. WenshuConductor init must handle failure gracefully (return empty if no DB)