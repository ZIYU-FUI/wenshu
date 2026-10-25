//
//  ImportAgentRefusalLadderTests.swift · wenshu
//
//  The provider can refuse a request (= a budget it will not take,
//  = a quota, = a model it does not know). The refusal arrives inside
//  the stream (= the stream carries the error instead of throwing),
//  = so the driver is the one that has to see it.
//
//  The ladder the driver walks:
//
//    1. the exotic knob goes first
//       (= the thinking budget is off)
//    2. then the output budget halves
//    3. at the floor the refusal is an error
//
//  A refusal must never pass as a success: a run that produced no
//  document says so.
//

import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportAgentRefusalLadderTests: XCTestCase {

    // MARK: - the ladder

    func testTheFirstRefusalDropsTheThinkingBudget() async throws {
        let stub = RefusingStubConnector()
        let driver = ImportAgentDriver(connector: stub, modelSlug: "stub")
        await Self.runExpectingTheRefusal(driver, stub)
        // The first call carried the thinking budget; = the second
        // (= the one after the refusal) does not.
        XCTAssertEqual(stub.receivedOptions.first?.thinkingBudget, 8192)
        XCTAssertNil(stub.receivedOptions.dropFirst().first?.thinkingBudget)
    }

    func testTheOutputBudgetHalvesWhenTheRefusalStays() async throws {
        let stub = RefusingStubConnector()
        let driver = ImportAgentDriver(connector: stub, modelSlug: "stub")
        await Self.runExpectingTheRefusal(driver, stub)
        // The output budget halves once the thinking budget is gone,
        // = and it halves once only (= the floor holds).
        let budgets = stub.receivedOptions.map(\.maxTokens)
        XCTAssertEqual(budgets.first, 16384)
        XCTAssertEqual(budgets[budgets.count - 2], 16384)
        XCTAssertEqual(budgets.last, 8192)
    }

    func testTheLadderStopsAtTheFloorAndThrows() async throws {
        let stub = RefusingStubConnector()
        let driver = ImportAgentDriver(connector: stub, modelSlug: "stub")
        do {
            _ = try await driver.run(
                input: Self.input(), bookContext: Self.context(), progress: nil
            )
            XCTFail("the refusal must not pass as a success")
        } catch {
            // The refusal is an error, = and it carries the provider's
            // own words.
            let message = String(describing: error)
            XCTAssertTrue(message.contains("provider refused"), message)
        }
    }

    // MARK: - the helpers

    /// Runs the driver against a provider that refuses everything, = and
    /// insists that the refusal ends the run.
    private static func runExpectingTheRefusal(
        _ driver: ImportAgentDriver,
        _ stub: RefusingStubConnector
    ) async {
        do {
            _ = try await driver.run(
                input: input(), bookContext: context(), progress: nil
            )
            XCTFail("the refusal must not pass as a success")
        } catch {
            // (= expected; = the floor is reached)
        }
        XCTAssertGreaterThan(stub.receivedOptions.count, 1)
    }

    private static func input() -> ImportAgentDriver.TaskInput {
        ImportAgentDriver.TaskInput(
            filePath: "/tmp/source.md",
            body: "# source content",
            bookPath: "/ws/book",
            bookTitle: "book",
            targetFolder: .world
        )
    }

    private static func context() -> ImportAgentBookContext {
        ImportAgentBookContext(bookPath: { "/ws/book" })
    }
}

// MARK: - Stub connector

/// A provider that refuses every request.
private final class RefusingStubConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "refusing-stub"
    var receivedOptions: [LLMCallOptions] = []

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedOptions.append(options)
        return LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.text("[stream error] the provider refused the request")],
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
