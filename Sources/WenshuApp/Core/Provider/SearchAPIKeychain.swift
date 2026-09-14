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

import Foundation
import Security

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
/// Mirrors `AppleKeychainStore` (= same SecItemAdd / SecItemCopyMatching /
/// SecItemDelete pattern). Uses a separate keychain service string to
/// isolate from LLM provider keys.
public final class AppleSearchKeychainStore: SearchAPIKeychainStoring, @unchecked Sendable {

    /// Keychain service identifier for web-search API keys (= isolated
    /// from `AppleKeychainStore.service` which is "wenshu.providers").
    static let service = "wenshu.search"

    /// Remote-debug short-circuit (= matches `AppleKeychainStore` pattern).
    /// When `wenshu.debugNoKeychain` UserDefaults flag is set, all
    /// operations become no-ops. Lets wenshu launch remotely (= via CUA)
    /// without triggering the SecurityAgent modal.
    public init() {}

    private var debugNoKeychain: Bool {
        UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain")
    }

    public func saveKey(_ key: String, for provider: String) throws {
        guard !key.isEmpty else { throw SearchAPIKeychainError.invalidKeyFormat }
        if debugNoKeychain { return }

        let account = "\(provider).api.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]

        // Delete existing then add (= SecItemAdd fails if item exists)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = Data(key.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SearchAPIKeychainError.keychainStatus(status)
        }
    }

    public func loadKey(for provider: String) -> String? {
        if debugNoKeychain { return nil }

        let account = "\(provider).api.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteKey(for provider: String) throws {
        if debugNoKeychain { return }
        let account = "\(provider).api.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SearchAPIKeychainError.keychainStatus(status)
        }
    }

    public func listConfiguredProviders() -> [String] {
        if debugNoKeychain { return [] }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let array = items as? [[String: Any]] else {
            return []
        }
        return array.compactMap { $0[kSecAttrAccount as String] as? String }
            .compactMap { $0.hasSuffix(".api.key") ? String($0.dropLast(".api.key".count)) : nil }
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