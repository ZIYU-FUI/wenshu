# 005 — Note Composer (Obsidian replica 16) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Composer/NoteComposer.swift` + `ComposerPanel.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `ComposerPanel` actions into the **Z-NOVEL document row context menu** (right-click on document).

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/Library/LibraryOutlineView.swift` or `BookOutlineView.swift` (whichever renders the document row) — add `.contextMenu` entries:
   - "Merge with..." → present `ComposerPanel` merge UI
   - "Split into..." → present `ComposerPanel` split UI
   - "Rename with link rewriting" → invoke `NoteComposer.renameAndRewriteLinks`
2. `Sources/WenshuApp/Core/Composer/ComposerPanel.swift` — verify it accepts current document selection

**Do NOT touch:** parent views

## Acceptance criteria

- [ ] Right-click on document row shows 3 new context menu items
- [ ] Each invokes the corresponding backend operation
- [ ] Internal links (`[[name]]`) auto-rewritten on rename / merge / split
- [ ] No parent modified
- [ ] Code-review 2 axes

## Risks

- Backend `NoteComposer` may need new init params (target doc id). Read existing API first