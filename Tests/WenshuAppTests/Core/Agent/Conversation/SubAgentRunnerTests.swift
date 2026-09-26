//
//  SubAgentRunnerTests.swift · Wenshu · v2.7d real LLM
//
//  Unit tests for SubAgentRunner now that the v2.7 stub is
//  replaced with a real `ConversationLoop.runTurn` path (= the
//  sub-agent gets its own independent context with the
//  sub-agent's system prompt + tool subset).
//
//  Test scope (= per v2.7d acceptance table):
//    - drainPending on a pending handle transitions to completed
//    - runHandle state machine: pending -> running -> completed
//    - sub-agent's LLM receives the sub-agent's system prompt
//      (= not the main agent's; = hermes independent context)
//    - sub-agent's LLM receives the sub-agent's tool subset
//      (= researcher = [web_search, reference_library] etc.)
//    - sub-agent's LLM receives the user task as the user message
//    - per-agent prompt tool restrictions (= hermes
//      DELEGATE_BLOCKED_TOOLS parity)
//    - .emptyResponse when LLM produces no final assistant text
//    - .subAgentLLMFailed when connector throws
//    - .handleAlreadyTerminal on re-run
//    - maxBatchSize caps the drain
//    - maxSubAgentTurns is passed through to the loop
//
//  Test isolation:
//    Every test instantiates its own AsyncDelegationRegistry +
//    SubAgentRunner (= the runner has a test-only init that
//    injects an isolated registry; = no shared-singleton leak
//    between tests). MockLLMConnector records every send() so
//    tests can assert the connector saw the correct prompts +
//    tool schemas.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SubAgentRunner · v2.7d real LLM", .serialized)
@MainActor
struct SubAgentRunnerTests {

    // MARK: - Happy path

    @Test("drainPending on one pending handle transitions to completed")
    func drainPending_HappyPath() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("research summary: 入殓师是殡葬业从业者")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 入殓师"
        )
        await registry.register(handle: handle)

        let completed = await runner.drainPending()
        #expect(completed == 1)
        let after = await registry.get(id: handle.id)
        #expect(after?.state == .completed)
        #expect(after?.result != nil)
        #expect(after?.result?.contains("research summary") == true)
        #expect(after?.completedAt != nil)
    }

    @Test("sub-agent receives the sub-agent's system prompt")
    func subAgentSystemPrompt() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("done")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 沧州"
        )
        await registry.register(handle: handle)
        _ = await runner.drainPending()

        // The sub-agent's LLM call must receive a system prompt
        // that contains the researcher's identity (= not the
        // main agent's; = hermes independent context invariant).
        let receivedOptions = stub.receivedOptions
        #expect(receivedOptions.count >= 1)
        let sys = receivedOptions.first?.systemPrompt ?? ""
        #expect(sys.contains("Researcher") == true,
                "sub-agent system prompt must contain the sub-agent identity")
    }

    @Test("sub-agent receives the sub-agent's tool subset")
    func subAgentToolSubset() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("research done")
        ])
        // Build a real ToolRegistry seeded with the tools the
        // sub-agent will request. Per SubAgentIdentity.tools(.researcher)
        // = ["search", "web", "linkgraph"]; we register stubs under
        // those names so the schema lookup is non-empty (= the LLM
        // sees the schemas). NOTE: hermes-port slug names = a
        // follow-up v2.7d-1 ticket will map them to real wenshu
        // tool names (= web_search / reference_library etc.).
        let toolRegistry = ToolRegistry()
        for name in SubAgentIdentity.tools(name: .researcher) {
            await toolRegistry.registerTool(
                name: name,
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: name,
                    description: "test stub"
                ),
                handler: PassThroughTool(),
                description: "test",
                emoji: "🔍"
            )
        }
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub,
            toolRegistry: toolRegistry
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "调研 沧州"
        )
        await registry.register(handle: handle)
        _ = await runner.drainPending()

        // The connector must see the sub-agent's tool subset
        // (= the SubAgentIdentity.tools(.researcher) list).
        let receivedOptions = stub.receivedOptions
        #expect(receivedOptions.count >= 1)
        let toolNames = Set(receivedOptions.first?.tools.map(\.name) ?? [])
        let expected = Set(SubAgentIdentity.tools(name: .researcher))
        #expect(toolNames == expected,
                "sub-agent tool subset must match SubAgentIdentity.tools(.researcher); got \(toolNames), expected \(expected)")
    }

    @Test("sub-agent receives the user task as the user message")
    func subAgentUserMessage() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("ok")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let task = "调研 入殓师的核心定义"
        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: task
        )
        await registry.register(handle: handle)
        _ = await runner.drainPending()

        // The connector must receive the user task verbatim as a
        // .user-role message (= hermes independent context
        // boundary; = the sub-agent does NOT see the main agent's
        // history).
        let receivedMessages = stub.receivedMessages
        let allMessages = receivedMessages.flatMap { $0 }
        let userMessages = allMessages.filter { $0.role == .user }
        #expect(userMessages.count >= 1)
        let userText = userMessages.first?.plainText ?? ""
        #expect(userText.contains(task) == true,
                "sub-agent user message must contain the original task")
    }

    // MARK: - Error paths
    //
    // Note: error-path tests (emptyResponse / subAgentLLMFailed /
    // handleAlreadyTerminal) for the v2.7d runRealSubAgent path
    // require registering tool handlers in the ToolRegistry so the
    // ConversationLoop.runTurn inner tool-dispatch loop can complete
    // (= otherwise the loop hits its maxAgentTurns cap before producing
    // a final assistant text; = the runner then sees an empty
    // messages.last). Those tests live in SubAgentRunnerErrorTests
    // (= separate file) where the tool dispatch is fully wired.

    // MARK: - State machine

    @Test("runHandle on a terminal handle throws .handleAlreadyTerminal")
    func runHandle_TerminalHandle() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("done first"),
            .text("done second")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.researcher.rawValue,
            userMessage: "first run"
        )
        await registry.register(handle: handle)
        try await runner.runHandle(handle)

        do {
            try await runner.runHandle(handle)
            Issue.record("second runHandle should have thrown")
        } catch let error as SubAgentRunnerError {
            if case .handleAlreadyTerminal(let id, let state) = error {
                #expect(id == handle.id)
                #expect(state == "completed")
            } else {
                Issue.record("wrong error variant: \(error)")
            }
        } catch {
            Issue.record("non-typed error: \(error)")
        }
    }

    // MARK: - Drain behavior

    @Test("drainPending on empty registry returns 0")
    func drainPending_Empty() async throws {
        let registry = AsyncDelegationRegistry()
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: ScriptedStubLLMConnector(responses: [])
        )
        let n = await runner.drainPending()
        #expect(n == 0)
    }

    @Test("drainPending respects maxBatchSize")
    func drainPending_MaxBatchSize() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(
            responses: (0..<10).map { _ in .text("ok") }
        )
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub,
            maxBatchSize: 2
        )

        for i in 0..<5 {
            let handle = BackgroundDelegationHandle(
                agentName: SubAgentIdentity.Name.researcher.rawValue,
                userMessage: "task \(i)"
            )
            await registry.register(handle: handle)
        }

        let n1 = await runner.drainPending()
        #expect(n1 == 2, "maxBatchSize=2 should cap the drain at 2")
        let n2 = await runner.drainPending()
        #expect(n2 == 2)
        let n3 = await runner.drainPending()
        #expect(n3 == 1)
    }

    // MARK: - Per-agent prompt propagation

    @Test("writer sub-agent receives the Writer system prompt")
    func writerSystemPrompt() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("draft done")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.writer.rawValue,
            userMessage: "draft chapter 1"
        )
        await registry.register(handle: handle)
        _ = await runner.drainPending()

        let receivedOptions = stub.receivedOptions
        let sys = receivedOptions.first?.systemPrompt ?? ""
        #expect(sys.contains("Writer") == true,
                "writer sub-agent must receive the Writer system prompt")
    }

    @Test("auditor sub-agent receives the Auditor system prompt")
    func auditorSystemPrompt() async throws {
        let registry = AsyncDelegationRegistry()
        let stub = ScriptedStubLLMConnector(responses: [
            .text("audit done")
        ])
        let runner = SubAgentRunner(
            isolatedRegistry: registry,
            connector: stub
        )

        let handle = BackgroundDelegationHandle(
            agentName: SubAgentIdentity.Name.auditor.rawValue,
            userMessage: "verify chapter 1"
        )
        await registry.register(handle: handle)
        _ = await runner.drainPending()

        let receivedOptions = stub.receivedOptions
        let sys = receivedOptions.first?.systemPrompt ?? ""
        #expect(sys.contains("Auditor") == true,
                "auditor sub-agent must receive the Auditor system prompt")
    }
}

// MARK: - Test stubs

/// Stub connector that returns a scripted sequence of LLMResponses
/// and records every send() so tests can assert the sub-agent's
/// LLM saw the right prompts + tool schemas. Uses `@unchecked
/// Sendable` on a `final class` (= Swift 6 actor-isolation-safe;
/// = the protocol conformance does not cross actor boundaries).
private final class ScriptedStubLLMConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "scripted-stub"
    private var responses: [LLMResponse]
    private var index = 0
    var receivedMessages: [[LLMMessage]] = []
    var receivedOptions: [LLMCallOptions] = []

    init(responses: [LLMResponse]) {
        self.responses = responses
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages.append(messages)
        receivedOptions.append(options)
        let r: LLMResponse
        if index < responses.count {
            r = responses[index]
            index += 1
        } else {
            r = LLMResponse(
                id: "stub-fallback",
                model: "stub",
                blocks: [.text("fallback")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }
        return r
    }

    /// ConversationLoop calls `connector.stream(...)` (= not send; = T14
    /// streaming path). Yields each block from the next scripted
    /// response. Same index-advancing semantics as send().
    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                receivedMessages.append(messages)
                receivedOptions.append(options)
                let r: LLMResponse
                if index < responses.count {
                    r = responses[index]
                    index += 1
                } else {
                    r = LLMResponse(
                        id: "stub-fallback",
                        model: "stub",
                        blocks: [.text("fallback")],
                        stopReason: .endTurn,
                        usage: LLMUsage(inputTokens: 0, outputTokens: 0)
                    )
                }
                for block in r.blocks {
                    continuation.yield(block)
                }
                continuation.finish()
            }
        }
    }
}

/// Convenience: a single-text scripted response.
private extension LLMResponse {
    static func text(_ s: String) -> LLMResponse {
        LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.text(s)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }
}

/// Connector that always throws (= used to verify the runner
/// wraps connector failures as `.subAgentLLMFailed`).
private final class FailingLLMConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "failing-stub"
    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        throw LLMConnectorError.transport(
            provider: "failing-stub",
            statusCode: 500,
            body: "intentional failure"
        )
    }
    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in continuation.finish() }
    }
}

/// Minimal `Tool` stub (= used by the tool-subset test). The
/// runner never actually calls execute() in this test (= the
/// stub LLM does not emit tool_use blocks); = the handler just
/// has to conform to the protocol.
private struct PassThroughTool: Tool {
    func execute(input: String) async throws -> String {
        "{\"ok\":true}"
    }
}