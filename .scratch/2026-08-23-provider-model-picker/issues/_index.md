# Multi-provider model picker — issues index

> Parent spec: `.scratch/2026-08-23-provider-model-picker/spec.md`.
> Boss 2026-08-23 拍: 我配了三个厂家的 key,模型切换应分组展示.
> 4 tickets, 4 commits, 1 PR.

## Tickets

| # | Issue | Depends on | Status |
|---|-------|------------|--------|
| 001 | `001-discovery-struct.md` (AvailableModelsDiscovery) | — | pending |
| 002 | `002-chat-view-picker.md` (Menu Sections) | 001 | pending |
| 003 | `003-discovery-tests.md` (5 tests) | 001 + 002 | pending |
| 004 | `004-domain-modeling-picker.md` (CONTEXT.md) | 001 + 002 | pending |

## Order

Sequential: 001 → 002 → 003 → 004

## Per-ticket constraints

- Leaf-level changes only
- Code-review 2 axes (Standards + Spec)
- swift build + tests pass each commit
- Pollution vocab 0 leak