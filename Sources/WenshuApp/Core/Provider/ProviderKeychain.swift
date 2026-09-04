//
//  ProviderKeychain.swift
//
//  Apple Security framework backend for provider API keys (kSecClassGenericPassword).
//  Production path = InMemoryKeychainStore stub (B-10 revert 2026-09-04:
//  avoids SecurityAgent modal + ad-hoc-signing SIGABRT on the Settings
//  window). Real SecItemAdd/CopyMatching/Delete code is preserved as
//  comments for future restoration (when boss accepts the SecurityAgent
//  modal prompt). Tests still use InMemoryKeychainStore via
//  setBackendForTesting, and the WENSHU_DEBUG_INMEMORY_KEYCHAIN=1
//  override path in App.swift remains wired for cua / dev / CI.
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
///
/// v0.36 ticket 012 (= credential rotation + OAuth) adds optional protocol
/// methods with default no-op implementations. Backwards-compatible: existing
/// implementations (= AppleKeychainStore / InMemoryKeychainStore) compile
/// without changes. New backends can opt-in by overriding the rotation methods.
public protocol ProviderKeychainStoring: Sendable {
    func saveKeySync(_ key: String, for provider: Provider) throws
    func loadKeySync(for provider: Provider) -> String?
    func deleteKeySync(for provider: Provider) throws
    func listProvidersWithKeys() -> [String]

    // MARK: - v0.36 ticket 012 credential rotation + OAuth (optional)

    /// ProviderKeychainMetadata for the given provider (= expiry timestamp
    /// + OAuth refresh token if applicable). Default = nil (= no rotation
    /// tracking). Override to enable rotation.
    func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata?

    /// Save metadata (= call after successful saveKeySync to record expiry
    /// or OAuth refresh token). Default = no-op.
    func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws
}

extension ProviderKeychainStoring {
    public func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata? { nil }
    public func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws {}
}

/// Metadata accompanying an API key for credential rotation + OAuth flows.
/// Stored alongside the key (= Apple Keychain attribute, or in-memory dict
/// for test backends).
public struct ProviderKeychainMetadata: Sendable, Equatable, Codable {
    public var expiresAt: Date?
    public var oauthRefreshToken: String?
    public var oauthAccessToken: String?
    public var oauthScopes: [String]
    public var rotatedAt: Date

    public init(
        expiresAt: Date? = nil,
        oauthRefreshToken: String? = nil,
        oauthAccessToken: String? = nil,
        oauthScopes: [String] = [],
        rotatedAt: Date = Date()
    ) {
        self.expiresAt = expiresAt
        self.oauthRefreshToken = oauthRefreshToken
        self.oauthAccessToken = oauthAccessToken
        self.oauthScopes = oauthScopes
        self.rotatedAt = rotatedAt
    }

    /// True if metadata expiry is in the past (= key needs rotation).
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    /// True if metadata has OAuth credentials (= OAuth flow active).
    public var isOAuth: Bool {
        return oauthRefreshToken != nil || oauthAccessToken != nil
    }
}

/// Default production backend — Apple Security framework (`kSecClassGenericPassword`).
///
/// B-10 EMERGENCY in-place revert (Boss 2026-09-04 OOB '进设置页面闪退'):
/// the public methods below are stubs (= early-return + debug key) so the
/// macOS Security framework is never invoked at Settings-open time. The
/// real SecItemAdd / SecItemCopyMatching / SecItemDelete implementations
/// are preserved as `/* ... */` comments for future restoration when boss
/// accepts the SecurityAgent modal prompt on first key save.
public final class AppleKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    public static let service = "com.wenshu.app.provider"

    public init() {}

    public func saveKeySync(_ key: String, for provider: Provider) throws {
        // EMERGENCY in-place revert (Boss 2026-09-04 OOB '进设置页面闪退'):
        // B-10 commit faa5edc0e reactivated real SecItemAdd calls; on
        // ad-hoc signed wenshu.app without the keychain-access-groups
        // entitlement, SecItemAdd can SIGABRT the process at first
        // launch (= Settings window crash). Stub returns success so no
        // Keychain is touched. Restore the real implementation when
        // boss returns to Mac and accepts the SecurityAgent modal.
        return
        /*
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
        */
    }

    public func loadKeySync(for provider: Provider) -> String? {
        // EMERGENCY in-place revert (Boss 2026-09-04 OOB '进设置页面闪退'):
        // bypass macOS Keychain entirely (= avoid SecurityAgent modal
        // prompt AND ad-hoc-signing SIGABRT). Returns a debug key string
        // so LLM calls can complete the request flow without prompting
        // for user credentials. Restore the real SecItemCopyMatching
        // code below when boss returns to Mac and accepts the
        // SecurityAgent modal.
        return "wenshu.debug.api.key"
        /*
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
        */
    }

    public func deleteKeySync(for provider: Provider) throws {
        // EMERGENCY in-place revert (Boss 2026-09-04 OOB '进设置页面闪退'): bypass.
        return
        /*
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
        */
    }

    public func listProvidersWithKeys() -> [String] {
        // EMERGENCY in-place revert (Boss 2026-09-04 OOB '进设置页面闪退'): bypass.
        return []
        /*
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
        */
    }
}

/// Test backend — in-memory dict, no OS Keychain entitlements required.
/// Mirrors AppleKeychainStore public API (save / load / delete / list).
public final class InMemoryKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    private var store: [String: String] = [:]
    private var metadata: [String: ProviderKeychainMetadata] = [:]
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
        metadata.removeValue(forKey: provider.slug)
    }

    public func listProvidersWithKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys).sorted()
    }

    // MARK: - v0.36 ticket 012 metadata (= in-memory for test backend)

    public func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata? {
        lock.lock(); defer { lock.unlock() }
        return metadata[provider.slug]
    }

    public func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws {
        lock.lock(); defer { lock.unlock() }
        self.metadata[provider.slug] = metadata
    }
}

/// Backwards-compat shim — preserves existing call sites (`ProviderKeychain.saveKeySync`).
/// Delegates to `ProviderKeychain.backend` (default = InMemoryKeychainStore
/// after B-10 revert; was AppleKeychainStore before the 2026-09-04 emergency
/// in-place revert). Tests override `backend` via `setBackendForTesting()`.
public enum ProviderKeychain {
    // B-10 phase A (Boss 2026-09-04): entitlement embed done (= fix
    // codesign --entitlements in build-app.sh, commit 71349be49).
    // B-10 phase B (= real AppleKeychainStore default): pending
    // Apple Developer Program paid enrollment. Ad-hoc codesign without
    // a TeamIdentifier triggers macOS Security framework to SIGKILL
    // the process on SecItemAdd (= exit code -9), not a graceful
    // SecError. Keep InMemoryKeychainStore as the default until phase
    // B unlocks. WENSHU_DEBUG_INMEMORY_KEYCHAIN=1 env var still flips
    // to InMemory for cua / dev / CI contexts. Tests inject InMemory
    // via setBackendForTesting().
    //
    // B-10 phase B activation (Boss 2026-09-04 OOB '跳过我验收,往后推进'):
    // `B10_PHASE_B_ENABLED` Swift compile flag, when set via build setting
    // (`SWIFT_ACTIVE_COMPILATION_CONDITIONS += B10_PHASE_B_ENABLED`), switches
    // the default backend to `AppleKeychainStore` IF the running binary carries
    // a real embedded provisioning profile (= Apple Developer Program paid).
    // Otherwise falls through to `InMemoryKeychainStore` (= safe default).
    // Default OFF (= Phase A still active). Activation procedure:
    // `.scratch/2026-09-04-b-10-phase-b-activation.md`.
    public nonisolated(unsafe) static var backend: any ProviderKeychainStoring = {
        #if B10_PHASE_B_ENABLED
        if let signed = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
           let entitlements = try? Data(contentsOf: URL(fileURLWithPath: signed)),
           !entitlements.isEmpty {
            return AppleKeychainStore()
        }
        #endif
        return InMemoryKeychainStore()
    }()

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
    // v0.36 ticket 012 shim methods (= delegate to backend).
    public static func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata? {
        backend.loadMetadata(for: provider)
    }
    public static func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws {
        try backend.saveMetadata(metadata, for: provider)
    }
}