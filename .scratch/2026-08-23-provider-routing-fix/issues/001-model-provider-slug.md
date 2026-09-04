# 001 — WenshuLLMModel providerSlug mapping

> Parent spec: `.scratch/2026-08-23-provider-routing-fix/spec.md`.
> 1 commit. Modifies WenshuLLMModel.swift.

## What to build

Add `providerSlug: String` computed property to WenshuLLMModel enum. Each model case maps to its provider's slug.

Current cases (per spec search):
- `.m3` → `minimax-cn`

Future cases (when user adds providers):
- `.claudeSonnet` → `anthropic`
- `.gpt4o` → `openai`

This commit only adds the property for existing case (`.m3`). Future cases added when providers are configured.

## Acceptance criteria

- [ ] `WenshuLLMModel.m3.providerSlug == "minimax-cn"`
- [ ] Property is pure computed (no side effects)
- [ ] swift build + tests pass