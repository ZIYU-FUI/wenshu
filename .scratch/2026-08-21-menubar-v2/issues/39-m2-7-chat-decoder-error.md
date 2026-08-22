# 39 — MiniMax M2.7 chat error root cause (`DecodingError` "data corrupted")

**What to build:**
|Fix the error after switching to MiniMax M2.7 and sending a question: `Error: Operation could not be completed. (WenshuApp.MiniMaxError error 2.) Error: Could not read data because the data was lost.`

**Spec truth (Q63 verify-before-claim, must come first):**

**Step 1 — NSLog trace truth** (commit `098a5cebe fix(wenshu): v0.21 ticket 39 step 1 NSLog trace truth`, Q63 verify-before-claim):
- `MiniMaxVerifier.send()` adds 3 NSLog lines (request / response body 500 chars / decoder error)
- Run the real `.app`, switch to MiniMax M2.7, send "which model are you using", capture stderr truth
- Root cause locked (trace line):
  - M3 response: `content: [{"text":"I am MiniMax-M3, developed by MiniMax.","type":"text"}]` → decode OK
  - M2.7 response: `content: [{"thinking":"The user is asking which model I'm currently using...","signature":"ebb72a2c...","type":"thinking"}, {"text":"\nI'm currently using the **MiniMax-M2.7** model...","type":"te..."]` → `DecodingError.keyNotFound: Key 'text' not found in keyed decoding container. Path: content[0]`
- Root cause = M2.7 protocol returns chain-of-thought thinking block at `content[0]` (MiniMax thinking paradigm); current `MiniMaxContent.text` is required → `JSONDecoder` throws

**Step 2 — Fix** (Q57 ticket chain, single commit):
- Choose the fix direction based on NSLog truth (Q34 round-2 grill ruling):
  - Option A: `MiniMaxResponse` adds nullable fields + multi-content-block support (`content: [MiniMaxBlock]` union `text` / `thinking` / `tool_use`) — most robust
  - Option B: Decoder goes permissive (manual parse with `JSONSerialization`, tolerant of all unknown fields) — moderately robust
  - Option C: M2.7 temporarily falls back to M3 — not elegant, not recommended
- `ChatViewModel.send` catches `DecodingError` as a safety net → show Chinese error "Model <m> returned an unsupported data format" (Q36 `ChatMessage.source = .error`)

**Step 3 — domain-modeling** (commit 3, Q57):
- Add `MiniMaxResponseShape` domain word to `CONTEXT.md`
- Root-cause chain + fix paradigm + future model protocol extension approach

**Out of scope (Q20):**
- `Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift` `init` / Keychain truth paradigm (Q43)
- `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` `handle` model parameter (ticket 38)
- `Sources/WenshuApp/Views/Chat/ChatView.swift` `ChatViewModel.send` `currentModel` pass (ticket 38)
- ticket 34 + 35a + 35b + 36 + 37 + 38 committed chain untouched

**Dependencies:**
- ticket 38 (model switching actually wired) — committed, reused
- ticket 34 (real tokens) — committed, reused
- ticket 35b (reasoning effort picker) — wiring outside this ticket's scope (ticket 35c outstanding)

**Q47 + Q51 + Q20 + Q63 locks:**
- Q47 lock implementation method = Swift `Codable` + Apple `URLSession`, don't switch implementations
- Q51 parents untouched = `MiniMaxVerifier.swift` + `WenshuConductor.swift` + `ChatViewModel` don't change main structure
- Q20 untouched = ticket 38 model switching wire + `ProviderKeychain` Keychain paradigm untouched
- Q63 verify-before-claim = NSLog truth check required before impl, no guess-based fix

**Apple HIG references:**
- https://developer.apple.com/documentation/foundation/jsondecoder
- https://developer.apple.com/documentation/foundation/codable
- minimax cn `/anthropic /v1/messages` API doc (Anthropic compatible)

**References:**
- history: ticket 38 `fix(wenshu): v0.21 ticket 38 model switching actually wired`
- history: ticket 34 `fix(wenshu): v0.21 ticket 34 context usage real tokens from LLM API`
- backlog 19 done commit `35ff3b4ab docs(wenshu): v0.21 backlog 18 + 19 done`
- branch: `feature/agentan-bottom-toolbar-in-child` (Q53 ticket 10 onward, continued)
