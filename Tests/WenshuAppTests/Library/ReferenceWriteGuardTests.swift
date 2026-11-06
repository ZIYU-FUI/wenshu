//  ReferenceWriteGuardTests.swift
//
//  The corpus has ONE truth, and TWO writers.
//
//  **⇒ The rule (= the second-writer rule).** = *The user's write
//  wins.* = The agent may REPLACE the agent's own text, = may ADD to
//  the user's text, = and may never REPLACE any of the user's text.
//  = So an agent write is REFUSED (= `ReferenceStoreError
//  .userOwnsTheTruth`), = and the refusal is REPORTED (= the caller
//  sees it, = and the user hears about it instead of losing text).
//
//  **⇒ Why this needs a test at all.** = The corpus had two truths
//  (= the layer copy and the single-file copy), = and the read path
//  preferred the one the editor wrote. = So the agent's write landed
//  where nobody read it, = and the user's edit sat in the copy the
//  reader never looked at. = **⇒ So the test below drives the
//  librarian's REAL upsert path (= `upsertReference` -> the same-title
//  update branch), = and asserts what the truth holds afterwards**
//  (= the read side was already pinned; = the write side was not).
//
//  **⇒ What each test pins:**
//
//  1. A user edit, THEN an agent write = = the write is refused, =
//     and the user's text is still in the truth.
//  2. The refusal reaches the LLM as a NAMED error (= not a
//     stringified enum case), = with a message that says what to do.
//  3. Two agent writes in a row = = the second one lands (= the rule
//     does not refuse the agent's own text).
//  4. A write that ADDS to the user's text = = it lands (= the rule
//     allows adding, = and the truth keeps the user's text).
//  5. A document written BEFORE the rule (= no record) = = the corpus
//     copy is the witness: = a truth that holds text the corpus copy
//     never saw = = refused; = a truth that agrees with it = =
//     allowed.
//  6. A delete takes the record with it.
//  7. The record is bookkeeping, = not corpus content (= the readers
//     never see it).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The corpus has one truth, and the user's write wins")
@MainActor
struct ReferenceWriteGuardTests {
    // MARK: - The harness

    /// A `.ws` root with a reference library under it.
    ///
    /// = The layout the app runs on: = `<ws>/reference-library/` (= the
    /// corpus, = with the per-layer index files) = and `<ws>/references/`
    /// (= the single-file truth location, = the one the editor writes).
    private static func makeLibrary() throws -> URL {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-write-guard-\(UUID().uuidString)", isDirectory: true)
        let libraryRoot = wsRoot.appendingPathComponent("reference-library", isDirectory: true)
        for layer in ReferenceLayer.allCases {
            try FileManager.default.createDirectory(
                at: libraryRoot.appendingPathComponent(layer.directoryName),
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(
            at: wsRoot.appendingPathComponent("references"),
            withIntermediateDirectories: true
        )
        return libraryRoot
    }

    /// What the truth on the disk holds.
    private static func truthText(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> String? {
        try? String(
            contentsOf: ReferenceBodyStore.truthURL(
                id: id,
                referenceLibraryRoot: referenceLibraryRoot
            ),
            encoding: .utf8
        )
    }

    /// The editor's save: = it writes the truth itself, = and then the
    /// store's write-through records that the truth now holds the
    /// USER's text.
    ///
    /// = This is the one path the agent's gate must NOT block: = the
    /// user is the writer here.
    private static func userEdits(
        store: FileSystemReferenceStore,
        id: UUID,
        body: String,
        referenceLibraryRoot: URL
    ) throws {
        let truth = ReferenceBodyStore.truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        try body.write(to: truth, atomically: true, encoding: .utf8)
        try store.replaceReferenceByID(id: id, bodyMarkdown: body)
    }

    /// Write one document into a layer's index, = the way the store
    /// writes it.
    ///
    /// **⇒ The index is what makes an upsert an UPDATE.** = The
    /// store's upsert finds the document by title in the layer's index
    /// file, = and an id it did not find there becomes a NEW document
    /// (= a new id, = a new truth, = and no conflict to detect). = So a
    /// test about a conflict has to put the document in the index, =
    /// or it measures the wrong path.
    private static func writeIndex(
        reference: Reference,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([reference])
        try data.write(
            to: referenceLibraryRoot
                .appendingPathComponent(layer.directoryName)
                .appendingPathComponent("\(layer.directoryName).json"),
            options: .atomic
        )
    }

    // MARK: - 1. The conflict

    @Test("A user edit, THEN an agent write: the write is refused and the user's text survives")
    func userEditThenAgentWriteIsRefused() async throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let actor = ReferenceLibraryActor(referenceStore: store)

        // The agent writes the document (= the librarian's create).
        let created = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "the body the AGENT wrote",
            layer: "entities"
        )
        #expect(Self.truthText(id: created.id, referenceLibraryRoot: root)
            == "the body the AGENT wrote")

        // The user edits it in the editor (= the truth now holds the
        // user's text, = and the store records that it does).
        try Self.userEdits(
            store: store,
            id: created.id,
            body: "the body the USER typed",
            referenceLibraryRoot: root
        )

        // **⇒ The agent writes the SAME document again** (= the
        // librarian's real upsert path: = the same title, = so the
        // same-title update branch, = and the truth write with no
        // comparison of its own).
        await #expect(throws: ReferenceLibraryError.self) {
            try await actor.upsertReference(
                title: "Ming tax system",
                bodyMarkdown: "the body the AGENT wants to write",
                layer: "entities"
            )
        }

        // **⇒ The user's text is STILL in the truth.** = The whole
        // point: = the agent's write did not land, = and nothing the
        // user typed is gone.
        #expect(Self.truthText(id: created.id, referenceLibraryRoot: root)
            == "the body the USER typed")
    }

    @Test("The refusal reaches the LLM as a named error that says what to do")
    func refusalIsANamedErrorWithAnActionableMessage() async throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let actor = ReferenceLibraryActor(referenceStore: store)

        let created = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "the body the AGENT wrote",
            layer: "entities"
        )
        try Self.userEdits(
            store: store,
            id: created.id,
            body: "the body the USER typed",
            referenceLibraryRoot: root
        )

        var caught: ReferenceLibraryError?
        do {
            _ = try await actor.upsertReference(
                title: "Ming tax system",
                bodyMarkdown: "the body the AGENT wants to write",
                layer: "entities"
            )
        } catch let error as ReferenceLibraryError {
            caught = error
        }
        // **⇒ The error is NAMED** (= not `underlying("userOwnsTheTruth
        // (id: ...)")`, = which tells the LLM nothing).
        guard case let .userEditedReference(id) = caught else {
            Issue.record("expected .userEditedReference, got \(String(describing: caught))")
            return
        }
        #expect(id == created.id)
        let message = caught?.errorDescription ?? ""
        #expect(message.contains("refused"))
        #expect(message.contains("extend"))
    }

    @Test("The store's own error says the same thing to whoever holds the store")
    func storeErrorIsActionable() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)
        try store.saveReference(reference, bodyMarkdown: "the body the AGENT wrote")
        try Self.userEdits(
            store: store,
            id: reference.id,
            body: "the body the USER typed",
            referenceLibraryRoot: root
        )

        var caught: ReferenceStoreError?
        do {
            _ = try store.upsertReference(
                title: "Ming tax system",
                bodyMarkdown: "the body the AGENT wants to write",
                layer: .layerEntities,
                category: nil,
                tags: [],
                source: nil,
                url: nil,
                entityType: .other,
                summary: ""
            )
        } catch let error as ReferenceStoreError {
            caught = error
        }
        guard case let .userOwnsTheTruth(id) = caught else {
            Issue.record("expected .userOwnsTheTruth, got \(String(describing: caught))")
            return
        }
        #expect(id == reference.id)
        #expect((caught?.errorDescription ?? "").contains("refused"))
    }

    // MARK: - 2. The agent's own text

    @Test("Two agent writes in a row: the second one lands")
    func consecutiveAgentWritesLand() async throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let actor = ReferenceLibraryActor(referenceStore: store)

        _ = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "the FIRST body",
            layer: "entities"
        )
        // **⇒ The agent writes the same document again** (= the
        // librarian's own update, = which is the normal path, = and
        // the rule must not refuse it: = the truth still holds the
        // agent's own text).
        let updated = try await actor.upsertReference(
            title: "Ming tax system",
            bodyMarkdown: "the SECOND body",
            layer: "entities"
        )

        #expect(Self.truthText(id: updated.id, referenceLibraryRoot: root) == "the SECOND body")
    }

    @Test("A write that ADDS to the user's text lands, and the user's text stays")
    func additiveWriteLands() async throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let actor = ReferenceLibraryActor(referenceStore: store)

        let created = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "the body the AGENT wrote",
            layer: "entities"
        )
        try Self.userEdits(
            store: store,
            id: created.id,
            body: "the body the USER typed",
            referenceLibraryRoot: root
        )

        // **⇒ The agent EXTENDS the document** (= the librarian's
        // self-evolution verb: = it reads the body, = appends a
        // section, = and writes the result). = The result STARTS WITH
        // the user's text, = so nothing the user typed is lost, = and
        // the rule lets it land.
        let extended = try await actor.extendReference(
            id: created.id,
            sectionTitle: "What the records say",
            sectionBody: "The tax rolls were recorded per household."
        )

        let truth = Self.truthText(id: extended.id, referenceLibraryRoot: root) ?? ""
        #expect(truth.contains("the body the USER typed"))
        #expect(truth.contains("What the records say"))
    }

    // MARK: - 3. A document written before the rule

    @Test("A document with no record: the corpus copy is the witness")
    func legacyDocumentUsesTheCorpusCopyAsWitness() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let id = UUID()
        let reference = Reference(id: id, title: "Ming tax system", layer: .layerEntities)

        // A document written BEFORE this rule: = the truth and the
        // corpus copy hold DIFFERENT text (= the user's edit), = and
        // there is no record to ask.
        let truth = ReferenceBodyStore.truthURL(id: id, referenceLibraryRoot: root)
        let mirror = ReferenceBodyStore.mirrorURL(
            id: id,
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        try FileManager.default.createDirectory(
            at: truth.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "the body the USER typed".write(to: truth, atomically: true, encoding: .utf8)
        try "the body the AGENT wrote".write(to: mirror, atomically: true, encoding: .utf8)
        try Self.writeIndex(
            reference: reference,
            layer: .layerEntities,
            referenceLibraryRoot: root
        )

        // **⇒ The agent's write is refused** (= the truth holds text
        // the corpus copy never saw, = so it is the user's).
        #expect(throws: ReferenceStoreError.self) {
            try store.upsertReference(
                title: "Ming tax system",
                bodyMarkdown: "the body the AGENT wants to write",
                layer: .layerEntities,
                category: nil,
                tags: [],
                source: nil,
                url: nil,
                entityType: .other,
                summary: ""
            )
        }
        #expect(Self.truthText(id: id, referenceLibraryRoot: root) == "the body the USER typed")
    }

    @Test("A document with no record whose truth AGREES with the corpus copy: the write lands")
    func legacyDocumentThatAgreesWithTheCorpusCopyIsWritable() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let id = UUID()
        let reference = Reference(id: id, title: "Ming tax system", layer: .layerEntities)

        let truth = ReferenceBodyStore.truthURL(id: id, referenceLibraryRoot: root)
        let mirror = ReferenceBodyStore.mirrorURL(
            id: id,
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        try FileManager.default.createDirectory(
            at: truth.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // The two agree (= the agent wrote both, = and the user did not
        // touch it) = = so the agent owns the text, = and may replace it.
        try "the body the AGENT wrote".write(to: truth, atomically: true, encoding: .utf8)
        try "the body the AGENT wrote".write(to: mirror, atomically: true, encoding: .utf8)
        try Self.writeIndex(
            reference: reference,
            layer: .layerEntities,
            referenceLibraryRoot: root
        )

        _ = try store.upsertReference(
            title: "Ming tax system",
            bodyMarkdown: "the body the AGENT wants to write",
            layer: .layerEntities,
            category: nil,
            tags: [],
            source: nil,
            url: nil,
            entityType: .other,
            summary: ""
        )
        #expect(Self.truthText(id: id, referenceLibraryRoot: root)
            == "the body the AGENT wants to write")
    }

    // MARK: - 4. The record's life

    @Test("A delete takes the record with it")
    func deleteRemovesTheRecord() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)
        try store.saveReference(reference, bodyMarkdown: "the body")

        let recordURL = ReferenceWriteGuard.recordURL(id: reference.id, referenceLibraryRoot: root)
        #expect(FileManager.default.fileExists(atPath: recordURL.path))

        try store.deleteReference(id: reference.id)
        // **⇒ The record names a document that no longer exists.** = A
        // later document with the same id would read it, = and the
        // rule would answer about a document that is not there.
        #expect(!FileManager.default.fileExists(atPath: recordURL.path))
    }

    @Test("The record is bookkeeping, and the readers never see it")
    func theRecordIsNotCorpusContent() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)
        try store.saveReference(reference, bodyMarkdown: "the body")

        // The corpus readers go through the per-layer index files, =
        // so the hidden record directory is not corpus content.
        let all = try store.loadAllReferences()
        #expect(all.count == 1)
        #expect(all.first?.id == reference.id)

        // **⇒ And the record lives in a HIDDEN directory** (= a dot
        // prefix), = so it is not a layer and not a document.
        let directory = ReferenceWriteGuard.recordDirectoryURL(referenceLibraryRoot: root)
        #expect(directory.lastPathComponent.hasPrefix("."))
        #expect(directory.deletingLastPathComponent() == root)
    }
}
