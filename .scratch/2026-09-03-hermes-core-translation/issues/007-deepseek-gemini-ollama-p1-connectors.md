# 007: DeepSeek connector (P1, Anthropic-compatible) + Gemini native connector (P1) + Ollama connector (P1)

**What to build:** Add the three P1 connector profiles. DeepSeek reuses the Anthropic-compatible protocol (= same wire format as minimax from issue 001, just different endpoint). Gemini requires its native wire format (port of `agent/gemini_native_adapter.py` 1,021 LOC + `gemini_schema.py`). Ollama reuses the OpenAI-compatible protocol from issue 005 (= Ollama exposes an OpenAI-compatible endpoint on localhost). All three are P1 (boss拍 = ship them before v1 GA but after the P0 batch ships).

**Blocked by:** 004 (Anthropic connector for DeepSeek reuse), 005 (OpenAI connector for Ollama reuse), 002 (cache markers for Gemini thinking)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/gemini_native_adapter.py` | 1,021 | Full port = Gemini native wire format |
| `agent/gemini_schema.py` | ~500 | Full port = Gemini schema definitions |
| (DeepSeek reuses Anthropic-compatible path) | — | No new port needed; just add connector profile struct |
| (Ollama reuses OpenAI-compatible path) | — | No new port needed; just add connector profile struct |

## UI-affordance mapping (per spec §6.4)

All translated products in this ticket are 🟦 **underwater** (the connector structs are 🟦, the Settings → LLM Connector pane UI rows are 🟥 but built in ticket 006).

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| DeepSeekConnector | (engine); UI row = ticket 006 | 🟦 | wrapper around Anthropic-compatible; no new wire format |
| GeminiNativeConnector | (engine); UI row = ticket 006 | 🟦 | new wire format but logic = engine |
| OllamaConnector | (engine); UI row = ticket 006 | 🟦 | wrapper around OpenAI-compatible; no new wire format |

**3-question check** (per spec §6.4): the 3 connectors are called by `LLMConnector.send()` based on user-selected profile. User signal = LLM responses stream to chat. The connector structs do not need their own UI affordances; profile rows are reused from ticket 006's `ConnectorProfileRow` component.

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Connector/DeepSeekConnector.swift` exists (= thin wrapper around AnthropicConnector with DeepSeek endpoint URL)
- [ ] `Sources/WenshuApp/Core/Agent/Connector/GeminiNativeConnector.swift` exists (= new wire format, NOT reuse of any existing connector)
- [ ] `Sources/WenshuApp/Core/Agent/Connector/OllamaConnector.swift` exists (= thin wrapper around OpenAIConnector with localhost endpoint URL)
- [ ] Settings → LLM Connector pane: 3 new profile rows visible (UI wiring = reuse issue 006's ConnectorProfileRow component)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for DeepSeek / Gemini / Ollama request payload shapes
- [ ] X e2e dual-track (deferred — not required for ticket 007 per spec §6.2 rule "every 5 tickets"; rolled into batch boundary with ticket 010)

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers (only Gemini needs real porting; DeepSeek + Ollama are thin wrappers)
- [ ] DeepSeek + Ollama = no new port code; only connector profile struct + endpoint URL config
- [ ] Gemini native = port `gemini_native_adapter.py` + `gemini_schema.py`

## Estimated LOC

~2,500 Swift LOC (Gemini = ~2,000; DeepSeek + Ollama connector structs + Settings UI = ~500).

## Commit format

`feat(wenshu): v0.35 -- DeepSeek + Gemini + Ollama connectors (P1) (= ticket 007 of 11)`