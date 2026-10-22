//
//  CoverCascadeTests.swift · Wenshu
//
//  Proves the cover is a CHILD of its document, without touching a
//  real library.
//
//  The tests use an in-memory SwiftData container and a throwaway
//  library root, so nothing here can reach the developer's own
//  library. The root is pinned with the library-root override, so
//  the cover service resolves its directory inside the throwaway
//  root rather than the real one.
//
//  The four things that matter:
//  - removing a cover takes the row AND the files,
//  - removing a cover that was never there does NOT throw (= a
//    document delete must never fail because of a cover),
//  - removing a cover twice does NOT throw,
//  - the cascade NEVER touches the document.
//
//

import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("Cover cascade")
@MainActor
struct CoverCascadeTests {

    /// An in-memory container holding the cover rows.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WSCardCover.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A throwaway library root (= the .ws package the cover
    /// service resolves its directory against).
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-cover-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A cover row plus its file, inside the throwaway library root.
    private func makeCover(
        in container: ModelContainer,
        root: URL,
        key: String
    ) throws -> (row: WSCardCover, directory: URL, file: URL) {
        let directory = root
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("cover.heic")
        try Data([0x01, 0x02, 0x03]).write(to: file)

        let row = WSCardCover(
            id: key,
            cardKind: WSCardCoverKind.reference,
            imagePath: file.path,
            status: WSCardCoverStatus.staticReady
        )
        let context = container.mainContext
        context.insert(row)
        try context.save()
        return (row, directory, file)
    }

    @Test("Removing a cover takes the row and the files")
    func removesRowAndFiles() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        let (_, directory, file) = try makeCover(in: container, root: root, key: key)
        let context = container.mainContext

        try PathGuard.$libraryRootOverride.withValue(root.path) {
            try CoverCascade(modelContext: context).removeCover(forKey: key)
        }

        let remaining = try context.fetch(FetchDescriptor<WSCardCover>())
        #expect(remaining.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
        #expect(FileManager.default.fileExists(atPath: directory.path) == false)
    }

    @Test("Removing a cover that was never there does not throw")
    func removingAnAbsentCoverDoesNotThrow() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let cascade = CoverCascade(modelContext: container.mainContext)

        // A document delete must never fail because of a cover.
        var threw = false
        do {
            try PathGuard.$libraryRootOverride.withValue(root.path) {
                try cascade.removeCover(forKey: CardCoverService.key(forReference: UUID()))
            }
        } catch {
            threw = true
        }
        #expect(threw == false)
    }

    @Test("Removing a cover twice does not throw")
    func removingTwiceDoesNotThrow() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        _ = try makeCover(in: container, root: root, key: key)
        let cascade = CoverCascade(modelContext: container.mainContext)

        var threw = false
        do {
            try PathGuard.$libraryRootOverride.withValue(root.path) {
                try cascade.removeCover(forKey: key)
                try cascade.removeCover(forKey: key)
            }
        } catch {
            threw = true
        }
        #expect(threw == false)
    }

    @Test("The cascade never deletes the document")
    func neverDeletesTheDocument() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        _ = try makeCover(in: container, root: root, key: key)

        // The document of a reference lives beside the library's
        // covers, not inside the cover's own directory.
        let referencesRoot = root.appendingPathComponent("references", isDirectory: true)
        try FileManager.default.createDirectory(at: referencesRoot, withIntermediateDirectories: true)
        let document = referencesRoot.appendingPathComponent("doc.md")
        try Data("the document".utf8).write(to: document)

        let cascade = CoverCascade(modelContext: container.mainContext)
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            try cascade.removeCover(forKey: key)
        }

        // The document is still there. The cover is a child of the
        // document, and the cascade removes the CHILD.
        #expect(FileManager.default.fileExists(atPath: document.path))
    }

    @Test("The tolerant removal swallows a failure instead of throwing")
    func tolerantRemovalDoesNotThrow() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let cascade = CoverCascade(modelContext: container.mainContext)

        // No cover, no row, no file: the tolerant path must still be
        // silent.
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            cascade.removeCoverTolerantly(forKey: CardCoverService.key(forReference: UUID()))
        }
    }

    @Test("The reconciler finds a cover whose card is gone")
    func reconcilerFindsOrphans() {
        let live = Set(["reference-a", "reference-b"])
        let covers = Set(["reference-a", "reference-b", "reference-gone"])

        let orphans = CoverReconciler.orphanKeys(liveCardKeys: live, coverKeys: covers)

        #expect(orphans == Set(["reference-gone"]))
    }

    @Test("The reconciler leaves a cover whose card is alive")
    func reconcilerKeepsLiveCovers() {
        let live = Set(["reference-a", "reference-b"])
        let covers = Set(["reference-a", "reference-b"])

        #expect(CoverReconciler.orphanKeys(liveCardKeys: live, coverKeys: covers).isEmpty)
    }

    @Test("The sweep removes the orphan cover and keeps the live one")
    func sweepRemovesOnlyTheOrphan() throws {
        let container = try makeContainer()
        let root = try makeLibraryRoot()
        let context = container.mainContext

        let liveId = UUID()
        let goneId = UUID()
        let liveKey = CardCoverService.key(forReference: liveId)
        let goneKey = CardCoverService.key(forReference: goneId)
        _ = try makeCover(in: container, root: root, key: liveKey)
        _ = try makeCover(in: container, root: root, key: goneKey)

        let reconciler = CoverReconciler(modelContext: context)
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            reconciler.sweep(liveReferenceIds: [liveId], shelvesRoot: nil)
        }

        let remaining = try context.fetch(FetchDescriptor<WSCardCover>())
        #expect(remaining.map(\.id) == [liveKey])
        #expect(
            FileManager.default.fileExists(
                atPath: root
                    .appendingPathComponent("assets", isDirectory: true)
                    .appendingPathComponent("covers", isDirectory: true)
                    .appendingPathComponent(goneKey, isDirectory: true)
                    .path
            ) == false
        )
    }
}
