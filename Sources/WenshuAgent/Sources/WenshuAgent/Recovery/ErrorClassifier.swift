// ErrorClassifier.swift
//
// Classify errors from `LLMConnector.send()` into actionable categories
// (= rate-limit, auth, network, server, bad-request, unknown). The
// classifier enables the caller (= `ChatViewModel`) to surface
// user-friendly error messages + decide retry policy without
// inspecting raw URLSession / Foundation errors.
//
// Pure Swift (= no external deps; per wenshu §11 hard rule + ADR-0011
// no LLM calls in classifier path).

import Foundation
import WenshuAgent

/// Error category (= single source of truth for user-facing error messages
/// + retry policy). Use these categories instead of raw error types
/// (= URLSession errors, decoding errors, HTTP status codes).
public enum LLMErrorCategory: String, Sendable, Equatable, Codable, CaseIterable {
    /// 429 Too Many Requests (= provider rate limit hit; back off + retry).
    case rateLimit
    /// 401 Unauthorized / 403 Forbidden (= API key invalid or scope issue).
    case unauthorized
    /// Network unreachable / DNS failure / TLS handshake error (= retry).
    case networkUnreachable
    /// 5xx server error (= provider outage; back off + retry).
    case serverError
    /// 400 Bad Request (= malformed request; do NOT retry; fix payload).
    case badRequest
    /// Context length exceeded (= 400 with specific error type; do NOT retry).
    case contextLengthExceeded
    /// Model not found / deprecated (= 404; user must change model selection).
    case modelNotFound
    /// Unknown / unexpected (= fall back to default message).
    case unknown
}

// MARK: - LLMConnectorError classifier (wenshu port wire-up)

/// Classify an `LLMConnectorError` as transient (= retryable) or
/// non-transient (= fail fast). Mirrors hermes `classify_api_error`'s
/// retry-eligibility surface (= hermes retries on rate-limit +
/// server-error + transient transport, fails on auth + bad-request).
///
/// ConversationLoop.runTurn() uses this to decide whether to retry
/// after a thrown `LLMConnectorError`. Default behaviour (= no
/// classifier) is "fail fast" (= never retry); ConversationLoop injects
/// an instance that respects the LLMErrorCategory.isRetryable mapping.
public enum LLMConnectorErrorClassifier {

    /// True when the error is classified as transient (= retryable).
    /// The mapping follows the same categories the rest of the retry ladder
    /// uses (= rate limit + server error + transport blips).
    public static func isTransient(_ error: LLMConnectorError) -> Bool {
        switch error {
        case .transport(let provider, let statusCode, _):
            // 429 (rate limit) + 5xx (server error) = retryable.
            // 4xx other than 429 = non-retryable (= bad request, auth).
            if statusCode == 429 { return true }
            if (500...599).contains(statusCode) { return true }
            _ = provider
            return false
        case .decode:
            // Decode errors are usually non-retryable (= provider
            // returned a malformed response; retrying won't help).
            return false
        case .missingAPIKey, .unsupportedProvider, .streamingFailed:
            // All other variants are configuration / wire-level issues
            // that won't be fixed by retrying.
            return false
        }
    }
}
