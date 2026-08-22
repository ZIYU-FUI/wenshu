# 03 — AgentProtocol.handle: real synthesis (drop the echo)

**What to build:**
老板 2026-08-21 inspected v0.20 ticket 01 ChatView and said "there are replies, but I don't know if they're real." Root cause: `AgentProtocol.handleMessageSend` L188-190 echoes the first 50 characters of the user message as the agent reply instead of calling a real LLM. Remove the echo; instead call `MiniMaxVerifier.send` to send the real user message to `MiniMax-M3` and write back `response.content.first.text`. On LLM failure throw `AgentRuntimeError.llmFailed`; `ChatViewModel` falls back to `verifier.ping` (path already exists).

**Blocked by:** ticket 01 (`ChatMessage.source` is in).

**Status:** ready-for-agent

## Fix specification

1. In `Sources/WenshuApp/Core/Agent/AgentProtocol.swift`, delete the L188-190 echo in `handleMessageSend`:
   ```swift
   // DELETE
   let ack = AgentMessage(role: .agent, content: "received from \(fromAgent): \(message.content.prefix(50))")
   task.messages.append(ack)
   ```
2. Replace it with a real LLM call via `MiniMaxVerifier.send`:
   - Inject `WenshuAppDelegate.sharedVerifier` into `AgentProtocol` (pass at init).
   - `handleMessageSend` takes `message.content` → builds a `MiniMaxRequest` (model: `"MiniMax-M3"`, `max_tokens: 1024`, `messages: [MiniMaxMessage(role: "user", content)]`).
   - Call `verifier.send(request)`.
   - On success → `AgentMessage(role: .agent, content: response.content.first.text)`.
   - On failure → throw `AgentRuntimeError.llmFailed` (add the case to `AgentRuntime.swift`).
3. `ChatViewModel.send()` already has a fallback path: `delegateTask` catch → `verifier.ping` (L75-80). But `ping` only sends the literal string `"ping"`. Update it to send the user's original text and retry once: replace the L77 call `verifier.ping()` with `verifier.chat(text)`.
4. Add `public func chat(_ text: String) async throws -> MiniMaxResponse` to `MiniMaxVerifier` (same shape as `ping`, but `messages = [MiniMaxMessage(role: "user", content: text)]` and `max_tokens 1024`).

## Acceptance

- [ ] `AgentProtocol.handleMessageSend` no longer echoes a hardcoded string
- [ ] Real `MiniMaxVerifier.send` call returns a real LLM reply
- [ ] On LLM failure, throw `AgentRuntimeError.llmFailed`
- [ ] `AgentRuntimeError` gains a new `.llmFailed` case
- [ ] `MiniMaxVerifier` exposes `chat(text:)`
- [ ] `ChatViewModel` fallback path uses `chat(text:)` instead of `ping()`
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: ChatView receives a real LLM reply, not "received from user: ..."

## Out of scope

- A2A protocol `message/send` / `task/get` / `task/list` interfaces (echo removed but the `messageReceived` response is kept)
- `AgentRuntime.delegateTask` call chain
- `MiniMaxVerifier.ping()` (other tickets may still use it)

## References

- Depends on: ticket 01
- Required by: ticket 04 (`WenshuConductor` uses the real LLM synthesis to produce the final reply)
