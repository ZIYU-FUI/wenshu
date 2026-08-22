# 40 — Context usage UI actually wired to LLM API usage (chat-zone bottom-bar red box 2)

**What to build:**
Fix the bug where the chat-zone bottom-bar right-side context usage UI always shows = 0 / 131.1k.
The current UI `Text` reads `ChatZoneView`'s own `@State contextUsed: Int = 0` (independent state),
but `ChatViewModel.recomputeContextUsed()` accumulates `ChatMessage.tokens` and updates `ChatViewModel.contextUsed`
— the two state chains are disconnected; 老板's UI sees forever = 0.

**Boss feedback verbatim (2026-08-22 16:10):**
- "Switching + sending questions already works" (= ticket 39 truth done)
- "But is the right-side context usage implemented?" (= context usage UI not wired)

**NSLog truth (Q63 verify-before-claim):**
- `[wenshu.chat] response status=200 body=...usage:{"input_tokens":41,"output_tokens":30,...}`
- `replyTokens = 71` written into `ChatMessage.tokens` ✅
- `ChatViewModel.recomputeContextUsed()` = 71 ✅
- `ChatZoneView.@State contextUsed = 0` ❌ (not bound to `ChatViewModel.contextUsed`)

**Root cause (Q3 audit gate honest disclosure):**
- `ChatZoneView` (`App.swift` L1117) `@State private var contextUsed: Int = 0` independent state
- `ChatViewModel.contextUsed` is an `Observable` property
- The two states have no binding / bridge
- Q47 SwiftUI `@Observable` paradigm requires `Observable` properties to auto-propagate,
  but `ChatZoneView` doesn't hold a `ChatViewModel` instance = can't receive updates

**Spec truth (Q34 round-1 grill ruling):**

**Step 1 — NSLog trace** (commit 1, Q63 verify-before-claim):
- `[wenshu.context] sum tokens after send: N` (print after `ChatViewModel.recomputeContextUsed()`)
- `[wenshu.context] ChatZoneView.@State contextUsed: N` (print in `ChatZoneView.onAppear` + `onChange(of: vm.messages.count)`)
- Run the real `.app`, send a question, capture stderr truth, confirm `ChatViewModel.contextUsed` accumulates ✅, `ChatZoneView.@State` never changes ❌

**Step 2 — Fix** (Q57 ticket chain, single commit):
- `ChatZoneView` holds its own `ChatViewModel` instance (`@State private var vm = ChatViewModel(...)`)
- `ChatView.init` adds an overload: `init(conductor:store:sessionId:vm: ChatViewModel? = nil)` — if `vm` is passed, use it
- `ChatZoneView` passes its own `vm` instance to `ChatView` (shared `Observable` instance)
- `ChatZoneView` bottom toolbar reads `vm.contextUsed` (Apple `@Observable` auto-propagate, no more independent `@State contextUsed`)
- `contextMax = ChatViewModel.contextMax` (`vm.contextMax`, no more hard-coded 131072)
- Q20 untouched: `ChatViewModel.send()` body / `.recomputeContextUsed()` impl / ticket 38 wire
- Q51 parents untouched: `ZoneModule` `.aiChat` case body untouched; `ChatZoneView` body `VStack` structure untouched
- Q47 lock: SwiftUI `@Observable` + Apple `@State` + `Observable` instance sharing, don't switch framework

**Step 3 — domain-modeling** (commit 2, Q57):
- Add `ChatZoneContextBinding` domain word to `CONTEXT.md`
- Root-cause chain + fix paradigm + Q51 sub-component override pattern (shared `vm` injection)

**Out of scope (Q20):**
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatViewModel.send()` / `.recomputeContextUsed()` impl (ticket 38 wire untouched)
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatView` body structure (Q47 locked)
- `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` `handle` truth (ticket 38)
- `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` `send` truth (ticket 39 union decode)
- ticket 34 + 35a + 35b + 36 + 37 + 38 committed chain untouched

**Dependencies:**
- ticket 34 (real tokens from LLM API) — committed, reused
- ticket 38 (model switching wire) — committed, reused `ChatViewModel.send` real call
- ticket 39 (union decode + thinking footnote) — committed, real-value path for `ChatMessage.tokens`

**Q47 + Q51 + Q20 + Q63 locks:**
- Q47 lock implementation method = SwiftUI `@Observable` instance sharing + `@State` holding + Apple `@Environment` not introduced
- Q51 parents untouched = `ZoneModule` `.aiChat` case body + `ChatZoneView` `VStack` structure untouched
- Q20 untouched = `ChatViewModel.send()` body + `ChatView` body + ticket 38 wire untouched
- Q63 verify-before-claim = NSLog truth check required before impl, no guess-based fix

**Apple HIG references:**
- https://developer.apple.com/documentation/swiftui/state
- https://developer.apple.com/documentation/swiftui/observable
- Apple SwiftUI `Observable` instance-sharing paradigm (same as Pages / Numbers)

**References:**
- history: ticket 39 `fix(wenshu): v0.21 ticket 39 step 2 MiniMaxBlock union decode + thinking footnote`
- history: ticket 38 `fix(wenshu): v0.21 ticket 38 model switching actually wired`
- history: ticket 34 `fix(wenshu): v0.21 ticket 34 context usage real tokens from LLM API`
- branch: `feature/agentan-bottom-toolbar-in-child` (Q53 ticket 10 onward, continued)
