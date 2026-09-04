# 003 — ProviderResolution tests

> Parent spec: `.scratch/2026-08-23-provider-routing-fix/spec.md`.
> Depends on: 001 + 002.
> 1 commit. New test file.

## What to build

Test the dynamic resolution logic end-to-end:

- `testModelProviderSlugMapping` — verify each WenshuLLMModel case → slug
- `testResolveCredentialsUsesDefaults` — when no UserDefaults override, use model.providerSlug
- `testResolveCredentialsRespectsUserOverride` — when UserDefaults has different slug, use that
- `testResolveCredentialsLoadsKeyFromKeychain` — keychain lookup happens
- `testResolveCredentialsThrowsOnMissingProvider` — unknown slug → error
- `testResolveCredentialsThrowsOnMissingKey` — no key for provider → error
- `testWenshuVerifierInitNoFrozenKey` — init no longer captures apiKey (verify by checking type signature)
- `testSendUsesResolvedCredentials` — when send is called, it reads UserDefaults + Keychain fresh (not init capture)

## Acceptance criteria

- [ ] 8 tests pass
- [ ] swift test total: 396 + 8 = 404+