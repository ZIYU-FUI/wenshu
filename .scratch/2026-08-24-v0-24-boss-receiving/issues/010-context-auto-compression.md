# Ticket 015.010 — Auto context compression (invisible to user)

Boss 2026-08-25 OOB: '真实过程中的上下文压缩, 等用户无感知' + '我看现在 hermes
重新打开 APP 上下文内容也还在'.

## 现状
- `vm.contextUsed` accumulates unbounded (= sum of all agent message tokens).
- When contextUsed > contextMax (= 1M), LLM API rejects input.
- No auto-summarization, no truncation.
- User perception: chat history visible until LLM errors (= broken state).

## Hermes pattern (research from `agent/context_compressor.py`)
- Self-contained class with OpenAI client for summarization.
- Auto-summarize middle turns when context > limit (= use auxiliary cheap model).
- Protect head + tail context (= recent N turns + system prompt + recent user input).
- Token-budget tail protection (dynamic, not fixed message count).
- Tool output pruning before LLM summarization (cheap pre-pass).
- Iterative summary updates (= preserves info across multiple compactions).
- User sees only summary card 'Compressed: 30 → 12 messages' (= invisible).

## Fix plan
- New file: `Sources/WenshuApp/Core/Chat/ContextCompressor.swift`
- `actor ContextCompressor`:
  - `func maybeCompress(messages: [ChatMessage], maxTokens: Int, model: String) async -> [ChatMessage]`
  - Triggers when `messages.sumTokens > maxTokens * 0.8` (= 80% threshold).
  - Strategy: keep first 2 (system + first user) + recent N (= tail protection)
    + summarize middle turns via LLM call (= reuse WenshuVerifier + cheap model).
  - Insert summary card (= new ChatMessage with role=.system, content='[Earlier
    conversation summarized: X → Y messages]').
- Trigger after each `vm.send()` (= check before recomputeContextUsed).

## Per ticket 015.010 scope
- Compression trigger threshold: 80% of contextMax.
- Compression strategy: head + tail protection with middle summarization.
- Reuse WenshuVerifier for LLM call (= no new LLM client).
- Summary card inserted as new ChatMessage (visible in UI as marker).

## Out of scope
- Custom compression ratio (= fixed 80% threshold for v0.24).
- Multi-tier compression (= head + middle + tail tiers).
- Compression retry on LLM error (= single-pass for v0.24).
- Compression audit log (= separate ticket if boss拍 need).