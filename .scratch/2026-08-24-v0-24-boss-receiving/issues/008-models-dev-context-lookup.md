# Ticket 015.008 — Future: models.dev lookup for context window (hermes hybrid strategy)

Boss 2026-08-25 OOB: '查一下 hermes 是怎么实现的, 是真实查接口获取的, 还是
把各大厂家的信息拿过来预置的'.

## Hermes strategy (per agent/model_metadata.py:1456-1487)
- Resolution order: config override → custom_providers per-model → persistent
  cache → endpoint metadata → local-server query → Anthropic `/v1/models` →
  provider-aware lookups (including `models.dev`) → OpenRouter live →
  hardcoded defaults → fallback (256K).
- For MiniMax-M3:
  - `/v1/models` doesn't return `context_length` (Live API gap)
  - `models.dev` returns 512K (vendor publishes there; runs out of sync with
    official docs claiming 1M)
  - Hardcoded 1M never reached (because step 5f short-circuits)

## Plan
- Mirror hermes strategy in wenshu:
  - Try `https://models.dev/api.json` (3rd-party registry, real API call)
  - Fallback to hardcoded catalog (per-model `contextMax`)
- Cache result for performance (avoid hitting models.dev every chat call)
- Default wenshu value = 1_000_000 (per ticket 015.006 fix)

## Status (per Boss 8/25 OOB)
- Boss 拍 '查一下 hermes 是怎么实现的' = **research phase**.
- Not yet blocked v0.24 (= ticket 015.006 hardcoded 1M is acceptable interim).
- When boss 拍 'do it' (= 跑 models.dev lookup), implement.

## Implementation outline
- New file: `Sources/WenshuApp/Core/Provider/ModelContextRegistry.swift`
- `actor ModelContextRegistry` with `func contextMax(for modelId: String) async -> Int`
- Hardcoded fallback table: `["minimax-m3": 1_000_000, "minimax": 204_800]`
- Cache results in `@AppStorage("wenshu.modelContext.{modelId}")`
- Fetch URLSession → models.dev JSON → parse → cache → return

## Out of scope
- Live MiniMax cn `/v1/models` query (= confirmed doesn't return context_length)
- Token cost calculation
- Multi-provider switch fallback (= ticket 015.002 Keychain covers)