# 文枢 Agent 基础设定 — issues index

> Parent spec: `.scratch/2026-08-23-agent-identity/spec.md`.
> 1 ticket (consolidated per boss 拍 "推进"). 1 commit.

## Tickets

| # | Issue | Status |
|---|-------|--------|
| 001 | `001-wenshu-agent-identity.md` (WenshuAgentIdentity struct + WenshuConductor integration + 6 tests) | pending |

## Order

- Single commit: create struct + inject into 2 LLM call sites + 6 tests

## Per-ticket constraints

- 修改只发生在叶子 (WenshuConductor.handle() 是 1 个 actor method, 修改它的 2 处 prompt 字符串)
- 不增加新分区
- 不改父组件
- Code-review 2 axes (Standards + Spec)
- swift build + 344 tests pass

## Follow-up (not in this ticket)

- v0.23: per-ticket role memories (different agent personas per context)
- v0.24: agent memory viewer UI (let user see what agent remembers)