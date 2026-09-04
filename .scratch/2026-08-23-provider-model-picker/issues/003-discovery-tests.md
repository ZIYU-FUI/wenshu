# 003 — AvailableModelsDiscovery tests

> Parent spec: `.scratch/2026-08-23-provider-model-picker/spec.md`.
> Depends on: 001 + 002.
> 1 commit. New tests file.

## What to build

Tests verifying the discovery logic.

## Implementation outline

`Tests/WenshuAppTests/Core/Provider/AvailableModelsDiscoveryTests.swift`:

- testLoadFromKeychainReturnsEmptyInSandbox: no Keychain keys → empty array
- testLoadFromKeychainFiltersProvidersWithoutKeys: only providers with keys returned
- testProviderDefaultModelsNonEmpty: every Provider.all entry has at least 1 defaultModel
- testProviderSlugsUnique: no duplicate slugs in Provider.all
- testAvailableProviderModelsStruct: equatable, sendable, simple

## Acceptance criteria

- [ ] 5 tests pass
- [ ] swift test total: 404 + 5 = 409+