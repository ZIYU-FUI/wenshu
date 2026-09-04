# Grill-with-docs — 多 Agent 调度

> Boss 2026-08-23: "多 agent 调度能实现吗? 我现在有时间了, 有完整流程, 从需求澄清走全流程".
> Status: **需求澄清阶段**. Boss needs to answer 5 questions to unblock spec.
> If boss can't answer now, defaults proposed below (boss拍 ).

## Q1: 多 agent 调度的范围 — 哪些 module 跑成 sub-agent?

**Current state**: `WenshuConductor.handle()` hardcodes 5 candidate agents: search / outline / wordcount / linkgraph / composer (per intent classify prompt in line 156-168).

**Options**:

- (A) **全部 16 modules 都跑 sub-agent** — too many, intent classify 出错率高, 每次 query 派 5+ agent cost 高
- (B) **只 writer 相关 5 个** (search / outline / wordcount / linkgraph / composer) — 跟当前实现一致, 风险低
- (C) **老板拍** — 老板挑具体哪几个

**Default proposal** (if boss doesn't拍 ): **(B) 5 writer agents**, expand later per需求.

## Q2: sub-agent 真跑 LLM 还是 fake?

**Current state**: `AgentRuntime.delegateTask(to: agentName, ...)` 调 1 次 LLM, prompt 改写, **不是真子 agent** (没独立 system prompt, 没独立 context window, 没独立 state).

**Options**:

- (A) **Fake 继续** — prompt 改写, 1 LLM call per query, cost 低. 限制: 1 sub-agent 不能超过 LLM context window.
- (B) **真 LLM per sub-agent** — 每个 sub-agent 独立 system prompt + 独立 messages. Cost 高 (2 sub-agents = 2-3x query cost).
- (C) **Hybrid** — intent classify 1 LLM call + synthesis 1 LLM call, 派 N sub-agent 各自 1 LLM call. Total = N+2 calls per query.

**Default proposal**: **(C) Hybrid** — 跟当前架构一致, intent + synthesis 已经是真 LLM call, 改 sub-agent 也是真 LLM call. Cost = N+2 per query (3 sub-agents ≈ 4x cost).

## Q3: sub-agent 串行 vs 并行?

**Current state**: `for agentName in selectedAgents { ... }` — 串行 (sync loop).

**Options**:

- (A) **串行** — sub-agent 1 跑完再跑 2. Total time = sum(times). 简单.
- (B) **并行** — `async let` / `TaskGroup` 全部 sub-agent 同时跑. Total time = max(times). 复杂, 但快.

**Default proposal**: **(B) 并行** (TaskGroup) — 老板 query latency 降 2-3x (3 sub-agent 串行 9s → 并行 3s). 复杂但值.

## Q4: sub-agent 失败时 graceful degradation?

**Current state**: 每个 sub-agent 调用 `try?`, 失败时 `subResults.append((agentName, "(subagent unreachable)"))`, 不影响其他 sub-agent + synthesis 继续. **已经是 graceful degradation**.

**Default proposal**: **保持现状** (graceful degradation 已就位). 不需要改.

## Q5: sub-agent 调用 tool?

**Current state**: `WenshuConductor.invokeTool(name, input)` 已经接 5 tools (h10 wired) + AVMedia (h14 wired). 任何 LLM call 都可以用 `extraSystemPrompt` 提到 tool. 实际 sub-agent LLM call 没接 tool.

**Options**:

- (A) **sub-agent 不调 tool** — search agent 只调 LLM 做"模拟搜索", 跟现状一致. Cost 低.
- (B) **sub-agent 调 tool** — search agent 调 WebTools.fetch() 真的搜, outline agent 调 LinkGraph 真的算. Cost 仍低 (tool 调不花钱 token).

**Default proposal**: **(B) sub-agent 调 tool** — WenshuConductor.invokeTool 已有, sub-agent LLM call 加 tool prompt 段, 1 行改动.

---

## Boss拍 plate

| Q | Default | Boss 拍 |
|---|---------|---------|
| Q1 范围 | B (5 writer agents) | _______ |
| Q2 真跑 vs fake | C (Hybrid, N+2 calls) | _______ |
| Q3 串行 vs 并行 | B (TaskGroup parallel) | _______ |
| Q4 graceful degradation | keep现状 | _______ |
| Q5 sub-agent 调 tool | B (yes, add tool prompt) | _______ |

如果老板 5 问都"按默认" = 我**5 defaults** 走全流程.

## 推荐顺序 (post-grill)

按 po main flow:
1. `to-spec` — 写 spec v0.1
2. `to-tickets` — 拆 N 个 issue
3. `implement` — 改 WenshuConductor + AgentRuntime + 加 SubAgentIdentity struct
4. `code-review` — 双轴 (Standards + Spec)
5. `domain-modeling` — 加新词到 CONTEXT.md

每个阶段完成后, 给老板一个进展报告.