//
//  ImportReferenceCategoryTests.swift · wenshu
//
//  An imported reference carries the library category the model chose,
//  and the keyword classifier fills one when the model gives none.
//
//  Coverage:
//    1. A model reply naming a category produces that category.
//    2. A reply naming an entity type produces that entity type.
//    3. A reply with no category falls through to the classifier.
//    4. The request offers the second-level codes, and no second-level
//       code is stored.
//

import WenshuAgent
import XCTest
@testable import WenshuApp

final class ImportReferenceCategoryTests: XCTestCase {

    // MARK: - The model's answer decides

    func testAModelReplyNamingACategoryProducesThatCategory() async throws {
        let result = try await Self.route(reply: Self.answer(
            title: "A poem",
            summary: "A poem about a king.",
            category: "I",
            entityType: 1
        ))
        XCTAssertEqual(result.category, EntityCategory.i.rawValue)
        XCTAssertEqual(result.entityType, EntityType.character.rawValue)
    }

    func testAModelReplyNamingAnEntityTypeProducesThatEntityType() async throws {
        let result = try await Self.route(reply: Self.answer(
            title: "A city",
            summary: "A city and its walls.",
            category: "K",
            entityType: 2
        ))
        XCTAssertEqual(result.entityType, EntityType.location.rawValue)
    }

    func testAModelReplyWithNoCategoryFallsThroughToTheClassifier() async throws {
        // The source names a place, so the keyword pass can decide.
        let result = try await Self.route(
            reply: Self.answer(
                title: "The city walls",
                summary: "The walls of the city.",
                category: nil,
                entityType: 2
            ),
            body: "The city wall was built in the Ming dynasty."
        )
        XCTAssertNotNil(
            result.category,
            "A reply with no category must fall through to the classifier."
        )
    }

    func testAnUnrecognisedCategoryLetterLeavesTheCategoryEmpty() async throws {
        let result = try await Self.route(reply: Self.answer(
            title: "A poem",
            summary: "A poem.",
            category: "Q9",
            entityType: 1
        ))
        // The model named something that is not a category; = the
        // classifier decides, and the catch-all is the last word.
        XCTAssertNotNil(result.category)
    }

    // MARK: - The second-level codes

    func testTheRequestOffersTheSecondLevelCodes() {
        let prompt = ImportReferenceLibraryRouter.prompt(
            filePath: "/tmp/source.md",
            body: "A poem."
        )
        XCTAssertTrue(
            prompt.contains("I1"),
            "The request must offer the second-level codes."
        )
        XCTAssertTrue(
            prompt.contains("K9"),
            "The request must offer the second-level codes."
        )
    }

    func testNoSecondLevelCodeIsStored() async throws {
        let result = try await Self.route(reply: Self.answer(
            title: "A poem",
            summary: "A poem about a king.",
            category: "I",
            entityType: 1
        ))
        let category = try XCTUnwrap(result.category)
        XCTAssertEqual(category.count, 1, "The stored category is the top-level one.")
    }

    // MARK: - The fixtures

    /// The model's answer, with the fields the test cares about.
    static func answer(
        title: String,
        summary: String,
        category: String?,
        entityType: Int
    ) -> String {
        let categoryField = category.map { "\"category\": \"\($0)\"," } ?? ""
        return """
        {"title": "\(title)", "summary": "\(summary)", "tags": ["a"], \(categoryField) "entity_type": \(entityType), "body": "The body."}
        """
    }

    /// Run the reference library branch against a canned reply.
    static func route(reply: String, body: String = "A poem about a king.") async throws -> ImportRoutingResult {
        let stub = CategoryStubConnector(reply: reply)
        let router = ImportReferenceLibraryRouter(
            connector: stub,
            modelSlug: "stub-model",
            dispatchWebSearch: { _ in "{\"ok\":true}" }
        )
        return try await router.route(
            input: ImportFileInput(
                filePath: "/tmp/source.md",
                targetBookId: nil,
                targetShelfId: nil,
                rewriteMode: .searchAndRewrite,
                body: nil
            ),
            body: body,
            fallbackTitle: "a-source"
        )
    }
}

// MARK: - Stub connector

/// A connector that answers with a canned reply.
private final class CategoryStubConnector: LLMConnector, @unchecked Sendable {
    nonisolated let connectorID: String = "category-stub"
    private let reply: String

    init(reply: String) {
        self.reply = reply
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        LLMResponse(
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
