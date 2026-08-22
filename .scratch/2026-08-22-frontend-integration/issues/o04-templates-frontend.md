# 004 — Templates (Obsidian replica 15) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Templates/TemplateEngine.swift` + `TemplatePicker.swift` (done 8/19, never mounted).
> 1 commit. Leaf-level change only.

## What to build

Wire `TemplatePicker` into the **File menu (NSMenu via `WenshuAppDelegate`)** as a new "New from Template..." item (Hermes appChrome pattern).

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Core/Agent/WenshuAppDelegate.swift` (or `WenshuApp.swift` if delegate missing) — add new NSMenu item "新建 - 模板..." → action handler that presents `TemplatePicker` as sheet
2. `Sources/WenshuApp/Core/Templates/TemplatePicker.swift` — bind to template directory

**Do NOT touch:** LayoutShellView, ZoneModule, ChatView, etc.

## Acceptance criteria

- [ ] File menu shows "New from Template..." item
- [ ] Click → modal sheet shows available templates (date / outline / chapter / character / setting)
- [ ] Pick template → new document created with template variables substituted
- [ ] No parent modified
- [ ] Code-review 2 axes

## Risks

- NSMenu item action wiring is a leaf-level change IF the menu structure already exists in `WenshuAppDelegate`. Verify before committing