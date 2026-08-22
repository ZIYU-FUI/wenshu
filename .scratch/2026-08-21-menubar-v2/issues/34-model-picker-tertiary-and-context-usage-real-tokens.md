# 34 — Model picker tertiary color + Context usage real tokens

**What to build:**
- Fix 1: `Sources/WenshuApp/App.swift` L1134 model picker `.foregroundStyle(.secondary)` → `.tertiary` (Apple HIG gray)
- Fix 2: Context usage real tokens from LLM API:
  - `StoredChatMessage` add `tokens: Int? = nil`
  - `ChatMessage` add `tokens: Int? = nil`
  - `MiniMaxResponse` add `usage: MiniMaxUsage?` + new `MiniMaxUsage` struct
  - `WenshuConductor.handle()` return `(String, Int)` tuple
  - `ChatViewModel.send()` fill `tokens` field from real LLM response
  - `ChatViewModel.recomputeContextUsed()` = `messages.compactMap { $0.tokens }.reduce(0, +)`

**Why:**
Boss 2026-08-22 ruled 3 items: "do 19" + "white is too bright, gray text would be better" + "are all our current texts using Apple's text styles" = ticket 19 backlog fix + model picker color fix + Apple text style confirmation

**Acceptance:**
- Boss macOS verify: model picker gray + context usage real tokens accumulated
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
