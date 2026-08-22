# h09 — Backup (Hermes replica 26) frontend integration

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> Backend: `Sources/WenshuApp/Core/Backup/Backup.swift` (done v0.18 ticket 26).
> 1 commit. Leaf-level change only.

## What to build

Wire `Backup` as Settings page section + File menu item: backup vault to timestamped folder, restore from backup.

## Implementation outline

**Files to touch (leaf only):**

1. `Sources/WenshuApp/Views/Settings/BackupView.swift` (new) — Settings page section
2. `Sources/WenshuApp/Core/Agent/WenshuAppDelegate.swift` (or App.swift) — File menu → "备份..." menu item

**Do NOT touch:** parent components

## Acceptance criteria

- [ ] Settings → Backup section: list of backups + restore button
- [ ] File menu → "Backup now..." triggers Backup.run
- [ ] Restore from selected backup
- [ ] Code-review 2 axes

## Risks

- Backup involves file system I/O. Verify Backup.swift exposes the right async API