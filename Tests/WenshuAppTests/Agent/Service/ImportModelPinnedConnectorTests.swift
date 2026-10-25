//
//  ImportModelPinnedConnectorTests.swift · wenshu
//
//  The pin replaces the model and nothing else.
//
//  A setting that is dropped at the pin never reaches the provider: = the
//  import's token cap and its thinking budget both travel this seam, = so
//  a rebuild that forgets one of them silently takes the setting away
//  from the request.
//

import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportModelPinnedConnectorTests: XCTestCase {

    func testThePinKeepsEverySettingButTheModel() async throws {
        let base = RecordingConnector()
        let pinned = ImportModelPinnedConnector(base: base, model: "the-model-the-user-picked")
        let options = LLMCallOptions(
            model: "the-provider-default",
            maxTokens: 16384,
            systemPrompt: "the procedure",
            temperature: 0.2,
            reasoningEffort: "high",
            thinkingBudget: 8192,
            tools: [WriteBookDocTool.schema]
        )
        _ = try await pinned.send(messages: [], options: options)
        let sent = try XCTUnwrap(base.receivedOptions.last)
        // The model is the one the user picked.
        XCTAssertEqual(sent.model, "the-model-the-user-picked")
        // Every other setting travels with it.
        XCTAssertEqual(sent.maxTokens, 16384)
        XCTAssertEqual(sent.systemPrompt, "the procedure")
        XCTAssertEqual(sent.temperature, 0.2)
        XCTAssertEqual(sent.reasoningEffort, "high")
        XCTAssertEqual(sent.thinkingBudget, 8192)
        XCTAssertEqual(sent.tools.count, options.tools.count)
    }

    func testThePinKeepsTheSettingsOnTheStreamToo() async throws {
        let base = RecordingConnector()
        let pinned = ImportModelPinnedConnector(base: base, model: "the-model-the-user-picked")
        let options = LLMCallOptions(
            model: "the-provider-default",
            maxTokens: 16384,
            thinkingBudget: 8192
        )
        let stream = pinned.stream(messages: [], options: options)
        for await _ in stream { }
        let sent = try XCTUnwrap(base.receivedOptions.last)
        XCTAssertEqual(sent.model, "the-model-the-user-picked")
        XCTAssertEqual(sent.thinkingBudget, 8192)
        XCTAssertEqual(sent.maxTokens, 16384)
    }
}

// MARK: - Stub connector

private final class RecordingConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "recording-stub"
    var receivedOptions: [LLMCallOptions] = []

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedOptions.append(options)
        return LLMResponse(
            id: "stub",
            model: options.model,
            blocks: [.text("ok")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }

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
