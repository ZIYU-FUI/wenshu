//
//  LibraryRenameAnnouncesTests.swift · Wenshu
//
//  The regression test for a change the audit's own card introduced.
//
//  The card cached the editor's wiki-link fingerprint (= the hash of the
//  reference library's entity index), = and the cache is dropped when the
//  app announces a library change. = The base read the disk on every call,
//  so a rename was ALWAYS visible. = The tip reads the cached value, =
//  and the rename path did not announce, = so the fingerprint stayed
//  STALE after an in-app rename: = the engine compares the fingerprint
//  against its last one and only restyles the wiki-links when it
//  changed, = so a renamed entity's link kept the old label.
//
//  MEASURED by the reviewer on both trees (= the same production seam,
//  = `ReferenceLibraryWikiLinkResolver.fingerprint()`, = not a replica):
//
//  | tree              | the rename is seen |
//  | ----------------- | ------------------ |
//  | base `2a4c5d0a4`  | YES                |
//  | tip  `9a1551482d` | NO (= the regression) |
//
//  ⇒ ⇒ So this test drives the PRODUCTION rename (= `SidebarService`),
//  reads the fingerprint through the PRODUCTION resolver, = and asserts
//  that the rename is visible. = ⇒ A rename that does not announce is
//  RED here, = which is the point: = the fix is the announcement, = and
//  the test holds the fix.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("a library rename announces the change (= the cached fingerprint must not go stale)")
@MainActor
struct LibraryRenameAnnouncesTests {
    /// A library with one entity, = and a service that can rename it.
    private struct Fixture {
        let root: URL
        let service: SidebarService
        let store: FileSystemReferenceStore
        let referenceID: UUID
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-rename-announce-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)

        let store = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: store
        )
        let bookStore = BookStore(stores: stores)
        // The service is built WITHOUT a reload: = a reload sweeps the
        // cover library (= a side effect on the user's own covers).
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { [] },
            bookStore: bookStore
        )

        // One entity in the entities layer (= the layer the editor's
        // wiki-link fingerprint hashes).
        let reference = Reference(
            title: "Original Name",
            layer: .layerEntities,
            entityType: .character
        )
        try store.saveReference(reference, bodyMarkdown: "# Original Name\n\nbody\n")

        return Fixture(
            root: root,
            service: service,
            store: store,
            referenceID: reference.id
        )
    }

    @Test("renaming a reference changes the editor's wiki-link fingerprint")
    func renamingAReferenceChangesTheFingerprint() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let resolver = ReferenceLibraryWikiLinkResolver(
            referenceLibraryRoot: fixture.root.appendingPathComponent("reference-library")
        )

        LibraryContentFingerprint.invalidate()
        let before = resolver.fingerprint()

        // The production rename (= the sidebar's rename sheet and the
        // preview pane's rename sheet both call this).
        try fixture.service.renameReference(id: fixture.referenceID, newTitle: "Renamed Entity")

        let after = resolver.fingerprint()

        // ⇒ A renamed entity rewrote the index the fingerprint hashes,
        // = so the fingerprint MUST change: = the engine compares it
        // against its last one and only restyles the wiki-links when it
        // changed, = so a stale value here is a stale link label.
        #expect(after != before, "the wiki-link fingerprint went stale after a rename")
    }

    @Test("the rename announcement is what makes it visible (= the engine's restyle trigger)")
    func theAnnouncementIsWhatMakesItVisible() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let resolver = ReferenceLibraryWikiLinkResolver(
            referenceLibraryRoot: fixture.root.appendingPathComponent("reference-library")
        )

        LibraryContentFingerprint.invalidate()
        let before = resolver.fingerprint()

        // The rename WITHOUT the announcement: = the bytes on disk
        // change, = and the cached value does not. = ⇒ This is the
        // regression's shape, = stated as a fact about the cache.
        try fixture.store.replaceReference(
            Reference(
                id: fixture.referenceID,
                title: "Renamed Entity",
                layer: .layerEntities,
                entityType: .character
            ),
            bodyMarkdown: "# Renamed Entity\n\nbody\n"
        )
        let stale = resolver.fingerprint()
        #expect(stale == before, "without the announcement the cached value is stale")

        // ⇒ AND the announcement is what the app does: = with it, the
        // next read recomputes and the value moves.
        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
        let fresh = resolver.fingerprint()
        #expect(fresh != before, "the announcement must make the fingerprint move")
    }
}
