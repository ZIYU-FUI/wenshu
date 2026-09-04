# 001 — SubAgentIdentity struct (5 sub-agent system prompts)

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> 1 commit. Leaf-level only.

## What to build

Create `SubAgentIdentity` enum with 5 sub-agent system prompts (Researcher / Writer / Analyst / Archivist / Auditor).

## Implementation outline

**File**: `Sources/WenshuApp/Core/Agent/SubAgentIdentity.swift` (new)

```swift
public enum SubAgentIdentity {
    public enum Name: String, CaseIterable, Sendable {
        case researcher, writer, analyst, archivist, auditor
    }

    public static func systemPrompt(name: Name) -> String { ... }
    // Each ~500-700 tokens. Prepended to sub-agent LLM call.
}
```

Each prompt has 4 sections: Identity / Capabilities (tools) / Output format / Limits.

## Acceptance criteria

- [ ] 5 system prompts defined (1 per agent)
- [ ] Each prompt mentions agent role + tools + output format
- [ ] Auditor prompt emphasizes verification + verdict format
- [ ] swift build exit 0
- [ ] 5 unit tests pass (1 per agent)

## Out of Scope

- Conductor integration (next ticket 002)
- AgentRuntime changes (next ticket 003)

## Risks

- Prompt overlap between agents (e.g. Researcher + Archivist both call memory). Mitigation: explicit "you do NOT call X" in each prompt.