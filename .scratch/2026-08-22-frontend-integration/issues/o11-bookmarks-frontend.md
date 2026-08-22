# 011 — Bookmarks (Obsidian replica 22) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift` + `BookmarkPanel.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `BookmarkPanel` as a new **View menu** item + Z-TITLE toolbar icon switcher.

## Implementation outline

**Files to touch (leaf only):**

1. Z-TITLE toolbar config — add `.bookmarks` item:
   - Icon: `bookmark`
   - Click → overlay `BookmarkPanel`
2. `Sources/WenshuApp/Core/Agent/WenshuAppDelegate.swift` (or App.swift) — add "View → Bookmarks" menu item

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Z-TITLE toolbar shows bookmark icon
- [ ] View menu shows Bookmarks item
- [ ] Both present `BookmarkPanel` overlay
- [ ] Add / remove bookmark from current document works
- [ ] Code-review 2 axes

## Risks

- Menu item location: see issue 004 (Templates) for the same pattern