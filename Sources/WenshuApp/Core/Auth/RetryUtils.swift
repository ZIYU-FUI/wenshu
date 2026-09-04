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
    public typealias JitterGenerator = SystemRandomNumberGenerator

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
}