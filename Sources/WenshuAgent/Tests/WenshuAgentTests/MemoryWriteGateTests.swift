//
//  MemoryWriteGateTests.swift · wenshu
//
//  The turn's own settings decide whether the turn is written into the
//  memory store.
//
//  The memory adapter's write carries its own guard, but that guard reads
//  a global user-defaults key (= `wenshu.memory.enabled`), so the turn's
//  settings could not turn the write off. A caller that asks for no memory
//  (= the import turn) would still leave a trace of every turn in the
//  memory store.
//
//  So the gate belongs where the write is: in the turn's "Persisting
//  memory" step. These tests drive the REAL turn loop with a recording
//  memory provider, so the assertion is on what the provider received.
//
//  Coverage:
//    1. The switch off (= the import's setting) writes nothing.
//    2. The switch on writes the turn, as it always did.
//

import Foundation
import XCTest
@testable import WenshuAgent

final class MemoryWriteGateTests: XCTestCase {

    /// A provider that records every turn written into it.
    private final class RecordingMemoryProvider: MemoryProvider, @unchecked Sendable {
        let slug = "recording-memory"
        var isEnabled: Bool { true }

        private let writes = Writes()

        func writtenTurns() async -> [String] { await writes.values }

        func getSystemPrompt() -> String { "" }

        func prefetch(forUserMessage message: String) async -> String { "" }

        func sync(userMessage: String, assistantResponse: String) async {
            await writes.append(userMessage)
        }

        func getToolSchemas() -> [ToolSchema] { [] }

        func preCompressCheckpoint() async -> String? { nil }
    }

    /// The recorded turns.
    ///
    /// A lock is unavailable in an async context, so the writes go through
    /// an actor (= the only safe way to mutate shared state from one).
    private actor Writes {
        private(set) var values: [String] = []
        func append(_ value: String) { values.append(value) }
    }

    /// A connector that answers with a plain text turn (= no tool call, so
    /// the turn ends after one round trip).
    private final class PlainTextConnector: LLMConnector, @unchecked Sendable {
        let connectorID = "plain-text"
        let contextWindow = 32_000

        func send(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) async throws -> LLMResponse {
            LLMResponse(
                id: "plain",
                model: options.model,
                blocks: [.text("the turn is over")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }

        nonisolated func stream(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) -> AsyncStream<LLMBlock> {
            AsyncStream { continuation in
                continuation.yield(.text("the turn is over"))
                continuation.finish()
            }
        }
    }

    func testTheTurnWritesNothingWhenTheMemorySwitchIsOff() async throws {
        let recorder = RecordingMemoryProvider()
        let loop = ConversationLoop(
            connection: PlainTextConnector(),
            systemPrompt: "system",
            memoryProvider: recorder
        )
        let settings = AgentSettings(
            memory: MemorySettings(enabled: false)
        )
        _ = try await loop.runTurn(
            userMessage: "the message that must not be remembered",
            systemMessage: "system",
            taskId: "memory-off",
            settings: settings
        )
        let written = await recorder.writtenTurns()
        XCTAssertTrue(
            written.isEmpty,
            "A turn whose settings say the memory subsystem is off must write nothing."
        )
    }

    func testTheTurnWritesTheTurnWhenTheMemorySwitchIsOn() async throws {
        let recorder = RecordingMemoryProvider()
        let loop = ConversationLoop(
            connection: PlainTextConnector(),
            systemPrompt: "system",
            memoryProvider: recorder
        )
        let settings = AgentSettings(
            memory: MemorySettings(enabled: true)
        )
        _ = try await loop.runTurn(
            userMessage: "the message that must be remembered",
            systemMessage: "system",
            taskId: "memory-on",
            settings: settings
        )
        let written = await recorder.writtenTurns()
        XCTAssertEqual(
            written,
            ["the message that must be remembered"],
            "A turn whose settings say the memory subsystem is on must write the turn."
        )
    }
}
