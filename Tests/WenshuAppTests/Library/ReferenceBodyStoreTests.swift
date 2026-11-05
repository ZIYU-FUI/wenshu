//
//  ReferenceBodyStoreTests.swift
//
//  One body, = one truth.
//
//  **⇒ The corpus had two copies of every body, = and both were
//  written.** = `<ws>/reference-library/<layer>/<uuid>.md` (= the
//  layer copy) = and `<ws>/references/<uuid>.md` (= the single-file
//  copy, = the one the editor's auto-save writes, = and the one the
//  doc-truth ticket named). = Measured against the user's real
//  library: = **six documents, = six divergent pairs**, = the
//  single-file copy newer in every case, = and one of them differing
//  in content (= the user edited it).
//
//  The three ways that bites, = and each one is a test here:
//
//  1. **The agent's write is invisible.** = In production the store
//     has no SwiftData container, = so the write path wrote the LAYER
//     copy, = while the read path prefers the single-file copy. = A
//     document the agent had just written read back as the older
//     text.
//  2. **A deleted document's body stays on disk.** = The delete path
//     removed the layer copy, = and the single-file copy survived.
//  3. **The update is invisible.** = Same shape as (1): = an update
//     wrote the mirror, = and the truth kept the previous body.
//
//  **⇒ The rule.** = The single-file location is the TRUTH. = The
//  layer copy is a MIRROR: = written whenever the truth is written, =
//  read only when the truth is absent. = One type answers "where does
//  this body live", = so the three paths cannot each pick their own.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The corpus has one truth for a body")
struct ReferenceBodyStoreTests {
    /// A `.ws` root with a reference library under it.
    private static func makeLibrary() throws -> URL {
        let wsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-body-truth-\(UUID().uuidString)", isDirectory: true)
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

    private static let id = UUID()

    // MARK: - Where the body lives

    @Test("The truth is the single-file location")
    func truthIsTheSingleFile() throws {
        let root = try Self.makeLibrary()
        let url = ReferenceBodyStore.truthURL(id: Self.id, referenceLibraryRoot: root)
        #expect(url.lastPathComponent == "\(Self.id.uuidString).md")
        #expect(url.deletingLastPathComponent().lastPathComponent == "references")
    }

    @Test("The mirror is the layer's copy")
    func mirrorIsTheLayerCopy() throws {
        let root = try Self.makeLibrary()
        let url = ReferenceBodyStore.mirrorURL(
            id: Self.id,
            layer: .layerEntities,
            referenceLibraryRoot: root
        )
        #expect(url.deletingLastPathComponent().lastPathComponent == "entities")
    }

    // MARK: - A write lands in both

    @Test("A write lands in the truth and in the mirror")
    func writeLandsInBoth() throws {
        let root = try Self.makeLibrary()
        try ReferenceBodyStore.write(
            id: Self.id,
            layer: .layerEntities,
            bodyMarkdown: "the body",
            referenceLibraryRoot: root
        )

        let truth = try String(
            contentsOf: ReferenceBodyStore.truthURL(id: Self.id, referenceLibraryRoot: root),
            encoding: .utf8
        )
        let mirror = try String(
            contentsOf: ReferenceBodyStore.mirrorURL(
                id: Self.id,
                layer: .layerEntities,
                referenceLibraryRoot: root
            ),
            encoding: .utf8
        )
        #expect(truth == "the body")
        #expect(mirror == "the body")
    }

    @Test("A second write replaces the first in BOTH")
    func secondWriteReplacesInBoth() throws {
        let root = try Self.makeLibrary()
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the first body", referenceLibraryRoot: root
        )
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the second body", referenceLibraryRoot: root
        )

        let truth = try String(
            contentsOf: ReferenceBodyStore.truthURL(id: Self.id, referenceLibraryRoot: root),
            encoding: .utf8
        )
        let mirror = try String(
            contentsOf: ReferenceBodyStore.mirrorURL(
                id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
            ),
            encoding: .utf8
        )
        #expect(truth == "the second body")
        #expect(mirror == "the second body")
    }

    // MARK: - The read prefers the truth

    @Test("The read prefers the truth over a stale mirror")
    func readPrefersTheTruth() throws {
        let root = try Self.makeLibrary()
        // The mirror holds an OLD body (= what the layer copy looked
        // like before the truth was introduced).
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the old body", referenceLibraryRoot: root
        )
        // And the truth holds the new one (= what the editor wrote).
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the new body", referenceLibraryRoot: root
        )
        // Make the mirror stale on purpose.
        let mirror = ReferenceBodyStore.mirrorURL(
            id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
        )
        try "the old body".write(to: mirror, atomically: true, encoding: .utf8)

        let read = ReferenceBodyStore.read(
            id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
        )
        #expect(read == "the new body")
    }

    @Test("The mirror is read when the truth is absent (= a library that predates it)")
    func mirrorIsTheFallback() throws {
        let root = try Self.makeLibrary()
        let mirror = ReferenceBodyStore.mirrorURL(
            id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
        )
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "only in the mirror".write(to: mirror, atomically: true, encoding: .utf8)

        let read = ReferenceBodyStore.read(
            id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
        )
        #expect(read == "only in the mirror")
    }

    @Test("The truth is read when the USER edits it (= the reason the truth wins)")
    func userEditIsRead() throws {
        let root = try Self.makeLibrary()
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the body", referenceLibraryRoot: root
        )
        // The user edits the document in the editor, = which writes the
        // truth location. = The mirror keeps the OLD body (= the
        // editor does not know the document's layer, = so it cannot
        // update the mirror).
        let truth = ReferenceBodyStore.truthURL(id: Self.id, referenceLibraryRoot: root)
        try "the body the USER typed".write(to: truth, atomically: true, encoding: .utf8)

        let read = ReferenceBodyStore.read(
            id: Self.id, layer: .layerEntities, referenceLibraryRoot: root
        )
        // **⇒ The user's edit is what the reader sees.** = A reader
        // that preferred the mirror would show the body the agent
        // wrote, = and the user's edit would be invisible until the
        // next agent write (= which may never come).
        #expect(read == "the body the USER typed")
    }

    // MARK: - A delete removes both

    @Test("A delete removes the body from both locations")
    func deleteRemovesBoth() throws {
        let root = try Self.makeLibrary()
        try ReferenceBodyStore.write(
            id: Self.id, layer: .layerEntities, bodyMarkdown: "the body", referenceLibraryRoot: root
        )

        ReferenceBodyStore.remove(id: Self.id, layer: .layerEntities, referenceLibraryRoot: root)

        #expect(!FileManager.default.fileExists(atPath: ReferenceBodyStore
                .truthURL(id: Self.id, referenceLibraryRoot: root).path))
        #expect(!FileManager.default.fileExists(atPath: ReferenceBodyStore
                .mirrorURL(id: Self.id, layer: .layerEntities, referenceLibraryRoot: root).path))
    }

    // MARK: - The editor's save

    @Test("The editor's save writes the truth, = and the store writes the mirror")
    @MainActor
    func editorSaveLeavesBothCurrent() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)
        try store.saveReference(reference, bodyMarkdown: "the body the agent wrote")

        // **⇒ What the EDITOR does**: = it writes the truth location
        // (= `tab.documentPath`), = and it does not know the layer, =
        // so it cannot write the mirror.
        let truth = ReferenceBodyStore.truthURL(id: reference.id, referenceLibraryRoot: root)
        try "the body the USER typed".write(to: truth, atomically: true, encoding: .utf8)

        // **⇒ And what the store does**: = the editor's save calls
        // `replaceReferenceByID`, = and that is where the mirror is
        // written (= the store knows the layer).
        try store.replaceReferenceByID(id: reference.id, bodyMarkdown: "the body the USER typed")

        let mirror = try String(
            contentsOf: ReferenceBodyStore.mirrorURL(
                id: reference.id, layer: .layerEntities, referenceLibraryRoot: root
            ),
            encoding: .utf8
        )
        // **⇒ The mirror carries the user's text.** = Before this, = a
        // mirror left stale was a file the user could open in the
        // Finder and find the OLD text in (= measured on the real
        // library: = six documents, = six divergent pairs).
        #expect(mirror == "the body the USER typed")
    }

    @Test("The editor's save leaves the truth file alone (= the editor wrote it)")
    @MainActor
    func editorSaveDoesNotRewriteTheTruth() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)
        try store.saveReference(reference, bodyMarkdown: "the body the agent wrote")

        let truth = ReferenceBodyStore.truthURL(id: reference.id, referenceLibraryRoot: root)
        try "the body the USER typed".write(to: truth, atomically: true, encoding: .utf8)
        let before = try FileManager.default.attributesOfItem(atPath: truth.path)[.modificationDate] as? Date

        try store.replaceReferenceByID(id: reference.id, bodyMarkdown: "the body the USER typed")

        let after = try FileManager.default.attributesOfItem(atPath: truth.path)[.modificationDate] as? Date
        // **⇒ The truth file's MODIFICATION DATE does not move.**
        // = The editor may have a watcher on it, = and rewriting a file
        // the editor just wrote can trigger a reload it does not need.
        #expect(before == after)
    }

    // MARK: - The store uses the rule

    @Test("The store reads the truth, = so the agent's write reads back")
    @MainActor
    func storeReadsWhatWasWritten() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)

        try store.saveReference(reference, bodyMarkdown: "the body the agent wrote")

        // **⇒ The body the agent wrote is the body that reads back.**
        // = Before this change the write went to the layer copy only,
        // = and the read preferred the single-file copy, = so a
        // document the agent had just written read back as absent.
        let read = store.loadReferenceBody(id: reference.id)
        #expect(read == "the body the agent wrote")
    }

    @Test("The store's update replaces the body, = and the read sees it")
    @MainActor
    func storeUpdateIsVisible() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)

        try store.saveReference(reference, bodyMarkdown: "the first body")
        try store.replaceReference(reference, bodyMarkdown: "the second body")

        let read = store.loadReferenceBody(id: reference.id) ?? ""
        #expect(read.contains("the second body"))
        #expect(read.contains("the first body") == false)
    }

    @Test("The store's delete takes the body off the disk, = in both places")
    @MainActor
    func storeDeleteRemovesBoth() throws {
        let root = try Self.makeLibrary()
        let store = FileSystemReferenceStore(referenceLibraryRoot: root)
        let reference = Reference(title: "Ming tax system", layer: .layerEntities)

        try store.saveReference(reference, bodyMarkdown: "the body")
        try store.deleteReference(id: reference.id)

        #expect(store.loadReferenceBody(id: reference.id) == nil)
        // **⇒ The body is not on the disk either.** = A delete that
        // leaves the file behind is not a delete.
        #expect(!FileManager.default.fileExists(atPath: ReferenceBodyStore
                .truthURL(id: reference.id, referenceLibraryRoot: root).path))
    }
}
