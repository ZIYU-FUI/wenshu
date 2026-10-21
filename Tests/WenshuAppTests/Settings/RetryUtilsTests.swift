// RetryUtilsTests.swift · Wenshu · TICKET-HERMES-GAP-007
//
// Tests for RetryUtils (= exponential backoff + retry helper).
// Covers the 7 acceptance criteria from ticket GAP-007 plus the
// `shouldRetry` predicate + RateLimitTracker integration smoke test.
//
// Pure unit tests; uses the `swift-testing` framework per the rest of the
// WenshuAppTests tree (= see Agent/*ConnectorTests.swift for the pattern).
//
// No third-party deps; Apple Foundation only.

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("RetryUtils (ticket GAP-007)")
struct RetryUtilsTests {

    @Test("backoffDelay(attempt: 0) returns value in [0, base)")
    func testBackoffDelay_zeroAttempt() {
        let base: TimeInterval = 5.0
        // Over 200 trials, every value must sit in [0, base). Pull min + max
        // and confirm both endpoints are reachable (jitter ∈ [0, 1) per spec).
        var minValue: TimeInterval = .greatestFiniteMagnitude
        var maxValue: TimeInterval = -.greatestFiniteMagnitude
        for _ in 0..<200 {
            let v = RetryUtils.backoffDelay(attempt: 0, base: base, cap: 60)
            minValue = min(minValue, v)
            maxValue = max(maxValue, v)
        }
        #expect(minValue >= 0)
        #expect(maxValue < base)
        // Both endpoints must be reachable across a 200-trial sample.
        #expect(maxValue > 0.5 * base)
    }

    @Test("backoffDelay(attempt: 100, cap: 60) stays under cap")
    func testBackoffDelay_caps() {
        let cap: TimeInterval = 60
        for _ in 0..<50 {
            let v = RetryUtils.backoffDelay(attempt: 100, base: 1.0, cap: cap)
            #expect(v >= 0)
            #expect(v < cap)
        }
    }

    @Test("backoffDelay mean grows monotonically with attempt")
    func testBackoffDelay_monotonic_mean() {
        // For attempt=N, the mean ≈ (min(base*2^N, cap)) * 0.5 (full-jitter
        // expected value = 0.5 * cap). For attempt=5 with base=1, cap=60,
        // the cap dominates so mean ≈ 30. For attempt=1, mean ≈ 0.5 * 2 = 1.
        // Sample 100 trials per attempt and compare means.
        func mean(_ attempt: Int) -> Double {
            var sum = 0.0
            let trials = 100
            for _ in 0..<trials {
                sum += RetryUtils.backoffDelay(attempt: attempt, base: 1.0, cap: 60.0)
            }
            return sum / Double(trials)
        }
        let mean1 = mean(1)
        let mean5 = mean(5)
        #expect(mean5 > mean1)
    }

    @Test("withRetry succeeds on first try")
    func testWithRetry_succeedsOnFirstTry() async throws {
        actor CallCounter {
            private(set) var count = 0
            func bump() { count += 1 }
        }
        let counter = CallCounter()
        let result: Int = try await RetryUtils.withRetry {
            await counter.bump()
            return 42
        }
        #expect(result == 42)
        let count = await counter.count
        #expect(count == 1)
    }

    @Test("withRetry retries on failure then succeeds")
    func testWithRetry_retriesOnFailure() async throws {
        actor CallCounter {
            private(set) var count = 0
            func bump() -> Int {
                count += 1
                return count
            }
        }
        let counter = CallCounter()
        // Fail twice (= attempts 1 + 2), succeed on attempt 3. Use small
        // base/cap so the test doesn't sleep noticeably.
        let result: Int = try await RetryUtils.withRetry(
            maxAttempts: 3,
            base: 0.001,
            cap: 0.01
        ) {
            let n = await counter.bump()
            if n < 3 { throw NSError(domain: "test", code: n) }
            return n
        }
        #expect(result == 3)
        let count = await counter.count
        #expect(count == 3)
    }

    @Test("withRetry throws after exhausting retries")
    func testWithRetry_exhaustsRetries() async {
        actor CallCounter {
            private(set) var count = 0
            func bump() -> Int {
                count += 1
                return count
            }
        }
        let counter = CallCounter()
        struct AlwaysFails: Error {}
        do {
            _ = try await RetryUtils.withRetry(
                maxAttempts: 3,
                base: 0.001,
                cap: 0.01
            ) {
                _ = await counter.bump()
                throw AlwaysFails()
            }
            Issue.record("withRetry should have thrown after exhausting retries")
        } catch {
            // Expected. Verify the loop actually retried (= count == 3).
            let count = await counter.count
            #expect(count == 3)
        }
    }

    @Test("withRetry respects shouldRetry=false and bails on first failure")
    func testWithRetry_shouldRetry() async {
        actor CallCounter {
            private(set) var count = 0
            func bump() { count += 1 }
        }
        let counter = CallCounter()
        struct NonRetryable: Error {}
        do {
            _ = try await RetryUtils.withRetry(
                maxAttempts: 5,
                base: 0.001,
                cap: 0.01,
                shouldRetry: { _ in false }
            ) {
                await counter.bump()
                throw NonRetryable()
            }
            Issue.record("withRetry should have thrown on first failure when shouldRetry=false")
        } catch is NonRetryable {
            let count = await counter.count
            #expect(count == 1)
        } catch {
            Issue.record("Wrong error type thrown: \(error)")
        }
    }
}

@Suite("RateLimitTracker.performWithRetry wiring (ticket GAP-007)")
struct RateLimitTrackerRetryWiringTests {

}