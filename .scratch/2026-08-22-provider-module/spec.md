# 05 — Provider 模块整克隆 (Hermes 范式)

> Date: 2026-08-22
> 老板 2026-08-21 拍: "整个复刻过来, 我们未来也要用户自己配他自己 key 不可能所有人有是 minimax, 整个提供方模块复刻, 除了 hermes 自己的商业订阅, 还有三方平台托管, 就是所有的模型提供方都罗列出来, 用户自选配置"

## 业务语言 (老板懂)

设置 → 提供方 tab:
- **罗列所有 provider** (= hermes 范式, openrouter / nous / minimax / minimax-cn + 用户自加)
- 用户自选 1 个 provider
- 用户自填 API key (= 已有 Keychain 集成, 加 provider 字段)
- 设置页 → 模型 tab 拉当前 provider 的 `/v1/models` 真值列表
- "配完省略显示" 老板原话保留

## Hermes 真值链 (待复刻范围)

**`hermes_cli/model_switch.py` (2452 lines):**
- `parse_model_flags` / `resolve_persist_behavior` / `switch_model` — 切模型 state machine
- `list_authenticated_providers` (1450) — 罗列有 key 的 providers + curated models
- `list_picker_providers` — picker UI 数据 (provider → model list)
- `prewarm_picker_cache_async` — 后台预热 cache
- `_load_direct_aliases` / `_ensure_direct_aliases` — alias 真值

**`hermes_cli/models.py` (4294 lines):**
- `_PROVIDER_MODELS` dict (provider → curated model list)
- `provider_model_ids(provider)` — provider 模型目录 (curated + live)
- `fetch_api_models` / `probe_api_models` — `/v1/models` 真值 fetch (5s timeout)
- `_fetch_anthropic_models` / `_fetch_github_models` / `fetch_nous_models` / `get_codex_model_ids` — 各 provider 特定 endpoint
- `ModelCache` (1h TTL) — 磁盘缓存
- `_PROVIDER_ALIASES` — provider slug 别名

**Hermes 支持的 providers (从 config.yaml / models.py 反推):**
- `openrouter` (OPENROUTER_API_KEY) — 三方平台, 路由任意模型
- `nous` (OAuth, hermes auth) — Nous Portal
- `minimax` (MINIMAX_API_KEY) — MiniMax
- `minimax-cn` (MINIMAX_CN_API_KEY) — MiniMax (China)
- `openai-codex` (OAuth)
- `copilot` / `copilot-acp` (GitHub token)
- `xai-oauth` (OAuth)
- `stepfun` (API key)
- `anthropic` (API key, native Anthropic protocol)
- 自定义 endpoints (用户填 base_url + key)

## 修法范围 (老板拍"用户自选配置" = 多 provider + 自填 key)

**Step 1 — provider 模块整克隆 (本 ticket 范围):**

1. `Sources/WenshuApp/Core/Provider/Provider.swift` — `enum Provider` 真值
   - `openrouter`, `nous`, `minimax`, `minimax-cn`, `openai-codex`, `copilot`, `xai-oauth`, `stepfun`, `anthropic`, `custom`
   - 每个 case: `name`, `slug`, `baseURL`, `apiMode` ("anthropic_messages" / "openai_chat"), `authHeader` ("x-api-key" / "Authorization"), `defaultModels: [String]`
2. `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — 真值
   - `static let providers: [Provider]` = hermes 范式列表
   - `static func defaultModels(for: Provider) -> [String]` — curated fallback
3. `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift` — 重构 MiniMaxModelFetcher → 多 provider
   - `func fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]?`
   - provider 走自己的 endpoint + headers (hermes 真值)
   - fallback to curated
4. `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` — 多 provider key 存储
   - 修 `LLMKeychain` → 按 provider 存 (`kSecAttrAccount = provider.slug`)
   - 删 `LLMKeychain.loadKeySync()` 静态简化 → 改 `KeychainStore.shared.key(for: provider)`
5. `Sources/WenshuApp/App.swift` 设置页 → 加 "提供方" tab (放通用 + 模型 之间)
   - 提供方 tab: List provider (radioGroup, 当前 selected provider 高亮) + 当 custom 时显示 base_url input
   - 模型 tab: 重写 Picker 用当前 provider 的 fetch 结果
6. 老板 macOS 真验:
   - 设置 → 提供方 → 选 openrouter → 提示输 OPENROUTER_API_KEY → Keychain 存
   - 设置 → 模型 → Picker 显示 openrouter 真值模型列表
   - 测试多个 provider (minimax / openrouter / nous) 都 work

**Step 2 — 后续 (本 ticket 不做):**
- provider 切换后 `sharedVerifier` 重建 (修真硬违反)
- 用户自加 custom provider UI
- OAuth 流程 (nous / copilot / openai-codex / xai-oauth)
- 自定义 base_url 持久化

## 验收标准

- [ ] Provider.swift enum (10+ cases, hermes 真值)
- [ ] ProviderCatalog.swift 静态列表
- [ ] ProviderFetcher.swift 多 provider 真值 fetch
- [ ] ProviderKeychain.swift 多 provider key 存储
- [ ] LLMKeychain.swift 修法或删除 (新 ProviderKeychain 替代)
- [ ] SettingView 重写: 4 个 tab (通用 / 提供方 / 模型 / 快捷键)
- [ ] 提供方 tab: radioGroup picker + 当前 provider 显示 + 当 custom 时显示 base_url
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 新增测试: testProviderFetchOpenRouter + testProviderFetchFallback
- [ ] 老板 macOS 真验: 选 openrouter → Keychain 存 key → 模型 tab 显 openrouter 真值列表

## 不动 (Q20 硬约束)

- v0.21 chat streak ticket 02-06 (不动)
- v0.21 ticket 04 MiniMaxModelFetcher (重构进 ProviderFetcher, 不重写)
- v0.21 ticket 03 LLMKeychain (重构进 ProviderKeychain, 不重写)
- AppIcon.icon/ (老板拍先放着)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/picker (radioGroup 真值)
- https://developer.apple.com/documentation/security/keychain_services
- hermes_cli/models.py probe_api_models (Hermes 真值)
- hermes_cli/model_switch.py list_authenticated_providers (Hermes 真值)

## 关联

- 依赖: ticket 03 (Keychain) + ticket 04 (Model fetcher) — 都已 commit, 重构不重写
- 被依赖: ticket 06 (mini LLM Keychain actor unsafe 修真), ticket 07 (provider 切换后 sharedVerifier 重建)