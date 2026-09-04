# 003 — AgentRuntime sub-agent tools support

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> Depends on: 001 (SubAgentIdentity).
> 1 commit. Modifies AgentRuntime.

## What to build

Add `delegateTask(to:agentName:content:tools:fromAgent:)` overload to `AgentRuntime` that takes a tools array (sub-agent specific tools).

## Implementation outline

```swift
public func delegateTask(
    to agentName: String,
    content: String,
    tools: [String],  // e.g. ["search", "web", "linkgraph"]
    fromAgent: String
) async throws -> A2ATask
```

Currently `delegateTask(to:content:fromAgent:)` exists. Add tools param (default empty).

Tools list comes from `SubAgentIdentity.tools(name:)`:
- researcher: [search, web, linkgraph]
- writer: [composer, template, wordcount]
- analyst: [outline, bases, graph]
- archivist: [memory, bookmark, backup]
- auditor: [memory] (read-only)

## Acceptance criteria

- [ ] Overload signature added
- [ ] 5 unit tests pass (1 per agent: tools list correct)
- [ ] Backward compat: existing call sites still work (default empty tools)
- [ ] swift build + tests pass

## Out of Scope

- Conductor integration (ticket 002)