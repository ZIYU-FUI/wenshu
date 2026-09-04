# 004 — Domain modeling: AvailableModelsDiscovery

> Parent spec: `.scratch/2026-08-23-provider-model-picker/spec.md`.
> 1 commit. CONTEXT.md update.

## What to build

Add `**AvailableModelsDiscovery (multi-provider 模型分组发现)**` to CONTEXT.md.

## Domain word

| **AvailableModelsDiscovery (multi-provider 模型分组发现)** | ChatView 底栏 ModelMenu 从 flat `availableModels: [String]` 改为 `availableSections: [AvailableProviderModels]`。`AvailableModelsDiscovery.loadFromKeychain()` 扫 `Provider.all` 列表,过滤出 `AppleKeychainStore.loadKeySync(for:)` 有 non-empty key 的 providers,返回 `{provider, models: provider.defaultModels}` 数组。Menu 渲染用 `Section(provider.name) { ForEach(models) }` 按 provider 分组,Apple HIG menu selection pattern 显示 checkmark。`Provider.defaultModels` 静态 curated 列表 (e.g. minimax-cn: MiniMax-M3/M2/Reasoning, anthropic: claude-opus-4.8, openai: gpt-5/gpt-5-mini/o4-mini)。Boss 2026-08-23 拍: 我配了三个厂家的 key,模型切换应该分组展示可用模型合集 | v0.23 ticket 011 |

## Acceptance criteria

- [ ] CONTEXT.md updated
- [ ] swift build + tests pass