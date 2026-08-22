# Frontend integration — issues index

> Parent spec: `.scratch/2026-08-22-frontend-integration/spec.md`.
> 14 tickets = 1 commit each = 1 PR (or 1 branch with 14 commits).

## Order

| # | Issue | Depends on |
|---|-------|------------|
| 013 | MemoryStore (Hermes replica) | — |
| 014 | SkillRegistry (Hermes replica) | — |
| 001 | Backlinks (Obsidian replica) | — |
| 002 | Graph view (Obsidian replica) | — |
| 003 | Canvas (Obsidian replica) | — |
| 004 | Templates (Obsidian replica) | — |
| 005 | Note Composer (Obsidian replica) | — |
| 006 | Full-text Search (Obsidian replica) | — |
| 007 | Bases (Obsidian replica) | — |
| 008 | Quick Switcher (Obsidian replica) | — |
| 009 | Word Count (Obsidian replica) | — |
| 010 | Outline (Obsidian replica) | — |
| 011 | Bookmarks (Obsidian replica) | — |
| 012 | Obsidian Integration cross-tool verify | 001-011 done |

## Execution order rationale

Tickets 013 + 014 are background-only wiring (no UI). Land them first to unblock agent capabilities.

Tickets 001-011 are UI integrations. Each touches ONE zone toolbar / ONE menu / ONE view. No parent component edits.

Ticket 012 last: integration test verification across all 11 UI mounts.

## Branch

`wt/frontend-integration` — all 14 commits on one branch, single PR.

## Per-ticket constraints (boss拍)

- 修改只发生在叶子组件 (ZoneModule 子组件 / Toolbar config / 独立 view 文件)
- **不要修改 LayoutShellView / ZoneModule / WenshuApp root entry**
- 每个 zone 修改不互相影响 (one zone = one commit = independent)
- 1 ticket = 1 commit
- 测过再下个 (swift build + relevant test pass)
- code-review 2 axes per commit

## Blocking edges

- 012 blocked by 001-011 (needs all UI mounted to verify round-trip)
- All other tickets independent (different files / different toolbar slots)