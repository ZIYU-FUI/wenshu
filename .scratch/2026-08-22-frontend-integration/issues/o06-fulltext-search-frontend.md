# 006 — Full-text Search (Obsidian replica 17) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Search/FullTextSearch.swift` + `SearchPanel.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `SearchPanel` as overlay + add ⌘F shortcut, mount via **Z-TITLE toolbar icon switcher**.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/App.swift` — add `.keyboardShortcut("f", modifiers: .command)` to a new search button (or to existing search trigger)
2. Z-TITLE toolbar config — add `.search` toolbar item:
   - Icon: `magnifyingglass`
   - Click → overlay `SearchPanel`
3. `Sources/WenshuApp/Core/Search/SearchPanel.swift` — bind to current vault

**Do NOT touch:** LayoutShellView, ZoneModule (parent)

**Caveat on App.swift**: App.swift is the root entry but is leaf-level for adding menu commands / keyboard shortcuts (Apple HIG pattern). It is NOT a parent view component.

## Acceptance criteria

- [ ] Z-TITLE toolbar shows search icon
- [ ] ⌘F triggers search panel
- [ ] Search across all vault documents returns matches
- [ ] Click match → jumps to document
- [ ] Code-review 2 axes

## Risks

- ⌘F may collide with system text-field find. Apple HIG reserves ⌘F for "Find" — typically the right behavior. Verify