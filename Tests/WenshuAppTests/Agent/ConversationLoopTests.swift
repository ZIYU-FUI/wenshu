//
//  ConversationLoopTests.swift · Wenshu · v0.35 ticket 001 sub-step 3
//
//  Unit tests for ConversationLoop actor (= hermes-core-translation
//  spec §3.1 + §3.4 + §0.1 truth-survey finding A1).
//
//  Hermes Python target: conversation_loop.run_conversation at L523-L546
//  (= 9-param entry, returns Dict[str, Any]).
//  Swift port: ConversationLoop actor with matching signature.
//
//  Test surface:
//  1. ConversationLoop signature mirrors hermes run_conversation 9-param shape
//  2. First-turn (empty conversation history) handling
//  3. Multi-turn (conversation history threading)
//  4. streamCallback receives LLMBlock events (= streaming contract)
//  5. Result struct contains final response + message history
//  6. System prompt precedence (= systemMessage overrides)
//  7. Error propagation (= LLMConnectorError)
//
//  All tests use MockLLMConnector (= defined in LLMConnectorTests.swift)
//  for deterministic non-streaming responses.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ConversationLoop (ticket 001 sub-step 3)")
struct ConversationLoopTests {

    // MARK: - Test 1: Signature mirrors hermes run_conversation

    @Test("ConversationLoop.runConversation signature has all 9 hermes run_conversation params")
    func testSignatureMirrorsHermes() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        // Hermes L523-L546 params:
        // agent, user_message, system_message=None, conversation_history=None,
        // task_id=None, stream_callback=None, persist_user_message=None,
        // persist_user_timestamp=None, moa_config=None
        let result = try await loop.runConversation(
            userMessage: "hello",
            systemMessage: nil,
            conversationHistory: nil,
            taskId: nil,
            streamCallback: nil,
            persistUserMessage: nil,
            persistUserTimestamp: nil,
            moaConfig: nil
        )

        // Result must contain final response + message history (= hermes return shape)
        #expect(result.response.model == "mock-model")
        #expect(result.messages.count >= 2)  // user + assistant at minimum
    }

    // MARK: - Test 2: First-turn (empty history)

    @Test("First turn with empty conversation history builds correct message list")
    func testFirstTurnEmptyHistory() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        let result = try await loop.runConversation(
            userMessage: "first turn",
            conversationHistory: nil
        )

        // First message in history must be the user message
        #expect(result.messages[0].role == .user)
        #expect(result.messages[0].plainText == "first turn")
        // Last message must be the assistant response
        #expect(result.messages.last?.role == .assistant)
    }

    // MARK: - Test 3: Multi-turn (history threading)

    @Test("Subsequent turn threads conversation history correctly")
    func testMultiTurnHistoryThreading() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        let priorHistory = [
            LLMMessage.user("prior question"),
            LLMMessage.assistant("prior answer")
        ]

        let result = try await loop.runConversation(
            userMessage: "follow-up",
            conversationHistory: priorHistory
        )

        // Result history starts with prior history, appends new user + assistant
        #expect(result.messages.count == 4)  // 2 prior + 1 user + 1 assistant
        #expect(result.messages[0].role == .user)
        #expect(result.messages[1].role == .assistant)
    }

    // MARK: - Test 4: Stream callback receives LLMBlock events

    @Test("streamCallback receives LLMBlock events (= non-streaming simulates 1 text event)")
    func testStreamCallbackReceivesBlocks() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        actor BlockCollector {
            var blocks: [LLMBlock] = []
            func append(_ b: LLMBlock) { blocks.append(b) }
        }
        let collector = BlockCollector()

        _ = try await loop.runConversation(
            userMessage: "test streaming",
            streamCallback: { block in
                await collector.append(block)
            }
        )

        let received = await collector.blocks
        #expect(received.count >= 1)
    }

    // MARK: - Test 5: Result struct shape

    @Test("ConversationResult contains response + messages + taskId")
    func testResultStructShape() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        let result = try await loop.runConversation(
            userMessage: "test result",
            taskId: "task-abc-123"
        )

        #expect(result.taskId == "task-abc-123")
        #expect(result.response.model == "mock-model")
        #expect(result.messages.count >= 2)
    }

    // MARK: - Test 6: System prompt precedence

    @Test("systemMessage parameter is accepted (= stub layer)")
    func testSystemPromptPrecedence() async throws {
        let connector = MockLLMConnector()
        let loop = ConversationLoop(connector: connector)

        let result = try await loop.runConversation(
            userMessage: "test",
            systemMessage: "you are a writing assistant"
        )

        #expect(result.response.id == "mock")
        #expect(!result.messages.isEmpty)
    }

    // MARK: - Test 7: Error propagation

    @Test("Connector errors propagate as LLMConnectorError")
    func testErrorPropagation() async throws {
        let failingConnector = FailingMockConnector()
        let loop = ConversationLoop(connector: failingConnector)

        await #expect(throws: LLMConnectorError.self) {
            _ = try await loop.runConversation(userMessage: "test")
        }
    }
}

// MARK: - Mock connector that fails (= used by test 7)

private actor FailingMockConnector: LLMConnector {
    nonisolated let connectorID = "failing-mock"

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        throw LLMConnectorError.transport(provider: "failing-mock", statusCode: 500, body: "test failure")
    }
}

// Note: MockLLMConnector (= defined in LLMConnectorTests.swift) is reused
// for tests 1-6. Its actor isolation means it can be passed as `connector:`
// parameter without additional wrapping.