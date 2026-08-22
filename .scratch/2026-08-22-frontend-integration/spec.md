# Frontend integration — 26 modules (Hermes replica 14 + Obsidian replica 12)

> 老板 2026-08-22 拍: "我看你说的是十四模块，是否是全量？" + "模块之间是有关联关系的，需要你做好分析和会话，不是每个模块都需要有前端入口，有可能只是后端服务和调度，这需要你来判断".
> Pocock 第一次盘点错了 (漏了 13 个 hermes v0.18 复刻) = **14 → 26 modules**.
> Pocock 第二次也错了 (以为每个模块都要 UI 入口) = **23 tickets → 16 UI + 5 backend = 21 tickets**.
> This spec v0.3 = frontend integration tickets grouped by **layer** (user-facing UI vs backend-only).

## Business language (老板 understands)

Previously (8/19 + 8/19 evening) 老板拍 "复刻后端, 前端不接入核心项目" — backend done, frontend never mounted.

Today (8/22) 老板拍 "把所有复刻全都接入前端, 周一看到" — 但**接入** 意思是:
- **User-facing UI**: 用户在 App 上看得到 / 点得到 (toolbar icon / menu item / pane)
- **Backend wiring**: 模块被其他模块调用 (agent invoke / persistence),用户不可见,**不需要 UI**

Not every module needs UI entry. Some modules are **services for other modules** — that's correct architecture, not lazy frontend.

After this work: 16 modules 挂 UI, 5 modules wired backend, 3 already wired unchanged, 2 deferred (out of scope). Total 26 modules → app is fully functional.

## Architecture analysis (per boss 拍 "做好分析和会话")

### Module dependency graph

```
                    [User]
                       ↓
                 WenshuApp.swift (root, no UI tool registry)
                       ↓
              ChatView + LayoutShellView (6-zone + tab switching)
                       ↓
            ┌──────────┼──────────────┐
            ↓          ↓              ↓
       Z-TITLE    Z-NOVEL        Z-CHAT
       toolbar    toolbar        toolbar
            ↓          ↓              ↓
       (graph,    (backlinks,    (todo,
        search,    canvas,        context,
        qswitch,   templates,     read-aloud,
        word,      composer,      chat)
        bookmarks) bases)
            ↓          ↓              ↓
       [User-visible features]

                  ┌──── Backend (no UI) ────┐
                  ↓           ↓             ↓
              WenshuConductor (already wired)
              ├ AgentProtocol (already)
              ├ AgentRuntime (already)
              ├ MemoryStore (wire)
              ├ SkillRegistry (wire)
              ├ FileTools (wire)
              ├ ProcessTools (wire)
              ├ WebTools (wire)
              ├ VisionTools (wire)
              ├ AVMediaTools (wire)
              ↓
           [Persistence + Tools] (callbacks into agent flow)
```

### Already-wired (3 modules, no work)

- H03 AgentProtocol — used by ChatView for A2A message flow
- H04 AgentRuntime — used by ChatView for multi-agent dispatch
- H05 WenshuConductor — used by App + ChatView for chat flow

These are the **conductor layer** — already in place, no UI changes needed.

### Layer A — User-facing UI (16 modules, 16 tickets)

Each gets a visible toolbar / menu / pane entry:

| # | Module | UI entry | Reason |
|---|--------|----------|--------|
| O01 | Backlinks | Z-NOVEL right pane tab | writers need reverse-link lookup |
| O02 | Canvas | Z-NOVEL toolbar → fullscreen modal | advanced visual canvas |
| O03 | Graph view | Z-TITLE toolbar → fullscreen modal | relationship visualization |
| O04 | Templates | File menu "New from Template..." | daily driver for new docs |
| O05 | Note Composer | Z-NOVEL document row context menu | merge / split / rename |
| O06 | Full-text Search | Z-TITLE toolbar + ⌘F shortcut | universal search |
| O07 | Bases | Z-NOVEL toolbar toggle (cards ↔ bases) | database view |
| O08 | Quick Switcher | Z-TITLE toolbar + ⌘O shortcut | universal nav |
| O09 | Word Count | Z-TITLE toolbar badge (always visible) | must-have for writers |
| O10 | Outline | Z-NOVEL right pane tab (alongside Backlinks) | document structure |
| O11 | Bookmarks | Z-TITLE toolbar + View menu | cross-doc favorites |
| H06 | KanbanStore | Z-NOVEL right pane (third tab after Backlinks/Outline) | task tracking |
| H07 | TodoStore | Z-CHAT right pane (tabbed with ContextUsage) | quick todos |
| H08 | Cronjob | Settings page section | scheduled tasks |
| H09 | Backup | Settings page section + File menu | vault backup |
| H14 | AVMediaTools read-aloud | Z-CHAT toolbar speaker icon | hear AI reply |

### Layer B — Backend wiring (5 modules, 5 tickets, no UI)

These are services used by other modules (primarily WenshuConductor → agent → invoke tool). No user-visible UI entry — they're invoked programmatically.

| # | Module | Wire to | Reason (no UI) |
|---|--------|---------|----------------|
| H01 | MemoryStore | `WenshuConductor` (add as property; bootstrap on init) | Long-term memory persistence for agent. User invokes via chat ("remember this"); agent stores / retrieves automatically. **No settings page needed** — works invisibly. |
| H02 | SkillRegistry | `WenshuConductor` (scan on init; expose `invokeSkill`) | Skills loaded at startup; agent invokes them. User sees the **result** in chat, not the registry itself. |
| H10 | FileTools | `WenshuConductor.invokeTool("file", ...)` | Agent toolkit. User triggers via chat ("read this file"); agent reads. No UI affordance needed. |
| H11 | ProcessTools | `WenshuConductor.invokeTool("process", ...)` | Agent toolkit. Same pattern. |
| H12 | WebTools | `WenshuConductor.invokeTool("web", ...)` | Agent toolkit. Same pattern. |
| H13 | VisionTools | `WenshuConductor.invokeTool("vision", ...)` | Agent toolkit. Same pattern. |
| (H14 toolkit part) | AVMediaTools | `WenshuConductor.invokeTool("av", ...)` | Agent toolkit. UI part is in Layer A. |

(Note: H14 has both Layer A UI = read-aloud button, AND Layer B backend = invokeTool dispatch. 1 ticket covers both.)

### Layer C — Out of scope (deferred)

- O12 Obsidian Integration cross-tool verify — already done as test fixture (`ObsidianFixturesTests.swift` passes). No new ticket needed.

## Tickets (21 total)

### Layer A — UI tickets (16)

1. O01 Backlinks — Z-NOVEL right pane tab
2. O02 Canvas — Z-NOVEL toolbar fullscreen modal
3. O03 Graph view — Z-TITLE toolbar fullscreen modal
4. O04 Templates — File menu sheet
5. O05 Note Composer — Z-NOVEL context menu
6. O06 Full-text Search — Z-TITLE toolbar + ⌘F
7. O07 Bases — Z-NOVEL toolbar toggle
8. O08 Quick Switcher — Z-TITLE toolbar + ⌘O
9. O09 Word Count — Z-TITLE toolbar badge
10. O10 Outline — Z-NOVEL right pane tab
11. O11 Bookmarks — Z-TITLE toolbar + View menu
12. H06 KanbanStore — Z-NOVEL right pane (third tab)
13. H07 TodoStore — Z-CHAT right pane tab
14. H08 Cronjob — Settings page section
15. H09 Backup — Settings page section + File menu
16. H14 AVMediaTools — Z-CHAT toolbar read-aloud + agent invokeTool

### Layer B — Backend tickets (5)

17. H01 MemoryStore — `WenshuConductor` wiring
18. H02 SkillRegistry — `WenshuConductor` wiring
19. H10 FileTools — `WenshuConductor.invokeTool` dispatch
20. H11 ProcessTools — `WenshuConductor.invokeTool` dispatch
21. H12 WebTools + H13 VisionTools — combined (similar pattern, both agent toolkits)

## Total: 21 tickets, 21 commits, 1 branch `wt/frontend-integration`

## Per-ticket constraints (boss拍 unchanged)

- 修改只发生在叶子组件
- **不要修改 LayoutShellView / ZoneModule / WenshuApp root entry**
- 每个 zone 修改不互相影响
- 1 ticket = 1 commit
- code-review 2 axes per commit

## Execution order

**Phase A — Backend wiring (5 tickets, low risk, no UI):**
1. H01 MemoryStore (background)
2. H02 SkillRegistry (background)
3. H10 FileTools (toolkit dispatch)
4. H11 ProcessTools (toolkit dispatch)
5. H12 WebTools + H13 VisionTools (combined toolkit dispatch)
- Plus H14 toolkit part (UI button in Phase B)

**Phase B — UI mounts (16 tickets):**
- Z-TITLE toolbar: O03 Graph + O06 Search + O08 Quick Switcher + O09 Word Count + O11 Bookmarks
- Z-NOVEL toolbar: O02 Canvas + O07 Bases
- Z-NOVEL right pane (TabView): O01 Backlinks + O10 Outline + H06 Kanban
- Z-NOVEL document row context menu: O05 Note Composer
- File menu: O04 Templates
- View menu: O11 Bookmarks
- Settings page: H08 Cron + H09 Backup
- Z-CHAT right pane: H07 Todo + H14 read-aloud button

## Acceptance criteria (overall)

- [ ] 16 modules have UI entry (Layer A)
- [ ] 5 modules wired backend-only (Layer B)
- [ ] 3 already-wired unchanged
- [ ] 2 deferred (Memory/Skill UI viewer = future work)
- [ ] swift build exit 0
- [ ] swift test: 338 + new tests pass
- [ ] macOS binary launches, all 16 UI entries visible
- [ ] Boss 拍 review (周一 on-machine)
- [ ] Code-review 2 axes per ticket

## Why some modules are correctly backend-only

Boss 拍 "模块之间是有关联关系的, 不是每个模块都需要有前端入口, 有可能只是后端服务和调度".

Real example: agent memory retention. When user chats with agent:
1. User: "记住这个人物的设定"
2. Agent stores via MemoryStore.add(content)
3. MemoryStore persists to SQLite
4. Next session: agent reads via MemoryStore.search(query)

User never needs to open a "Memory Viewer" UI for this to work. **MemoryStore is correctly invisible.** Forcing UI = bad UX (settings page nobody visits).

Same for SkillRegistry: user sees the skill's **effect** in agent reply, not the registry itself. **SkillRegistry is correctly invisible.**

Same for 4 tools (File / Process / Web / Vision): user invokes via chat ("summarize this URL"), agent does it. **Tools are correctly invisible.**

Forcing UI on these = clutter, not value.

## What this spec does NOT cover

- Backend changes (already done)
- New layout zones (boss拍 hard constraint)
- Skill / Memory UI viewers (future, if user demand)

## Out of scope

- Renaming any replica modules
- Changing backend logic
- Memory viewer / Skill manager UI

## Follow-up (after boss reviews 周一)

- CONTEXT.md updates for `ObsidianReplicaScope` + `HermesReplicaScope` glossary entries
- ADR `0008-frontend-integration-plan.md` documenting layer decisions

---

*Spec v0.3 · 2026-08-22 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*