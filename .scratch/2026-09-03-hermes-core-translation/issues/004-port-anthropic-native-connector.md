# 004: Port Anthropic native connector (P0)

**What to build:** Port `agent/anthropic_adapter.py` (2,789 LOC) into a Swift `AnthropicConnector` that conforms to `LLMConnector` protocol. This is the second P0 connector (after minimax from issue 001). Anthropic native supports thinking blocks, redacted_thinking, tool_use, 1M context (claude-sonnet-4.5 / claude-opus-4), SSE streaming. Cache_control markers from issue 002 ride on this connector's outgoing requests.

**Blocked by:** 001 (LLMConnector protocol), 002 (cache markers must be applied)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/anthropic_adapter.py` | 2,789 | Full port = Anthropic native wire format (cache_control, content parts, tool_result, redacted_thinking) |
| `agent/chat_completion_helpers.py` (Anthropic path) | ~1,500 of 3,103 | Anthropic-specific marshaling only |

## UI-affordance mapping (per spec §6.4)

All translated products in this ticket are 🟦 **underwater** (the connector struct is 🟦, the Settings → LLM Connector pane UI is 🟥 but lands in ticket 006).

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| AnthropicConnector | (engine); user-facing UI = ticket 006's Settings → LLM Connector | 🟦 | connector logic = engine; profile row UI = ticket 006 |

**3-question check** (per spec §6.4): Anthropic connector is called by `LLMConnector.send()` when the active profile is Anthropic. User signal = LLM responses stream to chat. The connector struct does not need its own UI affordance; the profile row in Settings → LLM Connector is built in ticket 006.

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Connector/AnthropicConnector.swift` exists, conforms to `LLMConnector` protocol
- [ ] Wire format handles: cache_control on tools, content parts, assistant last block, tool_result
- [ ] Wire format handles: thinking blocks, redacted_thinking blocks (= strip cache marker only; preserve content)
- [ ] SSE streaming supported via `mattt/EventSource` (= §11.1 approved P1 lib, already pinned)
- [ ] Tool use round-trip works (= LLM emits tool_use, wenshu runs tool, returns tool_result, LLM continues)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for request payload shape (request = exactly what hermes Python sends for identical input)
- [ ] X e2e dual-track: same prompt against hermes Python and wenshu Swift — identical tool-call sequence + identical final text
- [ ] Settings → LLM Connector pane: Anthropic profile row added (= UI wiring deferred to issue 006, but the connector struct must exist)

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] Anthropic SDK alternative: NOT used. Port is direct wire format (= avoids third-party SDK lock-in). Apple's URLSession handles HTTPS + streaming. SSE via mattt/EventSource.
- [ ] `mattt/EventSource` is already pinned in §11.1 — no new deps
- [ ] Cache_control integration: must come AFTER issue 002's `PromptCaching.applyCacheControl` is applied

## Estimated LOC

~2,100 Swift LOC (Anthropic wire format is dense; minimal Swift idiom savings).

## Commit format

`feat(wenshu): v0.35 -- Anthropic native connector (P0) (= ticket 004 of 11)`