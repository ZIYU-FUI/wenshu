# 04 — SettingView 重写 4 tab (通用 / 提供方 / 模型 / 快捷键)

**Blocked by:** ticket 01 (Provider enum), 02 (ProviderKeychain), 03 (ProviderFetcher).

**Status:** ready-for-agent

## 修法真值 (5 步, Hermes list_picker_providers 范式)

1. SettingView 加 tab "提供方" (位置: 通用 + 模型之间):
   - 4 个 tab: 通用 / 提供方 / 模型 / 快捷键
2. "提供方" tab:
   - List Provider.all (radioGroup, 当前 selectedProvider 高亮)
   - 选中 provider → 弹 NSAlert 输入 key (走 ticket 03 NSWindow sheet prompt 真值)
   - 选中 custom → 显示 base_url input (@AppStorage "wenshu.llm.base_url")
   - 显示每个 provider 的 status (有 key ✓ / 没 key ✗)
3. "模型" tab:
   - 调 ProviderFetcher.loadModelIds(provider: currentProvider, apiKey: ProviderKeychain.loadKeySync(for:))
   - Picker 显示返回的 model IDs
   - 切 provider → reload models
4. 重写 LLMKeychain.promptForLLMKeyIfNeeded 接收 provider 参数 (或重命名 ProviderKeychain.promptForKey)
5. 加 `@AppStorage("wenshu.llm.provider")` 默认 "minimax-cn"

## Acceptance

- [ ] SettingView 4 tab (通用/提供方/模型/快捷键)
- [ ] 提供方 tab: List Provider.all radioGroup + 当前 provider 高亮
- [ ] 提供方 tab: 选 provider → 弹 NSAlert 输入 key → ProviderKeychain.saveKeySync
- [ ] 提供方 tab: 每 provider 显示 status (有/没 key)
- [ ] 模型 tab: 用 ProviderFetcher 拉当前 provider 的真值模型
- [ ] 切 provider → 模型 tab reload
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 提供方 tab 11 provider 罗列 → 选 openrouter → 输 key → 模型 tab 显 openrouter 真值列表

## 不动

- v0.21 ticket 01/02/03 (provider 模块)
- v0.21 chat bottom bar (model + context)
- LLMKeychain (保留 backwards compat API)
- v0.20 ticket 04/05 (LOGO)
