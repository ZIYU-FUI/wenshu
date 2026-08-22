# Multi-agent dispatch — issues index

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> 4 tickets, sequential. 4 commits, 1 PR.

## Tickets

| # | Issue | Depends on | Status |
|---|-------|------------|--------|
| 001 | `001-sub-agent-identity.md` (5 sub-agent system prompts) | — | pending |
| 002 | `002-conductor-taskgroup-dispatch.md` (TaskGroup parallel + Auditor + synthesis) | 001 | pending |
| 003 | `003-agent-runtime-tools.md` (AgentRuntime tools param) | 001 | pending |
| 004 | `004-multi-agent-dispatch-tests.md` (8 tests) | 001 + 002 + 003 | pending |

## Order

Sequential: 001 → 002 → 003 → 004

(Note: 003 could be parallel with 002 since different file, but easier to keep sequential for review clarity.)

## Per-ticket constraints

- Leaf-level changes only (no LayoutShellView / WenshuAppDelegate)
- 1 ticket = 1 commit
- Code-review 2 axes
- swift build + tests pass each commit
- No pollution vocab in new files

## Branch

`wt/multi-agent-dispatch` (separate from `wt/frontend-integration`)

## Post-merge

- v0.23: per-query budget token cap (current: 3-6x baseline)
- v0.23: sub-agent user override (boss disables specific sub-agent in Settings)
- v0.24: sub-agent memory (each sub-agent has scratch memory for intermediate results)