//
//  ImportAgentDriverTests.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  Unit tests for ImportAgentDriver. The
//  driver is the part that wires:
//    1. SOP lookup (= ImportSOPTrigger)
//    2. SOP load (= ImportSOPLoader)
//    3. ConversationLoop.runTurn with the
//       SOP as system message
//
//  Coverage:
//    1. `run()` with a world-folder input
//       resolves the SOP, invokes the LLM,
//       and returns an `ImportAgentResult`.
//    2. A non-world folder throws
//       `noSOPForFolder` (= no SOP = no
//       run; = orchestrator falls back to
//       legacy path in A5).
//

import XCTest
@testable import WenshuApp

final class ImportAgentDriverTests: XCTestCase {

    // MARK: - run() resolves SOP for .world

    func testRunWithWorldFolderLoadsSOPAndReturnsResult() async throws {
        // Stub connector = returns a
        // single end-turn response (= the
        // agent says "完成" right away =
        // (= no real LLM call; = just
        // validates the wiring).
        let stub = WorldFolderStubConnector()
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "stub"
        )
        let context = ImportAgentBookContext(
            bookPath: { "/ws/十二地仙" }
        )
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "# source content\n\nSome source text.",
            bookPath: "/ws/十二地仙",
            bookTitle: "十二地仙",
            targetFolder: .world
        )
        let result = try await driver.run(
            input: input,
            bookContext: context,
            progress: nil
        )
        // The SOP name is the world SOP.
        XCTAssertEqual(result.sopName, "ImportWorldPrompt")
        // The stub returned end-turn
        // immediately (= no tool_use; = 0).
        XCTAssertEqual(result.toolUseCount, 0)
        // The connector should have received
        // at least one call (= the agent's
        // user message).
        XCTAssertGreaterThan(stub.receivedMessages.count, 0)
        // The connector received the system
        // message (= the substituted SOP).
        // The last `receivedOptions.systemPrompt`
        // contains the substituted text.
        let lastSystemPrompt = stub.receivedOptions
            .last?
            .systemPrompt ?? ""
        XCTAssertTrue(lastSystemPrompt.contains("/tmp/source.md"),
                       "Substituted SOP should contain the file path")
        XCTAssertTrue(lastSystemPrompt.contains("/ws/十二地仙"),
                       "Substituted SOP should contain the book path")
        XCTAssertTrue(lastSystemPrompt.contains("十二地仙"),
                       "Substituted SOP should contain the book title")
        XCTAssertTrue(lastSystemPrompt.contains("# source content"),
                       "Substituted SOP should contain the body content")
    }

    // MARK: - No SOP for non-world folder

    func testRunWithNonWorldFolderThrowsNoSOPError() async throws {
        let stub = WorldFolderStubConnector()
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "stub"
        )
        let context = ImportAgentBookContext(
            bookPath: { "/ws/十二地仙" }
        )
        // characters folder = no SOP yet
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "x",
            bookPath: "/ws/十二地仙",
            bookTitle: "十二地仙",
            targetFolder: .characters
        )
        do {
            _ = try await driver.run(
                input: input,
                bookContext: context,
                progress: nil
            )
            XCTFail("Expected noSOPForFolder error, but driver ran.")
        } catch {
            guard let driverError = error as? ImportAgentDriver.ImportAgentError else {
                XCTFail("Expected ImportAgentDriver.ImportAgentError, got \(error)")
                return
            }
            if case .noSOPForFolder(let f) = driverError {
                XCTAssertEqual(f, .characters)
            } else {
                XCTFail("Expected noSOPForFolder, got \(driverError)")
            }
        }
    }
}

// MARK: - Stub connector

private final class WorldFolderStubConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "world-stub"
    var receivedMessages: [[LLMMessage]] = []
    var receivedOptions: [LLMCallOptions] = []

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages.append(messages)
        receivedOptions.append(options)
        // Return end-turn (= no tool_use).
        // The agent's tool loop will exit
        // immediately; = we can verify
        // the SOP was injected correctly.
        return LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.text("完成")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }
    // `stream(...)` uses the default
    // implementation in the LLMConnector
    // extension (= it calls `send(...)`
    // and yields each block).
}