//
//  ReferenceLayerMembershipTests.swift
//
//  Who is IN a layer.
//
//  **⇒ The corpus's membership was the INDEX, = and the index is one
//  of TWO writes.** = The body is written by `ReferenceBodyStore.write`
//  (= the truth, = then the ownership record, = then the mirror), = and
//  the index by `writeIndexToFileSystem`. = `AtomicFileWrite` makes
//  EACH one atomic, = **⇒ but the PAIR is not.** = A crash between
//  them leaves a body on disk that the index does not list.
//
//  **⇒ And the consequence was a LIE.** = The corpus was READABLE
//  (= so the strict read did not help), = and the report said **"NOT
//  in the library, = so it did not land"** about a document that was
//  sitting there.
//
//  Coverage:
//    - a body the index does not list is still a member
//    - a body the index lists is not duplicated
//    - a recovered member names ITSELF (= the body's own first H1)
//    - a recovered member does not INVENT its kind (= ".other")
//    - a file that is not a document (= no uuid in the name) is not a
//      member
//    - the index's rows keep their metadata
//
//  Q112: 1 source + 1 test per ticket
//  (= ReferenceLayerMembership.swift + this file).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("A layer's membership is what is on disk")
struct ReferenceLayerMembershipTests {

    // MARK: - The crash window

    @Test("a body the index does not list is still a member")
    func bodyWithoutAnIndexRowIsAMember() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(id: id, layer: .layerEntities, root: root, text: "# The tax roll\n\nThe body.")

        // The index holds nothing (= the crash happened between the
        // body write and the index write).
        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.id == id)
    }

    @Test("a body the index lists is not duplicated")
    func listedBodyIsNotDuplicated() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(id: id, layer: .layerEntities, root: root, text: "# The tax roll\n\nThe body.")
        let row = Reference(
            id: id,
            title: "The tax roll",
            layer: .layerEntities,
            entityType: .concept
        )

        let members = ReferenceLayerMembership.members(
            indexRows: [row],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.entityType == .concept)
    }

    @Test("the index's rows keep their metadata")
    func indexRowsKeepTheirMetadata() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let row = Reference(
            title: "Cao Cao",
            layer: .layerEntities,
            tags: ["Three Kingdoms"],
            entityType: .character,
            summary: "The warlord."
        )
        let members = ReferenceLayerMembership.members(
            indexRows: [row],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.tags == ["Three Kingdoms"])
        #expect(members.first?.entityType == .character)
        #expect(members.first?.summary == "The warlord.")
    }

    // MARK: - What a recovered member says about itself

    @Test("a recovered member names ITSELF (= the body's own first H1)")
    func recoveredMemberNamesItself() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(
            id: id,
            layer: .layerEntities,
            root: root,
            text: "# The tax roll of 680\n\nThe body."
        )

        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.title == "The tax roll of 680")
    }

    @Test("a recovered member does not INVENT its kind")
    func recoveredMemberDoesNotInventItsKind() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(id: id, layer: .layerEntities, root: root, text: "# The tax roll\n\nThe body.")

        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        // **⇒ The kind, = the tags, = and the category lived in the
        // index row that was lost.** = A document filed under a kind
        // nobody chose is a worse lie than one filed under "other".
        #expect(members.first?.entityType == .other)
        #expect(members.first?.tags.isEmpty == true)
        #expect(members.first?.category == nil)
    }

    @Test("a recovered member is in the layer it was found in")
    func recoveredMemberKeepsItsLayer() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(id: id, layer: .layerRaw, root: root, text: "# The original\n\nThe body.")

        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerRaw,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.layer == .layerRaw)
    }

    // MARK: - What is not a document

    @Test("a file whose name is not a document's is not a member")
    func nonDocumentFileIsNotAMember() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        // A file the user dropped in (= its name carries no id, = so
        // it has no identity, = and a member with a made-up identity
        // is a lie).
        try "not a document".write(
            to: root
                .appendingPathComponent("entities", isDirectory: true)
                .appendingPathComponent("notes.md"),
            atomically: true,
            encoding: .utf8
        )

        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.isEmpty)
    }

    @Test("the index file itself is not a member")
    func indexFileIsNotAMember() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        try "[]".write(
            to: root
                .appendingPathComponent("entities", isDirectory: true)
                .appendingPathComponent("entities.json"),
            atomically: true,
            encoding: .utf8
        )
        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.isEmpty)
    }

    @Test("a body in a legacy subdirectory is still a member")
    func legacySubdirectoryBodyIsAMember() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        let legacy = root
            .appendingPathComponent("entities", isDirectory: true)
            .appendingPathComponent("taxes", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try "# The tax roll\n\nThe body.".write(
            to: legacy.appendingPathComponent("\(id.uuidString).md"),
            atomically: true,
            encoding: .utf8
        )

        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.count == 1)
        #expect(members.first?.id == id)
    }

    @Test("one layer's bodies do not join another layer")
    func bodiesDoNotCrossLayers() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let id = UUID()
        try Self.writeBody(id: id, layer: .layerRaw, root: root, text: "# The original\n\nThe body.")

        let entities = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(entities.isEmpty)
    }

    @Test("an empty corpus has no members")
    func emptyCorpusHasNoMembers() throws {
        let root = try Self.makeCorpus()
        defer { Self.remove(root) }
        let members = ReferenceLayerMembership.members(
            indexRows: [],
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(members.isEmpty)
    }

    // MARK: - The corpus on disk

    /// A corpus root in a temporary directory (= the user's real
    /// library is never written by a test).
    private static func makeCorpus() throws -> URL {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-membership-\(UUID().uuidString)", isDirectory: true)
        let libraryRoot = wsRoot.appendingPathComponent("reference-library", isDirectory: true)
        for layer in ReferenceLayer.allCases {
            try FileManager.default.createDirectory(
                at: libraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(
            at: wsRoot.appendingPathComponent("references", isDirectory: true),
            withIntermediateDirectories: true
        )
        return libraryRoot
    }

    /// Write a body into the corpus (= the truth and the mirror).
    private static func writeBody(
        id: UUID,
        layer: ReferenceLayer,
        root: URL,
        text: String
    ) throws {
        try ReferenceBodyStore.write(
            id: id,
            layer: layer,
            bodyMarkdown: text,
            referenceLibraryRoot: root
        )
    }

    /// Remove a temporary corpus.
    private static func remove(_ root: URL) {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }
}
