# 004 — Domain modeling: ProviderResolution

> Parent spec: `.scratch/2026-08-23-provider-routing-fix/spec.md`.
> 1 commit. CONTEXT.md update.

## What to build

Add `**ProviderResolution (动态 key + baseURL)**` to CONTEXT.md domain glossary.

## Domain word

| **ProviderResolution (动态 key + baseURL 解析)** | WenshuVerifier 不再 capture apiKey / baseURL 在 init 时 — 每次 send() call 时通过 `resolveCredentials()` 从 UserDefaults (provider slug) + ProviderCatalog (provider 配置) + AppleKeychain (key 真值) 三方动态解析。改动原因 = boss 2026-08-23 拍 用户切 provider / key 后,主 agent + 5 sub-agent 必须同步切,否则 mismatch 卡死。配套 `WenshuLLMModel.providerSlug` 计算属性显式声明每个 model 对应的 provider (m3 → minimax-cn, claudeSonnet → anthropic, gpt4o → openai 等) | v0.23 ticket 010 |

## Acceptance criteria

- [ ] CONTEXT.md updated
- [ ] swift build + tests pass (no Swift change in this commit)