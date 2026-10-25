//
//  ImportReferenceLibraryRouterTests.swift · wenshu
//
//  The reference library import is one call that produces the whole
//  entity, with the search tool to check the content.
//
//  Coverage:
//    1. The request the connector received advertises the search tool.
//    2. The parsed reply carries the library category and the entity
//       type.
//    3. An unrecognised category letter falls back to the catch-all
//       category.
//    4. The body and the title come out of the same reply.
//

import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportReferenceLibraryRouterTests: XCTestCase {

    // MARK: - The request

    func testTheRequestAdvertisesTheSearchTool() async throws {
        let stub = ReferenceLibraryStubConnector(
            reply: Self.answer(category: "I", entityType: 1)
        )
        let router = ImportReferenceLibraryRouter(
            connector: stub,
            modelSlug: "stub-model",
            dispatchWebSearch: { _ in "{\"ok\":true}" }
        )
        _ = try await router.route(
            input: Self.input,
            body: "A poem about a king.",
            fallbackTitle: "a-poem"
        )
        let options = try XCTUnwrap(stub.receivedOptions.first)
        XCTAssertFalse(options.tools.isEmpty, "The request must advertise the search tool.")
        XCTAssertTrue(
            options.tools.contains { $0.name == "web_search" },
            "The search tool must be the one advertised."
        )
        XCTAssertEqual(options.model, "stub-model")
    }

    func testTheModelCanCallTheSearchToolAndTheResultGoesBack() async throws {
        let stub = ReferenceLibraryStubConnector(
            reply: Self.answer(category: "I", entityType: 1),
            toolUseFirst: true
        )
        let searched = SearchRecorder()
        let router = ImportReferenceLibraryRouter(
            connector: stub,
            modelSlug: "stub-model",
            dispatchWebSearch: { _ in
                await searched.mark()
                return "{\"ok\":true,\"results\":[\"a king\"]}"
            }
        )
        _ = try await router.route(
            input: Self.input,
            body: "A poem about a king.",
            fallbackTitle: "a-poem"
        )
        let wasCalled = await searched.wasCalled
        XCTAssertTrue(
            wasCalled,
            "The model's tool call must reach the search tool."
        )
        let second = try XCTUnwrap(stub.receivedMessages.count > 1 ? stub.receivedMessages[1] : nil)
        var hasToolResult = false
        for message in second {
            if message.role == .tool {
                hasToolResult = true
                break
            }
        }
        XCTAssertTrue(
            hasToolResult,
            "The search result must go back into the conversation."
        )
    }

    // MARK: - The reply

    func testTheParsedReplyCarriesTheCategoryAndTheEntityType() async throws {
        let stub = ReferenceLibraryStubConnector(
            reply: Self.answer(category: "K", entityType: 2)
        )
        let router = ImportReferenceLibraryRouter(
            connector: stub,
            modelSlug: "stub-model",
            dispatchWebSearch: { _ in "{\"ok\":true}" }
        )
        let result = try await router.route(
            input: Self.input,
            body: "The founding of a city.",
            fallbackTitle: "a-city"
        )
        XCTAssertEqual(result.category, "K")
        XCTAssertEqual(result.entityType, EntityType.location.rawValue)
        XCTAssertEqual(result.title, "The founding of a city")
        XCTAssertEqual(result.summary, "How the city was founded.")
        XCTAssertEqual(result.tags, ["city", "history"])
        XCTAssertEqual(result.rewrittenBody, "The city was founded by a king.")
    }

    func testAnUnrecognisedCategoryLetterFallsBackToTheCatchAll() async throws {
        let stub = ReferenceLibraryStubConnector(
            reply: Self.answer(category: "Q9", entityType: 1)
        )
        let router = ImportReferenceLibraryRouter(
            connector: stub,
            modelSlug: "stub-model",
            dispatchWebSearch: { _ in "{\"ok\":true}" }
        )
        let result = try await router.route(
            input: Self.input,
            body: "A poem about a king.",
            fallbackTitle: "a-poem"
        )
        XCTAssertEqual(
            result.category,
            EntityCategory.z.rawValue,
            "An unrecognised category letter must fall back to the catch-all."
        )
    }

    /// The search result the model reads back is trimmed.
    ///
    /// The raw envelope carries every hit with its full snippet, and the
    /// web is not a place wenshu controls. The model needs enough to
    /// check the content, so the result is trimmed: the first few
    /// entries, each snippet short.
    func testTheSearchResultTheModelReadsIsTrimmed() {
        let raw = """
        {"query": "a king", "results": [
        {"title": "One", "url": "https://one.example", "snippet": "\(String(repeating: "x", count: 900))"},
        {"title": "Two", "url": "https://two.example", "snippet": "short"},
        {"title": "Three", "url": "https://three.example", "snippet": "short"},
        {"title": "Four", "url": "https://four.example", "snippet": "short"},
        {"title": "Five", "url": "https://five.example", "snippet": "short"},
        {"title": "Six", "url": "https://six.example", "snippet": "short"}
        ], "count": 6}
        """
        let trimmed = ImportReferenceLibraryRouter.compactedSearchOutput(raw)
        let object = (try? JSONSerialization.jsonObject(
            with: Data(trimmed.utf8)
        )) as? [String: Any]
        let results = object?["results"] as? [[String: Any]] ?? []
        XCTAssertEqual(results.count, 5, "Only the first few entries travel back.")
        let longest = results.compactMap { $0["snippet"] as? String }
            .map { $0.count }.max() ?? 0
        XCTAssertLessThanOrEqual(longest, 200, "A snippet must be short.")
    }

    /// A result that is not the search envelope travels back untouched.
    func testANonSearchOutputIsNotTouched() {
        let raw = "{\"ok\":false,\"error\":\"web_search dispatch failed\"}"
        XCTAssertEqual(
            ImportReferenceLibraryRouter.compactedSearchOutput(raw), raw,
            "An envelope that is not a search result must travel back as it was."
        )
    }

    // MARK: - The fixtures

    static let input = ImportFileInput(
        filePath: "/tmp/source.md",
        targetBookId: nil,
        targetShelfId: nil,
        rewriteMode: .searchAndRewrite,
        body: nil
    )

    /// The model's answer.
    static func answer(category: String, entityType: Int) -> String {
        """
        {"title": "The founding of a city", "summary": "How the city was founded.", "tags": ["city", "history"], "category": "\(category)", "entity_type": \(entityType), "body": "The city was founded by a king."}
        """
    }
}

// MARK: - Stub connector

/// A connector that records what it was asked and answers with a canned
/// reply (= the same shape as the import driver test's stub).
private final class ReferenceLibraryStubConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "reference-stub"
    var receivedMessages: [[LLMMessage]] = []
    var receivedOptions: [LLMCallOptions] = []

    private let reply: String
    private let toolUseFirst: Bool

    init(reply: String, toolUseFirst: Bool = false) {
        self.reply = reply
        self.toolUseFirst = toolUseFirst
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages.append(messages)
        receivedOptions.append(options)
        // The first turn asks for the search; = the second turn answers.
        if toolUseFirst && receivedMessages.count == 1 {
            return LLMResponse(
                id: "stub",
                model: options.model,
                blocks: [.toolUse(id: "call_1", name: "web_search", input: "{\"query\":\"a king\"}")],
                stopReason: .toolUse,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        }
        return LLMResponse(
            id: "stub",
            model: options.model,
            blocks: [.text(reply)],
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


/// Whether the search tool was called.
private actor SearchRecorder {
    private(set) var wasCalled = false
    func mark() { wasCalled = true }

}
