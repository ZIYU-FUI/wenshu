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
/// B-10 EMERGENCY in-place revert (Boss 2026-09-04 OOB 'Settings'):
/// the public methods below are stubs (= early-return + debug key) so the
/// macOS Security framework is never invoked at Settings-open time. The
/// real SecItemAdd / SecItemCopyMatching / SecItemDelete implementations
/// are preserved as `/* ... */` comments for future restoration when boss
/// accepts the SecurityAgent modal prompt on first key save.
public final class AppleKeychainStore: ProviderKeychainStoring, @unchecked Sendable {
    public static let service = "com.wenshu.app.provider"

    public init() {}

    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'build a remote-debug mode,
    /// once it's on, don't require the keychain — I can't test chat remotely otherwise, I can only poke at the UI': the
    /// Apple Security framework backend (SecItemAdd /
    /// SecItemCopyMatching / SecItemDelete) triggers the macOS
    /// SecurityAgent modal on ad-hoc-signed wenshu.app (= no
    /// Apple Developer Program paid enrollment = no embedded
    /// provisioning profile = securityd prompts on every keychain
    /// access). For the boss's off-site UI iteration (= no way to
    /// dismiss the modal remotely), this backend must NEVER touch
    /// the real keychain. The `wenshu.debugNoKeychain` UserDefaults
    /// (= set via `defaults write com.wenshu.app wenshu.debugNoKeychain
    /// -bool YES`) makes ALL Apple Security framework methods no-op
    /// (= saveKeySync = silent no-op; loadKeySync = nil; deleteKeySync
    /// = silent no-op; listProvidersWithKeys = empty array). The
    /// ProviderKeychain.backend lazy-init (= elsewhere in this
    /// file) ALSO checks the same UserDefaults and returns
    /// InMemoryKeychainStore when set; = belt-and-braces =
    /// the OS-level SecurityAgent modal is suppressed even if a
    /// future caller forgets the in-method check.
    private var debugNoKeychain: Bool {
        UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain")
    }

    public func saveKeySync(_ key: String, for provider: Provider) throws {
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'the configured key isn't persisted,
        // this needs to be implemented — going through the Apple Keychain API would be even better': restore the
        // real SecItemAdd implementation (= the canonical Apple
        // Security framework keychain path; = the canonical wenshu
        // architecture per AGENTS.md §11 hard rule 'API keys via
        // AppleKeychain NEVER plaintext SQLite'; = the previous
        // B-10 emergency revert stubbed this out because ad-hoc
        // signed wenshu.app triggered SecurityAgent modal + SIGABRT
        // on the Settings window). The canonical Apple HIG path for
        // API keys = the user's macOS Keychain = persists across
        // app restarts + sandbox-safe + encrypted at rest by the
        // OS. Per developer.apple.com/documentation/security/
        // keychain_services: `kSecClassGenericPassword` items with
        // `kSecAttrAccessibleAfterFirstUnlock` (= accessible after
        // the user logs in once; = the canonical 'user API key'
        // accessibility tier).
        //
        // Per AGENTS.md §11 baseline + boss direction 'going through the Apple
        // Keychain API would be even better': Apple Keychain is the canonical wenshu
        // path. This is the right restore.
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'build a remote-debug mode':
        // short-circuit when debugNoKeychain UserDefaults is set (= the
        // remote-debug mode toggle). Silent no-op (= no throw; =
        // callers = Settings Save button = silently accept and move on).
        if debugNoKeychain { return }
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
            // v0.24 bossverificationfix (2026-08-24): removed 'kSecUseDataProtectionKeychain: true'.
            // This iOS-only flag on macOS requires explicit entitlement
            // (kSecAttrAccessGroupFile or similar) and triggers -34018
            // errSecMissingEntitlement on ad-hoc signed apps. The default
            // (file-based) keychain on macOS works without entitlement.
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw ProviderKeychainError.keychainStatus(status) }
    }

    public func loadKeySync(for provider: Provider) -> String? {
        // v1.0.0-m1-shell: restore the real SecItemCopyMatching.
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'build a remote-debug mode,
        // once it's on, don't require the keychain — I can't test chat remotely otherwise, I can only poke at the UI': also
        // short-circuit the Apple Security framework call here (= the
        // OS-level SecurityAgent modal still prompts even when the
        // ProviderKeychain.backend lazy-init returned InMemoryKeychainStore;
        // = the OS scans the keychain at first access regardless of which
        // Swift object made the call; = the only way to suppress the
        // modal is to never enter SecItemCopyMatching at all). Check the
        // remote-debug UserDefaults at the top of every Apple Security
        // framework method (= saveKeySync / loadKeySync / deleteKeySync /
        // listProvidersWithKeys) and short-circuit (= saveKeySync /
        // deleteKeySync = no-op success; loadKeySync / listProvidersWithKeys
        // = nil / []). Belt-and-braces with the ProviderKeychain.backend
        // lazy-init override (= both paths converge to 'no keychain
        // touches' = boss can launch wenshu.app remotely without ever
        // seeing the SecurityAgent modal prompt).
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return nil
        }
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
        // v1.0.0-m1-shell: restore the real SecItemDelete.
        // See saveKeySync (= same remote-debug short-circuit).
        if debugNoKeychain { return }
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
        // v1.0.0-m1-shell: restore the real SecItemCopyMatching
        // (= queries all generic-password items under our service).
        // See loadKeySync (= same remote-debug short-circuit).
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return []
        }
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
    // B-10 phase B activation (Boss 2026-09-04 OOB 'skipverification,'):
    // `B10_PHASE_B_ENABLED` Swift compile flag, when set via build setting
    // (`SWIFT_ACTIVE_COMPILATION_CONDITIONS += B10_PHASE_B_ENABLED`), switches
    // the default backend to `AppleKeychainStore` IF the running binary carries
    // a real embedded provisioning profile (= Apple Developer Program paid).
    // Otherwise falls through to `InMemoryKeychainStore` (= safe default).
    // Default OFF (= Phase A still active). Activation procedure:
    // `.scratch/2026-09-04-b-10-phase-b-activation.md`.
    //
    // v0.40 fix (apple-001 phase 1 candidate A-revised): the WENSHU_DEBUG_INMEMORY_KEYCHAIN
    // env check is honoured eagerly here (= the test helper process never calls
    // WenshuAppDelegate.applicationWillFinishLaunching, so the lazy init in
    // WenshuAppDelegate.sharedKeychainBackend never fires in tests; reading the env
    // var here at first access guarantees test bundles pick InMemoryKeychainStore
    // without touching the real Apple Keychain (= avoids securityd IPC hang in
    // macOS 27 when running swift test). Production builds never set this env var,
    // so production behavior is unchanged.
    // v1.0.0-m1-shell boss 2026-09-10 OOB 'the configured key isn't persisted — needs
    // to be implemented; going through the Apple Keychain API would be even better': flip the default
    // backend back to AppleKeychainStore (= the canonical wenshu
    // path per AGENTS.md §11 hard rule 'API keys via AppleKeychain
    // NEVER plaintext SQLite'; = the previous B-10 revert flipped
    // the default to InMemoryKeychainStore as an emergency stop-
    // gap to avoid ad-hoc-signing SIGABRT on the Settings window).
    //
    // The AppleKeychainStore's public methods are now restored
    // (= SecItemAdd / SecItemCopyMatching / SecItemDelete / list
    // over real macOS Keychain). The WENSHU_DEBUG_INMEMORY_KEYCHAIN=1
    // env var remains as an opt-in escape hatch (= for cua / dev /
    // CI contexts where ad-hoc signing triggers SecurityAgent modal
    // = production users never see this).
    //
    // Production path = AppleKeychainStore (= the user's macOS
    // Keychain = persists across app restarts + encrypted at rest
    // by the OS + sandbox-safe + survives wenshu updates).
    public nonisolated(unsafe) static var backend: any ProviderKeychainStoring = {
        // apple-001 phase 1 candidate A-revised: eager env-var check
        // (= test bundles that never call applicationWillFinishLaunching
        // still honor the override; = cua / dev / CI overrides also
        // honored).
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'build a remote-debug mode,
        // once it's on, don't require the keychain — I can't test chat remotely otherwise, I can only poke at the UI':
        // add a UserDefaults-based remote-debug switch (= boss is
        // off-site, = the macOS Keychain prompt for ad-hoc-signed
        // wenshu.app hangs onboarding with no remote way to dismiss
        // it; = for UI iteration over NavigationSplitView / sidebar
        // / preview / editor / chat layout, the boss needs to be
        // able to launch wenshu.app WITHOUT touching keychain at
        // all). 3 sources of the override, checked in this order
        // (= first hit wins):
        // 1. `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1` env var (cua / dev
        //    / CI; pre-existing convention from B-10 phase A).
        // 2. UserDefaults key `wenshu.debugNoKeychain = YES` (NEW;
        //    boss-set on the company Mac via `defaults write com.wenshu.
        //    app wenshu.debugNoKeychain -bool YES` before launching
        //    wenshu.app via `open`; = persists across launches; = the
        //    canonical 'remote debug mode' toggle for off-site UI
        //    iteration).
        // 3. Default: AppleKeychainStore (= the production path; =
        //    the user's real API keys).
        //
        // Override flips the backend to InMemoryKeychainStore (=
        // loadKeySync returns nil for every provider = ChatZoneView
        // shows the empty-state hint 'please configure the LLM provider in Settings first'
        // = no LLM call can be sent = boss can iterate on UI
        // without ever touching macOS Keychain).
        if ProcessInfo.processInfo.environment["WENSHU_DEBUG_INMEMORY_KEYCHAIN"] == "1" {
            return InMemoryKeychainStore()
        }
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return InMemoryKeychainStore()
        }
        return AppleKeychainStore()
    }()

    /// Test-only override. Production code must never call this.
    public static func setBackendForTesting(_ store: any ProviderKeychainStoring) {
        backend = store
    }

    public static func saveKeySync(_ key: String, for provider: Provider) throws {
        // v1.0.0-m1-shell: belt-and-braces remote-debug short-circuit
        // at the ProviderKeychain shim level (= the dispatch layer
        // that all call sites reach). Combined with the backend lazy
        // init override (= InMemoryKeychainStore when
        // `wenshu.debugNoKeychain = YES`) and the AppleKeychainStore
        // method-level short-circuits (= every SecItem* call is
        // no-op'd), this gives 3 layers of defense against the
        // macOS SecurityAgent modal prompt.
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return
        }
        try backend.saveKeySync(key, for: provider)
    }
    public static func loadKeySync(for provider: Provider) -> String? {
        // See saveKeySync.
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return nil
        }
        return backend.loadKeySync(for: provider)
    }
    public static func deleteKeySync(for provider: Provider) throws {
        // See saveKeySync.
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return
        }
        try backend.deleteKeySync(for: provider)
    }
    public static func listProvidersWithKeys() -> [String] {
        // See saveKeySync.
        if UserDefaults.standard.bool(forKey: "wenshu.debugNoKeychain") {
            return []
        }
        return backend.listProvidersWithKeys()
    }
    // v0.36 ticket 012 shim methods (= delegate to backend).
    public static func loadMetadata(for provider: Provider) -> ProviderKeychainMetadata? {
        backend.loadMetadata(for: provider)
    }
    public static func saveMetadata(_ metadata: ProviderKeychainMetadata, for provider: Provider) throws {
        try backend.saveMetadata(metadata, for: provider)
    }
}