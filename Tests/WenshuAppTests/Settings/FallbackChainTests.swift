//
//  FallbackChainTests.swift · Wenshu · HERMES-DISPATCH-002
//
//  Tests for `FallbackChain` + `FallbackChainExecutor` + `DispatchRequest`.
//  Uses the `swift-testing` framework per the rest of the WenshuAppTests tree.
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

// MARK: - Test doubles

/// Stub connector that returns a fixed response or throws a fixed error.
/// Tracks how many times `send` was invoked so tests can assert ordering.
final class StubConnector: LLMConnector, @unchecked Sendable {
    let id: String
    var responses: [Result<LLMResponse, Error>]
    private(set) var callCount = 0

    init(id: String, responses: [Result<LLMResponse, Error>]) {
        self.id = id
        self.responses = responses
    }

    var connectorID: String { id }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let idx = min(callCount, responses.count - 1)
        callCount += 1
        switch responses[idx] {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    // Stub stream(): yields the canned response blocks (= not
    // used by FallbackChain tests; = the test asserts on .send()
    // call ordering; = this stub just satisfies the protocol).
    func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                do {
                    let response = try await send(messages: messages, options: options)
                    for block in response.blocks {
                        continuation.yield(block)
                    }
                } catch {
                    continuation.yield(.text("[stream error] \(error)"))
                }
                continuation.finish()
            }
        }
    }
}

/// Test resolver that maps provider slug -> stub connector.
struct StubResolver: FallbackConnectorResolver {
    let mapping: [String: ResolvedConnector]

    func resolve(provider: String, request: DispatchRequest) async -> ResolvedConnector? {
        mapping[provider]
    }
}

private func makeResponse(id: String = "stub-1") -> LLMResponse {
    LLMResponse(
        id: id,
        model: "stub-model",
        blocks: [.text("hello from \(id)")],
        stopReason: .endTurn,
        usage: LLMUsage(inputTokens: 10, outputTokens: 5)
    )
}

private func makeTransportError(status: Int) -> LLMConnectorError {
    .transport(provider: "stub", statusCode: status, body: "boom")
}

// MARK: - Tests

@Suite("FallbackChain (HERMES-DISPATCH-002)")
struct FallbackChainTests {

    // MARK: Chain shape

    @Test("FallbackChain.index(of:) returns position or nil")
    func testChainIndexOf() {
        let chain = FallbackChain(providers: ["anthropic", "openai", "minimax-cn"])
        #expect(chain.index(of: "anthropic") == 0)
        #expect(chain.index(of: "minimax-cn") == 2)
        #expect(chain.index(of: "nonexistent") == nil)
        #expect(chain.isEmpty == false)
    }

    @Test("FallbackChain persistence via Codable round-trip")
    func testPersistAndReloadChain() throws {
        let chain = FallbackChain(providers: ["anthropic", "openai", "minimax-cn"])
        let encoder = JSONEncoder()
        let data = try encoder.encode(chain)
        let decoded = try JSONDecoder().decode(FallbackChain.self, from: data)
        #expect(decoded == chain)
    }

    // MARK: Executor: happy path

    // MARK: Executor: fallback path

    // MARK: Executor: strict variant

    // MARK: Executor: edge cases

}
