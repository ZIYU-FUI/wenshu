# 01 — Hermes core capability audit report (limit replica scope = mem0 + skills)

**What to build:**
老板 2026-08-19 拍 "scan hermes code, evaluate what to replica". Engineering management authorized (老板 8/19 19:55) + no verification needed (老板 8/19 19:57).

After change:
- Read hermes truth source code (read-only, do not touch hermes)
- Assemble audit report (scope = mem0 + skills)
- 拍 replica priority + suggest next step

**Blocked by:** None
**Status:** done — spec in `.scratch/2026-08-19-hermes-audit/spec.md`

## Truth (Hermes source code read-only)

- `/Volumes/ANAN/.hermes/hermes_cli/memory_providers.py` 149 lines
- `/Volumes/ANAN/.hermes/hermes_cli/memory_setup.py` 501 lines
- `/Volumes/ANAN/.hermes/hermes_cli/skills_config.py` 183 lines
- `/Volumes/ANAN/.hermes/hermes_cli/skills_hub.py` 1997 lines (35 `do_*` functions)

## Replica evaluation (recommendation)

| Priority | Module | Status |
|---|---|---|
| ✅ done | MemoryStore (mem0) | ticket 01 commit `047b43cfa` |
| ⏭ next | SkillRegistry (skills_hub simplified) | ticket 02 pending |
| skip | mem0 CLI / skills CLI / skills Hub browse-install | SwiftUI app does not need CLI |
| future | Kanban / Cron / Profile | subsequent ticket scheduling |

## wenshu current vs hermes truth comparison

- MemoryStore.swift (wenshu) vs MemoryProvider (hermes): naming order difference + backend (SQLite vs mem0 SDK) + missing `delete_all` / count aggregation
- SkillRegistry: not implemented, plan to mimic hermes skills_hub.py truth

## Business-language description (老板 understands)

- hermes core capabilities scanned by module
- Replica priority: mem0 + skills are high-value, kanban / cron / profile are future
- wenshu MemoryStore already done, SkillRegistry pending ticket 02

## Do not touch hermes (老板 8/11 拍)

- read-only read source code
- do not modify `/Volumes/ANAN/.hermes/`