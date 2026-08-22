# 05 — Sliding window + persistent summary (context never blows up)

**What to build:**
老板 2026-08-21 ruled: "what looks like a single session has to keep going, and the context must never blow up." Sliding window + persistent summary: keep the latest 10 turns verbatim; older history is summarized by the LLM and stored separately in SQLite (the `chat_summaries` table). When feeding the LLM, assemble `summary + last 10`; UI still shows every message (no deletion), only the LLM prompt uses the context window.

**Blocked by:** ticket 02 (`chat_summaries` table built) + ticket 03 (real LLM synthesis callable).

**Status:** ready-for-agent

## Fix specification

1. Add an actor method to `Sources/WenshuApp/Core/Chat/ChatSessionStore.swift`:
   - `summarizeIfNeeded(sessionId: String, lastN: Int = 10, threshold: Int = 20) async throws`
   - When `loadMessages(sessionId).count > threshold` → trigger summary.
   - Take the first `count - lastN` messages → call `MiniMaxVerifier.chat(`summarize the following chat: [messages] -> 200-word summary`)`.
   - Write to `chat_summaries` (overwrite) + delete the old messages (`DELETE FROM chat_messages WHERE id IN (...)`).
2. `ChatViewModel.buildContextForLLM() async throws -> String`:
   - `loadSummary(sessionId)` + last 10 messages.
   - Assemble: `summary + "\n\n---\n\nRecent conversation:\n" + last10messages`.
   - Return the `String` for `WenshuConductor.handle` to feed into the LLM.
3. Update `WenshuConductor.handle`: when calling the LLM, use `buildContextForLLM()` as the prompt prefix instead of feeding `userMessage` alone.
4. `ChatViewModel.send()` triggers `summarizeIfNeeded` asynchronously (does not block the main `send` flow).

## Acceptance

- [ ] `ChatSessionStore.summarizeIfNeeded` implemented and verified
- [ ] Trigger condition: `messages.count > 20`
- [ ] LLM is fed via `buildContextForLLM()` assembly
- [ ] UI still renders every message (no UI-layer deletion)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] New test: `testSummarizeIfNeeded` (construct 25 messages → trigger → summary saved + old messages deleted)

## Out of scope

- `ChatView` UI rendering (sees every message)
- `KanbanStore`
- `WenshuConductor` dispatch logic (only changes the LLM prompt source)

## References

- Depends on: ticket 02 + 03
- Required by: ticket 06 (`ChatViewModel` integrates `buildContextForLLM`)
