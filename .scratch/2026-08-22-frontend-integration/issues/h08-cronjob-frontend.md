# h08 — Cronjob (Hermes replica 21) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Cron/Cronjob.swift` (done v0.18 ticket 21).
> 1 commit. Leaf-level change only.

## What to build

Wire `Cronjob` as a new Settings page section: scheduled tasks list with add/edit/delete.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/Settings/CronScheduleView.swift` (new) — SwiftUI view rendering cron tasks
2. `Sources/WenshuApp/Views/Settings/SettingView.swift` — add "Cron Schedule" tab OR add to existing page

**Do NOT touch:** parent views (or only leaf-level additions to SettingView)

## Acceptance criteria

- [ ] Settings → Cron Schedule shows task list
- [ ] Add cron task (cron expression + name)
- [ ] Delete / edit existing
- [ ] Code-review 2 axes

## Risks

- SettingView is a parent component. If modifying it, ensure the change is leaf-level (new tab / new section, not restructuring)