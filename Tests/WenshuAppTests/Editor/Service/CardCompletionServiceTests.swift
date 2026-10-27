//
//  CardCompletionServiceTests.swift
//
//  The rule that decides which cards still need work.
//
//  Covers:
//  - a book document whose body still carries the import placeholder
//    needs completion,
//  - a complete book document does not,
//  - the placeholder is matched in the middle of a body, not only at
//    its start,
//  - the rule keys on the prefix alone, not on any wording behind it,
//  - a reference with no body needs completion,
//  - a reference with a body does not,
//  - the two lookups answer for a whole set of loaded cards.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Card completion rule")
@MainActor
struct CardCompletionServiceTests {
    // MARK: - Fixtures

    /// A book document whose body carries the given text.
    private static func bookDocument(body: String) -> BookDoc {
        BookDoc(
            id: UUID(),
            bookId: UUID(),
            folderName: "world",
            fileName: "document.md",
            modifiedAt: Date(),
            createdAt: Date(),
            tags: [],
            body: body
        )
    }

    /// A reference-library store over a throwaway root.
    private static func makeStore() throws -> (store: FileSystemReferenceStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-card-completion-\(UUID().uuidString)", isDirectory: true)
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        return (FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot), root)
    }

    /// Write a reference body where the store's own body read looks.
    private static func writeBody(
        _ body: String,
        for reference: Reference,
        store: FileSystemReferenceStore
    ) throws {
        try FileSystemReferenceStore.writeReferenceFileToFileSystem(
            id: reference.id,
            bodyMarkdown: body,
            referenceLibraryRoot: store.referenceLibraryRoot
        )
    }

    // MARK: - The book document rule

    @Test("a book document whose body still carries the placeholder needs completion")
    func bookDocumentWithPlaceholderNeedsCompletion() {
        let body = """
        ## Character profile

        [TODO:
        """
        #expect(CardCompletionService.bookDocumentNeedsCompletion(body: body))
    }

    @Test("a complete book document does not need completion")
    func completeBookDocumentDoesNotNeedCompletion() {
        let body = """
        ## Character profile

        A courier who knows every gate in the city.
        """
        #expect(!CardCompletionService.bookDocumentNeedsCompletion(body: body))
    }

    @Test("the placeholder is matched in the middle of a body, not only at its start")
    func placeholderIsMatchedInTheMiddleOfTheBody() {
        let body = """
        ## Character profile

        A courier who knows every gate in the city.

        [TODO:

        ## Motivation
        """
        #expect(CardCompletionService.bookDocumentNeedsCompletion(body: body))
    }

    @Test("the prefix alone decides, with nothing behind it")
    func thePrefixAloneDecidesWithNothingBehindIt() {
        // The prefix is the whole marker: a body that carries it and then
        // stops needs completion, so no wording behind the prefix can be
        // part of the rule.
        #expect(CardCompletionService.bookDocumentNeedsCompletion(body: "[TODO:"))
        #expect(CardCompletionService.bookDocumentNeedsCompletion(body: "## Profile\n\n[TODO:"))
    }

    @Test("a marker that is not the placeholder does not need completion")
    func aMarkerThatIsNotThePlaceholderDoesNotNeedCompletion() {
        #expect(!CardCompletionService.bookDocumentNeedsCompletion(body: "[TODO"))
        #expect(!CardCompletionService.bookDocumentNeedsCompletion(body: "TODO:"))
    }

    // MARK: - The reference rule

    @Test("a reference with no body needs completion")
    func referenceWithoutBodyNeedsCompletion() {
        #expect(CardCompletionService.referenceNeedsCompletion(body: nil))
    }

    @Test("a reference with a blank body needs completion")
    func referenceWithBlankBodyNeedsCompletion() {
        #expect(CardCompletionService.referenceNeedsCompletion(body: "   \n  "))
    }

    @Test("a reference with a body does not need completion")
    func referenceWithBodyDoesNotNeedCompletion() {
        #expect(!CardCompletionService.referenceNeedsCompletion(body: "# Harbor survey\n\nTide gauges."))
    }

    // MARK: - The lookups over a set of loaded cards

    @Test("the book document lookup answers with the documents that carry the placeholder")
    func bookDocumentLookupAnswersForTheWholeSet() {
        let unfinished = Self.bookDocument(body: "## Profile\n\n[TODO:\n")
        let finished = Self.bookDocument(body: "## Profile\n\nA courier.\n")
        let other = Self.bookDocument(body: "## Profile\n\n[TODO:\n")

        let needing = CardCompletionService.bookDocumentsNeedingCompletion([unfinished, finished, other])
        #expect(needing == [unfinished.id, other.id])
    }

    @Test("the reference lookup asks the library for each body")
    func referenceLookupAsksTheLibraryForEachBody() throws {
        let (store, root) = try Self.makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let withBody = Reference(title: "Harbor survey")
        let withoutBody = Reference(title: "Tax records")
        try Self.writeBody("# Harbor survey\n\nTide gauges.", for: withBody, store: store)

        let needing = CardCompletionService.referencesNeedingCompletion(
            [withBody, withoutBody],
            store: store
        )
        #expect(needing == [withoutBody.id])
    }
}
