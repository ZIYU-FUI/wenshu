# Spec — Sub-agent permission boundary (Hermes DELEGATE_BLOCKED_TOOLS parity)

> Boss 2026-08-23 拍: '关于 agent 的相关功能开发, 如果有不确定的, 就去 hermes 的源码里去扒, 一定有对应的解决方案'.

## Source: Hermes 真值

Boss 拍扒 hermes 源码. Pulled `https://github.com/NousResearch/hermes-agent.git` (clone to `/tmp/hermes-agent`). Key findings:

### Hermes `delegate_tool` enforces DELEGATE_BLOCKED_TOOLS

```python
# tools/delegate_tool.py line 39
DELEGATE_BLOCKED_TOOLS = frozenset([
    "delegate_task",  # no recursive delegation
    "clarify",        # no user interaction
    "memory",         # no writes to shared MEMORY.md
    "send_message",   # no cross-platform side effects
    "cronjob",        # no scheduling more work in parent's name
])
```

Children's toolsets are **stripped** of these before sub-agent launch.

### MemoryManager pattern

`agent/memory_manager.py` — memory is managed by **main agent only**, called via:
- pre-turn: `prefetch_all(user_message)` — load relevant memories into context
- post-turn: `sync_all(user_msg, assistant_response)` — persist new info

Sub-agents do NOT call memory_tool directly; they receive context already prefetched by main agent.

## Current wenshu state (mistakes identified)

### Bug A: Sub-agent can write memory (违反 hermes contract)

`WenshuConductor.invokeTool("memory", ...)` is reachable from ALL agents including sub-agents (Layer B ticket h01 wired `memoryStore` directly into conductor).

WenshuSubAgentIdentity.archivist prompt includes `"memory"` tool — but this should be **READ-ONLY** per hermes contract.

### Bug B: No recursion guard

Sub-agent could call delegateTask recursively (no DELEGATE_BLOCKED_TOOLS check).

### Bug C: No user-interaction guard

Sub-agent could call clarify tool (ask user clarifying questions) — violates hermes pattern.

### Bug D: No cronjob in parent's name guard

Sub-agent could schedule cron jobs — violates hermes pattern.

## Fix design

### Fix 1: Sub-agent tool list restriction (high priority)

Currently `SubAgentIdentity.tools(name:)` returns tools sub-agent *thinks* it has. Need to:
1. Define `ALLOWED_TOOLS_PER_AGENT` per agent (researcher / writer / analyst / archivist / auditor)
2. In `WenshuConductor.invokeTool(name:input:)` enforce this at runtime: caller passes agent context, invokeTool checks if this tool is allowed for this agent.

### Fix 2: Sub-agent memory is read-only

Per hermes contract, sub-agents never call `memory.add`. Only main agent (WenshuConductor) calls it post-turn.

Implementation:
1. Remove `"memory"` from `archivist.tools(name:)` — sub-agents have NO memory access at all
2. Auditor: keep `"memory"` but mark READ-ONLY (Auditor's existing prompt says "READ-ONLY")
3. WenshuConductor.addMemory() remains for main agent
4. invokeTool guard: if caller is sub-agent (not main) and tool is "memory", reject

### Fix 3: Block recursive delegation

`WenshuConductor.invokeTool("delegateTask", ...)` — block entirely. Sub-agents cannot spawn more sub-agents.

### Fix 4: Block user-interaction from sub-agents

No "clarify" tool exists yet in wenshu, but if added later, must be DELEGATE_BLOCKED.

### Fix 5: Block cron scheduling from sub-agents

Similar — `cronjob` tool blocked at sub-agent level.

## Files to touch (leaf only)

1. `Sources/WenshuApp/Core/Agent/SubAgentIdentity.swift` — strip memory tool from sub-agent lists (or keep but mark read-only for auditor)
2. `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` — invokeTool adds caller-context check
3. `Sources/WenshuApp/Core/Agent/WenshuConductorIdentity.swift` — main agent identity adds § "I am the only agent that writes memory / delegates / schedules"
4. New file `Sources/WenshuApp/Core/Agent/SubAgentPermissions.swift` — central blocked-tools allowlist per hermes contract
5. New tests file
6. `CONTEXT.md` — add `DELEGATE_BLOCKED_TOOLS` domain word

## Acceptance criteria

- [ ] `SubAgentIdentity.tools(.archivist)` does NOT include "memory" (sub-agent never writes)
- [ ] `SubAgentIdentity.tools(.auditor)` includes "memory" but system prompt says READ-ONLY
- [ ] `WenshuConductor.invokeTool` takes optional `callerAgent` parameter
- [ ] When callerAgent is sub-agent and tool is in DELEGATE_BLOCKED_TOOLS → reject
- [ ] Tests verify 5 blocked tools × 5 sub-agents = blocked combinations
- [ ] swift build + tests pass (target 571 (per 2026-08-23 audit #014))
- [ ] Code-review 2 axes

## Out of scope (deferred)

- async_delegation (background) — v0.24+
- Sub-agent cross-conversation memory isolation — v0.24+
- MemoryManager pre-turn prefetch pattern — v0.25+

## Why this matters

Boss 8/23: '如果有不确定的, 就去 hermes 的源码里去扒'. My current implementation allows sub-agents to write memory, delegate recursively, and schedule jobs — all of which Hermes specifically disallows. Adopting the contract now prevents architectural drift later.