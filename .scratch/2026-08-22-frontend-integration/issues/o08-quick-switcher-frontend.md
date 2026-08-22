# 008 — Quick Switcher (Obsidian replica 19) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherIndex.swift` + `QuickSwitcherWindow.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `QuickSwitcherWindow` as ⌘O modal (Apple HIG Spotlight pattern), mount via **Z-TITLE toolbar icon switcher**.

## Implementation outline

**Files to touch (leaf only):**

1. Z-TITLE toolbar config — add `.quickSwitcher` item:
   - Icon: `doc.text.magnifyingglass`
   - Click → present `QuickSwitcherWindow` modal
2. `Sources/WenshuApp/App.swift` — add ⌘O keyboard shortcut to trigger QuickSwitcher
3. `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherWindow.swift` — bind to vault documents + chapters

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Z-TITLE toolbar shows quick switcher icon
- [ ] ⌘O triggers quick switcher modal
- [ ] Fuzzy search across all docs + chapters
- [ ] Pick → jump to that document
- [ ] Code-review 2 axes

## Risks

- ⌘O is Apple HIG reserved for "Open" — could conflict with NSOpenPanel. Verify behavior. Fallback: use ⌘⇧O if conflict