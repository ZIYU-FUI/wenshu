//
//  AgentLifecycleTrackerDesign.md · Wenshu · v0.73 ticket 004
//
//  Design doc for wiring `AgentLifecycleTracker` (= the v0.28
//  hermes-port in `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift`)
//  into the sub-agent spawn / heartbeat / complete surface that
//  `SubAgentProgressView` (= the aiDynamic-zone user-visible progress
//  card) consumes today.
//
//  Generated 2026-09-14 as part of v0.73 hermes agent wiring audit.
//  Per boss 2026-09-14 OOB "我们迁移了两回, 早期的一回漏接很普遍",
//  this design doc is the inventory of why the tracker is currently
//  orphaned + the decision matrix for wiring it in a future ticket.
//

# AgentLifecycleTracker wiring — design doc

## Why this file exists

`AgentLifecycleTracker` (= the v0.28 verbatim port of hermes
`agent/subagent_lifecycle.py`) defines:

- `AgentLifecycleTracker` (= @unchecked Sendable; spawn / heartbeat /
  terminal status tracking for sub-agents)
- `AgentLifecycleRecord` (= spawn time + status + result + error +
  heartbeat interval + dispatchTimeout)
- 6-step spawn-time bootstrap (= configLoaded / memoryLoaded /
  profileSlug / credentialsResolved / skillRegistryLoaded /
  dispatchTimeout)
- `AgentInitDefaults.pocock` (= per-profile defaults aligned with
  hermes' `agent_init.py`)

It was ported in v0.28 but never wired into:

1. **`AsyncDelegation`** (= `Core/Agent/Conversation/AsyncDelegation.swift`),
   the production sub-agent dispatch surface (Round 1 HERMES-PARTIAL-018)
2. **`WenshuConductor`** (= `Core/Agent/Conversation/WenshuConductor.swift`),
   the main conversation orchestration
3. **`SubAgentProgressView`** (= `Views/Kanban/SubAgentProgressView.swift`),
   the user-visible progress card

The user-visible progress card today reads from `WSKanbanRepository.shared`
(= SwiftData wrapper added in v0.72 Phase 5 ticket 6; = the KanbanStore
actor's SwiftData replacement), not from `AgentLifecycleTracker`. This is
the source of the orphaned-tracker pattern (= Q57: third-party verdict is
data, not authority; the tracker is real code, but its natural consumer
path went through a different data layer).

## Decision matrix

### Option A — Refactor `SubAgentProgressView` to read `AgentLifecycleTracker`

**Cost**:
- Move `SubAgentProgressView` from `WSKanbanRepository.shared` →
  `AgentLifecycleTracker.shared` (= ~200 LOC refactor + ~30 LOC UI
  reshape for the record shape)
- Wire `AsyncDelegation` to call `tracker.registerSpawn(...)` at
  dispatch time + `tracker.markCompleted(...)` at result collection
  (= ~50 LOC across `AsyncDelegation`)
- Add 1 explicit SwiftData @Model layer (= or rely on the tracker's
  in-memory state only = not persisted across launches)

**Risk**:
- `WSKanbanRepository` is the canonical "sub-agent task" persistence
  post Phase 5; switching the UI to the tracker means losing the
  SwiftData round-trip (= restart = lose progress)
- `AsyncDelegation` is part of Round 1 (= HERMES-PARTIAL-018) and is
  one of the few "well-tested but lightly-used" files; adding calls
  to it touches a high-traffic surface

**Test coverage**: existing `AgentLifecycleTrackerTests` cover
registerSpawn / markRunning / markCompleted / markFailed / cancel /
sweepStale (= ~10 tests); would need new "AsyncDelegation calls
tracker on dispatch" tests

### Option B — Parallel call site: `tracker.registerSpawn(...)` in `AsyncDelegation` + leave UI alone

**Cost**:
- Add ~20 LOC to `AsyncDelegation.swift` to call
  `tracker.registerSpawn(...)` at dispatch time + `tracker.markCompleted(...)`
  at result collection
- UI keeps reading from `WSKanbanRepository.shared` (= zero UI change)
- Add 1 lightweight "tracker observability" admin view (= ~100 LOC
  inside the existing Settings → Diagnostics pane) so the tracker
  state is at least inspectable by the user

**Risk**:
- Two parallel sources of truth (= `WSKanbanRepository` for UI +
  `AgentLifecycleTracker` for diagnostics) = risk of drift
- The tracker state is in-memory only (= loses on restart)

**Test coverage**: existing `AgentLifecycleTrackerTests` cover the
tracker API; would need new "AsyncDelegation dispatches → tracker
records" tests

### Option C — Defer entirely (= keep tracker as documented orphan)

**Cost**: zero

**Risk**: the tracker remains an undocumented orphan (= no spec.md link
to "why we kept this"; = future agents grep `AgentLifecycleTracker` and
ask "is this dead code?")

**Test coverage**: unchanged (= existing tests still pass; the tracker
is just unused)

## Recommendation: **Option B**

Per AGENTS.md §11.3 wenshu-side wins + boss 2026-09-04 OOB 'A':
- Parallel call site is the smallest-risk wiring (= UI is not touched)
- Drift risk is mitigated by the 1:1 source-of-truth on `AsyncDelegation`
  (= the only place that produces sub-agent events; both KanbanStore
  + tracker read from the same call site)
- The diagnostic pane gives the user a way to inspect the tracker
  state (= per Q90: "kanban = work-in-progress 明盒")

## Recommended next ticket (= v0.74+)

A future ticket (= separate from v0.73) should:

1. Land Option B as 1 file 1 commit per Q112 (= atomic)
2. Move the `SubAgentProgressView` reading source from
   `WSKanbanRepository.shared` to `tracker.records` (Option A) in a
   separate ticket (= refactor risk; = needs its own spec)
3. Add SwiftData persistence to the tracker (= separate ticket; = needs
   `WSAgentLifecycleRecord` @Model class)

## Acceptance for this design-doc ticket

- [ ] `swift build` = BUILD COMPLETE (no code change in this ticket)
- [ ] `swift build --target WenshuAppTests` = BUILD COMPLETE
- [ ] Design doc = present + readable + linked from
      `AgentLifecycleTracker.swift` doc-comment header
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope

- Wiring Option A or B (= separate ticket, future work)
- Deletion of `AgentLifecycleTracker.swift` (= NEVER per Q57)
- Refactor of `SubAgentProgressView` (= separate ticket, future work)
- SwiftData persistence for the tracker (= separate ticket, future work)