# 014 — SkillRegistry (Hermes replica 02) startup scan + invoke

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Skills/SkillRegistry.swift` (done 8/19).
> 1 commit. Leaf-level change only. Background wiring, no UI.

## What to build

Wire `SkillRegistry.scan()` at app startup; expose `SkillRegistry.invoke(name, input)` from `WenshuConductor` for agent use.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `SkillRegistry` as a property; scan on init; expose `invokeSkill(name, input)` method
2. `Sources/WenshuApp/Core/Skills/SkillRegistry.swift` — verify scan / load / invoke API signature (read existing file first)

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] `WenshuConductor` holds a `SkillRegistry` instance
- [ ] `scan()` called on init
- [ ] `invokeSkill(name, input)` returns skill result
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Risks

- `SkillRegistry.scan()` may be slow at startup. Mitigation: lazy scan on first invoke