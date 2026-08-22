# h14 — AVMediaTools (Hermes replica 11) agent toolkit + chat read-aloud

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Tools/AVMediaTools.swift` (done v0.18 ticket 11).
> 1 commit. Leaf-level change only.

## What to build

Wire `AVMediaTools` into `WenshuConductor.invokeTool()` (agent toolkit) + add read-aloud button in **Z-CHAT toolbar** for AI replies.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — add `AVMediaTools` property + dispatch
2. Z-CHAT toolbar config — add `.readAloud` icon switch:
   - Icon: `speaker.wave.2`
   - Click → trigger AVMediaTools.read aloud on current AI reply

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] WenshuConductor.invokeTool("av", ...) reads aloud
- [ ] Z-CHAT toolbar shows read-aloud icon
- [ ] Click → AI reply spoken
- [ ] Code-review 2 axes

## Risks

- AVSpeechSynthesizer available on macOS 27 — verify