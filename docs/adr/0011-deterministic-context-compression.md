# ADR-0011: Deterministic context compression (= NO LLM-driven compression)

> Status: accepted
> Date: 2026-09-03
> Decision-maker(s): 老板 (AGENTS.md §11 hard rule + Q1-Q4 implicit, ratified 2026-09-03)

## Context

Hermes Python's context compression layer (`agent/context_compressor.py` 3,082 LOC + `agent/conversation_compression.py` 1,367 LOC) implements a hybrid compression strategy: deterministic truncation as the primary path, but with an LLM-driven summarization escape hatch (= when deterministic truncation would lose too much context, ask an LLM to summarize the discarded middle). The hermes default budget = 30,000 tokens; above 30k, trigger manual or auto compression.

Wenshu's AGENTS.md §11 has a hard rule: "NO external AI platform calls in any code file" + "Stack = Apple HIG (.fcpbundle-style directory, single-process)". The §11 product-positioning rule (= boss 2026-09-03 拍): "wenshu 是写作工具,不是 LLM 平台" + "Wenshu never resells or bundles LLM access; never holds user tokens on its own backend; never charges for token consumption".

Three concrete concerns force the decision:

1. **AGENTS.md §11 hard rule**: No code file calls external AI platform. LLM-driven compression would violate this (= compression calls the LLM API).
2. **Token cost predictability**: LLM-driven compression = 1 extra LLM call per compression (= doubles token cost for long conversations).
3. **Deterministic test stability**: LLM-driven compression = non-deterministic (= tests cannot golden-file the output).

## Decision

Adopt **deterministic context compression only** as the canonical compression strategy for wenshu. NO LLM-driven summarization. Compression = `ContextCompressor` actor with `CharacterBasedTokenEstimator` (= 1 token ≈ 4 chars heuristic) + `Policy { keepRecentTurns, maxTokens, retainSystemAndLastN }` truncation. When user clicks the manual Compress button (`ChatViewCompressionRow`), force aggressive compression via `keepRecentTurns=4` + `maxTokens=1_000` (= threshold artificially low to ensure compression happens).

Three constraints flowing from this decision:

1. **No LLM calls in compression code path**: `ContextCompressor.compressContext()` is pure Swift (= no `await LLMConnector.send()`). The LLM is only called by `ConversationLoop` (= the agent loop), never by the compression layer.

2. **Deterministic policy**: `ContextCompressor.Policy` struct (`keepRecentTurns: Int = 8` / `maxTokens: Int = 30_000` / `retainSystemAndLastN: Int = 3`). Same input + same policy → byte-identical output. Test invariant: 100 iterations → identical `[LLMMessage]`.

3. **Manual trigger only** (= no auto-compression): Compression fires only on user click (= Compress button). NO automatic `every N turns` or `every M tokens` triggers. Rationale: auto-compression can surprise the user (= their context disappeared mid-task); manual trigger is boss-friendly.

Five concrete architectural commitments:

- **CharacterBasedTokenEstimator**: `4 chars = 1 token` heuristic. NOT a real tokenizer (= hermes uses tiktoken for accuracy). Trade-off: 5-10% token count error vs zero external dep.
- **Policy default**: `keepRecentTurns: 8` (= 4 user + 4 assistant = 8 messages, ~16 turns); `maxTokens: 30_000`; `retainSystemAndLastN: 3`.
- **Manual trigger policy** (`manualTrigger`): `keepRecentTurns: 4` + `maxTokens: 1_000` (= aggressive, force compression).
- **No mid-conversation summary block**: When compression discards middle messages, no `[... compressed N messages ...]` placeholder. Discarded = lost (= user knows via "X% compressed" pill).
- **Compression round-trip preserves identity**: `ChatMessage.id` + `timestamp` + `tokens` survive the round-trip via bridge extensions (`ChatRole.toLLMRole` + `LLMMessage.Role.fromLLMRole` + `LLMMessage.firstTextContent`).

## Consequences

**Easier**:
- AGENTS.md §11 hard rule compliance (= no external AI platform calls in compression code)
- Token cost predictability (= no LLM call per compression)
- Deterministic tests (= byte-stable output = golden file tests work)
- LLM cache hit preservation (= cache markers on system + last 3 messages survive compression)
- Boss-friendly UX (= no surprise auto-compression)

**Harder**:
- Compression quality (= LLM summarization can preserve semantic content that truncation drops)
- Long-conversation memory (= after 30k tokens, oldest messages = lost forever; LLM summarization could preserve as bullet points)
- Token count accuracy (= 4-char heuristic ≠ real tokenizer)

**Locked in**:
- No LLM calls in compression path (= cannot add `await LLMConnector.send()` in `ContextCompressor`)
- Manual trigger only (= cannot add `everyNturns: Int` parameter)
- CharacterBasedTokenEstimator heuristic (= cannot replace with real tokenizer without external dep)

## Alternatives considered

1. **LLM-driven summarization** (= hermes default for >30k tokens): Rejected. AGENTS.md §11 hard rule violation + token cost + non-determinism.
2. **Hybrid (= LLM only for >100k tokens, deterministic for <100k)**: Rejected. Same hard rule violation; complexity not justified by use case.
3. **Real tokenizer (= tiktoken or similar Swift port)**: Deferred. External dep + 5-10% accuracy gain not worth current scope.
4. **Auto-compression every N turns**: Rejected. Boss UX surprise risk; manual trigger is sufficient.
5. **Mid-conversation summary placeholder** (`[... N messages compressed ...]`): Rejected. Adds visual noise; user gets the compression pill summary instead.
6. **No compression (= context window grows unbounded)**: Rejected. Most providers have 200k-1M context windows but token cost = linear.

## Cross-references

- AGENTS.md §11 baseline + §11 product-positioning rule
- spec.md §3.6 + §6.4 (UI pill + manual button mapping)
- ticket 003 sub-step 1 (= ContextCompressor) + sub-step 2 (= ConversationCompression) + sub-step 5 (= manualCompress real ChatMessage round-trip)
- ADR-0008 (7-connector BYOK — compression is provider-agnostic, not part of any connector)
- ADR-0009 (wenshu-side wins — ContextCompressor is hermes port but ConversationCompression wraps wenshu `Core/Chat/ChatSessionStore`)
- ADR-0010 (cache-stable invariant — compression must preserve cache markers on system + last 3 messages)