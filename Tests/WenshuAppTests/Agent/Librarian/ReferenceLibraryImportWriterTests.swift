//
//  Tests/Agent/Librarian/ReferenceLibraryImportWriterTests.swift · Wenshu
//
//  The import's writer honours the corpus's one-document rule.
//
//  Why this test exists (= the gap it closes):
//
//  The branch's own suite tested the import's LOOKUP, = and not the
//  import's WRITE. = A writer that stopped consulting the lookup
//  passed every suite, = and the corpus grew a second document with
//  the same title. = The behaviour was right; = nothing held it.
//
//  So this suite runs the writer itself, = twice, = with one title,
//  and counts what the library holds.
//
//  What is pinned here:
//
//  1. Writing the same title twice lands ONE document.
//  2. A title whose whitespace is doubled is the same title, = so it
//     lands ONE document too.
//  3. The second write UPDATES the document (= the body is the
//     second one), = and does not leave the first body behind.
//  4. A different title is a different document.
//  5. The lookup is what the writer consults, = so removing the
//     lookup from the writer turns this suite red.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The import's writer honours the one-document rule")
struct ReferenceLibraryImportWriterTests {

    // MARK: - Helpers

    @MainActor
    private static func makeStore() throws -> FileSystemReferenceStore {
        let root = URL(fileURLWithPath: "/tmp/wenshu-import-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: root)
    }

    /// The documents the library holds (= what the user would see).
    @MainActor
    private static func documents(_ store: FileSystemReferenceStore) -> [Reference] {
        ((try? store.loadAllReferences()) ?? []).filter { $0.layer == .layerEntities }
    }

    /// Write one document, = the way the import's writer does.
    @MainActor
    private static func write(
        title: String,
        body: String,
        into store: FileSystemReferenceStore,
        id: UUID = UUID()
    ) throws -> UUID {
        try ImportService.writeDocumentToLibrary(
            id: id,
            body: body,
            title: title,
            source: "a source",
            category: nil,
            tags: [],
            entityType: .other,
            summary: "The summary of \(title).",
            store: store
        )
    }

    // MARK: - The rule

    @MainActor
    @Test("writing the same title twice lands one document")
    func writingTheSameTitleTwiceLandsOneDocument() throws {
        let store = try Self.makeStore()

        try Self.write(title: "Ming tax system", body: "the first body", into: store)
        try Self.write(title: "Ming tax system", body: "the second body", into: store)

        #expect(Self.documents(store).count == 1, "the corpus has one document per title")
    }

    @MainActor
    @Test("a title whose whitespace is doubled is the same title")
    func aDoubledWhitespaceTitleIsTheSameTitle() throws {
        let store = try Self.makeStore()

        try Self.write(title: "Ming  tax system", body: "the first body", into: store)
        try Self.write(title: "Ming tax system", body: "the second body", into: store)

        #expect(Self.documents(store).count == 1, "a whitespace run must not make a second document")
    }

    @MainActor
    @Test("the second write updates the document rather than leaving the first body behind")
    func theSecondWriteUpdatesTheDocument() throws {
        let store = try Self.makeStore()

        try Self.write(title: "Ming tax system", body: "the first body", into: store)
        let secondID = try Self.write(title: "Ming tax system", body: "the second body", into: store)

        let documents = Self.documents(store)
        #expect(documents.count == 1)
        #expect(documents.first?.id == secondID, "the update lands on the document that was there")

        let body = store.loadReferenceBody(id: secondID) ?? ""
        #expect(body.contains("the second body"), "the body must be the one that was written last")
        #expect(body.contains("the first body") == false, "and the first body must be gone")
    }

    @MainActor
    @Test("a different title is a different document")
    func aDifferentTitleIsADifferentDocument() throws {
        let store = try Self.makeStore()

        try Self.write(title: "Ming tax system", body: "the first body", into: store)
        try Self.write(title: "Ming tax codes", body: "the second body", into: store)

        #expect(Self.documents(store).count == 2, "two names are two documents")
    }

    @MainActor
    @Test("the writer consults the lookup, so removing it turns this suite red")
    func theWriterConsultsTheLookup() throws {
        let store = try Self.makeStore()

        // The lookup is the writer's rule, = and the writer must go
        // through it. = The count below is what the lookup's answer
        // produces: = one document, = because the second write found
        // the first.
        try Self.write(title: "Ming tax system", body: "the first body", into: store)
        let found = ImportService.existingDocument(in: store, title: "Ming tax system")
        #expect(found != nil, "the lookup must see the document the writer created")

        try Self.write(title: "Ming tax system", body: "the second body", into: store)
        #expect(Self.documents(store).count == 1, "and the writer must have acted on that answer")
    }
}
