# 001 — AvailableModelsDiscovery struct + loadFromKeychain

> Parent spec: `.scratch/2026-08-23-provider-model-picker/spec.md`.
> 1 commit. New file in Core/Provider/.

## What to build

Create `AvailableProviderModels` struct + `AvailableModelsDiscovery.loadFromKeychain()` static func.

## Implementation outline

```swift
public struct AvailableProviderModels: Sendable {
    public let provider: Provider
    public let models: [String]
}

public enum AvailableModelsDiscovery {
    /// Load providers that have keys in Keychain + their defaultModels.
    /// Scans all known providers from Provider.all.
    public static func loadFromKeychain() -> [AvailableProviderModels] {
        let keychain = AppleKeychainStore()
        return Provider.all.compactMap { provider in
            guard let key = keychain.loadKeySync(for: provider), !key.isEmpty else {
                return nil  // provider has no key → skip
            }
            return AvailableProviderModels(
                provider: provider,
                models: provider.defaultModels
            )
        }
    }
}
```

## Acceptance criteria

- [ ] AvailableProviderModels struct exists
- [ ] loadFromKeychain returns only providers with non-empty keys
- [ ] Each section's models = provider.defaultModels
- [ ] No new providers added (use existing Provider.all list)
- [ ] swift build + tests pass