# Frontend integration — issues index

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md` (v0.2 — 26 modules total).
> 23 tickets to write (3 already wired, no ticket).

## Hermes replica tickets (11)

| # | Issue | Module | Status |
|---|-------|--------|--------|
| h01 | `h01-memorystore-frontend.md` | MemoryStore | ready |
| h02 | `h02-skill-registry-frontend.md` | SkillRegistry | ready |
| h03 | (already wired) | AgentProtocol | done (no work) |
| h04 | (already wired) | AgentRuntime | done (no work) |
| h05 | (already wired) | WenshuConductor | done (no work) |
| h06 | `h06-kanbanstore-frontend.md` | KanbanStore | ready |
| h07 | `h07-todostore-frontend.md` | TodoStore | ready |
| h08 | `h08-cronjob-frontend.md` | Cronjob | ready |
| h09 | `h09-backup-frontend.md` | Backup | ready |
| h10 | `h10-file-tools-frontend.md` | FileTools | ready (agent toolkit) |
| h11 | `h11-process-tools-frontend.md` | ProcessTools | ready (agent toolkit) |
| h12 | `h12-web-tools-frontend.md` | WebTools | ready (agent toolkit) |
| h13 | `h13-vision-tools-frontend.md` | VisionTools | ready (agent toolkit) |
| h14 | `h14-avmedia-tools-frontend.md` | AVMediaTools | ready (toolkit + read-aloud UI) |

## Obsidian replica tickets (12)

| # | Issue | Module | Status |
|---|-------|--------|--------|
| o01 | `o01-backlinks-frontend.md` | Backlinks | ready |
| o02 | `o02-canvas-frontend.md` | Canvas | ready |
| o03 | `o03-graph-view-frontend.md` | Graph view | ready |
| o04 | `o04-templates-frontend.md` | Templates | ready |
| o05 | `o05-note-composer-frontend.md` | Note Composer | ready |
| o06 | `o06-fulltext-search-frontend.md` | Full-text Search | ready |
| o07 | `o07-bases-frontend.md` | Bases | ready |
| o08 | `o08-quick-switcher-frontend.md` | Quick Switcher | ready |
| o09 | `o09-word-count-frontend.md` | Word Count | ready |
| o10 | `o10-outline-frontend.md` | Outline | ready |
| o11 | `o11-bookmarks-frontend.md` | Bookmarks | ready |
| o12 | `o12-obsidian-integration-tests.md` | Obsidian Integration | ready (verification) |

## Total: 23 commits on `wt/frontend-integration` branch

## Order

Phase A — Background wiring (low risk, 7 tickets, no UI):
1. h01 MemoryStore
2. h02 SkillRegistry
3. h10-h13 4 tools (File / Process / Web / Vision)
4. h14 AVMediaTools (toolkit part — UI button in later phase)

Phase B — UI mounts (16 tickets):
- Z-NOVEL toolbar: o01 Backlinks + o02 Canvas + o05 Composer + o07 Bases + h06 Kanban
- Z-TITLE toolbar: o03 Graph + o09 Word Count + o06 Search + o08 Quick Switcher + o11 Bookmarks
- Z-NOVEL right pane: o10 Outline
- Z-CHAT: h07 Todo + h14 read-aloud button
- Settings: h08 Cron + h09 Backup
- File menu: o04 Templates
- View menu: o11 Bookmarks

Phase C — Verification:
- o12 Obsidian Integration cross-tool verify

## Per-ticket constraints

- 修改只发生在叶子组件
- **不要修改 LayoutShellView / ZoneModule / WenshuApp root entry**
- 1 zone = 1 commit = independent (no cross-zone blast radius)
- 1 ticket 1 commit, test pass before next
- code-review 2 axes per commit