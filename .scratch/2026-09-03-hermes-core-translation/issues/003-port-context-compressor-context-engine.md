# 003: Port context_compressor + conversation_compression + context_engine

**What to build:** Port the context compression subsystem. `agent/context_compressor.py` (3,082 LOC) is the token-budget aware compressor that decides when to compress and what to keep. `agent/conversation_compression.py` (1,367 LOC) handles long-conversation compaction (manual + auto triggers). `agent/context_engine.py` (924 LOC) is the aggregator layer (world / character / chapter / foreshadow references). After this ticket, wenshu can hold long-conversation sessions without exceeding the LLM context window.

**Blocked by:** 001 (LLMConnector protocol + agent loop must exist so compressor can run inside the loop)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/context_compressor.py` | 3,082 | Full port = token-budget aware compressor |
| `agent/conversation_compression.py` | 1,367 | Full port = manual + auto compaction |
| `agent/context_engine.py` | 924 | Full port = context aggregator |
| `agent/context_breakdown.py` | ~300 | Full port = token count breakdown |
| `agent/context_references.py` | ~500 | Full port = cross-turn reference resolver |

## UI-affordance mapping (per spec §6.4)

This ticket's translated products and their UI landing:

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| ContextCompressor | ChatView top-bar compression status | 🟨 | user needs to see "context compressed 35%" |
| ConversationCompression (manual) | ChatView tool menu + button | 🟥 | user must manually trigger "compress and continue" |
| ContextEngine | (underwater) | 🟦 | aggregator, no direct UI |

**3-question check** (per spec §6.4):

1. **Who triggers it?** ContextCompressor triggers automatically inside `ConversationLoop` when token budget threshold is hit. ConversationCompression manual triggers when user clicks ChatView's compress button.
2. **What signal does the user see?** Top-bar pill shows "📦 compressed 35% (12,400 → 8,060 tokens)" with a small progress indicator. When user clicks compress, an animated progress indicator appears; on completion a confirmation toast.
3. **UI affordances added**: ChatView top-bar pill component (= 🟨); ChatView tool menu + "Compress and continue" button (= 🟥).

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Conversation/ContextCompressor.swift` ports `context_compressor.py`
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/ConversationCompression.swift` ports `conversation_compression.py`
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/ContextEngine.swift` ports `context_engine.py`
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/ContextBreakdown.swift` + `ContextReferences.swift` port their Python counterparts
- [ ] Compressor integrates with ConversationLoop.swift from issue 001 (= invoked when token budget threshold is hit)
- [ ] Manual compaction API exposed (= user-triggered from chat UI)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for compressor entry/exit, conversation rolling summary, context engine aggregation
- [ ] Long-conversation e2e: 100-turn conversation; verify tokens never exceed budget; verify summary quality (heuristic check)

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] Compressor is a `actor` (= Swift Concurrency isolation; hermes uses asyncio locks here)
- [ ] Token budget = configurable in Settings → LLM Connector pane per-profile (not global). Default = connector's `ModelMetadata.contextWindow - 8192` (= leave room for output)

## Estimated LOC

~4,000 Swift LOC.

## Commit format

`feat(wenshu): v0.35 -- port context compressor + conversation compression + context engine (= ticket 003 of 11)`