# 01 — Provider enum + Catalog (Hermes 真值)

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (2 步)

1. `Sources/WenshuApp/Core/Provider/Provider.swift` — `enum Provider` 真值
   - 10 cases: openrouter / nous / minimax / minimax-cn / openai-codex / copilot / copilot-acp / xai-oauth / stepfun / anthropic / custom
   - 每 case: `slug` (String, unique key, hermes `_PROVIDER_ALIASES` 真值), `name` (display 中文), `defaultBaseURL`, `apiMode` ("anthropic_messages" / "openai_chat"), `authHeader` ("x-api-key" / "Authorization"), `requiresOAuth: Bool`, `defaultModels: [String]` (curated)
2. `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — 静态 provider 列表 + curated models 真值

## Acceptance

- [ ] Provider.swift enum 11 cases (10 + custom)
- [ ] ProviderCatalog.swift 静态列表
- [ ] swift build exit 0
- [ ] 老板 macOS 真验 (后续 ticket 接 UI)

## 不动 (Q20)

- ticket 04 MiniMaxModelFetcher (后续重构)
- ticket 03 LLMKeychain (后续重构)
- App.swift (后续 ticket 接 UI)

## 关联

- 依赖: 无
- 被依赖: ticket 02 (ProviderKeychain), ticket 03 (ProviderFetcher), ticket 04 (SettingView)
