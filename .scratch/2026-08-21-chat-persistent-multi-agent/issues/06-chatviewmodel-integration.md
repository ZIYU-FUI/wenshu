# 06 — ChatViewModel integration + chat session singleton

**What to build:**
老板 2026-08-21 ruled: "users only ever see a single chat session." `ChatViewModel` integrates `ChatSessionStore` + `WenshuConductor`; the single `session_id = "default"` continues forever. `App.swift` instantiates the `sharedChatStore` + `sharedConductor` singletons and passes them into `ChatView.init`.

**Blocked by:** ticket 01 + 02 + 03 + 04 + 05.

**Status:** ready-for-agent

## Fix specification

1. In `Sources/WenshuApp/App.swift`, add to `WenshuAppDelegate`:
   ```swift
   static let sharedChatStore = ChatSessionStore()
   static let sharedConductor: WenshuConductor
   ```
   Initialize `sharedConductor` in `applicationDidFinishLaunching` (pass `sharedRuntime` + `sharedVerifier` + `sharedChatStore` + `kanbanStore`).
2. Add parameters to `ChatViewModel.init`: `store: ChatSessionStore`, `conductor: WenshuConductor`, `sessionId: String = "default"`.
3. In `ChatViewModel.init`, dispatch `Task { await store.loadMessages(sessionId) }` → fill the `messages` array.
4. Update `ChatViewModel.send()`:
   - Call `conductor.handle(userMessage, sessionId)` (no direct `delegateTask`).
   - Take the final reply → append `ChatMessage(source: .wenshu, ...)`.
   - Persist: `store.append(userMsg)` + `store.append(agentMsg)` asynchronously.
   - Call `store.summarizeIfNeeded(sessionId)` asynchronously.
5. Update `App.swift` L554-561 to pass `store` + `conductor` to `ChatView.init`:
   ```swift
   ChatView(
     store: WenshuAppDelegate.sharedChatStore,
     conductor: WenshuAppDelegate.sharedConductor
   )
   ```
6. Remove `ChatViewModel`'s old fields: `runtime` / `verifier` / `agentName` (the conductor wraps them).

## Acceptance

- [ ] `WenshuAppDelegate.sharedChatStore` + `sharedConductor` landed
- [ ] `ChatViewModel` integrates `store` + `conductor`
- [ ] `ChatViewModel.init` loads history asynchronously
- [ ] `ChatViewModel.send` routes through the conductor + persists asynchronously
- [ ] `App.swift` `ChatView.init` passes `store` + `conductor`
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: restart the app and pick up the chat + 文枢 replies for real + long chats don't blow up tokens + multi-agent stays hidden

## Out of scope

- `ChatView` UI (committed as `cf121f77a`; only changes the init signature)
- v0.18 + v0.19 + v0.20 already-committed modules

## References

- Depends on: ticket 01 + 02 + 03 + 04 + 05
- Required by: none (closing ticket)
