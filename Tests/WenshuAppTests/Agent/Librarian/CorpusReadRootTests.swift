//
//  CorpusReadRootTests.swift
//
//  Which directory the corpus is read from.
//
//  **This test exists because the check was inverted.** = The first
//  version of the librarian's corpus check built its store from
//  `ActiveLibrary.path`, = which is the `.ws` ROOT, = while the
//  corpus lives one directory deeper (= `<ws>/reference-library/`).
//  Measured against a real library: = six documents at the right
//  root, = zero at the root the reader used. = **⇒ Every librarian
//  run said "NOT in the library, so it did not land" about a document
//  that had landed.** = The check is the whole feature, = and the
//  feature was backwards.
//
//  **⇒ And the mutation that FIXED the root left every suite green.**
//  = The card's mutation checked that a reader is HANDED, = never
//  that it reads the right place. = A reader can be handed correctly
//  and still point at the wrong directory. = **⇒ So this test
//  measures the DIRECTORY, = against a fixture that has the real
//  shape** (= a corpus one level below the `.ws` root), = and it says
//  which root it used.
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuData

@Suite("The corpus is read from the right directory")
struct CorpusReadRootTests {
    /// A `.ws` root with a corpus one directory below it (= the shape
    /// the app really has).
    private static func makeLibrary(
        documents: Int
    ) throws -> (wsRoot: URL, referenceLibraryRoot: URL) {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-corpus-root-\(UUID().uuidString)", isDirectory: true)
        let referenceLibraryRoot = wsRoot.appendingPathComponent("reference-library", isDirectory: true)
        let entities = referenceLibraryRoot.appendingPathComponent("entities", isDirectory: true)
        try FileManager.default.createDirectory(at: entities, withIntermediateDirectories: true)

        var rows: [String] = []
        for index in 0 ..< documents {
            let id = UUID()
            rows.append(
                """
                {"id":"\(id.uuidString)","title":"Document \(index)","layer":"layerEntities","tags":[],"entityType":"other","summary":"","characterRefIds":[],"worldRefIds":[],"bookRefIds":[],"createdAt":0,"updatedAt":0}
                """
            )
            try "body of document \(index)".write(
                to: entities.appendingPathComponent("\(id.uuidString).md"),
                atomically: true,
                encoding: .utf8
            )
        }
        try ("[" + rows.joined(separator: ",") + "]").write(
            to: entities.appendingPathComponent("entities.json"),
            atomically: true,
            encoding: .utf8
        )
        return (wsRoot, referenceLibraryRoot)
    }

    // MARK: - The root

    @Test("The corpus is one directory below the .ws root, = not at it")
    @MainActor
    func corpusIsBelowTheRoot() throws {
        let library = try Self.makeLibrary(documents: 2)

        // The right root: = the corpus is here.
        let right = FileSystemReferenceStore(referenceLibraryRoot: library.referenceLibraryRoot)
        #expect((try? right.loadAllReferences().count) == 2)

        // The wrong root: = the corpus is NOT here, = and a reader
        // pointed at it sees nothing. = This is what the production
        // reader used to do, = and the check it produced said the
        // documents had not landed.
        let wrong = FileSystemReferenceStore(referenceLibraryRoot: library.wsRoot)
        #expect((try? wrong.loadAllReferences().count) == 0)
    }

    @Test("A reader pointed at the .ws root reads nothing, = and that is not an empty corpus")
    @MainActor
    func wrongRootIsNotAnEmptyCorpus() throws {
        let library = try Self.makeLibrary(documents: 1)
        let wrong = FileSystemReferenceStore(referenceLibraryRoot: library.wsRoot)

        // The two facts are different, = and a check that cannot tell
        // them apart reports a document as missing when it was never
        // looked for.
        let documents = (try? wrong.loadAllReferences()) ?? []
        #expect(documents.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: library.wsRoot.appendingPathComponent("entities").path
        ))
    }

    // MARK: - The reader the production uses

    @Test("The production reader reads the corpus the store is bound to")
    @MainActor
    func productionReaderReadsTheBoundStore() throws {
        let library = try Self.makeLibrary(documents: 3)
        let store = FileSystemReferenceStore(referenceLibraryRoot: library.referenceLibraryRoot)
        ReferenceLibraryLocator.shared.bind(
            referenceStore: store,
            referenceLibraryRoot: library.referenceLibraryRoot
        )
        defer { ReferenceLibraryLocator.shared.unbindForTest() }

        // The DEFAULT reader (= the one the production path uses, = with
        // no injection) = asks the locator. = So it reads the corpus
        // the user has open, = wherever that is. = **⇒ THIS is the
        // assertion the old suite lacked:** = the old mutation
        // replaced the locator's store with one built from
        // `ActiveLibrary.path` (= the `.ws` root), = and every test
        // stayed green because no test ever read the corpus THROUGH
        // the production reader. = A reader can be handed correctly
        // and still point at the wrong directory.
        let read = LibraryCorpusReader().read()
        #expect(read.wasRead)
        #expect(read.documents.count == 3)
    }

    @Test("The default reader reads the locator, = not a store built from a path")
    @MainActor
    func defaultReaderUsesTheLocator() throws {
        let library = try Self.makeLibrary(documents: 2)
        let store = FileSystemReferenceStore(referenceLibraryRoot: library.referenceLibraryRoot)
        ReferenceLibraryLocator.shared.bind(
            referenceStore: store,
            referenceLibraryRoot: library.referenceLibraryRoot
        )
        defer { ReferenceLibraryLocator.shared.unbindForTest() }

        // The corpus is BELOW the `.ws` root. = A reader that built its
        // own store from the `.ws` root would find nothing, = and would
        // then report that the documents had not landed. = This is the
        // defect, = measured.
        let read = LibraryCorpusReader().read()
        #expect(read.documents.count == 2)

        // And the same library, read through a store built from the
        // `.ws` root, = holds nothing. = The two readers disagree, =
        // and the default reader is on the right side.
        let wrong = FileSystemReferenceStore(referenceLibraryRoot: library.wsRoot)
        #expect(((try? wrong.loadAllReferences().count) ?? 0) == 0)
    }

    @Test("A reader handed a store reads THAT store")
    @MainActor
    func readerUsesTheStoreItIsHanded() throws {
        let library = try Self.makeLibrary(documents: 4)
        let store = FileSystemReferenceStore(referenceLibraryRoot: library.referenceLibraryRoot)
        let read = LibraryCorpusReader(storeProvider: { store }).read()
        #expect(read.wasRead)
        #expect(read.documents.count == 4)
    }

    @Test("A reader with no library says it could not read one")
    @MainActor
    func readerWithNoLibraryIsUnreadable() {
        let read = LibraryCorpusReader(storeProvider: { nil }).read()
        #expect(!read.wasRead)
        #expect(read.unreadableNotice.contains("could not be read"))
    }

    /// A report the model wrote: = one document, = said to have
    /// landed.
    private static let reportJSON = """
    {"landed": 1, "documents": [
      {"title": "Ming tax system", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}
    ], "notes": []}
    """

    @Test("A report checked against a corpus that could not be read says it was NOT checked")
    @MainActor
    func unreadableCorpusIsNotCheckedAgainst() async {
        let handle = BackgroundDelegationHandle(
            id: "run-unreadable",
            agentName: SubAgentRoleRegistry.librarian.slug,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )

        let formatted = await SubAgentResultFormatter.format(
            handle: handle,
            text: Self.reportJSON,
            readingLibrary: { .unreadable("no library is open") }
        )

        // **⇒ The two facts must not be confused.** = The report must
        // NOT say the document is missing (= the check never ran), = and
        // it must SAY that it was not checked.
        #expect(!formatted.text.contains("NOT in the library"))
        #expect(formatted.text.contains("could not be read"))
        #expect(formatted.text.contains("NOT checked"))
    }

    @Test("A report checked against a corpus that WAS read says what the corpus holds")
    @MainActor
    func readableCorpusIsCheckedAgainst() async {
        let handle = BackgroundDelegationHandle(
            id: "run-readable",
            agentName: SubAgentRoleRegistry.librarian.slug,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )

        let formatted = await SubAgentResultFormatter.format(
            handle: handle,
            text: Self.reportJSON,
            readingLibrary: { .documents([]) }
        )

        // The corpus WAS read, = and it holds nothing, = so the report
        // says the document is not there. = This is the fact the
        // unreadable case must NOT claim.
        #expect(formatted.text.contains("NOT in the library"))
        #expect(!formatted.text.contains("could not be read"))
    }

    @Test("A corpus that cannot be read is not reported as an empty corpus")
    func unreadableIsNotEmpty() {
        let unreadable = LibraryCorpusRead.unreadable("no library is open")
        #expect(!unreadable.wasRead)
        #expect(unreadable.documents.isEmpty)

        let empty = LibraryCorpusRead.documents([])
        #expect(empty.wasRead)
        #expect(empty.documents.isEmpty)
    }
}
