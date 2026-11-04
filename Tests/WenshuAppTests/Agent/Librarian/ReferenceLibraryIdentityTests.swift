//
//  ReferenceLibraryIdentityTests.swift · Wenshu
//
//  One document, one identity.
//
//  The library had three writers and three answers to "is this the
//  same document?":
//
//  - the tool's `create` wrote a fresh random id and never looked;
//  - the tool's `upsert` matched on the trimmed title;
//  - the import matched on the collapsed title.
//
//  So the same noun, written by two callers, landed in the library
//  twice, and the two copies did not know about each other. The tool's
//  description told the model to `find` before it created; = that is
//  a request, = and the model is not the mechanism.
//
//  These tests pin one rule and make every writer answer with it.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference library · one document, one identity")
@MainActor
struct ReferenceLibraryIdentityTests {

    // MARK: - Helpers

    private static func makeActor() throws -> (ReferenceLibraryActor, FileSystemReferenceStore) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-ref-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
        return (ReferenceLibraryActor(referenceStore: store), store)
    }

    /// The documents the store holds (= what the user would see).
    private static func entities(_ store: FileSystemReferenceStore) -> [Reference] {
        ((try? store.loadAllReferences()) ?? []).filter { $0.layer == .layerEntities }
    }

    // MARK: - The rule itself

    @Test("the identity rule is trimmed, case-insensitive, and whitespace-collapsed")
    func theIdentityRule() {
        #expect(Reference.titlesMatch("Ming tax", "ming tax"))
        #expect(Reference.titlesMatch("Ming tax", "  Ming tax  "))
        #expect(Reference.titlesMatch("Ming tax", "Ming  tax"),
                "a whitespace run must not make a second document")
        #expect(Reference.titlesMatch("Ming tax", "Ming\ttax"))
        #expect(!Reference.titlesMatch("Ming tax", "Ming taxes"))
        #expect(!Reference.titlesMatch("Ming tax", "tax Ming"))
    }

    /// The rule must be the same one everywhere it is used, = not
    /// three copies that drift.
    @Test("every writer uses the one rule")
    func everyWriterUsesTheOneRule() {
        #expect(
            ImportServiceDedup.normalizeTitle("Ming  tax")
                == Reference.normalizeTitle("Ming  tax"),
            "the import must use the library's rule"
        )
        #expect(
            ReferenceLibraryActor.titlesMatch("Ming  tax", "Ming tax"),
            "the actor must use the library's rule"
        )
    }

    // MARK: - Create refuses a second copy

    @Test("a create with a title that already exists is refused")
    func createRefusesADuplicateTitle() async throws {
        let (actor, store) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nThe first body.",
            layer: "entities",
            summary: "The first summary."
        )

        await #expect(throws: ReferenceLibraryError.self) {
            try await actor.createReference(
                title: "Ming tax system",
                bodyMarkdown: "# Ming tax\n\nA second body.",
                layer: "entities",
                summary: "A second summary."
            )
        }
    }

    @Test("a create that duplicates a title writes nothing")
    func createRefusalWritesNothing() async throws {
        let (actor, store) = try Self.makeActor()
        let first = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nThe first body.",
            layer: "entities",
            summary: "The first summary."
        )

        await #expect(throws: ReferenceLibraryError.self) {
            try await actor.createReference(
                title: "ming  TAX system",
                bodyMarkdown: "# Ming tax\n\nA second body.",
                layer: "entities",
                summary: "A second summary."
            )
        }

        let entities = Self.entities(store)
        #expect(entities.count == 1, "the refused create must not add a document")
        #expect(entities[0].id == first.id, "the original document must be untouched")
        #expect(entities[0].summary == "The first summary.", "the original must be untouched")
    }

    @Test("a create in another layer is not a duplicate")
    func createInAnotherLayerIsNotADuplicate() async throws {
        let (actor, store) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Raw\n\nThe raw body.",
            layer: "raw",
            summary: "Raw."
        )
        // The same title in the other layer is a different document:
        // the two layers hold different things (= raw = the source,
        // entities = what the user reads).
        let second = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Entity\n\nThe entity body.",
            layer: "entities",
            summary: "Entity."
        )
        #expect(second.layer == "entities")
    }

    // MARK: - Upsert still updates in place

    @Test("an upsert of an existing title updates that document rather than adding one")
    func upsertUpdatesInPlace() async throws {
        let (actor, store) = try Self.makeActor()
        let first = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nThe first body.",
            layer: "entities",
            summary: "The first summary."
        )
        let updated = try await actor.upsertReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nThe second body.",
            layer: "entities",
            summary: "The second summary."
        )

        #expect(updated.id == first.id, "the upsert must land on the same document")

        let entities = Self.entities(store)
        #expect(entities.count == 1, "the upsert must not add a second document")
    }

    @Test("an upsert of a title that differs only in whitespace updates the same document")
    func upsertCollapsesWhitespace() async throws {
        let (actor, store) = try Self.makeActor()
        let first = try await actor.createReference(
            title: "Ming tax system",
            bodyMarkdown: "# Ming tax\n\nThe first body.",
            layer: "entities",
            summary: "The first summary."
        )
        let updated = try await actor.upsertReference(
            title: "Ming  tax system",
            bodyMarkdown: "# Ming tax\n\nThe second body.",
            layer: "entities",
            summary: "The second summary."
        )

        #expect(
            updated.id == first.id,
            "the two titles name one document; = the import's rule and the upsert's rule have to agree"
        )
    }
}
