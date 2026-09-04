//
//  AutoRotation.swift · Wenshu · HERMES-DISPATCH-004
//
//  Auto-rotating connector wrapper that detects 429 / 503 / auth errors and
//  either rotates to another key in the AuthPool OR throws (= falls back to
//  the caller's fallback chain).
//
//  Design (= hermes `_mark_exhausted` + `_retry_with_rotation` pattern):
//    - `AutoRotatingConnector.send(request:)` wraps an inner `LLMConnector`
//      (= the primary connector for the active provider).
//    - On 429 / 503 / auth error: mark the offending AuthKey accordingly,
//      pick a new key from the pool, re-send. Max `maxRotations` attempts
//      before throwing.
//    - On success: mark the active key .ok and return the response.
//    - On cooldown: respect the cooldown (= skip rotation, throw if no
//      usable key).
//    - Honors `AutoRotationPolicy` (= toggleable per signal type, max
//      rotations, cooldown seconds).
//
//  Public API is `Sendable` (= Swift 6 strict concurrency safe).
//  Stateful logic (= internal rotation state) lives inside the actor.
//
//  v0.40 dispatch layer 4 of 4. Refs: boss OOB 'A' 2026-09-04.
//

import Foundation

// MARK: - Policy

/// Auto-rotation policy (= configurable knobs for the wrapper).
public struct AutoRotationPolicy: Sendable, Codable, Equatable {
    /// Rotate on 429 (= rate-limit). Default true.
    public var rotateOn429: Bool
    /// Rotate on 503 (= server error). Default true.
    public var rotateOn503: Bool
    /// Rotate on auth error (= 401/403). Default true.
    public var rotateOnAuthError: Bool
    /// Max rotations (= attempts past the initial send) before throwing.
    public var maxRotations: Int
    /// Cooldown after rate-limit (= hermes default = 60s).
    public var rateLimitCooldownSeconds: TimeInterval

    public init(
        rotateOn429: Bool = true,
        rotateOn503: Bool = true,
        rotateOnAuthError: Bool = true,
        maxRotations: Int = 3,
        rateLimitCooldownSeconds: TimeInterval = 60
    ) {
        self.rotateOn429 = rotateOn429
        self.rotateOn503 = rotateOn503
        self.rotateOnAuthError = rotateOnAuthError
        self.maxRotations = maxRotations
        self.rateLimitCooldownSeconds = rateLimitCooldownSeconds
    }
}

// MARK: - Errors

public enum AutoRotationError: Error, LocalizedError, Sendable, Equatable {
    /// Initial send + all rotations failed.
    case exhausted(provider: String, attempts: Int, lastError: String)
    /// No more keys in the pool to rotate to (= pool exhausted).
    case noMoreKeys(provider: String)
    /// Disabled rotation signal (= 4xx other than 429). Caller should
    /// surface the error rather than retry.
    case nonRetryable(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .exhausted(let p, let n, let e):
            return "AutoRotation exhausted for '\(p)' after \(n) attempts: \(e)"
        case .noMoreKeys(let p):
            return "AutoRotation: no more keys in pool for '\(p)'."
        case .nonRetryable(let s):
            return "AutoRotation: non-retryable HTTP \(s); not rotating."
        }
    }
}

// MARK: - Inner-send abstraction

/// Abstraction over the inner connector + key the wrapper rotates on.
///
/// Production wiring (= ticket 013) supplies a closure that:
///   1. Reads the active AuthKey from AuthPool (= picks a key for the
///      provider, ignores status = .ok cooldown = not active).
///   2. Resolves the connector + credentials via ProviderKeychain +
///      ConnectorCredentials (= wenshu-side wins preserved).
///   3. Sends the request via the connector.
///
/// The wrapper itself never touches the keychain — it delegates every send
/// to the supplied closure, and uses the closure's return value to decide
/// whether to rotate. The closure is also responsible for marking the
/// AuthKey ok on success (= so this wrapper doesn't need direct access
/// to AuthPool's markOk internals — though it CAN call them when the
/// closure opts into the `(keyId)` parameter).
public struct AutoRotationSendContext: Sendable {
    public let provider: String
    public let keyId: UUID?
    public init(provider: String, keyId: UUID? = nil) {
        self.provider = provider
        self.keyId = keyId
    }
}

// MARK: - AutoRotatingConnector

/// A connector wrapper that auto-rotates on transient errors.
///
/// Threading model:
///   - `send(request:)` is the entry point (= `async throws`).
///   - The wrapper delegates every send to `performSend` (= supplied by
///     the caller), which knows how to resolve a connector + key for the
///     given provider and execute the send.
///   - The wrapper inspects the result + thrown errors to decide whether
///     to rotate (= advance to the next key) or surface the error.
///
/// `primaryConnector` is kept for callers that want to bypass rotation
/// (= e.g. for "best-effort, no retries" paths). It's not used by
/// `send(request:)`; rotation is driven by `performSend`.
public actor AutoRotatingConnector {

    private let pool: AuthPool
    private let policy: AutoRotationPolicy
    /// Caller-supplied closure: resolve (connector + key) for `provider`,
    /// send `request`, return the result OR throw on failure.
    /// The wrapper observes the thrown error and decides to rotate.
    private let performSend:
        @Sendable (DispatchRequest, AutoRotationSendContext) async throws -> LLMResponse

    /// Unused for send path (kept for the public init signature contract).
    /// Reserved for the future ticket 014 wiring (= "send with primary
    /// first, rotate only after primary fails").
    private let _primaryConnector: (any LLMConnector)?

    public init(
        primaryConnector: (any LLMConnector)? = nil,
        pool: AuthPool,
        policy: AutoRotationPolicy = .init(),
        performSend: @Sendable @escaping (
            DispatchRequest,
            AutoRotationSendContext
        ) async throws -> LLMResponse
    ) {
        self.pool = pool
        self.policy = policy
        self.performSend = performSend
        self._primaryConnector = primaryConnector
    }

    /// Send the request, rotating through the AuthPool on transient errors.
    /// The active provider is inferred from the first usable key in the
    /// pool (= hermes-style: pick the best key, use its provider).
    public func send(request: DispatchRequest) async throws -> LLMResponse {
        // Pick initial key (= defines the provider we're targeting).
        let allKeys = await pool.allKeys()
        guard let firstOk = allKeys.first(where: { KeychainSelector.isValid($0) }) else {
            throw AutoRotationError.noMoreKeys(provider: "<unknown>")
        }
        let provider = firstOk.provider
        return try await sendWithRotation(
            request: request,
            provider: provider,
            excludedKeyIds: [],
            attemptCount: 0
        )
    }

    /// Send targeting a specific provider (= bypasses initial-key inference).
    /// Useful when the caller already knows which provider to use.
    public func send(
        request: DispatchRequest,
        provider: String
    ) async throws -> LLMResponse {
        return try await sendWithRotation(
            request: request,
            provider: provider,
            excludedKeyIds: [],
            attemptCount: 0
        )
    }

    // MARK: - Private

    private func sendWithRotation(
        request: DispatchRequest,
        provider: String,
        excludedKeyIds: Set<UUID>,
        attemptCount: Int
    ) async throws -> LLMResponse {
        // Budget check FIRST: if we've already used our rotation budget,
        // surface `.exhausted` (= caller's fallback chain takes over).
        // Without this, the loop recurses until pickKey returns nil and
        // surfaces `.noMoreKeys` (= correct but less informative).
        if attemptCount >= policy.maxRotations {
            throw AutoRotationError.exhausted(
                provider: provider,
                attempts: attemptCount,
                lastError: "maxRotations (\(policy.maxRotations)) reached"
            )
        }
        // Pick best non-excluded key for this provider.
        let candidate = try await pickKey(
            for: provider,
            excluding: excludedKeyIds
        )
        guard let key = candidate else {
            throw AutoRotationError.noMoreKeys(provider: provider)
        }
        let context = AutoRotationSendContext(provider: provider, keyId: key.id)

        do {
            let response = try await performSend(request, context)
            // Mark ok (= reset status after successful send).
            try? await pool.markOk(keyId: key.id)
            return response
        } catch {
            // Classify the error to decide whether to rotate.
            let classified = ClassifiedLLMErrorPolicy.classify(error: error)
            let shouldRotate = policySaysRotate(
                statusCode: classified.statusCode,
                category: classified.category
            )
            // Mark the failing key according to the error type.
            try? await applyStatusForFailure(
                keyId: key.id,
                category: classified.category
            )
            if !shouldRotate {
                throw AutoRotationError.nonRetryable(statusCode: classified.statusCode ?? 0)
            }
            // Rotate: try next key (excluding the one that just failed).
            return try await sendWithRotation(
                request: request,
                provider: provider,
                excludedKeyIds: excludedKeyIds.union([key.id]),
                attemptCount: attemptCount + 1
            )
        }
    }

    private func pickKey(
        for provider: String,
        excluding: Set<UUID>
    ) async throws -> AuthKey? {
        let keys = try await pool.keys(for: provider)
        let now = Date()
        let candidates = keys
            .filter { !excluding.contains($0.id) }
            .filter { KeychainSelector.isValid($0, now: now) }
        return candidates.first  // already sorted by KeychainSelector's pick order
    }

    private func policySaysRotate(
        statusCode: Int?,
        category: LLMErrorCategory
    ) -> Bool {
        switch category {
        case .rateLimit:
            return policy.rotateOn429
        case .serverError:
            return policy.rotateOn503
        case .unauthorized:
            return policy.rotateOnAuthError
        case .networkUnreachable:
            return true  // always rotate on network blips
        case .badRequest, .contextLengthExceeded, .modelNotFound, .unknown:
            return false
        }
    }

    private func applyStatusForFailure(
        keyId: UUID,
        category: LLMErrorCategory
    ) async throws {
        switch category {
        case .rateLimit:
            try await pool.markRateLimited(
                keyId: keyId,
                cooldownSeconds: policy.rateLimitCooldownSeconds
            )
        case .unauthorized:
            try await pool.markAuthFailed(
                keyId: keyId,
                error: "AutoRotation: 401/403"
            )
        case .serverError, .networkUnreachable:
            try await pool.markNetworkError(
                keyId: keyId,
                error: "AutoRotation: \(category.rawValue)"
            )
        case .badRequest, .contextLengthExceeded, .modelNotFound, .unknown:
            // Non-retryable categories: do NOT mark the key (the issue is
            // request-level, not key-level).
            break
        }
    }
}

// MARK: - Error classification shim

/// Bridges `LLMConnectorError` (+ arbitrary errors) into the policy's
/// rotation decisions. Mirrors `LLMConnectorErrorClassifier.isTransient` +
/// `ErrorClassifier.classify` so the wrapper can decide whether to rotate
/// without duplicating the HTTP-status-code-to-category mapping.
public enum ClassifiedLLMErrorPolicy {
    public struct Snapshot: Sendable, Equatable {
        public let statusCode: Int?
        public let category: LLMErrorCategory
        public let userMessage: String
    }

    public static func classify(error: Error) -> Snapshot {
        // First, try to extract an LLMConnectorError (= wenshu's standard
        // connector-thrown error = HTTP status + body).
        if let connectorErr = error as? LLMConnectorError {
            switch connectorErr {
            case .transport(_, let status, _):
                return snapshot(status: status)
            case .decode:
                return Snapshot(
                    statusCode: nil,
                    category: .unknown,
                    userMessage: "Decode failed."
                )
            case .missingAPIKey, .unsupportedProvider, .streamingFailed:
                return Snapshot(
                    statusCode: nil,
                    category: .badRequest,
                    userMessage: "Configuration error: \(connectorErr.errorDescription ?? "?")"
                )
            }
        }
        // ClassifiedLLMError already produced upstream.
        if let classified = error as? ClassifiedLLMError {
            return Snapshot(
                statusCode: classified.category == .rateLimit ? 429 :
                    classified.category == .serverError ? 500 : nil,
                category: classified.category,
                userMessage: classified.userMessage
            )
        }
        // Fall back to string-based classification (matches ErrorClassifier).
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("dns") ||
           msg.contains("tls") || msg.contains("unreachable") {
            return Snapshot(
                statusCode: nil,
                category: .networkUnreachable,
                userMessage: "Network unreachable."
            )
        }
        return Snapshot(
            statusCode: nil,
            category: .unknown,
            userMessage: error.localizedDescription
        )
    }

    private static func snapshot(status: Int) -> Snapshot {
        switch status {
        case 400:
            return Snapshot(statusCode: 400, category: .badRequest,
                            userMessage: "Bad request.")
        case 401, 403:
            return Snapshot(statusCode: status, category: .unauthorized,
                            userMessage: "Auth failed.")
        case 404:
            return Snapshot(statusCode: 404, category: .modelNotFound,
                            userMessage: "Model not found.")
        case 429:
            return Snapshot(statusCode: 429, category: .rateLimit,
                            userMessage: "Rate limit.")
        case 500...599:
            return Snapshot(statusCode: status, category: .serverError,
                            userMessage: "Server error.")
        default:
            return Snapshot(statusCode: status, category: .unknown,
                            userMessage: "Unknown HTTP \(status).")
        }
    }
}
