//
//  RetryUtilsHermesGapPortTests.swift · Wenshu · H2-RETRY-UTILS-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Auth/RetryUtils.swift` (= hermes
//  `agent/retry_utils.py` Z.AI-Coding-Plan overload helpers):
//    - isZaiCodingOverloadError (= hermes L92-L106)
//    - adaptiveRateLimitBackoff (= hermes L108-L141)
//    - zaiCodingOverloadRetryCeiling (= hermes L143-L153)
//    - retryErrorText (= hermes L82-L88, public for wenshu-side
//      ergonomics)
//    - zaiCodingOverloadLongBackoff (= hermes L25 constant)
//    - zaiCodingOverloadShortAttempts (= hermes L31 constant)
//
//  Per AGENTS.md §11.3 decision 1 (= wenshu-side wins): the helpers
//  are preserved 1:1 but they're hermes-Z.AI-Coding-Plan-specific.
//  Wenshu does NOT ship a Z.AI connector (= AGENTS.md §11.2 lists
//  7 connectors: Anthropic / OpenAI / DeepSeek / Gemini / Ollama /
//  OpenRouter / minimax cn); = the helpers are inert until a
//  future ticket wires them to minimax cn (= if minimax adopts
//  a similar overload code).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("RetryUtils hermes-Python gap port (H2)")
struct RetryUtilsHermesGapPortTests {

    /// H2 contract: zaiCodingOverloadLongBackoff = hermes schedule.
    @Test func zaiCodingOverloadLongBackoff_matches_hermes() {
        #expect(RetryUtils.zaiCodingOverloadLongBackoff == [30.0, 60.0, 90.0, 120.0])
    }

    /// H2 contract: zaiCodingOverloadShortAttempts = 3 (= hermes default).
    @Test func zaiCodingOverloadShortAttempts_is_three() {
        #expect(RetryUtils.zaiCodingOverloadShortAttempts == 3)
    }

    /// H2.1 contract: retryErrorText returns lowercased concatenated
    /// string (= hermes `_error_text` L82-L88).
    @Test func retryErrorText_concatenates_and_lowercases() {
        let error = NSError(
            domain: "test",
            code: 429,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 429 Code 1305"]
        )
        let result = RetryUtils.retryErrorText(error)
        #expect(result.contains("429"))
        #expect(result.contains("1305"))
        #expect(result == result.lowercased())
    }

    /// H2.1 contract: retryErrorText handles nil error (= hermes safe-guard).
    @Test func retryErrorText_handles_string() {
        let result = RetryUtils.retryErrorText("HTTP 429 1305")
        #expect(result.contains("429"))
        #expect(result.contains("1305"))
    }

    /// H2.2 contract: isZaiCodingOverloadError returns true for the
    /// exact Z.AI Coding Plan GLM-5.2 429/1305 shape (= hermes L100-L106).
    @Test func isZaiCodingOverloadError_detects_zai_overload() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Error 1305: The service may be temporarily overloaded" }
        }
        let detected = RetryUtils.isZaiCodingOverloadError(
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError()
        )
        #expect(detected)
    }

    /// H2.2 contract: isZaiCodingOverloadError returns false for
    /// non-429 (= hermes L100 status check).
    @Test func isZaiCodingOverloadError_rejects_non_429() {
        let detected = RetryUtils.isZaiCodingOverloadError(
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 500,
            error: "Some 500 error"
        )
        #expect(!detected)
    }

    /// H2.2 contract: isZaiCodingOverloadError returns false for
    /// non-Z.AI URL (= hermes L101 base check).
    @Test func isZaiCodingOverloadError_rejects_non_zai_url() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Error 1305" }
        }
        let detected = RetryUtils.isZaiCodingOverloadError(
            baseURL: "https://api.openai.com/v1",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError()
        )
        #expect(!detected)
    }

    /// H2.2 contract: isZaiCodingOverloadError returns false for
    /// non-glm-5.2 model (= hermes L102 model check).
    @Test func isZaiCodingOverloadError_rejects_non_glm52() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Error 1305" }
        }
        let detected = RetryUtils.isZaiCodingOverloadError(
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "gpt-5",
            statusCode: 429,
            error: TestError()
        )
        #expect(!detected)
    }

    /// H2.2 contract: isZaiCodingOverloadError returns false when
    /// error text has neither 1305 nor "temporarily overloaded"
    /// (= hermes L103 text check).
    @Test func isZaiCodingOverloadError_rejects_wrong_error_text() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Rate limit exceeded" }
        }
        let detected = RetryUtils.isZaiCodingOverloadError(
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError()
        )
        #expect(!detected)
    }

    /// H2.3 contract: adaptiveRateLimitBackoff returns defaultWait for
    /// non-Z.AI providers (= hermes L119-L120).
    @Test func adaptiveRateLimitBackoff_returns_default_for_non_zai() {
        let (wait, reason) = RetryUtils.adaptiveRateLimitBackoff(
            attempt: 5,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-5",
            statusCode: 429,
            error: "Some 429",
            defaultWait: 10.0,
        )
        #expect(wait == 10.0)
        #expect(reason == nil)
    }

    /// H2.3 contract: adaptiveRateLimitBackoff for Z.AI within
    /// short_attempts = defaultWait + "zai_coding_overload_short" label
    /// (= hermes L125-L126).
    @Test func adaptiveRateLimitBackoff_short_tier_for_zai() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Error 1305 temporarily overloaded" }
        }
        let (wait, reason) = RetryUtils.adaptiveRateLimitBackoff(
            attempt: 2,  // <= shortAttempts (3)
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError(),
            defaultWait: 8.0,
        )
        #expect(wait == 8.0)
        #expect(reason == "zai_coding_overload_short")
    }

    /// H2.3 contract: adaptiveRateLimitBackoff for Z.AI long tier
    /// = schedules from 30/60/90/120 (= hermes L129-L135).
    @Test func adaptiveRateLimitBackoff_long_tier_for_zai() {
        struct TestError: CustomStringConvertible {
            let statusCode = 429
            var description: String { "Error 1305 temporarily overloaded" }
        }
        // attempt = 4 = shortAttempts(3) + 1 -> idx 0 = 30s base
        let (wait30, reason30) = RetryUtils.adaptiveRateLimitBackoff(
            attempt: 4,
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError(),
            defaultWait: 8.0,
        )
        // backoffDelay(0, 30, 30) = capped(30) * jitter[0,1) = [0, 30)
        #expect(wait30 < 30.0)
        #expect(wait30 >= 0.0)
        #expect(reason30 == "zai_coding_overload_long")

        // attempt = 8 = shortAttempts(3) + 5 -> idx min(4, 3) = 3 = 120s base
        let (wait120, reason120) = RetryUtils.adaptiveRateLimitBackoff(
            attempt: 8,
            baseURL: "https://api.z.ai/api/coding/paas/v4",
            model: "glm-5.2",
            statusCode: 429,
            error: TestError(),
            defaultWait: 8.0,
        )
        // backoffDelay(0, 120, 120) = capped(120) * jitter[0,1) = [0, 120)
        #expect(wait120 < 120.0)
        #expect(wait120 >= 0.0)
        #expect(reason120 == "zai_coding_overload_long")
    }

    /// H2.4 contract: zaiCodingOverloadRetryCeiling = shortAttempts +
    /// len(longBackoff) + 1 (= hermes L143-L153).
    @Test func zaiCodingOverloadRetryCeiling_matches_hermes() {
        // Default: 3 + 4 + 1 = 8
        #expect(RetryUtils.zaiCodingOverloadRetryCeiling() == 8)
        // Custom shortAttempts = 2: 2 + 4 + 1 = 7
        #expect(RetryUtils.zaiCodingOverloadRetryCeiling(shortAttempts: 2) == 7)
    }
}
