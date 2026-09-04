# Multi-agent dispatch — issues index

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> 4 tickets, sequential. 4 commits, 1 PR.

## Tickets

| # | Issue | Depends on | Status |
|---|-------|------------|--------|
| 001 | `001-sub-agent-identity.md` (5 sub-agent system prompts) | — | ✅ done |
| 002 | `002-conductor-taskgroup-dispatch.md` (TaskGroup parallel + Auditor + synthesis) | 001 | ✅ done |
| 003 | `003-agent-runtime-tools.md` (AgentRuntime tools param) | 001 | ⚠️ **SKIPPED** — see note |
| 004 | `004-multi-agent-dispatch-tests.md` (8 tests) | 001 + 002 + 003 | pending (003 dependency dropped) |

## Note on ticket 003 (SKIPPED)

Boss拍 5 expert model + ticket 002 implementation chose a simpler path:
`WenshuConductor` calls `verifier.chat(_:system:model:)` directly with the
sub-agent's system prompt, **bypassing `AgentRuntime.delegateTask()`**.

This was a design decision: the new model treats sub-agents as direct LLM
calls with independent system prompts, not as a separate A2A dispatch layer.
`AgentRuntime` remains available for future use (e.g. multi-process dispatch),
but is not on the hot path.

Therefore ticket 003 (modify AgentRuntime delegateTask signature) is **NOT
REQUIRED** for the v0.23 multi-agent dispatch MVP. Deferred to v0.24+ if
sub-agents ever need true A2A protocol.

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