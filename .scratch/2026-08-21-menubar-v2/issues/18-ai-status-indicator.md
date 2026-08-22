# 18 — AI reply status indicator (Apple `ProgressView` + `Text` + SF Symbol `symbolEffect` pulse)

Depends on: ticket 13 + 14 (`ChatBottomBar` 18 PT inset) + ticket 22 + 23 (`.transition` + `.animation` Apple default) + ticket 28 (`Button` paradigm) + ticket 29 (revert bottom padding)

**What to build:**
Add a status indicator to `ChatView` `ChatBottomBar`:
- Display only when `isResponding == true`
- `HStack`: SF Symbol `brain` + `.symbolEffect(.pulse, options: .repeating)` + `Text("AI thinking…")` + `ProgressView` circular indeterminate
- Whole `HStack` `.transition(.opacity)` + `.animation(.default, value: chatViewModel.isResponding)`

**Why:**
老板 2026-08-22 06:18 ruled "when chatting, while AI is replying, I can't see any status" + "reference hermes, implement dynamic display" + 2026-08-22 ruled to advance "A" = Option A = Apple HIG paradigm

**Acceptance:**
- 老板 macOS verification: send a message → during AI reply, status indicator appears / AI reply finishes → disappears
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
- Dual-axis code-review verbatim into commit body
