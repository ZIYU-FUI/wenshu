//
//  UserFacingErrorSSEClientTests.swift · Wenshu
//
//  Behavioral tests for the `UserFacingError.from` mapping of
//  SSEClient raw NSError (= the streaming transport path).
//  Per boss 2026-10-16 OOB "聊天一直未知错误":
//  before this fix, the user always saw "未知错误，请稍后重试
//  或重启应用。" even when the real cause was a clear
//  provider HTTP 400 (= "对话上下文超过模型限制" should
//  have been shown).
//
//  These tests pin the mapping table so the user-facing
//  text can never regress to "未知错误" for the known
//  streaming cases.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("UserFacingError.from (SSEClient mapping)")
struct UserFacingErrorSSEClientTests {

    /// Build an SSEClient-shaped NSError for a given HTTP
    /// status. Mirrors the production throw site at
    /// `Sources/WenshuApp/Features/Agent/Service/SSEClient.swift:75`.
    private func sseError(status: Int) -> NSError {
        NSError(
            domain: "SSEClient",
            code: status,
            userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"]
        )
    }

    @Test("SSEClient 400 -> contextTooLong (per the user's chat log)")
    func testSSEClient400_mapsToContextTooLong() {
        let mapped = UserFacingError.from(sseError(status: 400), context: "minimax-cn")
        // The mapping is .contextTooLong (= 400 is
        // ambiguous in providers; = in wenshu the
        // dominant cause is "history exceeded
        // the model's context window").
        if case .contextTooLong = mapped {
            // pass
        } else {
            Issue.record("expected .contextTooLong for SSEClient 400, got \(mapped)")
        }
    }

    @Test("SSEClient 401/403 -> apiKeyInvalid")
    func testSSEClientAuthMapsToApiKeyInvalid() {
        for status in [401, 403] {
            let mapped = UserFacingError.from(sseError(status: status), context: "minimax-cn")
            if case .apiKeyInvalid = mapped {
                // pass
            } else {
                Issue.record("expected .apiKeyInvalid for SSEClient \(status), got \(mapped)")
            }
        }
    }

    @Test("SSEClient 408/504 -> timeout")
    func testSSEClientTimeoutMapsToTimeout() {
        for status in [408, 504] {
            let mapped = UserFacingError.from(sseError(status: status), context: "minimax-cn")
            if case .timeout = mapped {
                // pass
            } else {
                Issue.record("expected .timeout for SSEClient \(status), got \(mapped)")
            }
        }
    }

    @Test("SSEClient 429 -> rateLimited")
    func testSSEClient429MapsToRateLimited() {
        let mapped = UserFacingError.from(sseError(status: 429), context: "minimax-cn")
        if case .rateLimited = mapped {
            // pass
        } else {
            Issue.record("expected .rateLimited for SSEClient 429, got \(mapped)")
        }
    }

    @Test("SSEClient 5xx -> networkFailure")
    func testSSEClient5xxMapsToNetworkFailure() {
        for status in [500, 502, 503] {
            let mapped = UserFacingError.from(sseError(status: status), context: "minimax-cn")
            if case .networkFailure = mapped {
                // pass
            } else {
                Issue.record("expected .networkFailure for SSEClient \(status), got \(mapped)")
            }
        }
    }

    /// Per boss 2026-10-16 OOB "开可以查看详细的 LOG, 错
    /// 在哪": the user-facing description for an
    /// unrecognized error must INCLUDE the raw
    /// underlying string (= so the user can read the
    /// real cause). Pin that contract here.
    @Test("unknown error description includes underlying hint")
    func testUnknownIncludesUnderlying() {
        let underlying = "Error Domain=SSEClient Code=418 \"I'm a teapot\""
        let mapped = UserFacingError.unknown(underlying: underlying)
        let desc = mapped.errorDescription ?? ""
        #expect(desc.contains("未知错误"),
                "unknown description should still lead with 未知错误")
        #expect(desc.contains(underlying),
                "unknown description must include the underlying hint so the user can see the real reason (= per boss 2026-10-16 OOB \"开可以查看详细的 LOG, 错在哪\")")
    }

    /// `.unknown(underlying: nil)` falls back to the
    /// localized "error.unknown" (= no raw hint available;
    /// the friendly Chinese text is the only message).
    @Test("unknown without underlying falls back to localized text")
    func testUnknownWithoutUnderlying() {
        let mapped = UserFacingError.unknown(underlying: nil)
        let desc = mapped.errorDescription ?? ""
        #expect(!desc.isEmpty, "unknown must still produce a description even without underlying")
    }
}
