//
//  FallbackChainTests.swift · Wenshu · HERMES-DISPATCH-002
//
//  Tests for `FallbackChain` + `FallbackChainExecutor` + `DispatchRequest`.
//  Uses the `swift-testing` framework per the rest of the WenshuAppTests tree.
//

import Testing
import Foundation
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

    @Test("execute: first provider succeeds -> no fallback")
    func testExecute_firstProviderSucceeds() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1")
        _ = try await pool.register(provider: "openai", credential: "k2")
        let primary = StubConnector(id: "anthropic", responses: [.success(makeResponse(id: "anthropic-1"))])
        let fallback = StubConnector(id: "openai", responses: [.success(makeResponse(id: "openai-1"))])
        let resolver = StubResolver(mapping: [
            "anthropic": ResolvedConnector(connector: primary, apiKey: "k1"),
            "openai": ResolvedConnector(connector: fallback, apiKey: "k2")
        ])
        let executor = FallbackChainExecutor(pool: pool, resolver: resolver)
        let chain = FallbackChain(providers: ["anthropic", "openai"])
        let result = try await executor.execute(request: .user("hi", model: "test"), chain: chain)
        #expect(result.provider == "anthropic")
        #expect(result.providerIndex == 0)
        #expect(result.attempts == 1)
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 0)
    }

    // MARK: Executor: fallback path

    @Test("execute: first fails, second succeeds -> reports second provider")
    func testExecute_secondProviderFallback() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1")
        _ = try await pool.register(provider: "openai", credential: "k2")
        let primary = StubConnector(id: "anthropic", responses: [
            .failure(makeTransportError(status: 429))
        ])
        let fallback = StubConnector(id: "openai", responses: [
            .success(makeResponse(id: "openai-1"))
        ])
        let resolver = StubResolver(mapping: [
            "anthropic": ResolvedConnector(connector: primary, apiKey: "k1"),
            "openai": ResolvedConnector(connector: fallback, apiKey: "k2")
        ])
        let executor = FallbackChainExecutor(pool: pool, resolver: resolver)
        let chain = FallbackChain(providers: ["anthropic", "openai"])
        let result = try await executor.execute(request: .user("hi", model: "test"), chain: chain)
        #expect(result.provider == "openai")
        #expect(result.providerIndex == 1)
        #expect(result.attempts == 2)
        #expect(primary.callCount == 1)
        #expect(fallback.callCount == 1)
    }

    @Test("execute: every provider fails -> throws allFailed(attempts:)")
    func testExecute_allProvidersFail_throws() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1")
        _ = try await pool.register(provider: "openai", credential: "k2")
        _ = try await pool.register(provider: "minimax-cn", credential: "k3")
        let c1 = StubConnector(id: "anthropic", responses: [.failure(makeTransportError(status: 429))])
        let c2 = StubConnector(id: "openai", responses: [.failure(makeTransportError(status: 503))])
        let c3 = StubConnector(id: "minimax-cn", responses: [.failure(makeTransportError(status: 401))])
        let resolver = StubResolver(mapping: [
            "anthropic": ResolvedConnector(connector: c1, apiKey: "k1"),
            "openai": ResolvedConnector(connector: c2, apiKey: "k2"),
            "minimax-cn": ResolvedConnector(connector: c3, apiKey: "k3")
        ])
        let executor = FallbackChainExecutor(pool: pool, resolver: resolver)
        let chain = FallbackChain(providers: ["anthropic", "openai", "minimax-cn"])
        do {
            _ = try await executor.execute(request: .user("hi", model: "test"), chain: chain)
            Issue.record("expected allFailed error")
        } catch let FallbackChainError.allFailed(attempts) {
            #expect(attempts.count == 3)
            #expect(attempts[0].provider == "anthropic")
            #expect(attempts[1].provider == "openai")
            #expect(attempts[2].provider == "minimax-cn")
            #expect(c1.callCount == 1)
            #expect(c2.callCount == 1)
            #expect(c3.callCount == 1)
        } catch {
            Issue.record("expected allFailed, got \(error)")
        }
    }

    // MARK: Executor: strict variant

    @Test("executeOrThrow: propagates primary error without trying fallback")
    func testExecuteOrThrow_propagatesError() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1")
        _ = try await pool.register(provider: "openai", credential: "k2")
        let primary = StubConnector(id: "anthropic", responses: [
            .failure(makeTransportError(status: 503))
        ])
        let fallback = StubConnector(id: "openai", responses: [
            .success(makeResponse(id: "openai-1"))
        ])
        let resolver = StubResolver(mapping: [
            "anthropic": ResolvedConnector(connector: primary, apiKey: "k1"),
            "openai": ResolvedConnector(connector: fallback, apiKey: "k2")
        ])
        let executor = FallbackChainExecutor(pool: pool, resolver: resolver)
        let chain = FallbackChain(providers: ["anthropic", "openai"])
        do {
            _ = try await executor.executeOrThrow(request: .user("hi", model: "test"), chain: chain)
            Issue.record("expected primary error")
        } catch {
            // success: error is propagated
            #expect(primary.callCount == 1)
            #expect(fallback.callCount == 0)  // fallback was NOT tried
        }
    }

    // MARK: Executor: edge cases

    @Test("execute: empty chain throws emptyChain")
    func testExecute_emptyChain_throws() async throws {
        let pool = AuthPool()
        let resolver = StubResolver(mapping: [:])
        let executor = FallbackChainExecutor(pool: pool, resolver: resolver)
        let chain = FallbackChain(providers: [])
        await #expect(throws: FallbackChainError.emptyChain) {
            _ = try await executor.execute(request: .user("hi", model: "test"), chain: chain)
        }
    }
}
