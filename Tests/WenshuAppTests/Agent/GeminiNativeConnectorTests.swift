//
//  GeminiNativeConnectorTests.swift · Wenshu · v0.35 ticket 007
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("GeminiNativeConnector (ticket 007)")
struct GeminiNativeConnectorTests {

    @Test("Gemini native: ?key= query param + generateContent endpoint")
    func testGeminiNativeURL() async throws {
        let stub = URLProtocolStub()
        stub.response = makeGeminiResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("gem-test-key", for: .gemini)
        ProviderKeychain.setBackendForTesting(store)

        let connector = GeminiNativeConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "gemini-2.5-flash")
        )

        let captured = stub.lastRequest
        #expect(captured?.url?.path.contains("/models/gemini-2.5-flash:generateContent") == true)
        #expect(captured?.url?.query?.contains("key=gem-test-key") == true)
    }

    @Test("Gemini native: systemInstruction field separate from contents")
    func testSystemInstructionSeparate() async throws {
        let stub = URLProtocolStub()
        stub.response = makeGeminiResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("k", for: .gemini)
        ProviderKeychain.setBackendForTesting(store)

        let connector = GeminiNativeConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "gemini-2.5-flash", systemPrompt: "stable system")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        #expect(body?["systemInstruction"] != nil)
        // contents should NOT contain the system message
        let contents = body?["contents"] as? [[String: Any]]
        let firstContent = contents?[0]
        #expect(firstContent?["role"] as? String == "user")
    }

    @Test("Missing API key throws LLMConnectorError.missingAPIKey")
    func testMissingAPIKey() async {
        let store = InMemoryKeychainStore()
        ProviderKeychain.setBackendForTesting(store)

        let connector = GeminiNativeConnector(session: .shared)

        await #expect(throws: LLMConnectorError.self) {
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "gemini-2.5-flash")
            )
        }
    }
}

private func makeGeminiResponse(content: String) -> Data {
    let body: [String: Any] = [
        "candidates": [
            [
                "content": [
                    "parts": [["text": content]],
                    "role": "model"
                ],
                "finishReason": "STOP"
            ]
        ],
        "modelVersion": "gemini-2.5-flash",
        "usageMetadata": [
            "promptTokenCount": 0,
            "candidatesTokenCount": 0
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: body)
}