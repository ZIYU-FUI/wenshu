//
//  Tests/Agent/Librarian/CorpusUnreadableTests.swift · Wenshu
//
//  A corpus that cannot be read is not an empty corpus.
//
//  Why this suite exists (= the gap it closes):
//
//  The previous round added the difference between "the library does
//  not hold this document" and "the library could not be read", = and
//  the report layer already said the right thing in the second case.
//  **⇒ But the second case could never happen.** = The store's
//  `loadAllReferences()` turns EVERY read failure into an empty
//  layer: = a layer's index that cannot be decoded becomes `[]`, =
//  a fetch that throws becomes `[]`, = a missing context becomes
//  `[]`. = So `LibraryCorpusRead.unreadable` was UNREACHABLE from
//  the filesystem, = and the report's "NOT in the library, so it did
//  not land" was printed about a document sitting in a corpus the
//  reader never managed to read.
//
//  The previous round's mutation did not catch it, = and the reason
//  matters: = that mutation injected a `.unreadable` VALUE, = so it
//  tested the branch that handles the value, = not the path that
//  produces it. = **⇒ A fake that hands the code the answer cannot
//  tell whether the code could ever reach it.**
//
//  So this suite does the opposite: = it builds a REAL library on
//  disk, = corrupts one layer's index, = and reads it through the
//  PRODUCTION store. = No fake, = no injection, = no value the test
//  chose.
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuData

@Suite("A corpus that cannot be read is not an empty corpus")
struct CorpusUnreadableTests {
    // MARK: - The helpers

    /// A library on disk, = with one layer's index holding one
    /// document.
    private static func makeLibrary() throws -> URL {
        let referenceLibraryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-unreadable-\(UUID().uuidString)", isDirectory: true)
        let entities = referenceLibraryRoot.appendingPathComponent("entities", isDirectory: true)
        try FileManager.default.createDirectory(at: entities, withIntermediateDirectories: true)
        let id = UUID()
        let row = """
        {"id":"\(id.uuidString)","title":"Ming tax system","layer":"layerEntities","tags":[],"entityType":"other","summary":"","characterRefIds":[],"worldRefIds":[],"bookRefIds":[],"createdAt":0,"updatedAt":0}
        """
        try ("[" + row + "]").write(
            to: entities.appendingPathComponent("entities.json"),
            atomically: true,
            encoding: .utf8
        )
        return referenceLibraryRoot
    }

    /// The index of a layer, = damaged so that it cannot be decoded.
    private static func corrupt(_ referenceLibraryRoot: URL) throws {
        let indexURL = referenceLibraryRoot
            .appendingPathComponent("entities", isDirectory: true)
            .appendingPathComponent("entities.json")
        try "{ this is not an index".write(
            to: indexURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Read the corpus at a root, = through the REAL store.
    ///
    /// **⇒ This is `@MainActor` and `async` hops onto it**, = exactly
    /// the shape production uses (`WenshuAppDelegate+SubAgentDrainLoop.swift`
    /// calls `{ await Self.readLibrary() }` from the same
    /// `@Sendable` closure). = **⇒ The test reads the corpus the way
    /// the app reads it**, = so a fix that only worked in a `@MainActor`
    /// test body would not pass here.
    @MainActor
    private static func read(at referenceLibraryRoot: URL) -> LibraryCorpusRead {
        LibraryCorpusReader {
            FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        }.read()
    }

    /// The report the model wrote: = one document, = said to have
    /// landed.
    private static let reportJSON = """
    {"landed": 1, "documents": [
      {"title": "Ming tax system", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}
    ], "notes": []}
    """

    private static func handle() -> BackgroundDelegationHandle {
        BackgroundDelegationHandle(
            id: "run-unreadable",
            agentName: SubAgentRoleRegistry.librarian.slug,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )
    }

    // MARK: - The read

    @Test("A damaged index is unreadable, = not an empty layer")
    @MainActor
    func aDamagedIndexIsUnreadableNotEmpty() throws {
        let root = try Self.makeLibrary()
        try Self.corrupt(root)

        let reading = Self.read(at: root)

        // **⇒ The whole point.** = The corpus could not be read, = so
        // the read says that. = **⇒ It does NOT say the corpus holds
        // nothing** (= `.documents([])`), = because that is a fact
        // about a corpus the reader never read.
        #expect(!reading.wasRead, "a damaged index must not read as a corpus that was read")
        #expect(reading.documents.isEmpty, "an unreadable corpus holds no documents to report on")
        guard case let .unreadable(reason) = reading else {
            Issue.record("expected the corpus to be unreadable, got \(reading)")
            return
        }
        // The reason names the layer, = so the user can act on it.
        #expect(reason.contains("entities"), "the reason must name the layer that failed, got: \(reason)")
    }

    @Test("A sound corpus is read as documents")
    @MainActor
    func aSoundCorpusIsReadAsDocuments() throws {
        let root = try Self.makeLibrary()

        let reading = Self.read(at: root)

        #expect(reading.wasRead, "a sound corpus must read as read")
        #expect(reading.documents.count == 1, "the corpus holds one document")
        #expect(reading.documents.first?.title == "Ming tax system", "the document is the one that was written")
    }

    // MARK: - The report

    @Test("A report about a corpus that cannot be read does not say the documents are missing")
    @MainActor
    func aReportAboutAnUnreadableCorpusDoesNotSayTheDocumentsAreMissing() async throws {
        let root = try Self.makeLibrary()
        try Self.corrupt(root)
        let formatted = await SubAgentResultFormatter.format(
            handle: Self.handle(),
            text: Self.reportJSON,
            readingLibrary: { await Self.read(at: root) }
        )

        // **⇒ The check did not run, = so the report must not carry a
        // result.** = "NOT in the library, so it did not land" is a
        // fact about a corpus the reader never read, = and printing
        // it is the same lie as reading the wrong directory.
        #expect(
            !formatted.text.contains("NOT in the library"),
            "the report must not name the documents as missing when the corpus could not be read"
        )
        #expect(
            !formatted.text.contains("so it did not land"),
            "the report must not say the document failed to land when the corpus could not be read"
        )
        // **⇒ And it must SAY that the check did not run**, = because
        // silence reads as "everything is fine".
        #expect(
            formatted.text.contains("could not be read"),
            "the report must say the corpus could not be read, got: \(formatted.text)"
        )
    }

    @Test("A report about a corpus that CAN be read does say the documents are missing")
    @MainActor
    func aReportAboutAReadableCorpusDoesSayTheDocumentsAreMissing() async throws {
        // The same report, = against a corpus that holds a DIFFERENT
        // document. = **⇒ The check ran, = so it may report a
        // missing document.** = This is the control: = without it,
        // the test above could pass for the wrong reason (= a report
        // that never names documents at all).
        let root = try Self.makeLibrary()
        let formatted = await SubAgentResultFormatter.format(
            handle: Self.handle(),
            text: """
            {"landed": 1, "documents": [
              {"title": "Something else entirely", "id": "33333333-3333-3333-3333-333333333333", "action": "created"}
            ], "notes": []}
            """,
            readingLibrary: { await Self.read(at: root) }
        )

        #expect(
            formatted.text.contains("NOT in the library"),
            "a document the corpus does not hold must be reported as missing"
        )
        #expect(
            !formatted.text.contains("could not be read"),
            "a readable corpus must not be reported as unreadable"
        )
    }
}
