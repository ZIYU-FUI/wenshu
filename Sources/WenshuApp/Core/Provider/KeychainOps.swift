//
//  KeychainOps.swift · Wenshu · v0.84 ticket 001
//
//  Shared low-level Apple Security framework wrappers used by BOTH
//  `AppleKeychainStore` (LLM provider keys) and `AppleSearchKeychainStore`
//  (= web-search API keys).
//
//  Per repowise dry_violation finding (v0.84 spec §ticket-001):
//  - SearchAPIKeychain.swift and ProviderKeychain.swift were 16% duplicated
//    (= ~30 LOC of SecItemAdd / SecItemCopyMatching / SecItemDelete code).
//  - This module extracts the shared primitives (= `save` / `load` / `delete`)
//    so both providers can call into one canonical implementation.
//
//  Per AGENTS.md §11.1: NO third-party deps (= Foundation + Security only).
//  Per Q173 ponytail: extraction is minimal — only the Security framework
//  glue (= the per-provider error mapping stays in each provider file
//  because the error types differ).
//

import Foundation
import Security

/// Low-level Apple Security framework wrappers shared across wenshu
/// keychain consumers (= LLM provider keys + web-search API keys).
///
/// Every operation:
/// 1. Returns silently (= no-op success) when `wenshu.debugNoKeychain`
///    UserDefaults flag is set (= remote-debug mode).
/// 2. Throws `KeychainOpsError` (= canonical keychain errors; = each
///    provider file maps these into its own domain-specific error type).
public enum KeychainOps {

    /// Save (= insert or replace) a UTF-8 string value into the keychain
    /// under `(service, account)`.
    public static func save(
        value: String,
        service: String,
        account: String
    ) throws {
        if isRemoteDebugMode() { return }
        guard !value.isEmpty else { throw KeychainOpsError.invalidKeyFormat }
        let data = Data(value.utf8)

        // Delete any existing item first (= SecItemAdd fails if a duplicate exists)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainOpsError.from(status)
        }
    }

    /// Load a UTF-8 string value from the keychain. Returns nil if missing
    /// (= caller treats as "not configured").
    public static func load(
        service: String,
        account: String
    ) -> String? {
        if isRemoteDebugMode() { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a keychain entry (= no-op when missing).
    public static func delete(
        service: String,
        account: String
    ) throws {
        if isRemoteDebugMode() { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainOpsError.keychainStatus(status)
        }
    }

    /// List all configured accounts under a service (= returns the account
    /// suffix-stripped names, = e.g. "anthropic" instead of "anthropic.api.key").
    public static func listAccounts(service: String, suffix: String = ".api.key") -> [String] {
        if isRemoteDebugMode() { return [] }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let array = items as? [[String: Any]] else {
            return []
        }
        return array.compactMap { $0[kSecAttrAccount as String] as? String }
            .compactMap { $0.hasSuffix(suffix) ? String($0.dropLast(suffix.count)) : nil }
    }

    // MARK: - Private helpers

    /// Returns true when `wenshu.debugNoKeychain` UserDefaults flag is set
    /// (= remote-debug mode; = same flag used by both provider files
    /// before this refactor).
    private static func isRemoteDebugMode() -> Bool {
        UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain")
    }
}

/// Canonical keychain errors (= mapped into each provider's domain-specific
/// error type by the calling provider file).
///
/// v0.91 ticket 001 (= pre-existing flake fix): the
/// `errSecMissingEntitlement` case (= OSStatus -34018) is now a
/// first-class error type so callers can show a graceful error message
/// (= "Keychain access requires code signing entitlement; please run
/// from the signed .app bundle") instead of a generic Swift error.
/// Per boss 2026-08-24 fix-tracking: the previous behavior showed
/// "The operation couldn't be completed" (= generic Swift error) on
/// ad-hoc-signed wenshu.app (= no TeamIdentifier = no embedded
/// provisioning profile). The new case preserves the OSStatus code for
/// callers that need to log it, while giving users an actionable hint.
public enum KeychainOpsError: Error, LocalizedError {
    case keychainStatus(OSStatus)
    case missingEntitlement(OSStatus = -34018)
    case invalidKeyFormat

    public var errorDescription: String? {
        switch self {
        case .keychainStatus(let s):
            return "Keychain operation failed (status=\(s))"
        case .missingEntitlement(let s):
            return "Keychain access requires code-signing entitlement (errSecMissingEntitlement, status=\(s)). Run wenshu.app from the signed .app bundle (= the ad-hoc-signed build does not carry the entitlement)."
        case .invalidKeyFormat:
            return "Key format invalid"
        }
    }

    /// Bridge from raw `OSStatus` (= the Security framework return value)
    /// to a typed `KeychainOpsError`. Per Apple developer.apple.com/
    /// documentation/security/keychain_services: -34018 is the
    /// canonical `errSecMissingEntitlement` (= team identifier missing
    /// for ad-hoc-signed binaries; = the boss 2026-08-24 fix-tracking
    /// root cause for the chat zone showing a generic Swift error).
    public static func from(_ status: OSStatus) -> KeychainOpsError {
        if status == -34018 {
            return .missingEntitlement(status)
        }
        return .keychainStatus(status)
    }
}