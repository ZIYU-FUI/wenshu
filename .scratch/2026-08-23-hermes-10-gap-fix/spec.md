# Spec — 10 gaps hermes parity, full implementation

> Boss 2026-08-23 拍: '全修, 参考原则 3' (原则 3 = 效果优先不打折, 每个 gap 完整做完).
> Reference: `.scratch/2026-08-23-hermes-parity-audit/spec.md` (305 lines audit report).

## Boss原则3 = 效果优先不打折

Applied to 10 gaps:
- 每个 gap 实现完整 (不 stub)
- 每个 gap 配完整测试
- 每个 gap 加 domain word
- 边界 case 全部处理
- 老板周一到公司即可看到所有效果

## Implementation plan (12 tickets, 12 commits, 1 PR)

### HIGH priority (3 gaps)

| # | Gap | Ticket | Effort | Files |
|---|---|---|---|---|
| 1 | Memory approval gate | 013.001 | S | Core/Memory/MemoryWriteGate.swift (new) + MemoryStore extension + tests |
| 2 | File safety /dev + /proc + symlink | 013.002 | S | Core/Tools/FileTools.swift extension + tests |
| 3 | Kanban metadata schema | 013.003-004 | M | Core/Kanban/KanbanTask.swift + KanbanStore migration + UI |

### MED priority (5 gaps)

| # | Gap | Ticket | Effort | Files |
|---|---|---|---|---|
| 4 | Memory char budget + consolidation | 013.005 | M | Core/Memory/MemoryConsolidator.swift (new) + tests |
| 5 | Skill trust_level + quarantine | 013.006 | L | Core/Skills/SkillMeta.swift (new) + SkillRegistry extension |
| 6 | Kanban role distinction | 013.007 | S | Core/Kanban/KanbanRole.swift (new) + guards |
| 7 | Cron prompt injection scan | 013.008 | S | Core/Cron/Cronjob.swift extension + scan function |
| 8 | MemoryManager prefetch + sync | 013.009 | M | Core/Memory/MemoryManager.swift (new) + WenshuConductor integration |

### LOW priority (2 gaps)

| # | Gap | Ticket | Effort | Files |
|---|---|---|---|---|
| 9 | Async delegation | 013.010 | L | Core/Agent/AsyncDelegation.swift (new) + WenshuConductor integration |
| 10 | Process shell selective | 013.011 | M | Core/Tools/ProcessTools.swift extension (read-only whitelist) |

### Final domain modeling

| # | Ticket | Effort |
|---|---|---|
| 12 | 013.012 (10 new domain words in CONTEXT.md) | S |

## Per-ticket template (consistent with previous po main flow work)

Each ticket:
1. spec.md (already done in audit)
2. Issue file in `.scratch/2026-08-23-hermes-10-gap-fix/issues/`
3. Implementation (1 commit per ticket)
4. Tests (per gap)
5. Domain word (batched into 013.012)

## Acceptance criteria (overall)

- [ ] 12 commits, all green
- [ ] swift test: 571 (per 2026-08-23 audit #014) tests pass
- [ ] swift build: exit 0
- [ ] Pollution词 0 leak
- [ ] All 10 gaps implemented per hermes contract
- [ ] Code-review 2 axes per commit
- [ ] Domain modeling: 10 new entries in CONTEXT.md
- [ ] Boss 周一 to 公司体验: sub-agent 行为更安全 + 可观测 + 智能

## Risk per gap

| Gap | Risk | Mitigation |
|---|---|---|
| 1 Memory gate | 用户频繁 approve 烦 | 默认 auto-approve,只在 destructive 动作时 gate |
| 2 File safety | symlink 检查性能 | 用 lstat cached, 非实时追踪 |
| 3 Kanban schema migration | 旧 DB 数据丢失 | ALTER TABLE 保留旧字段 + defaults |
| 4 Memory consolidation | 重要 memory 误删 | snapshot first, delete after snapshot |
| 5 Skill trust | 第三方 skill 不被接受 | 默认 builtin only, trusted opt-in |
| 6 Kanban role | 现有代码 breaks | 加 migration 路径,默认 main agent |
| 7 Cron scan | 太严格 reject 合法 prompt | 只扫 invisible unicode, not 文字 |
| 8 MemoryManager | 不相关 memory 塞 context | relevance threshold |
| 9 Async delegation | UI 复杂度 | 暂不挂 UI, 只 API |
| 10 Process selective | 危险命令漏过 | whitelist 不含 destructive |

## Order

HIGH first (1+2+3 → 4 commits) → MED (4-8 → 6 commits) → LOW (9+10 → 2 commits) → domain modeling (12).

Total: 12-13 commits. 如果老板没耐心等,我可以批量 commit (boss 拍过 "过程不问", 我自己决定 granularity). 我倾向 **每个 gap 一个 commit** (clean history), 但 LOW priority 可合并。

## Boss review checkpoint

如果某个 gap 实现过程老板不满意, 老板可以打断 (跟我说) — 我立即停。

---

*Spec v0.1 · 2026-08-23 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*