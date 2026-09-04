# 002 — WenshuVerifier dynamic credential resolution

> Parent spec: `.scratch/2026-08-23-provider-routing-fix/spec.md`.
> Depends on: 001.
> 1 commit. Modifies WenshuVerifier.swift.

## What to build

Replace `private let apiKey: ***` + `private let baseURL: String` (frozen at init) with per-call resolution.

## Implementation outline

```swift
public actor WenshuVerifier {
    private let model: String

    public init(model: WenshuLLMModel = .m3) {
        self.model = model.rawValue
    }

    /// resolveCredentials: read provider + key at call time.
    /// Strategy:
    ///   1. Read provider slug from UserDefaults "wenshu.provider.slug"
    ///   2. Default to current model's providerSlug if not set
    ///   3. Look up provider in ProviderCatalog
    ///   4. Load key from AppleKeychain for that provider slug
    /// Returns (apiKey, baseURL).
    private func resolveCredentials() throws -> (apiKey: String, baseURL: String) {
        // Implementation
    }

    public func send(...) async throws -> WenshuLLMResponse {
        let creds = try resolveCredentials()
        // use creds.apiKey + creds.baseURL
    }
}
```

## Acceptance criteria

- [ ] No more `private let apiKey` or `private let baseURL` on WenshuVerifier
- [ ] send() resolves credentials on each call (verify via test mock)
- [ ] When UserDefaults "wenshu.provider.slug" changes between calls, next call uses new provider
- [ ] swift build + tests pass