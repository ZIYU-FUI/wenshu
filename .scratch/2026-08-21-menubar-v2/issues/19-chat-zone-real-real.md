# 19 — ChatZoneView bottom-bar 2 red boxes: real values (model picker real list + context usage real tokens)

Depends on: `MiniMaxModelFetcher.fetchLiveModelIds` + `ModelCache` + `Provider.minimaxCn.defaultModels` + `ChatViewModel` existing API

**What to build:**
`ChatZoneView` 2 red boxes — real hard-feature implementation (老板 2026-08-22 06:20 ruled):
1. Model picker `Menu` = real fetchable model list (via `MiniMaxModelFetcher.fetchLiveModelIds` truth + `ModelCache` TTL 3600s)
2. Context usage `Text` + `ProgressView` = real token count (via `MiniMaxResponse.usage` `input_tokens` + `output_tokens` accumulated)
3. `ChatView` / `ChatZoneView` share a single `ChatViewModel` instance (Q51 sub-component override paradigm)

**Why:**
老板 ruled "implement the real functionality of these two red boxes". The current `ChatZoneView` L1110-1113 has `@State` dual-source state + hardcoded `contextMax` = 老板's screenshot shows "0 / 131.1k" forever 0 = user mistakenly thinks nothing is in use. Real hard feature = real fetchable list + real token count.

**Acceptance:**
- 老板 macOS verification: model picker dropdown = real fetchable list + switch model = persists + context usage = real token count
- `swift build` exit 0 + `swift test` exit 0 (old tests compatible)
- Dual-axis code-review report verbatim into commit body
- Q40: no file / log / commit contains 老板's real key
