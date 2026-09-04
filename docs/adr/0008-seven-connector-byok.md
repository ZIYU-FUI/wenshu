# ADR-0008: 7-connector LLM BYOK architecture (no default, user-picks profile)

> Status: accepted
> Date: 2026-09-03
> Decision-maker(s): 老板 (8/27, 9/3 OOB), 1 RULE 1 commit enforce

## Context

Pre-v0.35, wenshu shipped with a single hard-coded `minimax cn` connector (= v0.20-v0.30). Boss 2026-09-03 OOB clarified product positioning: "wenshu 是写作工具,不是 LLM 平台" (= wenshu is a writing tool, not an LLM platform). Early-era minimax cn was justified by 老板's own developer account ("我之前说过 X" = "early we had minimax as our only LLM, because I only bought minimax, but I also said: the LLM config module must be there"). Three concrete concerns forced this decision:

1. **Product positioning**: Wenshu never resells or bundles LLM access; never holds user tokens on its own backend; never charges for token consumption. Any PR that adds metering / billing / quota tracking is out of scope (§11 product-positioning rule).
2. **Customer diversity**: 老板 noted "我们未来面对的客户, 有可能完全不用 hermes" (= our future customer base may have never used hermes) — vendor lock-in to a single provider would create onboarding friction for users on Anthropic / OpenAI / DeepSeek / Ollama / OpenRouter / Gemini / etc.
3. **Hermes precedent**: Hermes itself ships with 7 connector profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax). The boss asked for parity (Q3 of grilling round).

The 7-connector architecture must satisfy three constraints simultaneously: (a) provider-agnostic core (= LLMConnector protocol), (b) no default (= wenshu UI shows no LLM details until user configures), (c) BYOK (= user-supplied API keys stored in Apple Keychain via ProviderKeychain).

## Decision

Adopt the **7-connector BYOK architecture** as the canonical LLM layer pattern for wenshu. One Swift `protocol LLMConnector` (= single canonical interface, boss Q14 拍) with 7 concrete implementations (= `MinimaxConnector` / `AnthropicConnector` / `OpenAIConnector` / `OpenAICompatibleConnector` / `GeminiNativeConnector` / `DeepSeek via OpenAICompatible` / `Ollama via OpenAICompatible` / `OpenRouter via OpenAICompatible`). Each profile = 1 case of the `Provider` enum (= `minimax-cn / anthropic / openai / gemini / deep-seek / ollama / open-router`). User picks profile in Settings → LLM Connector pane (🦊 must-UI). Wenshu ships with the connector layer wired but **every profile is empty until user supplies credentials** (= no default recommendation, no bundled test key).

Constraints flowing from this decision:

1. **Single canonical interface**: All connectors implement `LLMConnector.send(request:) async throws -> LLMResponse`. Boss Q14 "应该单接口" = one protocol, 7 impls.
2. **BYOK only**: API keys stored in Apple Keychain via `ConnectorCredentials` (= thin adapter over `ProviderKeychainStoring`). No bundled test key. No usage telemetry.
3. **Minimax cn compatible**: Default recommendation (= per Q4 branch iii "minimax cn 作为开始阶段的 v1 default" — but not locked). User can change in Settings. `WenshuConductor.resolveCredentials()` reads `UserDefaults["wenshu.provider.slug"]` override each call (= dynamic, no cache).
4. **Provider-agnostic UI**: AgentSettingsView shows 7 rows, no LLM details surfaced beyond provider name + protocol + auth field + endpoint + test button (= boss Q3 "没有推荐,用户自己决定").
5. **Test per connector**: Each connector has Z contract test (= request format + response parse) + 1 e2e byte-stability test (= PromptCaching invariant).
6. **No Metering / Billing / Quota**: §11 hard rule. The connector layer MUST NOT introduce any token-counting-for-billing infrastructure.

## Consequences

**Easier**:
- Customer onboarding (= any of 7 providers works out-of-the-box)
- Future provider addition (= add 1 enum case + 1 connector impl = 1 file change)
- Testing (= single interface = mock LLMConnector in tests, no real API)
- Per-provider error handling (= `ConnectorTestButton` shows concrete failure)

**Harder**:
- 7 connector implementations to maintain (= ~150 LOC each, ~1,000 LOC total connector code)
- Provider-specific quirks (= Anthropic = system top-level + content array union; OpenAI = system message + tool_calls; Gemini = generateContent with parts; Ollama = no auth header; OpenRouter = X-Title header)
- Caching normalization (= Anthropic = `cache_control` markers, OpenAI = no equivalent, Gemini = `cachedContent` resource)
- Spec coverage (= all 7 need Z contract test + 1 e2e test = 14 test files)

**Locked in**:
- LLMConnector protocol shape (= can't add a method without breaking all 7 impls)
- Provider enum = 7 cases (= boss Q3 = "no other recommendations needed, but don't lock the architecture")
- §11 product-positioning (= wenshu = tool only, never platform)

## Alternatives considered

1. **Single-connector (minimax cn only)**: Rejected. Vendor lock-in + onboarding friction + contradicts hermes parity + boss Q3 explicit "no recommendation, user decides".
2. **Universal connector adapter pattern (thin wrapper over hermes Python)**: Rejected. §11 hard rule "no external AI platform calls in any code file". Wenshu single-process Swift .app, no Python embed.
3. **API gateway wenshu-hosted (e.g. user pays wenshu, wenshu proxies to any provider)**: Rejected. §11 product-positioning rule. Boss Q4 "文枢不提供这个服务, 文枢只卖工具".
4. **Dynamic provider addition (user pastes OpenAPI spec)**: Deferred to v2+. Current 7 covers all major providers per boss Q3.

## Cross-references

- AGENTS.md §11 baseline + §11.2 LLM connector profiles table
- spec.md §3.5 / §3.6 / §6.4 / §7.4
- tickets 004-008 (= 5 connector impls + WenshuModelCatalog)
- ADR-0009 (wenshu-side wins)
- ADR-0012 (Scope B)