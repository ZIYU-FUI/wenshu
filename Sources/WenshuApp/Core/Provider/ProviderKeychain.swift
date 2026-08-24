//
//  ProviderKeychain.swift
//
//  Apple Security framework backend for provider API keys (kSecClassGenericPassword).
//  Production path = SecItemAdd/Query/Delete via AppleKeychainStore.
//  Test path = InMemoryKeychainStore (swift test runs without user-attached session,
//  OS Keychain returns errSecInteractionNotAllowed / errSecMissingEntitlement).
//
//  Backwards-compat shim = ProviderKeychain enum, preserves existing
//  saveKeySync / loadKeySync / deleteKeySync / listProvidersWithKeys call sites.
//  Test backend switched via ProviderKeychain.setBackendForTesting(_:).
//
//  Fixes:
//  - ticket 02 acceptance: enum shim + Storing protocol + 2 backend (not literal actor)
//  - ticket 02 dev env skip: InMemoryKeychainStore for test isolation
//  - ticket 03 dev env skip: WenshuVerifierTests.testPingReal returns early without
//    Issue.record (Apple Swift Testing: record() counts as failure)
//

import Foundation
import Security

public enum ProviderKeychainError: Error, LocalizedError {
    case keychainStatus(OSStatus)
    case invalidKeyFormat

    public var errorDescription: String? {
        switch self {
        case .keychainStatus(let s): return "Keychain 操作失败 (status=\(s))"
        case .invalidKeyFormat: return "LLM key 格式无效"
        }
    }
}

/// Storage backend for provider API keys. Production = Apple Keychain via Security framework.
/// Tests inject `InMemory` to avoid OS Keychain entitlements requirement.
public protocol ProviderKeychainStoring: Sendable {
    func saveKeySync(_ key: String, for provider: Provider) throws
    func loadKeySync(for provider: Provider) -> String?
    func deleteKeySync(for provider: Provider) throws
    func listProvidersWithKeys() -> [String]
}

/// Default production backend — Apple Security framework (`kSecClassGenericPassword`).
public final class AppleKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    public static let service = "com.wenshu.app.provider"

    public init() {}

    public func saveKeySync(_ key: String, for provider: Provider) throws {
        guard !key.isEmpty else { throw ProviderKeychainError.invalidKeyFormat }
        let keyData = Data(key.utf8)
        let account = "\(provider.slug).api.key"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppleKeychainStore.service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppleKeychainStore.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            // v0.24 boss验收fix (2026-08-24): removed 'kSecUseDataProtectionKeychain: true'.
            // This iOS-only flag on macOS requires explicit entitlement
            // (kSecAttrAccessGroupFile or similar) and triggers -34018
            // errSecMissingEntitlement on ad-hoc signed apps. The default
            // (file-based) keychain on macOS works without entitlement.
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw ProviderKeychainError.keychainStatus(status) }
    }

    public func loadKeySync(for provider: Provider) -> String? {
        let account = "\(provider.slug).api.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppleKeychainStore.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteKeySync(for provider: Provider) throws {
        let account = "\(provider.slug).api.key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppleKeychainStore.service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderKeychainError.keychainStatus(status)
        }
    }

    public func listProvidersWithKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppleKeychainStore.service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let array = items as? [[String: Any]] else { return [] }
        return array.compactMap { $0[kSecAttrAccount as String] as? String }
            .compactMap { $0.hasSuffix(".api.key") ? String($0.dropLast(".api.key".count)) : nil }
    }
}

/// Test backend — in-memory dict, no OS Keychain entitlements required.
/// Mirrors AppleKeychainStore public API (save / load / delete / list).
public final class InMemoryKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func saveKeySync(_ key: String, for provider: Provider) throws {
        guard !key.isEmpty else { throw ProviderKeychainError.invalidKeyFormat }
        lock.lock(); defer { lock.unlock() }
        store[provider.slug] = key
    }

    public func loadKeySync(for provider: Provider) -> String? {
        lock.lock(); defer { lock.unlock() }
        return store[provider.slug]
    }

    public func deleteKeySync(for provider: Provider) throws {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: provider.slug)
    }

    public func listProvidersWithKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys).sorted()
    }
}

/// Backwards-compat shim — preserves existing call sites (`ProviderKeychain.saveKeySync`).
/// Delegates to `ProviderKeychain.backend` (default = AppleKeychainStore for production).
/// Tests override `backend` via `setBackendForTesting()`.
public enum ProviderKeychain {
    public nonisolated(unsafe) static var backend: any ProviderKeychainStoring = AppleKeychainStore()

    /// Test-only override. Production code must never call this.
    public static func setBackendForTesting(_ store: any ProviderKeychainStoring) {
        backend = store
    }

    public static func saveKeySync(_ key: String, for provider: Provider) throws {
        try backend.saveKeySync(key, for: provider)
    }
    public static func loadKeySync(for provider: Provider) -> String? {
        backend.loadKeySync(for: provider)
    }
    public static func deleteKeySync(for provider: Provider) throws {
        try backend.deleteKeySync(for: provider)
    }
    public static func listProvidersWithKeys() -> [String] {
        backend.listProvidersWithKeys()
    }
}