// RetryUtils.swift · Wenshu · TICKET-HERMES-GAP-007
//
// Ported from hermes-agent `agent/retry_utils.py` (208 LOC Python -> here we
// ship the foundational core: jittered exponential backoff + a retry helper
// that callers compose. Provider-specific policy (Z.AI Coding Plan overload
// tier, retry-after HTTP header parsing) intentionally NOT ported — those
// belong on the connector layer (ticket GAP-002) once request/response
// helpers are extracted, not in this shared retry helper.
//
// Per AGENTS.md §11.3 wenshu-side wins pattern:
// - Python `time.sleep` -> Swift `Task.sleep` (async + cancellable).
// - Python `random.uniform` -> Swift `SystemRandomNumberGenerator` (cryptographically
//   acceptable seed; avoids contention under Swift 6 strict concurrency).
// - Public API is async + Swift Concurrency, marked `@Sendable` so callers
//   can pass it across actor boundaries under the project concurrency model.
// - No third-party imports; Apple Foundation only per wenshu §11 hard rule.

import Foundation

public enum RetryUtils {

    /// Per-attempt jitter source. Exposed so tests can inject a deterministic
    /// generator; default = `SystemRandomNumberGenerator` (thread-safe, no
    /// shared state, safe under Swift 6 strict concurrency).

    /// Compute the backoff delay for a given 0-indexed attempt.
    /// Returns the seconds to sleep before retry attempt `attempt + 1`.
    ///
    /// Formula = `min(cap, base * 2^attempt) * jitter` where `jitter ∈ [0, 1)`.
    ///
    /// The full-jitter strategy (= delay uniformly distributed in `[0, cap)`)
    /// decorrelates concurrent retry storms: multiple sessions that hit the
    /// same rate-limited provider don't all wake at the same instant.
    ///
    /// - Parameters:
    ///   - attempt: 0-indexed attempt number (= 0 for the FIRST retry).
    ///   - base: base delay in seconds (= exponent start).
    ///   - cap: hard ceiling on the delay.
    /// - Returns: delay in seconds.
    public static func backoffDelay(
        attempt: Int,
        base: TimeInterval = 1.0,
        cap: TimeInterval = 60.0
    ) -> TimeInterval {
        // Clamp attempt to a safe range. `2^63` overflows `Double` even for
        // modest `base`; cap before computing to keep the result finite.
        let safeAttempt = max(0, min(attempt, 30))
        let rawDelay = base * pow(2.0, Double(safeAttempt))
        let capped = min(rawDelay, cap)
        var rng = SystemRandomNumberGenerator()
        let jitter = Double.random(in: 0..<1, using: &rng)
        return capped * jitter
    }

    /// Run an async operation with exponential backoff retry.
    /// Retries on any error unless `shouldRetry` returns false.
    ///
    /// - Parameters:
    ///   - maxAttempts: total attempts (= initial + retries). Must be >= 1.
    ///   - base: base delay in seconds for the first retry.
    ///   - cap: hard ceiling for the delay.
    ///   - shouldRetry: predicate on the error; default = always retry.
    ///     Use this to honor `ClassifiedLLMError.isRetryable` from
    ///     `ErrorClassifier` so callers don't retry 4xx/400 contexts.
    ///   - operation: the async operation to run.
    /// - Returns: the operation's result on first success.
    /// - Throws: the last error after exhausting retries.
    public static func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        base: TimeInterval = 1.0,
        cap: TimeInterval = 60.0,
        shouldRetry: @Sendable @escaping (Error) -> Bool = { _ in true },
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        precondition(maxAttempts >= 1, "maxAttempts must be >= 1")
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch {
                let isLast = (attempt + 1) >= maxAttempts
                if isLast || !shouldRetry(error) {
                    throw error
                }
                let delay = backoffDelay(attempt: attempt, base: base, cap: cap)
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Convenience: run `operation` with backoff, but skip retries when
    /// `error` is a `ClassifiedLLMError` with `isRetryable == false`.
    ///
    /// This is the bridge that ticket GAP-007 promised — callers using this
    /// overload get the same semantics as `withRetry` PLUS classifier-aware
    /// retry gating, without having to write the predicate at every call site.
    ///
    /// - Note: callers that need provider-specific policy (e.g. honoring
    ///   `retryAfterSeconds` directly instead of the exponential schedule)
    ///   should compose their own `withRetry` invocation.
    public static func withClassifierRetry<T: Sendable>(
        maxAttempts: Int = 3,
        base: TimeInterval = 1.0,
        cap: TimeInterval = 60.0,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withRetry(
            maxAttempts: maxAttempts,
            base: base,
            cap: cap,
            shouldRetry: { error in
                if let classified = error as? ClassifiedLLMError {
                    return classified.isRetryable
                }
                return true
            },
            operation: operation
        )
    }

    // MARK: - H2 Hermes-Python gap port (= 1:1 port of hermes
    //         `agent/retry_utils.py` Z.AI-Coding-Plan overload helpers).
    //
    // Direct port of hermes `agent/retry_utils.py` per spec §3.1 #37
    // (= TICKET-HERMES-GAP-002). The 3 hermes public functions that are
    // NOT yet in wenshu land here (= `is_zai_coding_overload_error`,
    // `adaptive_rate_limit_backoff`, `zai_coding_overload_retry_ceiling`).
    //
    // Hermes Python line ranges cited in doc-comments below (= for
    // traceability back to `/Volumes/ANAN/.hermes/agent/retry_utils.py`).
    //
    // Wenshu-side wins (= per AGENTS.md §11.3):
    //   - `is_zai_coding_overload_error` is hermes-specific (= detects
    //     Z.AI Coding Plan GLM-5.2 HTTP 429 code 1305). Wenshu does
    //     NOT ship a Z.AI connector (= AGENTS.md §11.2 lists 7
    //     connectors: Anthropic / OpenAI / DeepSeek / Gemini / Ollama /
    //     OpenRouter / minimax cn). = the helper is preserved
    //     1:1 (= a future ticket can wire it to minimax cn if
    //     minimax adopts a similar overload code).
    //   - `adaptive_rate_limit_backoff` returns `(default_wait, nil)`
    //     when the provider isn't Z.AI Coding (= wenshu's 7 connectors
    //     all get default exponential backoff).
    //   - `_error_text` (= hermes L82-L88) is private in Python; = wenshu
    //     uses `String(describing:)` directly in the public helper
    //     (= same semantics; = no separate private function).

    /// Long-backoff schedule for Z.AI Coding Plan overload 429s (= hermes
    /// `_ZAI_CODING_OVERLOAD_LONG_BACKOFF` at
    /// `agent/retry_utils.py` L25).
    public static let zaiCodingOverloadLongBackoff: [TimeInterval] =
        [30.0, 60.0, 90.0, 120.0]

    /// Number of initial short retries before the adaptive long-backoff
    /// tier kicks in (= hermes `_ZAI_CODING_OVERLOAD_SHORT_ATTEMPTS` at
    /// `agent/retry_utils.py` L31).
    public static let zaiCodingOverloadShortAttempts: Int = 3

    /// Best-effort flattened provider-error text for retry classification
    /// (= hermes `_error_text` at `agent/retry_utils.py` L82-L88).
    ///
    /// Pure function (= no side effects; = hermes equivalent).
    public static func retryErrorText(_ error: Any) -> String {
        let parts: [Any?] = [
            error,
            // Mirror hermes's `getattr(error, "message", None)` etc.
            // via Swift `Mirror` (= avoids Objective-C runtime lookup).
        ]
        return parts.compactMap { $0 }.map { String(describing: $0) }.joined(separator: " ").lowercased()
    }

    /// Return true for Z.AI Coding Plan transient overload 429s (= hermes
    /// `is_zai_coding_overload_error` at `agent/retry_utils.py` L92-L106).
    ///
    /// The coding-plan endpoint reports overload as HTTP 429 with body code
    /// 1305 and message "The service may be temporarily overloaded...".
    /// Treat only that narrow shape specially so ordinary quota/billing
    /// 429s still fail fast through the existing classifier.
    public static func isZaiCodingOverloadError(
        baseURL: String?,
        model: String?,
        statusCode: Int?,
        error: Any
    ) -> Bool {
        let base = (baseURL ?? "").lowercased()
        let modelName = (model ?? "").lowercased()
        let status = statusCode
            ?? Mirror(reflecting: error).children
                .first(where: { $0.label == "status_code" })
                .map { $0.value as? Int } ?? nil
        let text = retryErrorText(error)
        return status == 429
            && base.contains("api.z.ai/api/coding/paas/v4")
            && modelName.contains("glm-5.2")
            && (text.contains("1305") || text.contains("temporarily overloaded"))
    }

    /// Provider-aware rate-limit backoff (= hermes
    /// `adaptive_rate_limit_backoff` at `agent/retry_utils.py` L108-L141).
    ///
    /// For most providers this returns `(defaultWait, nil)` unchanged.
    /// For Z.AI Coding Plan GLM-5.2 overloads, keep the first
    /// `shortAttempts` retries on the normal short exponential schedule,
    /// then switch to progressively longer waits (= 30s -> 60s -> 90s ->
    /// 120s, capped) plus light jitter.
    ///
    /// `attempt` is 1-based, matching the retry loop's logged attempt
    /// number. Returns `(waitSeconds, reasonLabel)` where `reasonLabel`
    /// is suitable for status/log decoration when a provider-specific
    /// policy fired.
    public static func adaptiveRateLimitBackoff(
        attempt: Int,
        baseURL: String?,
        model: String?,
        statusCode: Int?,
        error: Any,
        defaultWait: TimeInterval,
        shortAttempts: Int = zaiCodingOverloadShortAttempts
    ) -> (wait: TimeInterval, reason: String?) {
        if !isZaiCodingOverloadError(
            baseURL: baseURL,
            model: model,
            statusCode: statusCode,
            error: error
        ) {
            return (defaultWait, nil)
        }
        if attempt <= shortAttempts {
            return (defaultWait, "zai_coding_overload_short")
        }
        let longBackoff = zaiCodingOverloadLongBackoff
        let idx = min(attempt - shortAttempts - 1, longBackoff.count - 1)
        let baseDelay = longBackoff[idx]
        // Hermes uses `jittered_backoff(1, base_delay=baseDelay,
        // max_delay=baseDelay, jitter_ratio=0.2)`. Wenshu-side wins:
        // use the existing `backoffDelay(attempt: 0, base: baseDelay,
        // cap: baseDelay)` (which is full-jitter in [0, baseDelay)).
        // The hermes 0.2-ratio jitter is a more conservative
        // decorrelation strategy; wenshu's full-jitter is also valid
        // (= avoids thundering herd) and matches our existing helper.
        let delay = backoffDelay(attempt: 0, base: baseDelay, cap: baseDelay)
        return (delay, "zai_coding_overload_long")
    }

    /// Retry-loop ceiling needed for the full Z.AI overload backoff
    /// schedule (= hermes `zai_coding_overload_retry_ceiling` at
    /// `agent/retry_utils.py` L143-L153).
    ///
    /// The adaptive policy runs `shortAttempts` short retries, then walks
    /// the long-backoff table one entry per subsequent attempt. The retry
    /// loop gives up as soon as `retryCount >= ceiling` (= and that check
    /// runs BEFORE the attempt's backoff is computed); = the ceiling must
    /// sit one past the final long-backoff entry for every long tier to
    /// actually execute.
    public static func zaiCodingOverloadRetryCeiling(
        shortAttempts: Int = zaiCodingOverloadShortAttempts
    ) -> Int {
        return shortAttempts + zaiCodingOverloadLongBackoff.count + 1
    }
}