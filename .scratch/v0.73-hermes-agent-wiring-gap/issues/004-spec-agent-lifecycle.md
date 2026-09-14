# Issue 004 · Spec the AgentLifecycleTracker surface (= design-doc only, no code)

**Ticket**: 004-spec-agent-lifecycle
**Scope**: 1 file (= design doc) + 1 file (= source comment update)
**Methodology**: Q112 + boss standing rule "agent decides cleanup scope" (Q79)

## Problem

`Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift` (= ~580 LOC, Round 2-ish port of hermes `agent/agent_runtime_helpers.py` subset) defines:
- `AgentLifecycleTracker` (= @unchecked Sendable; = tracks spawn / heartbeat / terminal status of sub-agents)
- `AgentLifecycleRecord` (= spawn time + status + result + error + heartbeat interval)
- 6-step bootstrap (= configLoaded / memoryLoaded / profileSlug / credentialsResolved / skillRegistryLoaded / dispatchTimeout)

**Production usage is uncertain.** Today:
- `SubAgentProgressView.swift` reads a DIFFERENT in-memory state (= refactor risk to consolidate)
- `WenshuConductor.swift` does NOT call `tracker.registerSpawn(...)`
- `ConversationLoop.swift` does NOT consult `tracker.markCompleted(...)` post-turn

## Decision (per spec.md §Acceptance)

**Defer + spec the surface.** Sub-agent heartbeat belongs to the WenshuConductor / SubAgentProgressView UI layer. Wiring it requires:
- Either: refactor `SubAgentProgressView` to read from `AgentLifecycleTracker` (= ~200 LOC refactor)
- Or: add a parallel `tracker.registerSpawn(...)` call site in `AsyncDelegation` (= per HERMES-PARTIAL-018 `delegate_tool.py`)

Both are real work. v0.73 stops at the design-doc stage.

## Plan

### 1. New file: `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTrackerDesign.md`

A short (= ~150 LOC) design doc capturing:
- The 2 wiring options (= refactor SubAgentProgressView OR parallel call site)
- The decision matrix (LOC cost / risk / test coverage per option)
- The recommended path (= boss 9/4 'A' protocol: ponytail = quality control, not token savings)
- The blocker (= which files need to change before wiring can land)

### 2. Update file: `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift`

Add a doc-comment header linking to the design doc:

```
//
//  DEFERRED (v0.73 spec decision):
//  This file's production caller is undecided. See
//  Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTrackerDesign.md
//  for the wiring decision matrix. Future ticket (= v0.74+) will land the
//  recommended path per the design doc.
//
```

No code change. No tests.

## Files changed

- `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTrackerDesign.md` (new, ~150 LOC)
- `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift` (+6 lines doc-comment)

## Commit message template

```
docs(wenshu): spec the AgentLifecycleTracker wiring surface (= deferred)

- New AgentLifecycleTrackerDesign.md with wiring decision matrix
- 2 options: refactor SubAgentProgressView OR parallel call site
- Per .scratch/v0.73-hermes-agent-wiring-gap/spec.md §Acceptance
- No code change (= design-doc only)

Refs: .scratch/v0.73-hermes-agent-wiring-gap/spec.md
Ticket: 004-spec-agent-lifecycle
```

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change)
- [ ] Design doc has both options + recommended path
- [ ] Doc-comment header present + links to design doc
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope

- Wiring (= future ticket, after boss decision)
- Deletion (= NEVER per Q57)
- Refactoring `SubAgentProgressView` (= not in v0.73 scope)