//
//  SearchAPIKeychain.swift · Wenshu · v0.81 ticket 001
//
//  Apple Security framework backend for web-search API keys
//  (= EXA / TAVILY / BRAVE / PARALLEL; = SEARXNG uses endpoint URL not API key).
//
//  Mirrors `ProviderKeychain` (= AppleKeychainStore / InMemoryKeychainStore
//  pattern) but uses a separate keychain namespace:
//  - ProviderKeychain service = "wenshu.providers" (= LLM provider keys)
//  - SearchAPIKeychain service = "wenshu.search" (= search provider keys)
//
//  This separation means a user can revoke all search keys without
//  invalidating LLM provider keys (= orthogonal blast radius).
//
//  Production path (= B-10 phase B pending) = Apple Security framework
//  via SecItemAdd / SecItemCopyMatching / SecItemDelete (= same code
//  pattern as `AppleKeychainStore`). Dev path = `InMemorySearchKeychainStore`
//  (= mirrors `InMemoryKeychainStore` for tests + dev environments).
//
//  Per AGENTS.md §11: API keys must use AppleKeychain in production.
//  This module satisfies the §11 mandate for web-search API keys.
//
//  Per Q57: do NOT delete hermes-port files (= `WebSearchConfigurator`
//  uses UserDefaults for dev path; = this module replaces that path on
//  production default).
//
//  v0.84 ticket 002: refactored to delegate Security framework calls to
//  `KeychainOps` (= canonical shared helper; = eliminates the 16% dup
//  with `ProviderKeychain.swift` flagged by repowise dry_violation).

import Foundation

public enum SearchAPIKeychainError: Error, LocalizedError {
    case keychainStatus(OSStatus)
    case invalidKeyFormat

    public var errorDescription: String? {
        switch self {
        case .keychainStatus(let s):
            return "Search API keychain operation failed (status=\(s))"
        case .invalidKeyFormat:
            return "Search API key format invalid"
        }
    }

    /// Map the canonical `KeychainOpsError` (= shared across all keychain
    /// consumers in wenshu) into the search-specific error type.
    /// Added in v0.84 ticket 002: ProviderKeychain.error.keychainStatus(_) and
    /// .invalidKeyFormat become SearchAPIKeychainError.keychainStatus(_) and
    /// .invalidKeyFormat respectively (= preserves the OSStatus / format
    /// semantics at the call site).
    public static func from(_ error: KeychainOpsError) -> SearchAPIKeychainError {
        switch error {
        case .keychainStatus(let s):
            return .keychainStatus(s)
        case .invalidKeyFormat:
            return .invalidKeyFormat
        }
    }
}

/// Storage backend for web-search API keys (= EXA / TAVILY / BRAVE / PARALLEL).
/// Production = Apple Keychain via Security framework. Tests inject
/// `InMemorySearchKeychainStore` to avoid OS Keychain entitlements requirement.
///
/// Mirrors the `ProviderKeychainStoring` protocol pattern but uses a
/// separate keychain namespace (= "wenshu.search") for blast-radius
/// isolation from LLM provider keys.
public protocol SearchAPIKeychainStoring: Sendable {
    /// Save a raw API key (= e.g. exa_api_key value).
    /// The provider name (= "exa" / "tavily" / etc.) namespaces the key.
    func saveKey(_ key: String, for provider: String) throws

    /// Load a raw API key (= nil if not configured).
    func loadKey(for provider: String) -> String?

    /// Delete a raw API key (= no-op when not configured).
    func deleteKey(for provider: String) throws

    /// Return the set of configured provider names (= "exa", "tavily", etc.).
    func listConfiguredProviders() -> [String]
}

/// Production Apple Keychain backend for search API keys.
/// Delegates the actual Security framework calls to `KeychainOps`
/// (= canonical shared helper; = same code path as `AppleKeychainStore`
/// for LLM provider keys, but with the search-specific service namespace).
public final class AppleSearchKeychainStore: SearchAPIKeychainStoring, @unchecked Sendable {

    /// Keychain service identifier for web-search API keys (= isolated
    /// from `AppleKeychainStore.service` which is "wenshu.providers").
    static let service = "wenshu.search"

    /// Remote-debug short-circuit (= matches `AppleKeychainStore` pattern).
    /// When `wenshu.debugNoKeychain` UserDefaults flag is set, all
    /// operations become no-ops. Lets wenshu launch remotely (= via CUA)
    /// without triggering the SecurityAgent modal.
    public init() {}

    public func saveKey(_ key: String, for provider: String) throws {
        do {
            try KeychainOps.save(value: key, service: Self.service, account: "\(provider).api.key")
        } catch let e as KeychainOpsError {
            throw SearchAPIKeychainError.from(e)
        }
    }

    public func loadKey(for provider: String) -> String? {
        KeychainOps.load(service: Self.service, account: "\(provider).api.key")
    }

    public func deleteKey(for provider: String) throws {
        do {
            try KeychainOps.delete(service: Self.service, account: "\(provider).api.key")
        } catch let e as KeychainOpsError {
            throw SearchAPIKeychainError.from(e)
        }
    }

    public func listConfiguredProviders() -> [String] {
        KeychainOps.listAccounts(service: Self.service)
    }
}

/// Test backend — in-memory dict, no OS Keychain entitlements required.
/// Mirrors `InMemoryKeychainStore` pattern.
public final class InMemorySearchKeychainStore: SearchAPIKeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func saveKey(_ key: String, for provider: String) throws {
        guard !key.isEmpty else { throw SearchAPIKeychainError.invalidKeyFormat }
        lock.lock(); defer { lock.unlock() }
        store[provider] = key
    }

    public func loadKey(for provider: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return store[provider]
    }

    public func deleteKey(for provider: String) throws {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: provider)
    }

    public func listConfiguredProviders() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys).sorted()
    }
}

/// Backwards-compat shim — preserves the `WebSearchConfigurator`
/// production path (= AppleKeychainStore per AGENTS.md §11) while
/// letting tests inject `InMemorySearchKeychainStore` via
/// `setBackendForTesting(_:)`.
public enum SearchAPIKeychain {
    /// Mutable global backend (= matches `ProviderKeychain.backend` pattern).
    /// `nonisolated(unsafe)` because this enum lives in the same module
    /// as the test code (= the test target = different isolation domain;
    /// tests are single-threaded at the @Suite level).
    private nonisolated(unsafe) static var _backend: SearchAPIKeychainStoring = AppleSearchKeychainStore()

    public static var backend: SearchAPIKeychainStoring { _backend }

    public static func setBackendForTesting(_ backend: SearchAPIKeychainStoring) {
        _backend = backend
    }

    public static func resetBackendForTesting() {
        _backend = AppleSearchKeychainStore()
    }

    // MARK: - Convenience (= same surface as ProviderKeychain)

    public static func saveKey(_ key: String, for provider: String) throws {
        try backend.saveKey(key, for: provider)
    }

    public static func loadKey(for provider: String) -> String? {
        backend.loadKey(for: provider)
    }

    public static func deleteKey(for provider: String) throws {
        try backend.deleteKey(for: provider)
    }

    public static func listConfiguredProviders() -> [String] {
        backend.listConfiguredProviders()
    }
}