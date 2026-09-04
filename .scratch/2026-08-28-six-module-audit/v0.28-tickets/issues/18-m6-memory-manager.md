# Issue 18 — M6/M6 hermes verbatim-port — memory manager

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Hermes port plan: `.scratch/2026-08-28-six-module-audit/modules/M6-*.md`
> Boss拍 2026-08-28 OOB: M5/M6 hermes 源码复刻 split into 4-5 v0.28 tickets (not one mega-commit)

## Module

M6 Settings & Library

## What (verbatim port)

MemoryManager REPLACES 现有 (1393 LOC verbatim port) + MemoryProvider = provider ABC + lifecycle hooks — 比现有 700 LOC 实现多 1 倍 (= 跟齐 hermes)

## From hermes

```
agent/memory_manager.py (1393 LOC) + agent/memory_provider.py
```

## To wenshu

```
Sources/WenshuApp/Core/Memory/MemoryManager.swift (REPLACES existing) + Core/Memory/MemoryProvider.swift
```

## Est LOC

~700

## Trigger condition (when to land)

M6 Memory 标签页扩展时 (= 显示 hermes parity)

## Dependencies

可独立 (existing MemoryStore 是 simple impl, 这次完整替换)

## Acceptance criteria

- All referenced hermes files inspected line-by-line (READ-ONLY)
- Verbatim port (= file → file, copy/adapt/drop per per-module audit plan)
- `swift build` exit 0
- `swift test` exit 0 (no new failures vs baseline 7c1f548e0)
- Dual-axis code-review (Standards + Spec) per Q125 protocol
- Pollution-defense hex-encoding rule honored (no [forbidden-vocab-1] / [forbidden-vocab-2] / forbidden-vocab-list literal in source)
- Per ADR-0008 carve-out: NOT a view-framework port (= pure data / service layer)

## Out of scope (= explicitly NOT porting per boss OOB)

- Cloud memory providers (mem0 cloud / honcho / hindsight / holographic / openviking / retaindb / supermemory / byterover) — boss拍 数据不出本机
- OAuth device-code / external flows — boss拍 single-user macOS
- External credential backends (Bitwarden / 1Password / command / iron_proxy)
- Plugin system (hermes agent_init.py plugin loading + gateway/control_socket.py + registration_lifecycle.py)
- Skill bundling / sync / commands (wenshu is single-user)
- Cron LLM tool (cronjob_tools.py) — boss拍 用户不可通过聊天改系统
- Cron notepad / blueprints / suggestions — boss拍 cron is user-scheduled
- OTLP exporter / monitoring
- Multi-profile cron isolation
- Cross-process file locking (cron fcntl/msvcrt)

**Total drops: ~10,500 LOC of hermes Python** for boss policy reasons, NOT for hermes-vs-wenshu technical gap.

## Test results

- PENDING

## UI verify (boss)

N/A — internal capability port; user-visible features land in separate feature tickets that consume this port.

## Risks

- Bus factor on hermes Python = 1 (Nous Research team); wenshu Swift port is independent and can diverge if hermes stops maintaining
- Pollution-defense: must hex-encode any [forbidden-vocab-1] / [forbidden-vocab-2] / etc. tokens per `WenshuVerifier.shortOutputStopSequences` pattern (see M5-character-world-codex.md §3.1 for the rule)

## Status: PENDING (lands when boss triggers the feature ticket that consumes this port)
