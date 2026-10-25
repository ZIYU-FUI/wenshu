//
//  ImportAgentCleanContextTests.swift · wenshu
//
//  Unit tests for the settings and the model that the import turn runs
//  under.
//
//  An import is a mechanical transformation with a fixed procedure, not a
//  conversation. So the turn must read nothing but its procedure, write
//  nothing back into the memory store, and go out on the model the user
//  picked.
//
//  Coverage:
//    1. Every guidance switch in the import settings is off.
//    2. The memory subsystem is off, so the turn writes no memory.
//    3. The visible tools set is empty (= every registered tool, so the
//       write tool stays reachable).
//    4. The turn goes out on the driver's model slug, not on the
//       connector's default model.
//

import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportAgentCleanContextTests: XCTestCase {

    // MARK: - The settings the import turn runs under

    func testTheImportSettingsTurnEveryGuidanceSwitchOff() {
        let prompt = ImportAgentDriver.importSettings.prompt

        XCTAssertFalse(prompt.identityEnabled)
        XCTAssertFalse(prompt.providerGuidanceEnabled)
        XCTAssertFalse(prompt.memoryGuidanceEnabled)
        XCTAssertFalse(prompt.skillGuidanceEnabled)
        XCTAssertFalse(prompt.toolGuidanceEnabled)
        XCTAssertFalse(prompt.helpGuidanceEnabled)
        XCTAssertFalse(prompt.includeProjectContextFiles)
        XCTAssertFalse(prompt.includeBookContext)
        XCTAssertFalse(prompt.includeEnvironmentHints)
    }

    func testTheImportSettingsTurnTheMemorySubsystemOff() {
        XCTAssertFalse(
            ImportAgentDriver.importSettings.memory.enabled,
            "The import turn must not write into the memory store."
        )
    }

    func testTheImportSettingsLeaveEveryToolVisible() {
        // An EMPTY set means every registered tool, so the write tool stays
        // reachable. A non-empty set would be a whitelist that hides it.
        XCTAssertTrue(
            ImportAgentDriver.importSettings.prompt.visibleTools.isEmpty,
            "The visible tools set must stay empty, so the write tool is reachable."
        )
    }

    // MARK: - The model the import turn goes out on

    func testTheImportTurnGoesOutOnTheDriversModelSlug() async throws {
        let stub = ModelRecordingStubConnector()
        let driver = ImportAgentDriver(
            connector: stub,
            modelSlug: "the-model-the-user-picked"
        )
        let context = ImportAgentBookContext(
            bookPath: { "/ws/twelve-immortals" }
        )
        let input = ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "# source content",
            bookPath: "/ws/twelve-immortals",
            bookTitle: "twelve-immortals",
            targetFolder: .world
        )
        _ = try await driver.run(
            input: input,
            bookContext: context,
            progress: nil
        )
        let models = stub.receivedOptions.map(\.model)
        XCTAssertFalse(models.isEmpty, "The stub connector received no call.")
        for model in models {
            XCTAssertEqual(
                model,
                "the-model-the-user-picked",
                "The import turn must go out on the driver's model slug."
            )
        }
    }
}

// MARK: - Stub connector

/// A stub that records the call options it received.
private final class ModelRecordingStubConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "model-stub"
    var receivedOptions: [LLMCallOptions] = []

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedOptions.append(options)
        return LLMResponse(
            id: "stub",
            model: options.model,
            blocks: [.text("done")],
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
                    continuation.finish()
                    return
                }
                continuation.finish()
            }
        }
    }
}
