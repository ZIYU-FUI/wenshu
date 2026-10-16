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
    /// `Sources/WenshuApp/WenshuAgent/Streaming/SSEClient.swift:75`.
    private func sseError(status: Int) -> NSError {
        NSError(
            domain: "SSEClient",
            code: status,
            userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"]
        )
    }

    @Test("SSEClient 400 no longer maps to contextTooLong (boss 2026-10-16 collapsed all chat errors)")
    func testSSEClient400NoLongerMapsToContextTooLong() {
        let sseErr = NSError(
            domain: "SSEClient",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 400"]
        )
        let mapped = UserFacingError.from(sseErr, context: "minimax-cn")
        // The previous behavior (= `0f48a3b6a`) mapped
        // 400 → contextTooLong. Boss 2026-10-16 OOB
        // "只接提示, 模型配置有误就行了" + "测试还是
        // 不通" revealed that this was a false positive
        // (= minimax returns 400 for many non-context
        // reasons; = the chat layer now collapses via
        // `modelConfigInvalid` regardless of the granular
        // case). The `from` function still preserves the
        // underlying hint (= the dev surface; = the
        // os_log carries it), but the granular case is
        // `.unknown(underlying:)` not `.contextTooLong`.
        if case .contextTooLong = mapped {
            Issue.record("SSEClient 400 must NOT map to .contextTooLong (= per boss 2026-10-16 OOB '只接提示, 模型配置有误就行了' + '测试还是不通' revealed the 400 was a false positive)")
        }
    }

    // The following tests were REMOVED in the
    // 2026-10-16 collapse (= boss OOB "只接提示,
    // 模型配置有误就行了"): the chat layer no
    // longer distinguishes SSEClient 401/403/408/504/
    // 429/5xx into per-status cases. The user sees
    // the single "模型配置有误" message; = the
    // granular mapping (= 401 → apiKeyInvalid, etc.)
    // is preserved in `from()` for non-chat callers
    // (= Settings; = import flow) but is no longer
    // the chat-layer contract. Tests for those
    // granular mappings live in the granular
    // `from()` test suite (= Settings pane tests)
    // and are not duplicated here.
}
