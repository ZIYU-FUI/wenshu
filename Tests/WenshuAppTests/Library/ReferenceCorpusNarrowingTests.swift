//
//  ReferenceCorpusNarrowingTests.swift
//
//  The two axes the corpus narrows by: = what KIND of document it is,
//  = and WHO wrote it.
//
//  Coverage:
//    - the kind axis (= the corpus's own closed set of 9)
//    - the owner axis (= you vs. an agent; = the binary the witness
//      can prove)
//    - the owner the witness CANNOT prove (= it reads as the user's,
//      because the agent may never claim text it cannot prove it
//      wrote)
//    - a document whose truth cannot be read at all (= absent from the
//      owners, = so it never lands in the agent's bucket)
//    - the search service's use of both axes
//
//  Q112: 1 source + 1 test per ticket
//  (= ReferenceCorpusNarrowing.swift + this file).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Reference corpus narrowing")
struct ReferenceCorpusNarrowingTests {
    // MARK: - The kind axis

    @Test("a narrowing by kind admits only that kind")
    func kindAdmitsOnlyThatKind() {
        let character = Reference(title: "a person", entityType: .character)
        let location = Reference(title: "a place", entityType: .location)
        let narrowing = ReferenceCorpusNarrowing(kind: .character, owner: nil)
        #expect(narrowing.admits(character, ownerOf: { _ in .user }))
        #expect(!narrowing.admits(location, ownerOf: { _ in .user }))
    }

    @Test("the kind axis is the corpus's own closed set of nine")
    func kindIsTheCorpusClosedSet() {
        // The archive has its own kind vocabulary (= what the agents
        // did); = the corpus's kind is the corpus's own. = A document
        // carries exactly one of these.
        #expect(EntityType.allCases.count == 9)
        #expect(Set(EntityType.allCases).contains(.character))
        #expect(Set(EntityType.allCases).contains(.location))
        #expect(Set(EntityType.allCases).contains(.event))
        #expect(Set(EntityType.allCases).contains(.concept))
        #expect(Set(EntityType.allCases).contains(.artifact))
        #expect(Set(EntityType.allCases).contains(.organization))
        #expect(Set(EntityType.allCases).contains(.era))
        #expect(Set(EntityType.allCases).contains(.work))
        #expect(Set(EntityType.allCases).contains(.other))
    }

    @Test("no narrowing admits everything")
    func noNarrowingAdmitsEverything() {
        let any = Reference(title: "anything", entityType: .artifact)
        #expect(ReferenceCorpusNarrowing.all.admits(any, ownerOf: { _ in .user }))
        #expect(ReferenceCorpusNarrowing.all.admits(any, ownerOf: { _ in .agent }))
        #expect(!ReferenceCorpusNarrowing.all.isActive)
    }

    @Test("a narrowing by one axis is active")
    func narrowingByOneAxisIsActive() {
        #expect(ReferenceCorpusNarrowing(kind: .concept, owner: nil).isActive)
        #expect(ReferenceCorpusNarrowing(kind: nil, owner: .agent).isActive)
    }

    // MARK: - The owner axis

    @Test("the owner axis separates the user from an agent")
    func ownerAxisSeparatesUserFromAgent() {
        let document = Reference(title: "a note", entityType: .concept)
        #expect(ReferenceCorpusNarrowing(kind: nil, owner: .user)
            .admits(document, ownerOf: { _ in .user }))
        #expect(!ReferenceCorpusNarrowing(kind: nil, owner: .user)
            .admits(document, ownerOf: { _ in .agent }))
        #expect(ReferenceCorpusNarrowing(kind: nil, owner: .agent)
            .admits(document, ownerOf: { _ in .agent }))
        #expect(!ReferenceCorpusNarrowing(kind: nil, owner: .agent)
            .admits(document, ownerOf: { _ in .user }))
    }

    @Test("the owner axis is binary (= it names no role)")
    func ownerAxisIsBinary() {
        // **⇒ The app can prove "an agent wrote this" or "the user
        // wrote this", = and it cannot prove WHICH agent.** = So the
        // axis offers exactly the two owners the witness can prove.
        #expect(ReferenceCorpusOwner.allCases.count == 2)
        #expect(ReferenceCorpusOwner.allCases.contains(.user))
        #expect(ReferenceCorpusOwner.allCases.contains(.agent))
    }

    @Test("both axes together narrow by kind AND by owner")
    func bothAxesTogether() {
        let mine = Reference(title: "mine", entityType: .concept)
        let theirs = Reference(title: "theirs", entityType: .concept)
        let narrowing = ReferenceCorpusNarrowing(kind: .concept, owner: .user)
        #expect(narrowing.admits(mine, ownerOf: { _ in .user }))
        #expect(!narrowing.admits(theirs, ownerOf: { _ in .agent }))
    }

    // MARK: - The witness

    @Test("a document whose truth cannot be read has no owner")
    func unreadableTruthHasNoOwner() {
        // The truth is not there: = there is nothing to prove, = so
        // the document is ABSENT from the owners (= and the search
        // reads an absent owner as the user's).
        let root = Self.makeCorpus()
        defer { Self.remove(root) }
        let document = Reference(title: "never written", entityType: .other)
        #expect(ReferenceCorpusOwnership.owner(
            of: document,
            referenceLibraryRoot: root
        ) == nil)
    }

    @Test("a document the user wrote reads as the user's")
    func userWrittenDocumentIsTheUsers() {
        let root = Self.makeCorpus()
        defer { Self.remove(root) }
        let document = Reference(title: "the user's note", entityType: .other)
        // **⇒ The user's write is THE EDITOR's write**, = and it does
        // not come through `ReferenceBodyStore.write` (= that is the
        // AGENT's path, = and it records the agent's ownership). = The
        // editor writes the truth itself, = and the store records the
        // user's write beside it.
        Self.writeTruth(document, root: root, text: "written by the user")
        _ = ReferenceWriteGuard.recordUserWrite(
            id: document.id,
            bodyMarkdown: "written by the user",
            referenceLibraryRoot: root
        )
        #expect(ReferenceCorpusOwnership.owner(
            of: document,
            referenceLibraryRoot: root
        ) == .user)
    }

    @Test("a document the user edited AFTER the agent wrote it reads as the user's")
    func userEditedDocumentIsTheUsers() {
        let root = Self.makeCorpus()
        defer { Self.remove(root) }
        let document = Reference(title: "the note", entityType: .other)
        // The agent wrote it (= the record says so, = and the mirror
        // holds the same text).
        try? ReferenceBodyStore.write(
            id: document.id,
            layer: .layerEntities,
            bodyMarkdown: "the agent's text",
            referenceLibraryRoot: root
        )
        // And then the user edited it (= the truth now holds different
        // text, = and the record's hash no longer matches).
        Self.writeTruth(document, root: root, text: "the user's edit")
        #expect(ReferenceCorpusOwnership.owner(
            of: document,
            referenceLibraryRoot: root
        ) == .user)
    }

    @Test("a document an agent wrote reads as the agent's")
    func agentWrittenDocumentIsTheAgents() {
        let root = Self.makeCorpus()
        defer { Self.remove(root) }
        let document = Reference(title: "the agent's note", entityType: .other)
        let text = "written by the agent"
        Self.writeBody(document, layer: .layerEntities, root: root, text: text)
        // The agent's write records its ownership (= the second-writer
        // rule's witness) = and the truth still holds that text.
        _ = ReferenceWriteGuard.recordAgentWrite(
            id: document.id,
            bodyMarkdown: text,
            ownership: .agent,
            referenceLibraryRoot: root
        )
        #expect(ReferenceCorpusOwnership.owner(
            of: document,
            referenceLibraryRoot: root
        ) == .agent)
    }

    @Test("the owners map covers the documents the witness can prove")
    func ownersMapCoversProvableDocuments() {
        let root = Self.makeCorpus()
        defer { Self.remove(root) }
        let written = Reference(title: "written", entityType: .other)
        let unwritten = Reference(title: "unwritten", entityType: .other)
        Self.writeTruth(written, root: root, text: "text")
        let owners = ReferenceCorpusOwnership.owners(
            for: [written, unwritten],
            referenceLibraryRoot: root
        )
        #expect(owners.count == 1)
        #expect(owners[written.id] == .user)
        #expect(owners[unwritten.id] == nil)
    }

    @Test("an owner the witness cannot name reads as the user's")
    func unknownOwnerReadsAsTheUsers() {
        // **⇒ The agent may never claim text it cannot prove it
        // wrote** (= the second-writer rule's own answer). = So an
        // owner the witness could not read (= nil) is the user's, = and
        // the agent's bucket never holds it.
        let document = Reference(title: "a note", entityType: .concept)
        #expect(ReferenceCorpusNarrowing(kind: nil, owner: .user)
            .admits(document, ownerOf: { _ in nil }))
        #expect(!ReferenceCorpusNarrowing(kind: nil, owner: .agent)
            .admits(document, ownerOf: { _ in nil }))
    }

    // MARK: - The search service's use of the axes

    @Test("the search admits a document the narrowing keeps")
    func searchAdmitsKeptDocument() {
        let document = Reference(title: "a person", entityType: .character)
        let hits = ReferenceLibrarySearch.search(
            query: "person",
            references: [document],
            bodyOf: { _ in "a person in the corpus" },
            narrowing: ReferenceCorpusNarrowing(kind: .character, owner: nil)
        )
        #expect(hits.count == 1)
    }

    @Test("the search drops a document the narrowing excludes")
    func searchDropsExcludedDocument() {
        let document = Reference(title: "a person", entityType: .character)
        let hits = ReferenceLibrarySearch.search(
            query: "person",
            references: [document],
            bodyOf: { _ in "a person in the corpus" },
            narrowing: ReferenceCorpusNarrowing(kind: .location, owner: nil)
        )
        #expect(hits.isEmpty)
    }

    @Test("the search excludes a document whose owner the witness cannot name")
    func searchExcludesUnknownOwnerFromTheAgentBucket() {
        // **⇒ The agent bucket holds only what the witness PROVES.**
        // = A document the owner cannot be read for (= the truth is
        // unreadable, = or there is no record and no mirror) = is not
        // the agent's to show. = **⇒ And it must not be the agent's
        // to TAKE either** (= the second-writer rule's own rule).
        let document = Reference(title: "a person", entityType: .character)
        let hits = ReferenceLibrarySearch.search(
            query: "person",
            references: [document],
            bodyOf: { _ in "a person in the corpus" },
            narrowing: ReferenceCorpusNarrowing(kind: nil, owner: .agent),
            ownerOf: { _ in nil }
        )
        #expect(hits.isEmpty)
    }

    @Test("the search keeps an unknown owner in the user's bucket")
    func searchKeepsUnknownOwnerInTheUsersBucket() {
        let document = Reference(title: "a person", entityType: .character)
        let hits = ReferenceLibrarySearch.search(
            query: "person",
            references: [document],
            bodyOf: { _ in "a person in the corpus" },
            narrowing: ReferenceCorpusNarrowing(kind: nil, owner: .user),
            ownerOf: { _ in nil }
        )
        #expect(hits.count == 1)
    }

    @Test("the narrowing runs BEFORE the body is read")
    func narrowingRunsBeforeTheBodyIsRead() {
        // **⇒ A document the user excluded must not be read at all.**
        // = And it must not be COUNTED in what the search found.
        let document = Reference(title: "a person", entityType: .character)
        var bodiesRead = 0
        _ = ReferenceLibrarySearch.search(
            query: "person",
            references: [document],
            bodyOf: { _ in
                bodiesRead += 1
                return "a person in the corpus"
            },
            narrowing: ReferenceCorpusNarrowing(kind: .location, owner: nil)
        )
        #expect(bodiesRead == 0)
    }

    // MARK: - The corpus on disk

    /// A corpus root in a temporary directory (= the user's real
    /// library is never written by a test).
    ///
    /// **⇒ The root is the LIBRARY root** (= `<ws>/reference-library`),
    /// **⇒ and the truth lives beside it** (= `<ws>/references`), = so
    /// the layout is the one the store writes.
    private static func makeCorpus() -> URL {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-narrowing-\(UUID().uuidString)", isDirectory: true)
        let libraryRoot = wsRoot.appendingPathComponent("reference-library", isDirectory: true)
        for layer in ReferenceLayer.allCases {
            try? FileManager.default.createDirectory(
                at: libraryRoot.appendingPathComponent(layer.directoryName, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try? FileManager.default.createDirectory(
            at: wsRoot.appendingPathComponent("references", isDirectory: true),
            withIntermediateDirectories: true
        )
        return libraryRoot
    }

    /// Write a body into the corpus (= the truth and the mirror, = so
    /// the witness can compare them).
    private static func writeBody(
        _ document: Reference,
        layer: ReferenceLayer,
        root: URL,
        text: String
    ) {
        try? ReferenceBodyStore.write(
            id: document.id,
            layer: layer,
            bodyMarkdown: text,
            referenceLibraryRoot: root
        )
    }

    /// Write the TRUTH (= the editor's own write, = and no record).
    private static func writeTruth(
        _ document: Reference,
        root: URL,
        text: String
    ) {
        let url = ReferenceBodyStore.truthURL(
            id: document.id,
            referenceLibraryRoot: root
        )
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Remove a temporary corpus.
    private static func remove(_ root: URL) {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }
}
