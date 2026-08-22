# 009 — Word Count (Obsidian replica 20) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/WordCount/WordCounter.swift` + `WordCountBadge.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `WordCountBadge` into the **Z-TITLE toolbar** as a tiny always-visible badge.

## Implementation outline

**Files to touch (leaf only):**

1. Z-TITLE toolbar config — add `.wordCount` slot:
   - Content: `WordCountBadge` (small Text view, 12pt, `.tertiary`)
   - Reads from currently selected document
2. `Sources/WenshuApp/Core/WordCount/WordCountBadge.swift` — bind to current document text

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Z-TITLE toolbar shows word count badge
- [ ] Badge updates as user types / switches documents
- [ ] Shows current doc word count + selection word count (if any)
- [ ] Code-review 2 axes

## Risks

- `WordCountBadge` may need a `@Observable` document binding. Read existing API first