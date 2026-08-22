# 04 — 文枢 main agent multi-module dispatch (KanbanStore writes tasks)

**What to build:**
老板 2026-08-21 ruled: "multi-agent collaboration is orchestrated by 文枢, dispatched via the kanban board; every other agent stays hidden." `WenshuConductor` = 文枢's main-agent dispatcher (actor + `AgentProcess` pattern). Receive user message → analyze intent → dispatch 0–N `KanbanTask` items to sub-agents (reusing v0.19's 12 modules) → wait for results → call `MiniMaxVerifier.send` to compose the final reply. Sub-agent progress flows through `KanbanStore`; `ChatView` never shows it.

**Blocked by:** ticket 02 (`KanbanStore` exists; schema needs `assignee` / `conductor_task_id` columns) + ticket 03 (real LLM synthesis available).

**Status:** ready-for-agent

## Fix specification

1. Create `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (actor + `AgentProcess` pattern, mirroring `AgentProtocol`).
2. `WenshuConductor` holds references to `AgentRuntime` + `KanbanStore` + `MiniMaxVerifier`.
3. `WenshuConductor.handle(userMessage: String, sessionId: String) async throws -> String`:
   - Call `MiniMaxVerifier.chat(`intent analysis: \(userMessage) -> {assignee, task}`)` to obtain the task list.
   - From the `KanbanTask` list → write to `KanbanStore` (`assignee` = sub-agent name, `conductor_task_id` = parent task ID).
   - Dispatch `AgentRuntime.delegateTask(to: assignee, ...)` to each sub-agent.
   - Wait for all sub-agent tasks to complete (poll `KanbanStore.status == .done`).
   - Call `MiniMaxVerifier.chat(`synthesis: sub-agent results + user message -> final reply`)` to produce 文枢's final reply.
   - Return the `String` to `ChatViewModel`.
4. Add 2 columns to the `KanbanStore` schema:
   ```sql
   ALTER TABLE kanban_tasks ADD COLUMN assignee TEXT;
   ALTER TABLE kanban_tasks ADD COLUMN conductor_task_id TEXT;
   ```
   (Add the matching fields to the `Task` struct inside `KanbanStore`.)
5. Register v0.19's 12 modules (`LinkGraph` / `Search` / `Composer` / `Templates` / `Graph` / `Canvas` / `Bases` / `QuickSwitcher` / `WordCount` / `Outline` / `Bookmarks` / `Verifier`) as optional `assignee` values inside `AgentRuntime`.
6. Update `ChatViewModel.send()`: prefer `WenshuConductor.handle` (no direct `delegateTask`); fall back to `verifier.chat(text)` (same as the ticket 03 fallback).

## Acceptance

- [ ] `WenshuConductor` actor + `AgentProcess` pattern landed
- [ ] `handle(userMessage:)` dispatches tasks → waits for results → composes a real synthesized reply
- [ ] `KanbanStore` schema gains `assignee` + `conductor_task_id`
- [ ] v0.19's 12 modules registered as sub-agent assignees
- [ ] `ChatViewModel.send()` routes through `WenshuConductor`
- [ ] Dispatch progress never enters `ChatView` (the `ChatMessage` stream only contains `.user` / `.wenshu` / `.system`)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: send a message, see 文枢's reply, inspect `KanbanStore` for sub-tasks (future UI)

## Out of scope

- v0.19's 12 module agent implementations (only register; don't rewrite)
- A2A protocol
- `KanbanStore` 7-state state machine (reuse as-is)

## References

- Depends on: ticket 02 + 03
- Required by: ticket 06 (`ChatViewModel` integrates `WenshuConductor`)
