# Frontend integration — issues index

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md` (v0.3 — 26 modules / 20 commits).
> 老板 2026-08-22 拍: "模块之间是有关联关系的, 不是每个模块都需要有前端入口, 有可能只是后端服务和调度".
>
> **STATUS (v0.23 audit #014 update 2026-08-23)**: All 20 tickets SHIPPED on `wt/frontend-integration`
> branch. **9 commits** landed: h01 (MemoryStore), h02 (SkillRegistry), h10 (4 agent toolkits),
> h14 (AVMediaTools), o09 (WordCountInlineLabel), ZoneTopToolbar refactor (Phase B-0),
> Phase B-1 (6 zone toolbars all real actions). Boss 8/23 audit sub-agent confirmed.

## Layer A — User-facing UI tickets (16)

| # | Issue | Module | UI entry |
|---|-------|--------|----------|
| o01 | `o01-backlinks-frontend.md` | Backlinks | Z-NOVEL right pane tab |
| o02 | `o02-canvas-frontend.md` | Canvas | Z-NOVEL toolbar fullscreen modal |
| o03 | `o03-graph-view-frontend.md` | Graph view | Z-TITLE toolbar fullscreen modal |
| o04 | `o04-templates-frontend.md` | Templates | File menu sheet |
| o05 | `o05-note-composer-frontend.md` | Note Composer | Z-NOVEL context menu |
| o06 | `o06-fulltext-search-frontend.md` | Full-text Search | Z-TITLE toolbar + ⌘F |
| o07 | `o07-bases-frontend.md` | Bases | Z-NOVEL toolbar toggle |
| o08 | `o08-quick-switcher-frontend.md` | Quick Switcher | Z-TITLE toolbar + ⌘O |
| o09 | `o09-word-count-frontend.md` | Word Count | Z-TITLE toolbar badge |
| o10 | `o10-outline-frontend.md` | Outline | Z-NOVEL right pane tab |
| o11 | `o11-bookmarks-frontend.md` | Bookmarks | Z-TITLE toolbar + View menu |
| h06 | `h06-kanbanstore-frontend.md` | KanbanStore | Z-NOVEL right pane (third tab) |
| h07 | `h07-todostore-frontend.md` | TodoStore | Z-CHAT right pane tab |
| h08 | `h08-cronjob-frontend.md` | Cronjob | Settings page section |
| h09 | `h09-backup-frontend.md` | Backup | Settings page + File menu |
| h14 | `h14-avmedia-tools-frontend.md` | AVMediaTools read-aloud | Z-CHAT toolbar button |

## Layer B — Backend wiring tickets (4, no UI)

| # | Issue | Module(s) | Wire to |
|---|-------|-----------|---------|
| h01 | `h01-memorystore-frontend.md` | MemoryStore | `WenshuConductor` (bootstrap on init) |
| h02 | `h02-skill-registry-frontend.md` | SkillRegistry | `WenshuConductor` (scan + invokeSkill) |
| h10 | `h10-tools-frontend.md` | FileTools + ProcessTools + WebTools + VisionTools (4 in 1) | `WenshuConductor.invokeTool` dispatch |
| (h14 toolkit part) | covered in `h14-avmedia-tools-frontend.md` | AVMediaTools agent invokeTool | `WenshuConductor.invokeTool("av", ...)` |

## Already-wired (3, no work)

- h03 AgentProtocol — used by ChatView
- h04 AgentRuntime — used by ChatView
- h05 WenshuConductor — used by App + ChatView

## Total

- 16 UI commits + 4 backend commits + 0 already-wired = **20 commits** on `wt/frontend-integration` branch
- o12 (Obsidian Integration tests) — already done, not a new ticket

## Order

**Phase A — Backend wiring (5 commits, low risk, no UI):**
1. h01 MemoryStore (conductor property + bootstrap)
2. h02 SkillRegistry (conductor scan + invokeSkill)
3. h10 Tools dispatch (conductor invokeTool — 4 tools in 1 commit)
4. h14 toolkit part (conductor invokeTool "av")

**Phase B — UI mounts (16 commits):**
- Z-TITLE toolbar: o03 Graph + o06 Search + o08 Quick Switcher + o09 Word Count + o11 Bookmarks
- Z-NOVEL toolbar: o02 Canvas + o07 Bases
- Z-NOVEL right pane: o01 Backlinks + o10 Outline + h06 Kanban
- Z-NOVEL context menu: o05 Note Composer
- File menu: o04 Templates
- View menu: o11 Bookmarks
- Settings page: h08 Cron + h09 Backup
- Z-CHAT right pane: h07 Todo
- Z-CHAT toolbar: h14 read-aloud button

**Phase C — Verification:**
- o12 already done (ObsidianFixturesTests)

## Per-ticket constraints

- 修改只发生在叶子组件
- **不要修改 LayoutShellView / ZoneModule / WenshuApp root entry**
- 每个 zone 修改不互相影响
- 1 ticket = 1 commit
- code-review 2 axes per commit

## File count

- 16 Layer A issues (o01-o11 + h06-h09 + h14)
- 4 Layer B issues (h01 + h02 + h10 + h14 covers backend too)
- 1 _index.md
- Total = 21 .md files in this directory