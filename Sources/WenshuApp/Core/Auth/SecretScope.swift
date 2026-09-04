//
//  SecretScope.swift · Wenshu · TICKET-HERMES-GAP-005
//
//  Ported from hermes-agent `agent/secret_scope.py` (205 LOC) +
//  `agent/secret_sources/` (onepassword + bitwarden + base + registry +
//  cache + __init__ = 6 files). Hermes' SecretScope = a credential
//  source resolution chain (= env var → keychain → 1Password CLI →
//  Bitwarden CLI → system default → fail). The wenshu-side wins pattern
//  (AGENTS.md §11) narrows the chain: wenshu is BYOK-only (= provider
//  keys live in the existing `ProviderKeychain` shim), so the 1Password
//  CLI / Bitwarden CLI / iCloud Keychain adapters are out of scope for
//  v0.40 and intentionally not ported (= documented in the gap audit).
//
//  This file ships the canonical SecretScope primitive + 2 source
//  implementations (EnvVarSource + KeychainSource). Future tickets can
//  add additional sources without changing the protocol surface.
//
//  Reference: docs/design/multiplexing-gateway.md (Hermes Workstream A).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only; no third-party
//  imports. The `secret_sources` module name is retained as a
//  Swift comment marker so future agents grepping for the original
//  Python identifier can find the port (see acceptance: `grep -n
//  'secret_sources' Sources/WenshuApp/Core/Auth/SecretScope.swift`).
//

import Foundation

// MARK: - SecretSource protocol

/// One resolution source in a `SecretScope` chain. Sources are queried
/// in registration order; the first non-nil value wins.
///
/// `read(name:)` returns `nil` (= not "throw") when the name is not
/// found in this source — that is the "ask the next source" signal.
/// Throwing is reserved for actual infrastructure failures (= e.g.
/// Keychain locked, registry unavailable).
///
/// All sources must be `Sendable` (= passes across actor boundaries
/// under the project's Swift 6 strict-concurrency model).
public protocol SecretSource: Sendable {
    /// Read a secret by name. Returns `nil` when this source has no
    /// value for that name (= caller should try the next source).
    func read(name: String) async throws -> String?
}

// MARK: - EnvVarSource

/// Source backed by the process environment (= `ProcessInfo.processInfo.environment`).
/// Matches hermes `secret_scope.get_secret` step 1 / step 3 fallback
/// ("read `os.environ`").
public struct EnvVarSource: SecretSource {
    public init() {}

    public func read(name: String) async throws -> String? {
        ProcessInfo.processInfo.environment[name]
    }
}

// MARK: - KeychainSource

/// Source backed by wenshu's existing `ProviderKeychain` shim
/// (= Apple Security framework via `AppleKeychainStore`, or
/// `InMemoryKeychainStore` in tests).
///
/// `providerKey` is a stable identifier that maps onto a `Provider`
/// slug (= e.g. `"anthropic.api.key"` for the Anthropic provider).
/// This is the wenshu-side surface for the original hermes "keychain"
/// source: hermes stores per-profile keys under
/// `~/.hermes/profiles/<slug>/.env`; wenshu stores them under the Apple
/// Keychain account `AppleKeychainStore.service / <slug>.api.key`
/// (= see `ProviderKeychain.swift` for the canonical key layout).
public struct KeychainSource: SecretSource {
    /// Provider identifier (= `Provider.slug`, e.g. `"anthropic"`).
    /// Resolved via `Provider.by(slug:)` against the static catalog.
    public let providerSlug: String

    public init(providerSlug: String) {
        self.providerSlug = providerSlug
    }

    public func read(name: String) async throws -> String? {
        // Route through the existing `ProviderKeychain` shim (= Apple
        // Security in production, in-memory dict in tests). We do NOT
        // re-implement SecItemCopyMatching here (= wenshu-side wins).
        guard let provider = Provider.by(slug: providerSlug) else {
            return nil
        }
        return ProviderKeychain.loadKeySync(for: provider)
    }
}

// MARK: - SecretScope actor

/// Thread-safe registry + resolution chain for `SecretSource`s.
///
/// Resolution order = registration order (= first non-nil value wins).
/// No state mutation outside actor isolation; safe under Swift 6
/// strict concurrency.
///
/// Default `SecretScope()` = empty chain = every `resolve(name:)`
/// returns `nil`. Callers register sources via `register(_:)` before
/// calling `resolve`.
public actor SecretScope {
    private var sources: [SecretSource] = []

    public init() {}

    /// Append a source to the chain. Duplicate types are allowed
    /// (= caller's responsibility to deduplicate if needed).
    public func register(_ source: SecretSource) {
        sources.append(source)
    }

    /// Snapshot of currently-registered sources, in registration order.
    public var current: [SecretSource] { sources }

    /// Clear all sources (= useful for tests + hot reload).
    public func unregisterAll() {
        sources.removeAll()
    }

    /// Walk the chain and return the first non-nil value.
    /// Returns `nil` when no source has the name (= hermes `default=nil`
    /// behavior in single-profile / non-multiplex mode).
    public func resolve(name: String) async throws -> String? {
        for source in sources {
            if let value = try await source.read(name: name) {
                return value
            }
        }
        return nil
    }

    /// Convenience: resolve with a fallback default (= hermes
    /// `get_secret(name, default=...)` shape).
    public func resolve(name: String, default defaultValue: String) async throws -> String {
        try await resolve(name: name) ?? defaultValue
    }
}

// MARK: - Errors

/// Errors thrown by `SecretScope` / sources. Distinct from
/// `ProviderKeychainError` so callers can pattern-match on the scope
/// layer without coupling to keychain internals.
public enum SecretScopeError: Error, LocalizedError, Sendable {
    /// A source threw while reading; the underlying error is preserved.
    case sourceFailed(sourceName: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .sourceFailed(let sourceName, let underlying):
            return "SecretSource \(sourceName) failed: \(underlying)"
        }
    }
}
