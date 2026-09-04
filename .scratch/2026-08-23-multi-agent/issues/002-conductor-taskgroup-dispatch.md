# 002 — WenshuConductor multi-agent dispatch (TaskGroup parallel)

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> Depends on: 001 (SubAgentIdentity struct).
> 1 commit. Modifies WenshuConductor.

## What to build

Replace current `for agentName in selectedAgents` loop with TaskGroup parallel dispatch.

## Implementation outline

Modify `WenshuConductor.handle()`:

1. Intent classify: prompt changes from "5 module names" to "5 sub-agent names: researcher / writer / analyst / archivist / auditor".
2. Replace for-loop with TaskGroup:
   ```swift
   await withTaskGroup(of: (String, String).self) { group in
       for agentName in selectedAgents {
           group.addTask {
               let prompt = buildSubAgentPrompt(name: agentName, userMessage: userMessage, systemPrompt: SubAgentIdentity.systemPrompt(name: agentName))
               let response = try? await verifier.chat(prompt, system: SubAgentIdentity.systemPrompt(name: agentName), model: model)
               return (agentName, response?.content.map(\.displayText).joined() ?? "(unreachable)")
           }
       }
   }
   ```
3. Audit pass: if writer or analyst ran, also spawn auditor task.
4. Synthesis: include sub-agent outputs + auditor verdict in synthesis prompt.

## Acceptance criteria

- [ ] Parallel dispatch (timing test: 2 sub-agents finish in ~time of 1, not 2x)
- [ ] Intent returns 1-3 sub-agents from 5 candidates
- [ ] Auditor runs iff writer or analyst in selection
- [ ] Synthesis includes sub-agent + auditor outputs
- [ ] swift build + tests pass
- [ ] Code-review 2 axes

## Out of Scope

- New sub-agent identity (ticket 001)
- New AgentRuntime signature (ticket 003)

## Risks

- TaskGroup cancellation if conductor actor deallocated. Mitigation: use `withTaskGroup` (auto-cancel on scope exit).