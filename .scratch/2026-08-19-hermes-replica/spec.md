# Spec — Hermes core capability replica (mem0 + skills loading mechanism, 老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 19:57 拍 new requirement:
> "Let's do some bottom-layer dependency requirements, no need for me to verify, research how to replicate hermes's core capabilities over"

**Business-language description (老板 understands)**:
- Previously all wenshu AI capabilities (long-term memory + 35 skill loading) ran inside hermes agent; 老板 wants to research how to **not depend on hermes** to also run — let wenshu have these capabilities itself
- 老板 拍 "no verification needed" = research + implement, do not look for 老板 to look
- 老板 拍 "bottom-layer dependency" = push to wenshu project's own lib/ or independent module

## Solution (per Q33 + Q34 + 老板 8/19 self-decision authorization 拍 scope A)

Per mem0 truth (老板 8/19 + 8/11 feedback):
- **Hermes mem0**: use cloud service mem0, modify `~/.hermes/profiles/pocock/mem0.json` mode = platform then ran successfully (commit verified)
- **Hermes skills loading**: `~/.hermes/profiles/pocock/skills/` directory markdown files, 35 skills, I have `SKILL.md` `skill_view` loaded

**Replica scope (A 拍)**:
1. **Local SQLite long-term memory** — replace hermes mem0 cloud service, wenshu locally can search/add memory, no hermes dependence
2. **Local Skills loading mechanism** — wenshu project `Sources/WenshuCore/Skills/` directory markdown files, wenshu own skill registry + loader, no hermes dependence

## User Stories

1. As 老板, I want wenshu to have its own long-term memory (local SQLite, no hermes cloud), so that wenshu works offline
2. As 老板, I want wenshu to have its own skills loading mechanism (local markdown files), so that wenshu does not depend on hermes's skill registry
3. As 老板, I want "no verification needed" pushed to bottom-layer = modified wenshu project internal code + new modules, do not touch hermes
4. As 老板, I want replica interface 1:1 with hermes truth (interfaces like skill_view comparable), so that subsequent separate upgrades are possible

## Implementation Decisions

Per "large workload but stable" + 4 principles + 1 pseudo-Apple-official + 老板 "no verification needed" push to bottom layer:

- **Plan 1 (local SQLite memory)**:
  - Create `Sources/WenshuCore/Memory/` directory
  - `MemoryStore.swift` — SQLite-backed, table schema = user_id / memory_id / content / created_at / updated_at
  - Interface `add(content, metadata)` / `search(query, limit)` / `get(memoryId)` / `delete(memoryId)` / `update(memoryId, content)`
  - Align with mem0 platform mode truth interface (mem0 SDK Python truth)
- **Plan 2 (local Skills loading)**:
  - Create `Sources/WenshuCore/Skills/` directory
  - `SkillRegistry.swift` — scan `Sources/WenshuCore/Skills/<name>/SKILL.md` directory, parse frontmatter + body
  - `SkillLoader.swift` — `load(name)` get SKILL.md content + linked_files
  - Align with hermes SKILL.md truth (frontmatter + markdown body)
- **Do not touch**: hermes app, `~/.hermes/profiles/pocock/`, wenshu current SwiftUI code, wenshu business logic

## Testing Decisions

- Only `swift build clean` (exit 0)
- Add unit tests (MemoryStore.search / add, SkillRegistry.load)
- 老板 8/19 拍 "no verification needed" — no screenshot evidence submission, only build + unit test verification

## Out of Scope

- Do not touch hermes app (老板 8/11 拍 'hermes do not touch')
- Do not touch `~/.hermes/profiles/pocock/` (老板 continues working with hermes profile)
- Do not touch wenshu current SwiftUI UI / business logic
- Do not replica hermes full capabilities (kanban / cron / profile / setup / multi-profile / credit gateway — all not in scope A)
- Do not replica hermes AI runtime (LLM call wrapper not in scope A, wenshu continues using hermes to call AI)

## Further Notes

- 老板 8/19 19:57 拍 "no verification needed" = 老板 explicitly does not want push audit / 老板 yes/no, ANAN runs po main flow + commit + push by themselves
- Per 8/15 rule strictly walk (currently 老板 8/19 self-decision authorization, simplified flow = no 拍 yes/no needed)
- spec / ticket / impl / review / domain-modeling all run, then one-time commit + push