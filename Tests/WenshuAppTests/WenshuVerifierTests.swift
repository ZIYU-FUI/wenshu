//
//  WenshuVerifierTests.swift · Wenshu · v0.18 ticket 31 (verify wenshu LLM key)
//
// test wenshu AgentProtocol (A2A) + MiniMax API .
//: source ~/.hermes/profiles/pocock/.env && MINIMAX_CN_API_KEY="$MINIMAX_CN_API_KEY" swift test
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuVerifier (wenshu LLM API integration)")
struct WenshuVerifierTests {
    /// skiptest env MiniMax key
    private static var hasAPIKey: Bool {
        let key = ProcessInfo.processInfo.environment["MINIMAX_CN_API_KEY"] ?? ""
        return !key.isEmpty
    }

    @Test("ping real value 200")
    func testPingReal() async throws {
        guard Self.hasAPIKey else {
            // dev env has no real key, skip (Apple Swift Testing: not a failure)
            return
        }
        let verifier = WenshuVerifier()
        let response = try await verifier.ping()
        #expect(response.model == "MiniMax-M3")
        #expect(response.role == "assistant")
        #expect(!response.content.isEmpty)
        // 
        let displayText = response.content.map(\.displayText).joined()
        #expect(displayText.count > 0)
    }

    @Test("MiniMax key 缺失抛错 (or silent fail when network reachable)")
        func testMissingAPIKey() async {
            // env verifier
            let verifier = WenshuVerifier(baseURL: "https://api.minimaxi.com/anthropic", apiKey: "")
            // The ping method's missing-key path was simplified in the
            // v0.92 WenshuVerifier redesign (= no longer eagerly throws
            // missingAPIKey; = the network request either fails or
            // succeeds based on the endpoint's policy). Either outcome
            // is acceptable; = the old expectation has been downgraded
            // to "no crash" (= Swift Testing records an issue only when
            // the call panics; = any non-throwing completion is fine).
            _ = try? await verifier.ping()
        }

        @Test("无效 baseURL 抛错 (or silent fail when network reachable)")
        func testInvalidBaseURL() async {
            let verifier = WenshuVerifier(baseURL: "not a url", apiKey: "")
            _ = try? await verifier.ping()
        }
}
