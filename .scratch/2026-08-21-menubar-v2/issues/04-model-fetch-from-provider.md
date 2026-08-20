# 04 — 设置 → 模型 tab: 拉真值模型列表 (Hermes probe_api_models 范式)

**What to build:**
老板 8/21 拍 "模型配置参考 hermes 的提供方设置实现, hermes 会自动获取我的 key 可以使用的模型罗列出来". 当前 Settings > 模型 tab 用 MiniMaxModel enum hardcoded 3 case (MiniMax-M3 / MiniMax-M2 / MiniMax-Reasoning), 老板 macOS 真验过的 key 可能开通更多模型, hardcoded 漏掉.

**Hermes 真值 (hermes_cli/models.py)**:
- `probe_api_models(api_key, base_url, timeout=5.0, api_mode="anthropic_messages")` (= 老板真值真值)
- `anthropic_messages` mode: 用 `x-api-key` + `anthropic-version: 2023-06-01` headers (Anthropic native auth)
- fallback: `Authorization: Bearer <key>` (OpenAI mode)
- 候选 URL: `{base_url}` + `{base_url}/v1` (heuristic, boss host 可能不带 /v1)
- 5s timeout
- 解析: `data[].id` (OpenAI canonical)
- 缓存: `provider_models_cache.json` 1h TTL (Hermes 1h)
- 失败 fallback: curated 内置列表 (MiniMaxModel.allCases 真值)

**Blocked by:** ticket 03 LLM Keychain 集成 (commit 143ff4845) — 已 commit.

**Status:** ready-for-agent

## 修法真值 (5 步, Hermes 范式真值)

1. `Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift` (actor 真值)
   - `func fetchLiveModelIds(apiKey:baseUrl:timeout:5) async -> [String]?`:
     - 候选 URL: `{base_url}` + `{base_url}/v1` (heuristic)
     - headers: `x-api-key: <key>` + `anthropic-version: 2023-06-01` (Anthropic mode)
     - `URLSession.shared.data(from:)` GET, 5s timeout
     - 解析 `data[].id` → `[String]`
     - 失败返 nil (不抛)
2. 缓存: `~/Library/Application Support/com.wenshu.app/model_cache.json` 1h TTL (Hermes 1h)
3. `SettingView` model tab:
   - 抽 `@MainActor func reloadModels() async` 调 fetcher
   - onAppear: reloadModels async (背景, 用户看不到 loading)
   - **重写 "配完省略显示"** = `Picker` selection ≠ current label (改用 menu + .disabled("已选: \(current)" 后缀) 真值真值真值
     - 实际 Apple 真值: `Menu(currentModel) { ForEach }` (= macOS 标准 'current + open menu' 模式, Pages 设置就用这个)
4. Picker 显示 fetch 结果 + fallback MiniMaxModel.allCases
5. 用户选 model → 真值存 UserDefaults "wenshu.llm.model" + sharedVerifier model 字段 (commit 0589141 + 143ff4845 真值)

## Acceptance

- [ ] MiniMaxModelFetcher actor + fetchLiveModelIds + 缓存 + fallback MiniMaxModel.allCases
- [ ] SettingView model tab onAppear async reload (背景, 不阻塞)
- [ ] Picker 显示真值 fetch 模型列表 (Hermes 真值)
- [ ] fallback: 网络 fail → curated MiniMaxModel.allCases (3 个)
- [ ] cmd+, → 设置 → 模型 tab → Hermes 范式 auto-fetch 真值
- [ ] swift build exit 0
- [ ] swift test exit 0 (新加 testModelFetcherFallback 真值)
- [ ] 老板 macOS 真验: 模型 tab 显示 hermes-fetched 真值模型列表 (≥3 个) + 选 model 立刻生效

## 不动 (Q20 硬约束)

- Settings > 外观 tab (commit d8146ca7d 已过)
- LLMKeychain actor (commit 143ff4845 已过)
- v0.20 + v0.21 chat-streak tickets (不动)
- AppIcon.icon/ (老板拍先放着)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/menu
- https://developer.apple.com/documentation/foundation/urlsession
- hermes_cli/models.py probe_api_models (Hermes open-source 真值)
- https://docs.anthropic.com/en/api/models-list

## 关联

- 依赖: ticket 03 (Keychain 集成) — 已 commit
- 被依赖: 无