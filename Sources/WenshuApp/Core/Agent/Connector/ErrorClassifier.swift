//
//  ErrorClassifier.swift · Wenshu · v0.36 ticket 015 sub-step 2
//
//  Classify errors from LLMConnector.send() into actionable categories
//  (= rate-limit, auth, network, server, bad-request, unknown).
//
//  Per spec §3.1 L209-210 + hermes-port: enables caller (= ChatViewModel)
//  to surface user-friendly error messages + decide retry policy
//  without inspecting raw URLSession / Foundation errors.
//
//  Pure Swift (= no external deps; per wenshu §11 hard rule + ADR-0011
//  no LLM calls in classifier path).
//
//  v0.36 sub-step 2 of 3 for ticket 015.
//

import Foundation

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

/// Classified error (= category + raw underlying + optional user message).
public struct ClassifiedLLMError: Error, Sendable, Equatable {
    public let category: LLMErrorCategory
    public let underlying: String
    public let userMessage: String
    public let isRetryable: Bool
    public let retryAfterSeconds: Int?

    public init(
        category: LLMErrorCategory,
        underlying: String,
        userMessage: String,
        isRetryable: Bool,
        retryAfterSeconds: Int? = nil
    ) {
        self.category = category
        self.underlying = underlying
        self.userMessage = userMessage
        self.isRetryable = isRetryable
        self.retryAfterSeconds = retryAfterSeconds
    }
}

/// Classify any Error from LLMConnector.send() into LLMErrorCategory.
/// Inspects URLResponse status code + underlying message keywords.
public enum ErrorClassifier {

    /// Classify an error into ClassifiedLLMError.
    /// - Parameters:
    ///   - error: the error thrown by LLMConnector.send
    ///   - httpResponse: optional HTTPURLResponse (= if available from URLSession)
    /// - Returns: ClassifiedLLMError with category + user-facing message
    public static func classify(
        error: Error,
        httpResponse: HTTPURLResponse? = nil
    ) -> ClassifiedLLMError {
        // 1. Check HTTP status code first (= most reliable signal)
        if let status = httpResponse?.statusCode {
            switch status {
                case 400:
                    // Distinguish context-length-exceeded (= common 400) from generic bad-request
                    if error.localizedDescription.lowercased().contains("context") ||
                       error.localizedDescription.lowercased().contains("maximum") {
                        return ClassifiedLLMError(
                            category: .contextLengthExceeded,
                            underlying: "\(status): \(error.localizedDescription)",
                            userMessage: "Conversation too long. Press Compress to reduce context.",
                            isRetryable: false
                        )
                    }
                    return ClassifiedLLMError(
                        category: .badRequest,
                        underlying: "\(status): \(error.localizedDescription)",
                        userMessage: "Request rejected by provider. Check settings.",
                        isRetryable: false
                    )
                case 401, 403:
                    return ClassifiedLLMError(
                        category: .unauthorized,
                        underlying: "\(status): \(error.localizedDescription)",
                        userMessage: "API key invalid or scope issue. Check Settings → LLM Connector.",
                        isRetryable: false
                    )
                case 404:
                    return ClassifiedLLMError(
                        category: .modelNotFound,
                        underlying: "\(status): \(error.localizedDescription)",
                        userMessage: "Model not found. Change model in Settings.",
                        isRetryable: false
                    )
                case 429:
                    return ClassifiedLLMError(
                        category: .rateLimit,
                        underlying: "\(status): \(error.localizedDescription)",
                        userMessage: "Rate limit hit. Try again in a moment.",
                        isRetryable: true,
                        retryAfterSeconds: 60
                    )
                case 500...599:
                    return ClassifiedLLMError(
                        category: .serverError,
                        underlying: "\(status): \(error.localizedDescription)",
                        userMessage: "Provider server error. Try again shortly.",
                        isRetryable: true,
                        retryAfterSeconds: 30
                    )
                default:
                    break
            }
        }

        // 2. Inspect underlying error message (= network errors don't have status)
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("unreachable") ||
           message.contains("dns") || message.contains("tls") {
            return ClassifiedLLMError(
                category: .networkUnreachable,
                underlying: error.localizedDescription,
                userMessage: "Network unreachable. Check connection.",
                isRetryable: true,
                retryAfterSeconds: 10
            )
        }

        // 3. Default = unknown (= fall back to generic message)
        return ClassifiedLLMError(
            category: .unknown,
            underlying: error.localizedDescription,
            userMessage: "Unexpected error. Check logs.",
            isRetryable: false
        )
    }
}

// MARK: - LLMConnectorError classifier (HERMES-PARTIAL-001 wire-up)

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
    /// The mapping matches `ErrorClassifier.classify(...)`'s
    /// `isRetryable` flag for the underlying categories.
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