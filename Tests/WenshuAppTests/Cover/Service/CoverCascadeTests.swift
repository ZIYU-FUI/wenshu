//
//  CoverCascadeTests.swift · Wenshu
//
//  Proves the cover is a CHILD of its document, without touching a
//  real library.
//
//  The tests use an in-memory SwiftData container and a throwaway
//  directory, so nothing here can reach the developer's own library.
//
//  The four things that matter:
//  - removing a cover takes the row AND the files,
//  - removing a cover that was never there does NOT throw (= a
//    document delete must never fail because of a cover),
//  - removing a cover twice does NOT throw,
//  - the cascade NEVER touches the document.
//

import Foundation
import SwiftData
import Testing
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

    /// A cover row plus its file, in a throwaway directory.
    private func makeCover(
        in container: ModelContainer,
        key: String
    ) throws -> (row: WSCardCover, file: URL) {
        let context = container.mainContext
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-covers-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("cover.heic")
        try Data([0x01, 0x02, 0x03]).write(to: file)

        let row = WSCardCover(
            id: key,
            cardKind: WSCardCoverKind.reference,
            imagePath: file.path,
            status: WSCardCoverStatus.staticReady
        )
        context.insert(row)
        try context.save()
        return (row, file)
    }

    @Test("Removing a cover takes the row and the files")
    func removesRowAndFiles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let key = "reference-\(UUID().uuidString)"
        let (row, file) = try makeCover(in: container, key: key)

        let cascade = CoverCascade(modelContext: context)
        try cascade.removeCover(forKey: key)

        let remaining = try context.fetch(FetchDescriptor<WSCardCover>())
        #expect(remaining.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
        _ = row
    }

    @Test("Removing a cover that was never there does not throw")
    func removingAnAbsentCoverDoesNotThrow() throws {
        let container = try makeContainer()
        let cascade = CoverCascade(modelContext: container.mainContext)

        // A document delete must never fail because of a cover.
        var threw = false
        do {
            try cascade.removeCover(forKey: "reference-does-not-exist")
        } catch {
            threw = true
        }
        #expect(threw == false)
    }

    @Test("Removing a cover twice does not throw")
    func removingTwiceDoesNotThrow() throws {
        let container = try makeContainer()
        let key = "reference-\(UUID().uuidString)"
        _ = try makeCover(in: container, key: key)
        let cascade = CoverCascade(modelContext: container.mainContext)

        try cascade.removeCover(forKey: key)
        var threw = false
        do {
            try cascade.removeCover(forKey: key)
        } catch {
            threw = true
        }
        #expect(threw == false)
    }

    @Test("The cascade never deletes the document")
    func neverDeletesTheDocument() throws {
        let container = try makeContainer()
        let key = "reference-\(UUID().uuidString)"
        let (_, file) = try makeCover(in: container, key: key)

        // The .md file sitting next to the cover, as a real library
        // has it.
        let document = file.deletingLastPathComponent().appendingPathComponent("doc.md")
        try Data("the document".utf8).write(to: document)

        let cascade = CoverCascade(modelContext: container.mainContext)
        try cascade.removeCover(forKey: key)

        // The document is still there. The cover is a child of the
        // document, and the cascade removes the CHILD.
        #expect(FileManager.default.fileExists(atPath: document.path))
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
    }

    @Test("The tolerant removal swallows a failure instead of throwing")
    func tolerantRemovalDoesNotThrow() throws {
        let container = try makeContainer()
        let cascade = CoverCascade(modelContext: container.mainContext)

        // No cover, no row, no file: the tolerant path must still be
        // silent.
        cascade.removeCoverTolerantly(forKey: "reference-nothing-here")
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
}
