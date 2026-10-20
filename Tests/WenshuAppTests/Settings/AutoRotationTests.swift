//
//  AutoRotationTests.swift · Wenshu · HERMES-DISPATCH-004
//
//  Tests for `AutoRotatingConnector` + `AutoRotationPolicy` +
//  `ClassifiedLLMErrorPolicy`.
//

import Testing
import Foundation
import WenshuAgent
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

    func invoke(_ request: DispatchRequest, context: AutoRotationSendContext) async throws -> LLMResponse {
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

    // MARK: Rotate on 429

    // MARK: Rotate on 503

    // MARK: Max rotations exceeded

    // MARK: Cooldown respected

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
