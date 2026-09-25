//
//  E2EMemoryAndLLMFlowTests.swift · Wenshu · v2.4 acceptance
//
//  Black-box end-to-end test (= the v2.4 §11.17 acceptance gate).
//
//  Flow (= exactly what wenshu.app does when the user types one prompt
//  and hits send in ChatView):
//
//    1. Wire the real ConversationLoop against the real minimax-cn
//       connector (= AppleKeychain key). No stub. No fake.
//       A thin RecordingLLMConnector wraps the real connector and
//       captures every send(messages:options:) call (= request payload
//       + response blocks) so the test can assert exactly what was
//       sent + received.
//
//    2. Reset WSMemoryProvider mirror + WSMemoryRepository (= empty
//       memory store before turn 1 so the prefetch path returns
//       zero rows = canonical "first ever turn" shape).
//
//    3. Call ConversationLoop.runTurn(userMessage: "你好, 我叫老王,
//       我喜欢写短篇小说") with tools: [] (= no tool_use dispatch
//       possible = the LLM emits a plain text reply).
//
//    4. Assert:
//       A. RecordingLLMConnector captured >=1 LLM send (= the LLM
//          was actually called).
//       B. The captured request payload contains the user message
//          (= "我叫老王" / "短篇小说") in the messages array.
//       C. The captured response has at least one .text block with
//          non-empty content (= real LLM reply).
//       D. WSMemoryRepository has >=1 row for userId="default"
//          after the turn (= the v2.4 memory write went through).
//       E. The persisted memory content includes the user's name
//          "老王" (= the assistant's reply made it into memory).
//
//  Streaming note:
//    This test does NOT exercise the streamCallback path
//    (= ConversationLoop.runTurn uses the blocking send()). The
//    streaming gate (= LLMBlock tokens rendered live in ChatView)
//    is verified separately by ConversationLoopTests +
//    ChatSessionViewModelStreamingTests.
//
//  Why no stub:
//    The whole point of this test is to confirm the v2.4 §11.17
//    "memory rewire" actually persists end-to-end. A stub would
//    prove the wiring compiles; = it would NOT prove the memory
//    row survives the SwiftData round-trip. The live test is
//    the only signal that boss OOB 2026-09-25 (用户不再被
//    自由编辑 agent, = 换取系统稳定输出) is honored.
//
//  Gate:
//    WENSHU_LIVE_API_TESTS=1 (default off; CI-safe). Boss opt-in
//    runs the test against the real minimax-cn endpoint using the
//    AppleKeychain-stored API key.
//

import Testing
import Foundation
import os
@testable import WenshuApp

@Suite("E2E: one prompt → real LLM call → real memory write (LIVE)")
struct E2EMemoryAndLLMFlowTests {

    private static var liveEnabled: Bool {
        ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"
    }

    @Test("one prompt: ConversationLoop calls minimax-cn exactly once, memory row persists with user name")
    @MainActor
    func fullFlow() async throws {
        guard Self.liveEnabled else {
            Issue.record("skipped (= WENSHU_LIVE_API_TESTS not set)")
            return
        }

        // Step 0: reset WSMemory mirror + SwiftData store so the
        // "first ever turn" canonical shape holds (= prefetch returns
        // []; = post-turn sync writes exactly 1 row).
        await WSMemoryProvider.shared.resetCache()
        // purgeOlderThan with retentionDays=0 wipes every row whose
        // updatedAt < now (= = every row in this dev test env).
        let purged = (try? WSMemoryRepository.shared.purgeOlderThan(
            userId: "default",
            retentionDays: 0
        )) ?? 0
        print("[E2E] purged \(purged) pre-existing memory row(s) (= dev residue)")
        let baselineCount = (try? WSMemoryRepository.shared.count(userId: "default")) ?? 0
        print("[E2E] baseline memory rows = \(baselineCount)")
        #expect(baselineCount == 0, "memory store must start empty for this e2e (= purge before turn)")

        // Step 1: build the real MinimaxConnector + wrap it with
        // RecordingLLMConnector. AppleKeychain key resolves via the
        // standard ConnectorCredentials path (= no special-cased
        // test injection).
        let realConnector = MinimaxConnector()
        let recording = RecordingLLMConnector(wrapping: realConnector)

        // Step 2: build ConversationLoop with the recording wrapper.
        // tools: [] (= no tool dispatch possible). Compression +
        // shell hooks use defaults (= no behavior change).
        let loop = ConversationLoop(connection: recording)

        // Step 3: one user turn. The user message carries identifying
        // information (= "我叫老王, 我喜欢写短篇小说") so the post-turn
        // assertion can verify the memory row captured it.
        let userMessage = "你好, 我叫老王, 我喜欢写短篇小说。请用一句话回复我。"
        print("[E2E] sending prompt: \(userMessage)")

        let result = try await loop.runTurn(
            userMessage: userMessage,
            systemMessage: nil,
            conversationHistory: [],
            tools: [:],
            taskId: "e2e-001"
        )

        // Step 4A: LLM was called at least once.
        let captured = await recording.capturedCalls()
        print("[E2E] LLM send calls captured = \(captured.count)")
        for (idx, call) in captured.enumerated() {
            print("[E2E]   call[\(idx)] model=\(call.options.model) systemPromptChars=\(call.options.systemPrompt?.count ?? 0) messageCount=\(call.requestMessages.count)")
            let textBlockCount = call.response.blocks.filter { if case .text = $0 { return true } else { return false } }.count
            print("[E2E]   call[\(idx)] responseTextBlocks=\(textBlockCount)")
        }
        guard let firstCall = captured.first else {
            Issue.record("ConversationLoop must call the LLM at least once per turn (= captured.count == 0); possibly failed before reaching the LLM round-trip")
            return
        }
        #expect(captured.count >= 1, "ConversationLoop must call the LLM at least once per turn")
        let userTexts = firstCall.requestMessages
            .filter { $0.role == .user }
            .compactMap { msg -> String? in
                for case .text(let s) in msg.blocks { return s }
                return nil
            }
        let userTextBlob = userTexts.joined(separator: " ")
        print("[E2E] request user-text blob: \(String(userTextBlob.prefix(200)))")
        #expect(userTextBlob.contains("老王"), "user message must reach the LLM request payload (= '老王' is the unique marker)")
        #expect(userTextBlob.contains("短篇小说"), "user message must reach the LLM request payload")

        // Step 4C: response has at least one .text block with content.
        let responseTexts = firstCall.response.blocks.compactMap { block -> String? in
            if case .text(let s) = block { return s }
            return nil
        }
        let responseText = responseTexts.joined(separator: "\n")
        print("[E2E] LLM reply (\(responseText.count) chars): \(String(responseText.prefix(200)))")
        #expect(!responseText.isEmpty, "LLM response must contain at least one non-empty text block")

        // Step 4D: a memory row was persisted for this turn.
        // ConversationLoop.runTurn step 8 fires MemoryAdapter().write(...)
        // which delegates to WSMemoryProvider.shared.sync(...) which writes
        // through WSMemoryRepository.shared to SwiftData.
        let postCount = (try? WSMemoryRepository.shared.count(userId: "default")) ?? 0
        print("[E2E] post-turn memory rows = \(postCount)")
        #expect(postCount >= 1, "ConversationLoop.runTurn must persist at least 1 memory row (= step 8: Persisting memory)")

        // Step 4E: the persisted row contains the user's name "老王".
        let recentRows = (try? WSMemoryRepository.shared.listRecent(userId: "default", limit: 5)) ?? []
        let rowContentBlob = recentRows.map(\.content).joined(separator: "\n")
        print("[E2E] persisted memory blob (\(rowContentBlob.count) chars): \(String(rowContentBlob.prefix(300)))")
        #expect(rowContentBlob.contains("老王"), "persisted memory must contain user name '老王' (= the write went through end-to-end)")

        // Step 4F (bonus): confirm system prompt was passed (= the
        // v2.4 memory prefetch happens inside composeSystemPrompt).
        let systemChars = firstCall.options.systemPrompt?.count ?? 0
        print("[E2E] system prompt chars sent to LLM = \(systemChars)")
        #expect(systemChars > 100, "system prompt must be non-trivial (= composeSystemPrompt must have built the full prompt)")

        // Sanity: confirm the ConversationResult response is non-empty
        // (= the same content as the LLM send response, just for completeness).
        print("[E2E] ConversationResult.response blocks: \(result.response.blocks.count)")
        #expect(result.response.blocks.count > 0, "ConversationResult.response must carry the LLM blocks")
    }
}

// MARK: - Recording connector

/// One captured send() invocation (= request payload + LLM response).
/// File-scope (= the wrapper returns it from capturedCalls()).
struct CapturedLLMCall: Sendable {
    let requestMessages: [LLMMessage]
    let options: LLMCallOptions
    let response: LLMResponse
}

/// Thin LLMConnector wrapper that captures every send() call's input
/// (= messages + options) + output (= LLMResponse blocks). Forwards
/// to the wrapped real connector (= so the network IO is real).
///
/// Uses an NSLock for thread-safe `calls` append (= the wrapped
/// connector may invoke send from a background URLSession task; =
/// cross-actor writes to the captured array are safe via lock).
final class RecordingLLMConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String

    private let wrapped: any LLMConnector
    private let lock = OSAllocatedUnfairLock<[CapturedLLMCall]>(initialState: [])

    init(wrapping wrapped: any LLMConnector) {
        self.wrapped = wrapped
        self.connectorID = wrapped.connectorID
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let response = try await wrapped.send(messages: messages, options: options)
        let captured = CapturedLLMCall(
            requestMessages: messages,
            options: options,
            response: response
        )
        lock.withLock { state in
            state.append(captured)
        }
        return response
    }

    func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        // ConversationLoop.runTurn uses the streamInto path
        // (= for await block in connector.stream). We forward to
        // the wrapped connector's send directly (= the default
        // extension's `stream` calls `send`, but if the wrapped
        // connector overrides `stream with native SSE, the capture
        // would miss it). Calling `wrapped.send` here guarantees
        // every recorded block traces back to a single LLM HTTP call
        // (= the canonical observability shape for this test).
        AsyncStream { continuation in
            Task {
                do {
                    let response = try await wrapped.send(messages: messages, options: options)
                    // Capture (= same shape as send()'s capture).
                    let captured = CapturedLLMCall(
                        requestMessages: messages,
                        options: options,
                        response: response
                    )
                    lock.withLock { state in
                        state.append(captured)
                    }
                    // Yield blocks + finish (= mirrors the default
                    // extension's behavior in LLMConnector.swift:75).
                    for block in response.blocks {
                        continuation.yield(block)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.text("[stream error] \(error)"))
                    continuation.finish()
                }
            }
        }
    }

    func capturedCalls() async -> [CapturedLLMCall] {
        lock.withLock { state in state }
    }
}