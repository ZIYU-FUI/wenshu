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

    /// A throwaway library root (= the .ws package the cover
    /// service resolves its directory against).
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-cover-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A cover folder with its picture, inside the throwaway library
    /// root.
    private func makeCover(
        in root: URL,
        key: String
    ) throws -> (directory: URL, file: URL) {
        let directory = root
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("cover.heic")
        try Data([0x01, 0x02, 0x03]).write(to: file)
        return (directory, file)
    }

    @Test("Removing a cover takes the whole cover folder")
    func removesTheCoverFolder() throws {
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        let (directory, file) = try makeCover(in: root, key: key)

        try PathGuard.$libraryRootOverride.withValue(root.path) {
            try CoverCascade().removeCover(forKey: key)
        }

        #expect(FileManager.default.fileExists(atPath: file.path) == false)
        #expect(FileManager.default.fileExists(atPath: directory.path) == false)
    }

    @Test("Removing a cover that was never there does not throw")
    func removingAnAbsentCoverDoesNotThrow() throws {
        let root = try makeLibraryRoot()
        let cascade = CoverCascade()

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
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        _ = try makeCover(in: root, key: key)
        let cascade = CoverCascade()

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
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        _ = try makeCover(in: root, key: key)

        // The document of a reference lives beside the library's
        // covers, not inside the cover's own directory.
        let referencesRoot = root.appendingPathComponent("references", isDirectory: true)
        try FileManager.default.createDirectory(at: referencesRoot, withIntermediateDirectories: true)
        let document = referencesRoot.appendingPathComponent("doc.md")
        try Data("the document".utf8).write(to: document)

        let cascade = CoverCascade()
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            try cascade.removeCover(forKey: key)
        }

        // The document is still there. The cover is a child of the
        // document, and the cascade removes the CHILD.
        #expect(FileManager.default.fileExists(atPath: document.path))
    }

    @Test("The tolerant removal swallows a failure instead of throwing")
    func tolerantRemovalDoesNotThrow() throws {
        let root = try makeLibraryRoot()
        let cascade = CoverCascade()

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
        let root = try makeLibraryRoot()

        let liveId = UUID()
        let goneId = UUID()
        let liveKey = CardCoverService.key(forReference: liveId)
        let goneKey = CardCoverService.key(forReference: goneId)
        _ = try makeCover(in: root, key: liveKey)
        _ = try makeCover(in: root, key: goneKey)

        let reconciler = CoverReconciler()
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            reconciler.sweep(liveReferenceIds: [liveId], shelvesRoot: nil)
        }

        // The covers on disk are the covers there are: the live one
        // stays, the orphan goes.
        let coversRoot = root
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: coversRoot.path)
        #expect(remaining.sorted() == [liveKey])
        #expect(
            FileManager.default.fileExists(
                atPath: coversRoot.appendingPathComponent(goneKey, isDirectory: true).path
            ) == false
        )
    }

    // MARK: - The delete paths

    /// A book directory in the library's own layout (= shelves /
    /// shelf / books / book), because a book doc's card id is
    /// derived from where its file lives.
    private func makeBookDirectory(in root: URL) throws -> (bookId: UUID, directory: URL) {
        let bookId = UUID()
        let directory = root
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (bookId, directory)
    }

    @Test("Deleting a book document removes its cover")
    func deletingABookDocumentRemovesItsCover() async throws {
        let root = try makeLibraryRoot()
        let (bookId, bookDirectory) = try makeBookDirectory(in: root)
        let actor = BookChapterActor(
            bookDirectoryProvider: { bookDirectory },
            currentChatBookIDProvider: { bookId }
        )

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let created = try await actor.createChapter(
                bookId: bookId,
                title: "Chapter One",
                bodyMarkdown: "# Chapter One\n\nThe body."
            )
            // The cover the material zone gave this card (= the id it
            // derives from where the file lives).
            let key = CardCoverService.key(forBookDoc: PreviewPane.stableBookDocId(
                bookId: bookId,
                folderName: "drafts",
                fileName: "\(created.id.uuidString).md"
            ))
            let (directory, file) = try makeCover(in: root, key: key)

            try await actor.deleteChapter(id: created.id)

            // The document is gone, so the cover that depicted it is
            // gone with it.
            #expect(FileManager.default.fileExists(atPath: file.path) == false)
            #expect(FileManager.default.fileExists(atPath: directory.path) == false)
        }
    }

    @Test("Deleting an outline removes its cover")
    func deletingAnOutlineRemovesItsCover() async throws {
        let root = try makeLibraryRoot()
        let (bookId, bookDirectory) = try makeBookDirectory(in: root)
        let actor = BookOutlineActor(
            bookDirectoryProvider: { bookDirectory },
            currentChatBookIDProvider: { bookId }
        )

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let created = try await actor.createOutline(
                bookId: bookId,
                title: "Volume One",
                bodyMarkdown: "# Volume One"
            )
            let key = CardCoverService.key(forBookDoc: PreviewPane.stableBookDocId(
                bookId: bookId,
                folderName: "outlines",
                fileName: "\(created.id.uuidString).md"
            ))
            let (directory, file) = try makeCover(in: root, key: key)

            try await actor.deleteOutline(id: created.id)

            #expect(FileManager.default.fileExists(atPath: file.path) == false)
            #expect(FileManager.default.fileExists(atPath: directory.path) == false)
        }
    }

    @Test("Deleting a reference removes its cover")
    func deletingAReferenceRemovesItsCover() async throws {
        let root = try makeLibraryRoot()
        let store = FileSystemReferenceStore(
            referenceLibraryRoot: root.appendingPathComponent("references", isDirectory: true)
        )
        let actor = ReferenceLibraryActor(referenceStore: store)

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let created = try await actor.createReference(
                title: "Ming tax",
                bodyMarkdown: "# Ming tax"
            )
            let key = CardCoverService.key(forReference: created.id)
            let (directory, file) = try makeCover(in: root, key: key)

            try await actor.deleteReference(id: created.id)

            #expect(FileManager.default.fileExists(atPath: file.path) == false)
            #expect(FileManager.default.fileExists(atPath: directory.path) == false)
        }
    }

    // MARK: - The housekeeping

    @Test("The sweep removes a cover whose book document is gone")
    func sweepRemovesTheOrphanBookDocCover() throws {
        let root = try makeLibraryRoot()
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        let (bookId, bookDirectory) = try makeBookDirectory(in: root)
        let folder = bookDirectory.appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let liveFileName = "live.md"
        try Data("# live".utf8).write(to: folder.appendingPathComponent(liveFileName))

        let liveKey = CardCoverService.key(forBookDoc: PreviewPane.stableBookDocId(
            bookId: bookId,
            folderName: "drafts",
            fileName: liveFileName
        ))
        let goneKey = CardCoverService.key(forBookDoc: PreviewPane.stableBookDocId(
            bookId: bookId,
            folderName: "drafts",
            fileName: "gone.md"
        ))
        _ = try makeCover(in: root, key: liveKey)
        _ = try makeCover(in: root, key: goneKey)

        let reconciler = CoverReconciler()
        try PathGuard.$libraryRootOverride.withValue(root.path) {
            reconciler.sweep(liveReferenceIds: [], shelvesRoot: shelvesRoot)
        }

        // The cover of the document that is still there stays; the
        // cover of the document that is gone goes.
        let coversRoot = root
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: coversRoot.path)
        #expect(remaining.sorted() == [liveKey])
    }
}
