# Frontend integration — 26 modules (Hermes replica 14 + Obsidian replica 12)

> 老板 2026-08-22 拍: "我看你说的是十四模块，是否是全量？我们复刻了 hermes.obsidian 两个项目的核心模块，应该比这个多".
> Pocock previous盘点错了 — 漏了 12 个 hermes v0.18 复刻 (MemoryStore + SkillRegistry 之外全漏数了).
> Total real replica scope = **26 modules** (14 Hermes + 12 Obsidian).
> This spec = 26 frontend integration tickets, 1 commit each.

## Business language (老板 understands)

Previously (8/19 + 8/19 evening) 老板拍 "复刻后端, 前端不接入核心项目" — backend done, frontend never mounted.

Today (8/22) 老板拍 "把所有复刻全都接入前端, 周一看到".

26 modules in scope:
- 14 Hermes replica modules (8/19 shipped, backend done)
  - 3 already wired (AgentProtocol, AgentRuntime, WenshuConductor → used by ChatView / App.swift chat flow)
  - 11 not mounted
- 12 Obsidian replica modules (8/19 evening shipped, backend done)
  - 0 mounted

After this work: every replica module's SwiftUI view挂载在 App 上, 老板周一可 macOS 启 binary 看效果给修改意见.

## Full inventory (26 modules)

### Hermes replica (14 modules)

| # | Module | Files | Already wired? | Frontend target |
|---|--------|-------|----------------|------------------|
| H01 | **MemoryStore** | `Memory/MemoryStore.swift` | ❌ (only mentioned in comments) | WenshuConductor.init() background |
| H02 | **SkillRegistry** | `Skills/SkillRegistry.swift` | ❌ | WenshuConductor.init() background |
| H03 | **AgentProtocol** | `Agent/AgentProtocol.swift` | ✅ (used by ChatView) | already wired — no work |
| H04 | **AgentRuntime** | `Agent/AgentRuntime.swift` | ✅ (used by ChatView) | already wired — no work |
| H05 | **WenshuConductor** | `Agent/WenshuConductor.swift` | ✅ (used by App + ChatView) | already wired — no work |
| H06 | **KanbanStore** | `Kanban/KanbanStore.swift` | ❌ | New view in Z-NOVEL right pane |
| H07 | **TodoStore** | `Todo/TodoStore.swift` | ❌ | Z-CHAT right pane or modal |
| H08 | **Cronjob** | `Cron/Cronjob.swift` | ❌ | Settings page (cron schedule list) |
| H09 | **Backup** | `Backup/Backup.swift` | ❌ | File menu or Settings page |
| H10 | **FileTools** | `Tools/FileTools.swift` | ❌ | Agent toolkit (no UI; WenshuConductor.invoke) |
| H11 | **ProcessTools** | `Tools/ProcessTools.swift` | ❌ | Agent toolkit (no UI; WenshuConductor.invoke) |
| H12 | **WebTools** | `Tools/WebTools.swift` | ❌ | Agent toolkit (no UI; WenshuConductor.invoke) |
| H13 | **VisionTools** | `Tools/VisionTools.swift` | ❌ | Agent toolkit (no UI; WenshuConductor.invoke) |
| H14 | **AVMediaTools** | `Tools/AVMediaTools.swift` | ❌ | Agent toolkit + chat read-aloud button |

### Obsidian replica (12 modules)

| # | Module | Files | Already wired? | Frontend target |
|---|--------|-------|----------------|------------------|
| O01 | **Backlinks** | `LinkGraph/*` (4 files) | ❌ | Z-NOVEL top toolbar icon switch |
| O02 | **Canvas** | `Canvas/*` (2 files) | ❌ | Z-NOVEL top toolbar icon switch (fullscreen modal) |
| O03 | **Graph view** | `Graph/*` (2 files) | ❌ | Z-TITLE toolbar icon switch (fullscreen modal) |
| O04 | **Templates** | `Templates/*` (2 files) | ❌ | File menu "New from Template..." |
| O05 | **Note Composer** | `Composer/*` (2 files) | ❌ | Z-NOVEL document row context menu |
| O06 | **Full-text Search** | `Search/*` (2 files) | ❌ | Z-TITLE toolbar + ⌘F shortcut |
| O07 | **Bases** | `Bases/*` (2 files) | ❌ | Z-NOVEL toolbar toggle (cards ↔ bases) |
| O08 | **Quick Switcher** | `QuickSwitcher/*` (2 files) | ❌ | Z-TITLE toolbar + ⌘O shortcut |
| O09 | **Word Count** | `WordCount/*` (2 files) | ❌ | Z-TITLE toolbar badge |
| O10 | **Outline** | `Outline/*` (2 files) | ❌ | Z-NOVEL right pane tab (alongside Backlinks) |
| O11 | **Bookmarks** | `Bookmarks/*` (2 files) | ❌ | Z-TITLE toolbar + View menu |
| O12 | **Obsidian Integration** | n/a (test only) | ✅ (ObsidianFixturesTests pass) | verification only |

## Already-wired modules (3, no work needed)

- H03 AgentProtocol — used by ChatView
- H04 AgentRuntime — used by ChatView
- H05 WenshuConductor — used by App + ChatView

## Tickets to write (23)

Already-wired 3 modules = no tickets. Remaining 23 modules = 23 tickets.

(Note: 5 tools H10-H14 are not real "frontend mounts" — they're agent toolkit access. They count as 5 tickets but each = 1-line wiring to WenshuConductor.invokeTool() method. Lightweight.)

## Per-ticket constraints (boss拍)

- 修改只发生在叶子组件
- **不要修改 LayoutShellView / ZoneModule / WenshuApp root entry**
- 每个 zone 修改不互相影响
- 1 ticket = 1 commit
- code-review 2 axes per commit

## Order of execution

Phase A — Background wiring (low risk, 7 tickets):
- H01 MemoryStore, H02 SkillRegistry, H10 FileTools, H11 ProcessTools, H12 WebTools, H13 VisionTools, H14 AVMediaTools

Phase B — UI mounts (12 tickets, in zone toolbar / pane):
- H06 KanbanStore, H07 TodoStore, H08 Cronjob, H09 Backup
- O01-O11 (11 obsidian modules)

Phase C — Verification:
- O12 (already done as test)

## Branch

`wt/frontend-integration` — 23 commits on one branch, 1 PR.

## Acceptance criteria (overall)

- [ ] 23 modules imported in wenshu binary
- [ ] 3 already-wired modules unchanged
- [ ] swift build exit 0
- [ ] swift test: 338 tests + new frontend tests pass
- [ ] macOS binary launches, all 23 modules visible / functional
- [ ] Boss 拍 review (周一 on-machine verification)
- [ ] Code-review 2 axes per ticket

## What this spec does NOT cover

- Backend changes (already done)
- WenshuConductor refactor (only minimal wiring needed)

## Risks

- 23 tickets = lots of UI work. Boss拍 review = need to expect multi-round UI adjustments
- Some modules may not have natural UI entry in current 6-zone layout (e.g. Cronjob, Backup). Mitigation: place in Settings pane

## Out of scope

- Renaming any replica modules
- Changing backend logic
- New layout zones (boss拍 hard constraint)

---

*Spec v0.2 · 2026-08-22 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*