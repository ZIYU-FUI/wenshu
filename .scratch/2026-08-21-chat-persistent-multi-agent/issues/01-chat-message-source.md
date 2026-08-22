# 01 — ChatMessage source field + ChatView renders 文枢 alone

**What to build:**
老板 2026-08-21 ruled: "users only ever see a single chat session; multi-agent collaboration shows only the single 文枢 agent; every other agent stays hidden." Add a `source` field to `ChatMessage` (distinguishing `.user` / `.wenshu` / `.system`); have `ChatView` render different ICON + color per source. Multi-agent dispatch results do NOT flow into the ChatMessage stream — they go through KanbanStore (follow-up ticket 04).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Fix specification

1. In `Sources/WenshuApp/Views/Chat/ChatView.swift`, add a `source: ChatSource` field to the `ChatMessage` struct, and update `Equatable` to compare `source` as well.
2. Add a new enum `ChatSource: String, Equatable, Sendable { case user, wenshu, system }`.
3. Add a `source` parameter to `ChatMessage.init` (default `.wenshu` to preserve backward compatibility).
4. In `ChatViewModel.send()`, tag user messages with `.user`, agent replies with `.wenshu`, errors with `.system`.
5. `ChatMessageView` renders per source:
   - `.user` → bubble on the right, blue background
   - `.wenshu` → bubble on the left, system-color background, "文枢" label
   - `.system` → centered gray text, Error icon
6. `AgentProtocol.handleMessageSend` dispatches sub-agent results without rendering them as `ChatMessage`; leave the seam for ticket 04 to wire up `KanbanStore`.

## Acceptance

- [ ] `ChatMessage` struct has a `source` field, default `.wenshu`
- [ ] `ChatSource` enum: `.user` / `.wenshu` / `.system`
- [ ] `ChatViewModel.send()` uses the `source` field to tag message types
- [ ] `ChatMessageView` shows different ICON + color per `source`
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0 (no existing tests broken)
- [ ] New tests: `testChatMessageSource` (one each for `.user` / `.wenshu` / `.system`)

## Out of scope (Q20)

- `runtime.delegateTask` / `AgentProtocol.handleMessageSend` L188-190 echo (changes land in ticket 03)
- `ChatViewModel.send` main flow + `verifier.ping` fallback
- v0.20 ticket 01 ChatView UI (`cf121f77a` already committed — only add `source`, don't change structure)

## References

- Depends on: none
- Required by: ticket 02 (`ChatSessionStore` uses `source` field) / ticket 06 (`ChatViewModel` integration)
