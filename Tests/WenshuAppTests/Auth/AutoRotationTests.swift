//
//  AutoRotationTests.swift · Wenshu · HERMES-DISPATCH-004
//
//  Tests for `AutoRotatingConnector` + `AutoRotationPolicy` +
//  `ClassifiedLLMErrorPolicy`.
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Test scaffolding

/// Per-call send actor that returns a fixed response or throws.
/// `actor` (= thread-safe under Swift 6 strict concurrency) so the
/// `@Sendable` closure captured by `AutoRotatingConnector` can mutate
/// internal counters without violating `SendableClosureCaptures`.
actor ScriptedSend {
    var responses: [Result<LLMResponse, Error>]
    private(set) var callCount = 0
    private(set) var observedContexts: [AutoRotationSendContext] = []

    init(responses: [Result<LLMResponse, Error>]) {
        self.responses = responses
    }

    func invoke(_ request: LLMRequest, context: AutoRotationSendContext) async throws -> LLMResponse {
        let idx = min(callCount, responses.count - 1)
        observedContexts.append(context)
        callCount += 1
        switch responses[idx] {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

private func makeResponse(id: String = "stub-1") -> LLMResponse {
    LLMResponse(
        id: id,
        model: "stub-model",
        blocks: [.text("hello")],
        stopReason: .endTurn,
        usage: LLMUsage(inputTokens: 10, outputTokens: 5)
    )
}

private func makeTransportError(status: Int) -> LLMConnectorError {
    .transport(provider: "stub", statusCode: status, body: "boom")
}

@Suite("AutoRotation (HERMES-DISPATCH-004)")
struct AutoRotationTests {

    // MARK: Primary succeeds

    @Test("send: primary key succeeds -> no rotation, no error")
    func testSend_primarySucceeds() async throws {
        let pool = AuthPool()
        let k1 = try await pool.register(provider: "anthropic", credential: "k1", priority: 0)
        _ = try await pool.register(provider: "anthropic", credential: "k2", priority: 1)
        let script = ScriptedSend(responses: [.success(makeResponse(id: "anthropic-1"))])
        let wrapper = AutoRotatingConnector(
            pool: pool,
            policy: .init(maxRotations: 3)
        ) { req, ctx in
            try await script.invoke(req, context: ctx)
        }
        let response = try await wrapper.send(
            request: .user("hi", model: "test"),
            provider: "anthropic"
        )
        #expect(response.id == "anthropic-1")
        let count = await script.callCount
        #expect(count == 1)
        // Mark-ok confirmed the primary key.
        let keys = await pool.allKeys()
        let updated = try #require(keys.first { $0.id == k1.id })
        #expect(updated.status == .ok)
    }

    // MARK: Rotate on 429

    @Test("send: 429 rotates to the next key")
    func testSend_rotateOn429() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1", priority: 0)
        _ = try await pool.register(provider: "anthropic", credential: "k2", priority: 1)
        let script = ScriptedSend(responses: [
            .failure(makeTransportError(status: 429)),  // k1 fails
            .success(makeResponse(id: "anthropic-2"))   // k2 succeeds
        ])
        let wrapper = AutoRotatingConnector(
            pool: pool,
            policy: .init(maxRotations: 3)
        ) { req, ctx in
            try await script.invoke(req, context: ctx)
        }
        let response = try await wrapper.send(
            request: .user("hi", model: "test"),
            provider: "anthropic"
        )
        #expect(response.id == "anthropic-2")
        let count = await script.callCount
        let contexts = await script.observedContexts
        #expect(count == 2)
        #expect(contexts.map { $0.provider }.allSatisfy { $0 == "anthropic" })
        #expect(contexts.map { $0.keyId?.uuidString }.allSatisfy { $0 != nil })
        // Two distinct keys were used.
        #expect(contexts[0].keyId != contexts[1].keyId)
    }

    // MARK: Rotate on 503

    @Test("send: 503 rotates to the next key")
    func testSend_rotateOn503() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "openai", credential: "k1", priority: 0)
        _ = try await pool.register(provider: "openai", credential: "k2", priority: 1)
        _ = try await pool.register(provider: "openai", credential: "k3", priority: 2)
        let script = ScriptedSend(responses: [
            .failure(makeTransportError(status: 503)),  // k1 fails
            .failure(makeTransportError(status: 503)),  // k2 fails
            .success(makeResponse(id: "openai-3"))      // k3 succeeds
        ])
        let wrapper = AutoRotatingConnector(
            pool: pool,
            policy: .init(maxRotations: 3)
        ) { req, ctx in
            try await script.invoke(req, context: ctx)
        }
        let response = try await wrapper.send(
            request: .user("hi", model: "test"),
            provider: "openai"
        )
        #expect(response.id == "openai-3")
        let count = await script.callCount
        #expect(count == 3)
    }

    // MARK: Max rotations exceeded

    @Test("send: maxRotations exceeded -> throws .exhausted")
    func testSend_maxRotationsExceeded_throws() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1", priority: 0)
        _ = try await pool.register(provider: "anthropic", credential: "k2", priority: 1)
        let script = ScriptedSend(responses: [
            .failure(makeTransportError(status: 429)),
            .failure(makeTransportError(status: 429)),
            .failure(makeTransportError(status: 429)),
            .failure(makeTransportError(status: 429))
        ])
        let wrapper = AutoRotatingConnector(
            pool: pool,
            policy: .init(maxRotations: 2)  // budget = 2 rotations past the initial send
        ) { req, ctx in
            try await script.invoke(req, context: ctx)
        }
        do {
            _ = try await wrapper.send(
                request: .user("hi", model: "test"),
                provider: "anthropic"
            )
            Issue.record("expected exhausted error")
        } catch let AutoRotationError.exhausted(provider, attempts, _) {
            #expect(provider == "anthropic")
            #expect(attempts == 3)  // 1 initial + 2 rotations
        } catch {
            Issue.record("expected exhausted, got \(error)")
        }
    }

    // MARK: Cooldown respected

    @Test("send: cooldown respected — rate-limited key is skipped on next pick")
    func testSend_cooldownRespected() async throws {
        let pool = AuthPool()
        _ = try await pool.register(provider: "anthropic", credential: "k1", priority: 0)
        _ = try await pool.register(provider: "anthropic", credential: "k2", priority: 1)
        // Mark k1 rate-limited for 60s (= default policy cooldown).
        let allKeys = await pool.allKeys()
        let k1 = try #require(allKeys.first)
        try await pool.markRateLimited(keyId: k1.id, cooldownSeconds: 60)
        // Now wrapper should skip k1 and pick k2.
        let script = ScriptedSend(responses: [.success(makeResponse(id: "k2-result"))])
        let wrapper = AutoRotatingConnector(
            pool: pool,
            policy: .init(maxRotations: 3)
        ) { req, ctx in
            try await script.invoke(req, context: ctx)
        }
        let response = try await wrapper.send(
            request: .user("hi", model: "test"),
            provider: "anthropic"
        )
        #expect(response.id == "k2-result")
        let count = await script.callCount
        let contexts = await script.observedContexts
        #expect(count == 1)
        // The single context.keyId should be k2, NOT k1.
        let ctx = try #require(contexts.first)
        #expect(ctx.keyId != k1.id)
    }

    // MARK: Policy: classify shim

    @Test("ClassifiedLLMErrorPolicy.classify: 429 -> rateLimit")
    func testClassify_429() {
        let s = ClassifiedLLMErrorPolicy.classify(
            error: makeTransportError(status: 429)
        )
        #expect(s.statusCode == 429)
        #expect(s.category == .rateLimit)
    }

    @Test("ClassifiedLLMErrorPolicy.classify: 503 -> serverError")
    func testClassify_503() {
        let s = ClassifiedLLMErrorPolicy.classify(
            error: makeTransportError(status: 503)
        )
        #expect(s.statusCode == 503)
        #expect(s.category == .serverError)
    }

    @Test("ClassifiedLLMErrorPolicy.classify: 401 -> unauthorized")
    func testClassify_401() {
        let s = ClassifiedLLMErrorPolicy.classify(
            error: makeTransportError(status: 401)
        )
        #expect(s.statusCode == 401)
        #expect(s.category == .unauthorized)
    }

    @Test("ClassifiedLLMErrorPolicy.classify: 400 -> badRequest (non-retryable)")
    func testClassify_400() {
        let s = ClassifiedLLMErrorPolicy.classify(
            error: makeTransportError(status: 400)
        )
        #expect(s.statusCode == 400)
        #expect(s.category == .badRequest)
    }
}
