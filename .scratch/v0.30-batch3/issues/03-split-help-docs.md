# 03 — split help-doc files (角色 1→6, 功能模块 1→9)

**What to build:**

Boss 2026-08-30 OOB '角色一个文件拆成六个吧，正常以后也是一个角色一个
文档' + '功能模块也是，一个功能模块拆成一个文档' = help documents in
default book should be split 1-to-many.

Pre-fix: 1 character file (`characters/六个Agent.md`) + 1 module file
(`chapters/功能模块说明.md`).

Fix: created `Scripts/split-help-docs.py` that splits each file at `## N.`
headers, creates 1 file per item.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `bf86a0b2b`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### New file: `Scripts/split-help-docs.py` (636 lines)

- Reads `characters/六个Agent.md` → splits at `## 1.` through `## 6.`
  → writes 6 files (`主Agent-Conductor.md`, etc.).
- Reads `chapters/功能模块说明.md` → splits at `## 1.` through `## 9.`
  → writes 9 files (`01-项目管理区-Sidebar.md`, etc.).
- Idempotent (= skips if file exists).

### Modified: `Sources/WenshuApp/Storage/LibraryMigrator.swift`

- `helpDocUpgrade` migration updated:
  - Removed creation of merged `六个Agent.md` and `功能模块说明.md`
  - Added deletion of these merged files if they exist (= ensures
    one-time split is preserved on subsequent launches)

## Acceptance

- [x] 6 agent files in `characters/`:
  - `主Agent-Conductor.md`
  - `副Agent-SubAgent.md`
  - `资料库Wiki派-Reference.md`
  - `状态追踪派-Status.md`
  - `备份派-Backup.md`
  - `定时任务派-Cron.md`
- [x] 9 module files in `chapters/`:
  - `01-项目管理区-Sidebar.md` through `09-交互约定-KeyboardShortcuts.md`
- [x] Merged files removed (= no longer in tree)
- [x] Build exit 0

## Out-of-scope

- Auto-migration of user-created merged docs (= future ticket;
  user would need to manually re-run script)
