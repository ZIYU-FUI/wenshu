# 005: Port OpenAI-compatible auxiliary client + OpenAI connector (P0)

**What to build:** Port the OpenAI-compatible path of `agent/auxiliary_client.py` (7,469 LOC; Anthropic path was ported as part of the LLMConnector protocol in issue 001 — the OpenAI-compatible path remains). Author `OpenAIConnector` that conforms to `LLMConnector` protocol for OpenAI (P0). Includes the OpenAI wire format (chat.completions API, tool_calls, function calling, streaming).

**Blocked by:** 001 (LLMConnector protocol)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/auxiliary_client.py` (OpenAI-compatible path) | ~3,000 of 7,469 | Full port = OpenAI-compatible request/response marshaling |
| `agent/chat_completion_helpers.py` (OpenAI path) | ~1,500 of 3,103 | OpenAI-specific marshaling only |

## UI-affordance mapping (per spec §6.4)

All translated products in this ticket are 🟦 **underwater** (the connector struct is 🟦, the Settings → LLM Connector pane UI is 🟥 but lands in ticket 006).

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| OpenAIConnector | (engine); user-facing UI = ticket 006's Settings → LLM Connector | 🟦 | connector logic = engine; profile row UI = ticket 006 |

**3-question check** (per spec §6.4): OpenAI connector is called by `LLMConnector.send()` when the active profile is OpenAI. User signal = LLM responses stream to chat. The connector struct does not need its own UI affordance; the profile row in Settings → LLM Connector is built in ticket 006.

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Connector/OpenAIConnector.swift` exists, conforms to `LLMConnector` protocol
- [ ] Wire format handles: chat.completions API, tool_calls array, function calling, SSE streaming
- [ ] Token metering: response includes `usage.prompt_tokens` + `usage.completion_tokens` (= reports back to `CreditsTracker` from gray-thin-port)
- [ ] Tool use round-trip works (OpenAI tool_calls → wenshu tool run → tool message → LLM continues)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for request payload shape
- [ ] X e2e dual-track: same prompt against hermes Python and wenshu Swift — identical tool-call sequence + identical final text
- [ ] Settings → LLM Connector pane: OpenAI profile row added (UI wiring deferred to issue 006)

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] OpenAI SDK alternative: NOT used. Port is direct wire format (= avoids third-party SDK lock-in). URLSession + mattt/EventSource.
- [ ] DeepSeek + Ollama + OpenRouter connectors come in later tickets (= all reuse this OpenAI-compatible base)

## Estimated LOC

~3,000 Swift LOC (7,469 / 2.5 = ~3,000; OpenAI path is ~40% of auxiliary_client).

## Commit format

`feat(wenshu): v0.35 -- OpenAI-compatible client + OpenAI connector (P0) (= ticket 005 of 11)`