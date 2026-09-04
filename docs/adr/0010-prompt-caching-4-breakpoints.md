# ADR-0010: PromptCaching 4 breakpoints + SystemPrompt byte-stable tier (§11.3 cache-stable invariant)

> Status: accepted
> Date: 2026-09-03
> Decision-maker(s): 老板 (via spec §11.3 + §3.6 acceptance, ratified 2026-09-03 OOB)

## Context

Hermes Python's prompt caching layer (`agent/prompt_caching.py` 119 LOC) and system prompt builder (`agent/system_prompt.py` 536 LOC) implement a "cache-stable invariant": the system prompt is byte-stable for the lifetime of a conversation, and cache markers are placed at exactly 4 breakpoints (= system message + last 3 non-system messages). Without byte stability, prompt caching returns zero hits (= wasted tokens + latency). Without the 4-breakpoint rule, prompt caching either over-marks (= wasted cache space) or under-marks (= cache misses).

The v0.35 hermes-core-translation project must preserve this invariant. The ticket 002 acceptance criteria explicitly mandate: "AGENTS.md §11.3 declares prompt-caching invariant: `cache_control: ephemeral` marker on system + last 3 non-system messages. System prompt byte-stable for life of a conversation."

Three concrete questions force the decision:

1. **Where do cache markers live?** Top-level `LLMMessage` field, or inside text block (= `LLMBlock.textWithCacheControl`)?
2. **How is byte stability enforced?** String equality, hash equality, or canonical-form equality?
3. **What's the SystemPrompt tier structure?** Tier-1 identity + Tier-2 capabilities + Tier-3 pollution-defense + Tier-4 deterministic postfix?

## Decision

Adopt the **PromptCaching 4 breakpoints** + **SystemPrompt byte-stable tier** architecture as the canonical prompt caching pattern for wenshu. Three constraints flowing from this decision:

1. **Top-level cacheControl field**: `cacheControl: CacheControl?` lives on `LLMMessage` (= top-level), NOT inside `LLMBlock.text`. Rationale: Anthropic native cache markers ride on the message itself, not on individual text blocks. Putting them inside blocks would force every Anthropic-native tool_use / tool_result block to also carry the marker (= wrong). Apple Codable + Swift property observer pattern enforces the rule at compile time.

2. **Byte-stable canonical form**: SystemPrompt generation uses a deterministic tier order with no random IDs / no Date() timestamps / no locale-dependent formatting (= no `DateFormatter` without fixed locale). Same input → byte-identical output. Test invariant: `systemPrompt(input) == systemPrompt(input)` across 100 iterations.

3. **4 breakpoints exactly**: PromptCaching places markers on `messages[0]` if `.system` + last 3 non-system messages. Marker shape: `{"type": "ephemeral"}` + optional `{"ttl": "1h"}` (= 1-hour TTL for max cache reuse in long conversations). NOT 1 (= cache miss). NOT all ( over-marker).

Five concrete architectural commitments:

- **SystemPrompt tier structure**: Tier-1 = identity (boss拍 1-2 sentences) + Tier-2 = capabilities list (15 capabilities from WenshuAgentIdentity) + Tier-3 = pollution-defense (12 forbidden tokens from `WenshuAgentIdentity.forbiddenTokens`) + Tier-4 = deterministic postfix (= wenshu version + session ID hash, no Date()).
- **Cache marker canonical shape**: `cacheControl: .ephemeral` (= default, no TTL) + `cacheControl: .ephemeralTTL1h` (= 1-hour TTL).
- **Wire format per connector**:
  - **AnthropicConnector**: `content` array union type; cache_control nested in content block (per Anthropic wire format). 4 breakpoints map 1:1 to 4 blocks.
  - **OpenAIConnector**: NO prompt caching (= OpenAI doesn't support cache_control markers).
  - **OpenAICompatibleConnector (= DeepSeek / Ollama / OpenRouter)**: depends on provider; minimax cn = Anthropic-compatible.
  - **GeminiNativeConnector**: `cachedContent` resource (= Google GenAI native caching mechanism, different wire format).

## Consequences

**Easier**:
- Cache hit rate = high (= 4 breakpoints cover system + last 3 messages, typical conversation turnover)
- Token cost = reduced (Anthropic = 25% markup on miss, 90% discount on hit)
- Latency = reduced (cached system prompt = ~10ms vs ~500ms)
- Test stability (= byte-stable SystemPrompt = golden file tests work)

**Harder**:
- Wire format per connector ≠ uniform (= Anthropic nested, OpenAI absent, Gemini resource)
- Cache invalidation risk (= if system prompt changes between requests, cache miss for 5 min TTL)
- Test determinism (= must mock Date() to ensure byte-stable across test runs)
- Cross-provider UX (= minimax cn Anthropic-compatible = works; OpenRouter Gemini via Anthropic-compatible endpoint = doesn't work)

**Locked in**:
- 4 breakpoints exact (= cannot add/remove without spec update + 老板拍)
- Top-level cacheControl field (= cannot move into blocks without breaking all 7 connectors)
- Byte-stable SystemPrompt (= cannot add Date() / locale-dependent formatting)
- Anthropic 25% / 90% pricing as the reference model

## Alternatives considered

1. **1 breakpoint (= system only)**: Rejected. Cache hit rate too low (= after first user message, cache is invalidated for rest of conversation). Boss 9/3 OOB "cache hit must be high".
2. **All messages marked (= over-cache)**: Rejected. Wastes cache space + Anthropic charges per cache write (= 25% markup).
3. **Hash-stable SystemPrompt (= use SHA-256 of canonical form as marker)**: Rejected. Adds complexity; byte-stable is sufficient if tier structure is deterministic.
4. **Per-provider cache (Anthropic-only)**: Accepted as initial scope. Other connectors (`OpenAIConnector` etc.) ship without cache; future provider-specific cache wiring as separate ticket.

## Cross-references

- AGENTS.md §11.3 cache-stable invariant
- spec.md §3.6 + §6.4 + §7.4
- ticket 002 sub-step 1 (= PromptCaching port) + sub-step 2 (= SystemPrompt port) + sub-step 3 (= wire into LLMConnector.send) + sub-step 4 (= e2e byte-stability test)
- ADR-0008 (7-connector BYOK — only Anthropic + Gemini + minimax-cn support caching; OpenAI / DeepSeek / Ollama / OpenRouter = no cache)
- ADR-0009 (wenshu-side wins — PromptCaching is hermes port but SystemPrompt layer uses existing WenshuAgentIdentity)