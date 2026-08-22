# 010 — Outline (Obsidian replica 21) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Outline/OutlineExtractor.swift` + `OutlinePanel.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `OutlinePanel` into the **Z-NOVEL right pane** (alongside Backlinks from issue 001, in a tabbed sub-pane).

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/LinkGraph/BacklinksPanel.swift` (or sibling) — host a small TabView with `.backlinks` + `.outline` tabs in the right pane
2. `Sources/WenshuApp/Core/Outline/OutlinePanel.swift` — bind to current document

**Do NOT touch:** ZoneModule parent

## Acceptance criteria

- [ ] Z-NOVEL right pane shows two tabs: Backlinks + Outline
- [ ] Outline tab shows H1-H6 outline of current document
- [ ] Click outline item → jumps to that heading
- [ ] Code-review 2 axes

## Risks

- Tabbed sub-pane in right column. If currently a flat panel, may need to wrap in TabView (still leaf-level change within the panel component)