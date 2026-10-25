//
//  ReferenceLibrarySearchIndexTests.swift
//
//  The reference library's documents have to be findable by a word in
//  them: a document nobody can find is no constraint for the writing
//  that follows.
//
//  Covers:
//  - a saved reference document is published to the search index and
//    answers a search for a word in it,
//  - the docId of a reference hit says which kind of document it is,
//  - a deleted reference document leaves the index.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference library search index")
@MainActor
struct ReferenceLibrarySearchIndexTests {

    /// A word that exists in no other document (= the marker keeps the
    /// search away from the rest of the index).
    private static func marker() -> String {
        "zephyrine\(UUID().uuidString.prefix(8))"
    }

    private static func makeStore() throws -> FileSystemReferenceStore {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-reference-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
    }

    @Test("a saved reference document answers a search for a word in it")
    func savedDocumentIsFindable() async throws {
        let store = try Self.makeStore()
        let word = Self.marker()
        let reference = Reference(title: "Harbor survey")
        try store.saveReference(
            reference,
            bodyMarkdown: "# Harbor survey\n\nThe \(word) tide gauge was read at dawn."
        )

        // The save is synchronous; the index write is not (= the system
        // indexer answers on its own time), so the write is awaited
        // here (= the document must be findable right after the save).
        await store.awaitSearchIndexWrites()

        let hits = try await CSSearchableIndexSearch.shared.search(query: word)
        #expect(
            hits.contains { $0.docId == CSSearchDomain.referenceDocId(for: reference.id) },
            "a saved reference document must answer a search for a word in it"
        )
    }

    @Test("a reference hit carries the reference docId (= not a bare uuid)")
    func referenceHitCarriesTheReferenceDocId() async throws {
        let store = try Self.makeStore()
        let word = Self.marker()
        let reference = Reference(title: "Harbor survey")
        try store.saveReference(reference, bodyMarkdown: "# Harbor survey\n\nThe \(word) gauge.")
        await store.awaitSearchIndexWrites()

        let hits = try await CSSearchableIndexSearch.shared.search(query: word)
        let hit = try #require(hits.first { $0.docId == CSSearchDomain.referenceDocId(for: reference.id) })
        #expect(hit.docId.hasPrefix("reference-"))
    }

    @Test("a deleted reference document leaves the index")
    func deletedDocumentLeavesTheIndex() async throws {
        let store = try Self.makeStore()
        let word = Self.marker()
        let reference = Reference(title: "Harbor survey")
        try store.saveReference(reference, bodyMarkdown: "# Harbor survey\n\nThe \(word) gauge.")
        await store.awaitSearchIndexWrites()

        try store.deleteReference(id: reference.id)
        await store.awaitSearchIndexWrites()

        // The mirror is the app's own live index (= the write the
        // store awaits), so it is what says whether the document is
        // still there. The system index removes asynchronously, so it
        // cannot answer this question yet.
        let title = await CSSearchableIndexSearch.shared.title(
            forDocId: CSSearchDomain.referenceDocId(for: reference.id)
        )
        #expect(title == CSSearchDomain.referenceDocId(for: reference.id))
    }
}
