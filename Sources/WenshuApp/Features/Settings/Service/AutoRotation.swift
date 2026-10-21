//
//  AutoRotation.swift
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
// dispatch layer 4 of 4. Refs: the (see OOB.md) 'A' 2026-09-04.
//

import Foundation
import WenshuAgent
import os

// MARK: - Policy

private let wenshuRotationLogger = Logger(subsystem: "org.wenshu.auth", category: "rotation")

// MARK: - Inner-send abstraction

/// Abstraction over the inner connector + key the wrapper rotates on.
///
/// Production wiring supplies a closure that:
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
struct AutoRotationSendContext: Sendable {
    let provider: String
    let keyId: UUID?
    init(provider: String, keyId: UUID? = nil) {
        self.provider = provider
        self.keyId = keyId
    }
}

// MARK: - Error classification shim

/// Bridges `LLMConnectorError` (+ arbitrary errors) into the policy's
/// rotation decisions. Mirrors `LLMConnectorErrorClassifier.isTransient` so the
/// wrapper can decide whether to rotate without duplicating the
/// HTTP-status-code-to-category mapping.
enum ClassifiedLLMErrorPolicy {
    struct Snapshot: Sendable, Equatable {
        let statusCode: Int?
        let category: LLMErrorCategory
        let userMessage: String
    }

    static func classify(error: Error) -> Snapshot {
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
        // Fall back to string-based classification (matches the retry ladder's
        // own transient check).
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
