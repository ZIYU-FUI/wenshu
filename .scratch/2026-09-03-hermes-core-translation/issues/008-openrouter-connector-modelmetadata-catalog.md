# 008: OpenRouter connector (P2) + ModelMetadata catalog

**What to build:** Add the OpenRouter connector (P2 — defer-acceptable to v1.x). OpenRouter exposes an OpenAI-compatible endpoint; the connector is a thin wrapper around `OpenAIConnector` (from issue 005) with OpenRouter's endpoint URL. Plus port `agent/model_metadata.py` (2,434 LOC) into `Sources/WenshuApp/Core/Agent/Connector/ModelMetadata.swift` — the per-provider model catalog (capabilities, context window, pricing awareness). Pricing awareness is BYOK-aware: wenshu shows estimated USD cost based on connector's reported pricing, but does NOT enforce or bill.

**Blocked by:** 005 (OpenAI connector)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/model_metadata.py` | 2,434 | Full port = per-provider model catalog |

Plus NEW wenshu-side authoring of `OpenRouterConnector.swift` (= thin wrapper around OpenAIConnector).

## UI-affordance mapping (per spec §6.4)

All translated products in this ticket are 🟦 **underwater** (the connector struct is 🟦; the Settings → LLM Connector pane UI rows are 🟥 but built in ticket 006).

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| OpenRouterConnector | (engine); UI row = ticket 006 | 🟦 | wrapper around OpenAI-compatible |
| ModelMetadata | (engine); per-model display = ticket 006 profile row dropdown | 🟦 | catalog = engine data |

**3-question check** (per spec §6.4): OpenRouter connector + ModelMetadata catalog are engine-side. Model list display in profile row dropdown = ticket 006.

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Connector/ModelMetadata.swift` ports `model_metadata.py` 1:1 with `// SWIFT-PORT:` markers
- [ ] `Sources/WenshuApp/Core/Agent/Connector/OpenRouterConnector.swift` exists (= thin wrapper around OpenAIConnector with OpenRouter endpoint URL)
- [ ] ModelMetadata covers all 7 connector profiles' models: claude-sonnet-4.5 / claude-opus-4 / gpt-5 / gpt-4.1 / MiniMax-M3 / MiniMax-M2.7 / deepseek-chat / deepseek-reasoner / gemini-2.5-pro / gemini-2.5-flash / ollama-llama3 / ollama-mistral / openrouter/* (= auto-discovery)
- [ ] Settings → LLM Connector pane: OpenRouter profile row visible (UI wiring = reuse issue 006's component)
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for ModelMetadata entry/exit per model
- [ ] AGENTS.md §11 product-positioning rule audit: pricing-awareness code does NOT add metering / billing / quota tracking. Pricing is display-only.

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] §11 product-positioning rule: pricing info is BYOK display only; wenshu never enforces or bills
- [ ] No third-party SDK for model metadata (= port is direct; no LiteLLM, no models.dev client)

## Estimated LOC

~1,200 Swift LOC (ModelMetadata ~1,000 + OpenRouter connector struct + Settings UI ~200).

## Commit format

`feat(wenshu): v0.35 -- OpenRouter connector (P2) + ModelMetadata catalog (= ticket 008 of 11)`