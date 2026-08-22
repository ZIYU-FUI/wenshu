# 18 — Bases database view (table / card / kanban) + .base YAML (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica scope A item 7: Bases database view (1:1 compatible with .base YAML file, integrate with v0.18 ticket 05 KanbanStore).

**After change:**
- `Sources/WenshuApp/Core/Bases/BaseParser.swift` (YAML .base file parsing, reuse with FrontmatterParser)
- `Sources/WenshuApp/Core/Bases/BaseView.swift` (table / card / kanban view)
- Integrate with v0.18 ticket 05 KanbanStore (Kanban is one Bases view)

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Bases/BaseParser.swift` YAML .base
- [ ] `Sources/WenshuApp/Core/Bases/BaseView.swift` table / card / kanban
- [ ] Integrate with KanbanStore (reuse ticket 05)
- [ ] `swift build` exit 0
- [ ] Unit tests: BaseParserTests (YAML round-trip) + BaseViewTests
- [ ] Do not touch hermes app
- [ ] Do not touch LayoutTokens / LayoutShellView

## Business-language description (老板 understands)

- Writing app strong requirement: character table / chapter progress / setting table
- Integrate with KanbanStore, don't reinvent the wheel

## Truth references

- Obsidian Bases: https://obsidian.md/help/bases
- Bases syntax: https://obsidian.md/help/bases/syntax (YAML schema)
- Reuse v0.18 ticket 05 KanbanStore (commit `2172c421c`)