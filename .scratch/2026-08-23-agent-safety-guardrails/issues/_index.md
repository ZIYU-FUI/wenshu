# Agent safety guardrails — issues index

> Parent spec: `.scratch/2026-08-23-agent-safety-guardrails/spec.md`.
> Boss 2026-08-23 拍: 用户不可通过聊天修改 agent 设定 / 系统代码 / 配置文件.
> 5 tickets, 5 commits, 1 PR.

## Tickets

| # | Issue | Depends on | Status |
|---|-------|------------|--------|
| 001 | `001-path-deny-list.md` (path deny-list helper + FileTools guard) | — | pending |
| 002 | `002-process-shell-deny.md` (ProcessTools.runShell always throws) | 001 | pending |
| 003 | `003-invoke-tool-allowlist.md` (WenshuConductor.invokeTool allowlist) | 001 + 002 | pending |
| 004 | `004-system-prompt-hardening.md` (L1 system prompt禁止 section) | 001 + 002 + 003 | pending |
| 005 | `005-tool-security-tests.md` (16 tests) | 001 + 002 + 003 + 004 | pending |

## Order

Sequential: 001 → 002 → 003 → 004 → 005

## Per-ticket constraints

- Leaf-level changes (FileTools / ProcessTools / WenshuConductor / Identity files)
- 不改 LayoutShellView / WenshuAppDelegate / parent components
- Code-review 2 axes (Standards + Spec)
- swift build + tests pass each commit
- Pollution vocab 0 leak