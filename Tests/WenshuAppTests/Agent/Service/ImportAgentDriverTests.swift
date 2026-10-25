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
//    2. A folder with an import template
//       resolves its own SOP (= every one
//       of the six import folders has a
//       procedure).
//    3. A folder without an import
//       template throws `noSOPForFolder`
//       (= no SOP = no run; = orchestrator
//       falls back to legacy path in A5).
//

import WenshuAgent
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
        let root = try makeBookRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = ImportAgentBookContext(
            bookPath: { root.path }
        )
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "# source content\n\nSome source text.",
            bookPath: "/ws/十二地仙",
            bookTitle: "十二地仙",
            targetFolder: .world
        )
        let result = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            try await driver.run(
                input: input,
                bookContext: context,
                progress: nil
            )
        }
        // The SOP name is the world SOP.
        XCTAssertEqual(result.sopName, "ImportWorldPrompt")
        // The stub wrote one document.
        XCTAssertEqual(result.toolUseCount, 1)
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

    // MARK: - The request advertises the write tool

    func testRunAdvertisesTheWriteToolToTheProvider() async throws {
        // The model can only emit a tool_use block for a tool the
        // request body names, so the request the connector receives
        // must carry the write tool's declaration (= without it the
        // import ends as a plain-text reply and nothing is written).
        let stub = WorldFolderStubConnector()
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "stub"
        )
        let root = try makeBookRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = ImportAgentBookContext(
            bookPath: { root.path }
        )
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "# source content",
            bookPath: "/ws/twelve-immortals",
            bookTitle: "twelve-immortals",
            targetFolder: .world
        )
        _ = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            try await driver.run(
                input: input,
                bookContext: context,
                progress: nil
            )
        }
        let advertised = stub.receivedOptions.last?.tools ?? []
        XCTAssertFalse(
            advertised.isEmpty,
            "The turn must advertise a tool declaration to the provider."
        )
        XCTAssertTrue(
            advertised.contains { $0.name == "writeBookDoc" },
            "The advertised tool must be the write tool the turn dispatches."
        )
    }

    // MARK: - Every import folder resolves its own SOP

    func testRunWithCharactersFolderLoadsTheCharactersSOP() async throws {
        // The sheet lets the user pick all six import folders,
        // = so each one must resolve a procedure (= a folder
        // without a procedure was a dead end).
        let stub = WorldFolderStubConnector()
        // The run writes into the folder the user picked (= the
        // characters one).
        stub.folder = "characters"
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "stub"
        )
        let root = try makeBookRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = ImportAgentBookContext(
            bookPath: { root.path }
        )
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "x",
            bookPath: "/ws/twelve-immortals",
            bookTitle: "twelve-immortals",
            targetFolder: .characters
        )
        let result = try await PathGuard.$libraryRootOverride.withValue(root.path) {
            try await driver.run(
                input: input,
                bookContext: context,
                progress: nil
            )
        }
        XCTAssertEqual(result.sopName, "ImportCharactersPrompt")
        // The procedure names its own folder (= not the world one).
        let systemPrompt = stub.receivedOptions.last?.systemPrompt ?? ""
        XCTAssertTrue(
            systemPrompt.contains("characters"),
            "The characters procedure must name the characters folder."
        )
    }

    // MARK: - No SOP for a folder without an import template

    func testRunWithFolderWithoutImportTemplateThrowsNoSOPError() async throws {
        let stub = WorldFolderStubConnector()
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "stub"
        )
        let context = ImportAgentBookContext(
            bookPath: { "/ws/十二地仙" }
        )
        // sessions folder = no import template = no SOP
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "x",
            bookPath: "/ws/十二地仙",
            bookTitle: "十二地仙",
            targetFolder: .sessions
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
                XCTAssertEqual(f, .sessions)
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
    /// The folder the stub writes into (= the folder the run owns).
    var folder: String = "world"

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages.append(messages)
        receivedOptions.append(options)
        // The model writes one document (= the run must land a file;
        // = a run that writes nothing is a failure, = not a success).
        if receivedOptions.count == 1 {
            return LLMResponse(
                id: "stub",
                model: "stub",
                blocks: [.toolUse(
                    id: "stub-call-1",
                    name: "writeBookDoc",
                    input: "{\"path\":\"\(folder)/stub.md\",\"body\":\"# stub\"}"
                )],
                stopReason: .toolUse,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }
        // The write is done (= the tool loop ends).
        return LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.text("done")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }
    // `stream(...)` delegates to `send(...)` (= the stub
    // is a non-streaming test fixture; = yielding the
    // canned response is the canonical mock behavior).
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

// MARK: - The book root

/// A real directory the write tool can write into.
///
/// The context's book path is where the tool writes; = the input's book
/// path is what the procedure names. = the two are separate, = so a test
/// can check the procedure's text and still land a real file.
func makeBookRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("wenshu-import-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: root, withIntermediateDirectories: true
    )
    return root
}
