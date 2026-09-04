//
//  AuthPool.swift · Wenshu · HERMES-DISPATCH-001
//
//  Multi-key credential pool with status state machine + disk persistence.
//  Ported from hermes-agent `agent/credential_pool.py` (2,384 LOC Python)
//  + `agent/credential_persistence.py` (174 LOC). Boss 2026-09-04 OOB 'A'
//  requested the dispatch layer (= AuthPool / FallbackChain / KeychainSelector
//  / AutoRotation) so the wenshu 7-connector + BYOK stack survives the first
//  429 / 503 / 401 it encounters.
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern:
//    - Python `threading.Lock` over dataclass list -> Swift `actor` over
//      Sendable struct array.
//    - Python `_save_auth_store` (atomic write to auth.json) -> Swift
//      `Data.write(to:options: .atomic)`.
//    - Python `STATUS_OK / STATUS_EXHAUSTED / STATUS_DEAD` (3 states) ->
//      Swift `AuthKeyStatus` (6 cases per boss spec = the dispatch surface
//      callers need for richer routing decisions).
//    - Storage path = `~/.wenshu/auth.json` (= mirrors hermes' ~/.hermes/auth.json
//      layout). Persistence is optional (= wenshu already has ProviderKeychain
//      as the production key path; AuthPool's JSON is the multi-key dispatch
//      layer sitting ABOVE it). Callers can keep pool in-memory only by passing
//      nil `persistenceRoot`.
//    - Credentials live in the AuthKey struct (= "the actual API key string"),
//      NOT in ProviderKeychain. The two layers do not duplicate: AuthPool is
//      the multi-key pool with status state machine; ProviderKeychain is the
//      single-key secure storage backend (= per AGENTS.md §11.3, do not
//      re-implement keychain). Future wiring can hand AuthPool.credential
//      through ConnectorCredentials (= the wenshu-side wins preserved by the
//      hard rule).
//
//  Public API is `Sendable` (= safe for Swift 6 strict concurrency). Pool state
//  lives inside the actor (= Swift 6 actor isolation). Public API mirrors
//  hermes' `CredentialPool` shape (register / list / pick / mark-* / persist).
//
//  v0.40 dispatch layer 1 of 4. Refs: boss OOB 'A' 2026-09-04.
//

import Foundation

// MARK: - Status state machine

/// Per-key status. Mirrors hermes `STATUS_OK / STATUS_EXHAUSTED / STATUS_DEAD`
/// (3 states) extended with 3 wenshu-side cases the dispatch layer needs
/// for richer routing: `authFailed` (401/403 = permanent until re-keyed),
/// `networkError` (transient), `quotaExhausted` (account-level quota = 24h
/// cooldown).
public enum AuthKeyStatus: String, Sendable, Codable, Equatable, CaseIterable {
    /// Last call succeeded (= eligible for selection).
    case ok
    /// 429 received (= cooldown until `cooldownUntil`).
    case rateLimited
    /// 401/403 received (= permanent until re-keyed by user).
    case authFailed
    /// Timeout / DNS failure (= transient; eligible after short cooldown).
    case networkError
    /// Account-level quota (= cooldown ~24h).
    case quotaExhausted
    /// Manually disabled by user (= never selected until re-enabled).
    case disabled

    /// True if a key with this status should never be selected
    /// (= authFailed / disabled are permanently out).
    public var isPermanentlyOut: Bool {
        switch self {
        case .authFailed, .disabled: return true
        case .ok, .rateLimited, .networkError, .quotaExhausted: return false
        }
    }
}

// MARK: - AuthKey

/// A single credential entry (= hermes `PooledCredential`).
///
/// `credential` is the actual API key string (= or OAuth access token). For
/// wenshu production, callers typically resolve via ProviderKeychain and pass
/// the resulting string into `AuthPool.register`; AuthPool itself does NOT
/// touch the macOS Keychain (= that's ProviderKeychain's job per §11.3).
public struct AuthKey: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let provider: String       // "anthropic" / "openai" / etc.
    public var credential: String      // the API key
    public var priority: Int          // 0 = highest; default 0
    public var status: AuthKeyStatus
    public var lastUsedAt: Date?
    public var lastError: String?
    public var cooldownUntil: Date?    // rate-limited until this time

    public init(
        id: UUID = UUID(),
        provider: String,
        credential: String,
        priority: Int = 0,
        status: AuthKeyStatus = .ok,
        lastUsedAt: Date? = nil,
        lastError: String? = nil,
        cooldownUntil: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.credential = credential
        self.priority = priority
        self.status = status
        self.lastUsedAt = lastUsedAt
        self.lastError = lastError
        self.cooldownUntil = cooldownUntil
    }
}

// MARK: - On-disk schema

/// On-disk JSON envelope. Stable across `persist` / `loadFromDisk` round trips.
struct AuthPoolSnapshot: Codable {
    var version: Int
    var keys: [AuthKey]

    static let currentVersion = 1
}

// MARK: - Errors

public enum AuthPoolError: Error, LocalizedError, Sendable, Equatable {
    case persistenceRootUnavailable
    case persistenceFailure(underlying: String)
    case keyNotFound(id: UUID)
    case emptyCredential

    public var errorDescription: String? {
        switch self {
        case .persistenceRootUnavailable:
            return "No writable persistence root available for AuthPool."
        case .persistenceFailure(let s):
            return "AuthPool persistence failed: \(s)"
        case .keyNotFound(let id):
            return "AuthPool: no key with id \(id)."
        case .emptyCredential:
            return "AuthPool: refusing to register an empty credential."
        }
    }
}

// MARK: - AuthPool actor

/// The credential pool (= hermes `CredentialPool` shape).
///
/// Holds in-memory `[AuthKey]` keyed by `provider`. `persist()` snapshots to
/// `<persistenceRoot>/auth.json` atomically; `loadFromDisk()` rehydrates from
/// the same path. With `persistenceRoot == nil`, the pool is in-memory only
/// (= useful for tests + ephemeral dispatch).
///
/// All mutating methods are actor-isolated; the struct values returned by
/// reads are `Sendable` so they can cross actor boundaries safely.
public actor AuthPool {

    private var keys: [AuthKey] = []
    /// nil = in-memory only.
    private let persistenceRoot: URL?
    /// File location for the JSON snapshot (= `<root>/auth.json`).
    private let snapshotURL: URL?

    /// Initialize.
    /// - Parameter persistenceRoot: directory where `auth.json` is written.
    ///   When nil, the pool is in-memory only. When provided, the directory
    ///   is created lazily on first `persist()`.
    public init(persistenceRoot: URL? = nil) {
        self.persistenceRoot = persistenceRoot
        self.snapshotURL = persistenceRoot?.appendingPathComponent("auth.json", isDirectory: false)
    }

    /// The default persistence root for wenshu (= mirrors hermes' HERMES_HOME).
    /// `~/.wenshu/auth.json` on disk; returns nil if the home directory cannot
    /// be resolved (= e.g. containerized test environments without $HOME).
    public static func defaultPersistenceRoot() -> URL? {
        let fm = FileManager.default
        guard let home = fm.homeDirectoryForCurrentUser as URL? else { return nil }
        return home.appendingPathComponent(".wenshu", isDirectory: true)
    }

    // MARK: Registration / read

    /// Register a new credential. Returns the created `AuthKey` (= its `id`).
    /// New keys default to `.ok` status, priority = next-slot for the provider
    /// (or `priority` argument when supplied).
    @discardableResult
    public func register(
        provider: String,
        credential: String,
        priority: Int = 0
    ) async throws -> AuthKey {
        guard !credential.isEmpty else { throw AuthPoolError.emptyCredential }
        let key = AuthKey(
            provider: provider,
            credential: credential,
            priority: priority,
            status: .ok
        )
        keys.append(key)
        try await persistIfRooted()
        return key
    }

    /// All keys for a provider (= sorted by priority ascending = 0 first).
    public func keys(for provider: String) async throws -> [AuthKey] {
        keys.filter { $0.provider == provider }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// All keys in the pool (= unsorted). Used by tests + diagnostics.
    public func allKeys() async -> [AuthKey] {
        keys
    }

    /// The single best key for a provider per the `KeychainSelector` rules
    /// (= lowest score = highest priority AND `.ok` status AND cooldown
    /// elapsed). Returns nil when no usable key exists.
    public func pickBestKey(for provider: String) async throws -> AuthKey? {
        let candidates = try await keys(for: provider)
        return KeychainSelector.pick(from: candidates)
    }

    /// Remove a key (= caller-driven; used by `disable` plus permanent
    /// removal flows).
    public func remove(keyId: UUID) async throws {
        let before = keys.count
        keys.removeAll { $0.id == keyId }
        if keys.count != before {
            try await persistIfRooted()
        }
    }

    // MARK: State machine transitions

    /// Mark a key as rate-limited. Sets `status = .rateLimited` and
    /// `cooldownUntil = now + cooldownSeconds`. Idempotent.
    public func markRateLimited(keyId: UUID, cooldownSeconds: TimeInterval) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .rateLimited
            key.lastError = "rate-limited"
            key.cooldownUntil = Date().addingTimeInterval(cooldownSeconds)
            key.lastUsedAt = Date()
        }
    }

    /// Mark a key as auth-failed (= 401 / 403). Permanent until re-keyed;
    /// the selector will not pick this key again until the caller re-enables
    /// it (= e.g. via a fresh `register` for the same slot or explicit
    /// `markOk` after the user rotates the credential).
    public func markAuthFailed(keyId: UUID, error: String) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .authFailed
            key.lastError = error
            key.cooldownUntil = nil
        }
    }

    /// Mark a key as ok after a successful call. Resets `lastError` and
    /// clears `cooldownUntil`.
    public func markOk(keyId: UUID) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .ok
            key.lastError = nil
            key.cooldownUntil = nil
            key.lastUsedAt = Date()
        }
    }

    /// Mark a key as network-error (= transient). Sets short cooldown so the
    /// selector skips it briefly without marking it permanently bad.
    public func markNetworkError(keyId: UUID, error: String) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .networkError
            key.lastError = error
            // 10-second cooldown matches ErrorClassifier.retryAfterSeconds for
            // networkUnreachable category (= hermes' default for transport
            // blips). Caller can override via a future explicit cooldown setter.
            key.cooldownUntil = Date().addingTimeInterval(10)
            key.lastUsedAt = Date()
        }
    }

    /// Mark a key as quota-exhausted. Sets 24h cooldown.
    public func markQuotaExhausted(keyId: UUID, error: String) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .quotaExhausted
            key.lastError = error
            key.cooldownUntil = Date().addingTimeInterval(24 * 60 * 60)
        }
    }

    /// Manually disable a key (= user action). Selector will never pick it.
    /// Re-enable via `markOk`.
    public func disable(keyId: UUID) async throws {
        try await mutate(keyId: keyId) { key in
            key.status = .disabled
            key.lastError = nil
            key.cooldownUntil = nil
        }
    }

    // MARK: Persistence

    /// Snapshot the pool to `<persistenceRoot>/auth.json`. Atomic write
    /// (= `Data.write(to:options: .atomic)`).
    public func persist() async throws {
        try await persistIfRooted()
    }

    /// Rehydrate from disk. Replaces in-memory state. Throws on decode
    /// failure (caller decides whether to fall back to empty pool).
    public func loadFromDisk() async throws {
        guard let url = snapshotURL else {
            // No rooted path = in-memory pool = nothing to load.
            return
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(AuthPoolSnapshot.self, from: data)
        keys = snapshot.keys
    }

    // MARK: Private helpers

    /// Run a mutation against the keyed entry, throwing if not found,
    /// then persist if rooted.
    private func mutate(
        keyId: UUID,
        _ body: (inout AuthKey) -> Void
    ) async throws {
        guard let idx = keys.firstIndex(where: { $0.id == keyId }) else {
            throw AuthPoolError.keyNotFound(id: keyId)
        }
        var key = keys[idx]
        body(&key)
        keys[idx] = key
        try await persistIfRooted()
    }

    /// Persist if a root was supplied (= silently no-op for in-memory pools).
    private func persistIfRooted() async throws {
        guard let root = persistenceRoot, let url = snapshotURL else { return }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let snapshot = AuthPoolSnapshot(version: AuthPoolSnapshot.currentVersion, keys: keys)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw AuthPoolError.persistenceFailure(underlying: String(describing: error))
        }
    }
}
