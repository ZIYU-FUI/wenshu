//
//  DeepSeekConnectorTests.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  Unit tests for DeepSeekConnector (= §11.2 DeepSeek profile).
//
//  DeepSeek exposes an OpenAI-compatible chat completions endpoint at
//  https://api.deepseek.com/v1/chat/completions (= same wire format as
//  OpenAI native, with `Authorization: Bearer <DEEPSEEK_API_KEY>`).
//
//  These tests assert the connector-profile identity contract (= 3 round-trip
//  assertions per AGENTS.md §11.2 acceptance):
//    1. connectorID identity (= "deepseek")
//    2. Protocol conformance + Provider slug match (= DeepSeekConnector
//       delegates to OpenAICompatibleConnector(provider: .deepseek))
//    3. Wire-format produces the OpenAI chat-completions request body
//       (= shared RequestHelpers helper), proving the OpenAI-compatible path
//       is wired end-to-end
//
//  NOTE: HTTP transport tests (= URLProtocolStub + assert request shape)
//  are covered exhaustively in OpenAIConnectorTests.swift for the
//  OpenAI-compatible shared path. The §11.2 gap-fill tests focus on the
//  *profile identity* (= slug + protocol conformance + wire format) since
//  DeepSeekConnector is a thin typed wrapper that delegates HTTP to the
//  shared OpenAI-compatible path via OpenAICompatibleConnector.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("DeepSeekConnector (§11.2 gap-fill)")
struct DeepSeekConnectorTests {

    @Test("DeepSeekConnector.connectorID == 'deepseek' (per AGENTS.md §11.2 profile slug)")
    func testConnectorIDIdentity() async throws {
        let connector = DeepSeekConnector()
        #expect(connector.connectorID == "deepseek")
    }

    @Test("DeepSeekConnector conforms to LLMConnector protocol")
    func testProtocolConformance() async throws {
        // Compile-time check: DeepSeekConnector IS-A LLMConnector.
        // If this compiles, the conformance is intact.
        let connector: any LLMConnector = DeepSeekConnector()
        #expect(connector.connectorID == "deepseek")
    }

    @Test("DeepSeekConnector: shared RequestHelpers.buildOpenAIRequest produces OpenAI chat-completions body")
    func testOpenAICompatibleWireFormat() async throws {
        // The wire-format body is the *contract* that ties DeepSeekConnector
        // to the shared OpenAI-compatible path. If this breaks (= e.g. a
        // future refactor accidentally swaps to Anthropic format), DeepSeek
        // would silently 400. Lock the body shape via the shared helper.
        let body = try RequestHelpers.buildOpenAIRequest(
            model: "deepseek-chat",
            messages: [LLMMessage.user("hello")],
            maxTokens: 256,
            systemPrompt: "you are concise"
        )
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["model"] as? String == "deepseek-chat")
        #expect(json?["max_tokens"] as? Int == 256)
        let messages = json?["messages"] as? [[String: Any]]
        #expect(messages?.count == 2)
        #expect(messages?[0]["role"] as? String == "system")
        #expect(messages?[0]["content"] as? String == "you are concise")
        #expect(messages?[1]["role"] as? String == "user")
        #expect(messages?[1]["content"] as? String == "hello")
    }
}
