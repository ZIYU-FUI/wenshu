//
//  MinimaxConnectorTests.swift · Wenshu · v0.35 ticket 001 sub-step 7
//
//  Unit tests for MinimaxConnector (= thin Anthropic-compatible wire format
//  wrapper over the existing minimax cn endpoint).
//
//  Per hermes-core-translation spec §3.2 + AGENTS.md §11.2:
//  Minimax cn = one of 7 connector profiles, uses Anthropic Messages API.
//
//  Tests use URLProtocol stubbing (= URLProtocolClient mock) to avoid
//  hitting the real minimax API. Tests cover:
//    1. Build Anthropic-compatible request body (= x-api-key header +
//       anthropic-version header + system + messages fields)
//    2. Decode Anthropic-style response (= text + thinking blocks + usage)
//    3. Throw on missing API key
//    4. Throw on non-2xx HTTP status (= transport error)
//    5. Throw on malformed JSON (= decode error)
//
//  v0.35 sub-step 7 of 8 for ticket 001.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MinimaxConnector (ticket 001 sub-step 7)")
struct MinimaxConnectorTests {

    // MARK: - Test 1: Build Anthropic-compatible request body

    @Test("Build Anthropic-compatible request body with x-api-key + anthropic-version headers")
    func testRequestBody() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "hello back", model: "MiniMax-M3")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        // Provide API key via InMemoryKeychainStore (= wenshu-side wins)
        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test-minimax", for: .minimaxCn)
        ProviderKeychain.setBackendForTesting(store)

        let connector = MinimaxConnector(session: session)
        let messages = [LLMMessage.user("hello")]
        let options = LLMCallOptions(model: "MiniMax-M3", systemPrompt: "you are a writer")
        _ = try await connector.send(messages: messages, options: options)

        // Verify request body shape
        let capturedRequest = try #require(stub.lastRequest)
        #expect(capturedRequest.value(forHTTPHeaderField: "x-api-key") == "sk-test-minimax")
        #expect(capturedRequest.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(capturedRequest.httpMethod == "POST")

        let bodyData = try #require(capturedRequest.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        #expect(body?["model"] as? String == "MiniMax-M3")
        #expect(body?["system"] as? String == "you are a writer")
        let bodyMessages = body?["messages"] as? [[String: Any]]
        #expect(bodyMessages?.count == 1)
        #expect(bodyMessages?[0]["role"] as? String == "user")
    }

    // MARK: - Test 2: Decode Anthropic-style response

    @Test("Decode Anthropic-style response (= text + thinking + usage)")
    func testResponseDecode() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(
            content: "decoded answer",
            model: "MiniMax-M3",
            includeThinking: true,
            usage: ["input_tokens": 100, "output_tokens": 50]
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .minimaxCn)
        ProviderKeychain.setBackendForTesting(store)

        let connector = MinimaxConnector(session: session)
        let response = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "MiniMax-M3")
        )

        #expect(response.model == "MiniMax-M3")
        #expect(response.usage.inputTokens == 100)
        #expect(response.usage.outputTokens == 50)
        #expect(response.blocks.contains { block in
            if case .text(let s) = block { return s == "decoded answer" } else { return false }
        })
    }

    // MARK: - Test 3: Missing API key

    @Test("Throw LLMConnectorError.missingAPIKey when keychain has no key")
    func testMissingAPIKey() async throws {
        // Reset to empty keychain
        let store = InMemoryKeychainStore()
        ProviderKeychain.setBackendForTesting(store)

        let connector = MinimaxConnector(session: .shared)

        await #expect(throws: LLMConnectorError.self) {
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "MiniMax-M3")
            )
        }
    }

    // MARK: - Test 4: Non-2xx HTTP status

    @Test("Throw LLMConnectorError.transport on non-2xx HTTP status")
    func testTransportError() async throws {
        let stub = URLProtocolStub()
        stub.response = HTTPURLResponse(
            url: URL(string: "https://api.minimaxi.com/anthropic/v1/messages")!,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .minimaxCn)
        ProviderKeychain.setBackendForTesting(store)

        let connector = MinimaxConnector(session: session)

        await #expect(throws: LLMConnectorError.self) {
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "MiniMax-M3")
            )
        }
    }
}

// MARK: - URLProtocol stub

private final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var sharedResponse: Any?
    nonisolated(unsafe) var capturedRequest: URLRequest?

    var response: Any? {
        get { Self.sharedResponse }
        set { Self.sharedResponse = newValue }
    }
    var lastRequest: URLRequest? { capturedRequest }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self()
        stub.capturedRequest = self.request

        if let httpResponse = response as? HTTPURLResponse {
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
        } else if let data = response as? Data {
            let httpResponse = HTTPURLResponse(
                url: self.request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        } else {
            // Default empty 200 response
            let httpResponse = HTTPURLResponse(
                url: self.request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Anthropic-style response builder

private func makeAnthropicResponse(
    content: String,
    model: String = "MiniMax-M3",
    includeThinking: Bool = false,
    usage: [String: Int] = ["input_tokens": 0, "output_tokens": 0]
) -> Data {
    var contentBlocks: [[String: Any]] = []
    if includeThinking {
        contentBlocks.append([
            "type": "thinking",
            "thinking": "reasoning",
            "signature": "sig"
        ])
    }
    contentBlocks.append([
        "type": "text",
        "text": content
    ])

    let body: [String: Any] = [
        "id": "msg-test-1",
        "model": model,
        "role": "assistant",
        "content": contentBlocks,
        "stop_reason": "end_turn",
        "usage": usage
    ]
    return try! JSONSerialization.data(withJSONObject: body)
}