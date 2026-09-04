# Provider routing fix — issues index

> Parent spec: `.scratch/2026-08-23-provider-routing-fix/spec.md`.
> Boss 2026-08-23 拍: 用户切 model/key 后主 + 子 agent 同步切换.
> 4 commits, 1 PR.

## Tickets

| # | Issue | Depends on | Status |
|---|-------|------------|--------|
| 001 | `001-model-provider-slug.md` (WenshuLLMModel.providerSlug) | — | pending |
| 002 | `002-verifier-dynamic-resolve.md` (WenshuVerifier per-call resolution) | 001 | pending |
| 003 | `003-provider-resolution-tests.md` (8 tests) | 001 + 002 | pending |
| 004 | `004-domain-modeling-provider-resolution.md` (CONTEXT.md update) | 001 + 002 | pending |

## Order

Sequential: 001 → 002 → 003 → 004

## Per-ticket constraints

- Leaf-level changes only (WenshuVerifier / WenshuLLMModel / ProviderCatalog / tests / CONTEXT.md)
- 不动 LayoutShellView / WenshuAppDelegate / parent components
- Code-review 2 axes (Standards + Spec)
- swift build + tests pass each commit
- Pollution vocab 0 leak