//
//  MiniMaxVerifierTests.swift · Wenshu · v0.18 ticket 31 (verify MiniMax)
//
//  集成测试 wenshu AgentProtocol (A2A) + MiniMax API 真值连接.
//  跑: source ~/.hermes/profiles/pocock/.env && MINIMAX_CN_API_KEY="$MINIMAX_CN_API_KEY" swift test
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MiniMaxVerifier (wenshu 调通 agent)")
struct MiniMaxVerifierTests {
    /// 跳过测试如果 env 没 MiniMax key
    private static var hasAPIKey: Bool {
        let key = ProcessInfo.processInfo.environment["MINIMAX_CN_API_KEY"] ?? ""
        return !key.isEmpty
    }

    @Test("ping 真值 200")
    func testPingReal() async throws {
        guard Self.hasAPIKey else {
            Issue.record("MINIMAX_CN_API_KEY 未设, 跳过真验证")
            return
        }
        let verifier = MiniMaxVerifier()
        let response = try await verifier.ping()
        #expect(response.model == "MiniMax-M3")
        #expect(response.role == "assistant")
        #expect(!response.content.isEmpty)
        // v0.21 ticket 39: union decode (text / thinking / tool_use)
        let displayText = response.content.map(\.displayText).joined()
        #expect(displayText.count > 0)
    }

    @Test("MiniMax key 缺失抛错")
    func testMissingAPIKey() async {
        // 用空 env 创 verifier
        let verifier = MiniMaxVerifier(baseURL: "https://api.minimaxi.com/anthropic", apiKey: "")
        await #expect(throws: MiniMaxError.self) {
            _ = try await verifier.ping()
        }
    }

    @Test("无效 baseURL 抛错")
    func testInvalidBaseURL() async {
        let verifier = MiniMaxVerifier(baseURL: "not a url", apiKey: "fake")
        await #expect(throws: (any Error).self) {
            _ = try await verifier.ping()
        }
    }
}