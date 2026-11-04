//
//  Tests/Agent/Librarian/ReferenceLibraryImportIdentityTests.swift · Wenshu
//
//  Verifies that the import honours the corpus's one-document rule.
//
//  Why this test exists (= the gap it closes):
//
//  The branch's stated goal was "one document, = one identity in the
//  reference library". = The tool's create honoured it, = the
//  tool's find honoured it, = and the IMPORT did not: = the import
//  wrote by content hash alone, = so importing a document whose
//  title already existed landed a SECOND document with the same
//  title. = The rule moved to `Reference.titlesMatch`, = but not
//  every reader was moved onto it.
//
//  What is pinned here:
//
//  1. The import finds the document that already carries the title.
//  2. The title match is the library's rule, = so a title whose
//     whitespace is doubled is the same title.
//  3. A document in another layer is not the same document. = The
//     import writes to the entities layer, = and a raw-layer
//     document with the same title is a different thing.
//  4. The lookup finds nothing when there is nothing to find.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The import honours the corpus's one-document rule")
struct ReferenceLibraryImportIdentityTests {

    // MARK: - Helpers

    @MainActor
    private static func makeStore() throws -> FileSystemReferenceStore {
        let root = URL(fileURLWithPath: "/tmp/wenshu-import-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return FileSystemReferenceStore(referenceLibraryRoot: root)
    }

    /// Write a document into the library's entities layer.
    @MainActor
    private static func seed(
        title: String,
        body: String = "# Body",
        layer: ReferenceLayer = .layerEntities
    ) throws -> FileSystemReferenceStore {
        let store = try Self.makeStore()
        let reference = Reference(
            title: title,
            layer: layer,
            summary: "The summary of \\(title)."
        )
        try store.saveReference(reference, bodyMarkdown: body)
        return store
    }

    // MARK: - The lookup

    @MainActor
    @Test("the import finds the document that already carries the title")
    func findsTheDocumentThatCarriesTheTitle() throws {
        let store = try Self.seed(title: "Ming tax system")

        let found = ImportService.existingDocument(in: store, title: "Ming tax system")

        #expect(found != nil)
        #expect(found?.title == "Ming tax system")
    }

    @MainActor
    @Test("the lookup uses the library's title rule, so a doubled space is the same title")
    func usesTheLibrarysTitleRule() throws {
        let store = try Self.seed(title: "Ming  tax system")

        let found = ImportService.existingDocument(in: store, title: "Ming tax system")

        #expect(found != nil, "a whitespace run must not make the import write a second document")
    }

    @MainActor
    @Test("a document in another layer is not the document the import is looking for")
    func anotherLayerIsNotADuplicate() throws {
        let store = try Self.seed(title: "Ming tax system", layer: .layerRaw)

        let found = ImportService.existingDocument(in: store, title: "Ming tax system")

        // The import writes to the entities layer, = so a raw-layer
        // document with the same title is a different thing. = The
        // import must not overwrite it, = and must not treat it as
        // the document it was going to write.
        #expect(found == nil)
    }

    @MainActor
    @Test("the lookup finds nothing when the library is empty")
    func findsNothingInAnEmptyLibrary() throws {
        let store = try Self.makeStore()

        let found = ImportService.existingDocument(in: store, title: "Ming tax system")

        #expect(found == nil)
    }

    @MainActor
    @Test("the lookup finds nothing for a title the library does not carry")
    func findsNothingForAnotherTitle() throws {
        let store = try Self.seed(title: "Ming tax system")

        let found = ImportService.existingDocument(in: store, title: "Ming tax codes")

        #expect(found == nil)
    }

    // MARK: - The rule itself

    @Test("the shared lookup follows the shared rule")
    func theSharedLookupFollowsTheSharedRule() {
        let documents = [
            Reference(title: "Ming  tax", layer: .layerEntities),
            Reference(title: "Other", layer: .layerEntities)
        ]

        let found = Reference.firstMatchingTitle(in: documents, title: "Ming tax", layer: .layerEntities)

        #expect(found?.title == "Ming  tax")
    }

    @Test("the shared lookup without a layer searches every layer")
    func theSharedLookupWithoutALayerSearchesEveryLayer() {
        let documents = [
            Reference(title: "Ming tax", layer: .layerRaw),
            Reference(title: "Other", layer: .layerEntities)
        ]

        #expect(Reference.firstMatchingTitle(in: documents, title: "Ming tax") != nil)
        #expect(Reference.firstMatchingTitle(in: documents, title: "Ming tax", layer: .layerEntities) == nil)
    }
}
