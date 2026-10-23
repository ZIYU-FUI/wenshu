//
//  CardCoverServiceTests.swift · Wenshu
//
//  Proves the cover service's cover RESOLUTION, without a real
//  library.
//
//  The tests use a throwaway library root, so nothing here can reach
//  the developer's own library.
//
//  The three things that matter:
//  - a card with a stored cover resolves to that file,
//  - a card with no cover resolves to nil,
//  - a cover whose file is gone resolves to nil (= the card falls
//    back to its gradient and symbol).
//
//  The last one is why the lookup goes through the FILES and not
//  through a separate record: a cover folder can hold a record whose
//  picture is not there any more, and a card whose picture was
//  deleted outside the app must not try to draw it.
//
//

import Foundation
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("Card cover service")
@MainActor
struct CardCoverServiceTests {

    /// A throwaway library root (= the .ws package the cover service
    /// resolves its directory against).
    private func makeLibraryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-cover-service-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A cover picture inside the throwaway library root.
    private func makeCover(in root: URL, key: String) throws -> (directory: URL, file: URL) {
        let directory = root
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("cover.heic")
        try Data([0x01, 0x02, 0x03]).write(to: file)
        return (directory, file)
    }

    @Test("A card with a stored cover resolves to its file")
    func resolvesAStoredCover() async throws {
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        let (_, file) = try makeCover(in: root, key: key)

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            #expect(service.coverImageURL(for: key) == file)
        }
    }

    @Test("A card with no cover resolves to nil")
    func resolvesNoCover() async throws {
        let root = try makeLibraryRoot()

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            #expect(service.coverImageURL(for: CardCoverService.key(forReference: UUID())) == nil)
        }
    }

    @Test("A cover whose file is gone resolves to nil")
    func resolvesAMissingFile() async throws {
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        let (_, file) = try makeCover(in: root, key: key)
        try FileManager.default.removeItem(at: file)

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            #expect(service.coverImageURL(for: key) == nil)
        }
    }

    @Test("A reference card and a book card resolve different covers")
    func resolvesPerCardKind() async throws {
        let root = try makeLibraryRoot()
        let id = UUID()
        let referenceKey = CardCoverService.key(forReference: id)
        let bookKey = CardCoverService.key(forBookDoc: id)
        let (_, file) = try makeCover(in: root, key: referenceKey)

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            // The book card has no cover of its own, so the reference
            // card's picture must not answer for it.
            #expect(service.coverImageURL(for: referenceKey) == file)
            #expect(service.coverImageURL(for: bookKey) == nil)
        }
    }

    @Test("A stored cover carries its record beside the picture")
    func theRecordTravelsWithThePicture() async throws {
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            try service.saveImage(
                Data([0x01, 0x02, 0x03]),
                forKey: key,
                kind: WSCardCoverKind.reference
            )

            // The record is a file in the library, beside the picture
            // it describes: a cover never depends on a store.
            let recordURL = CardCoverService.recordURL(forKey: key)
            #expect(recordURL != nil)
            #expect(FileManager.default.fileExists(atPath: recordURL!.path))

            let record = service.record(forKey: key)
            #expect(record?.status == WSCardCoverStatus.staticReady)
            #expect(record?.cardKind == WSCardCoverKind.reference)
        }
    }

    @Test("A cover resolves the same way on every read")
    func theLookupIsStable() async throws {
        let root = try makeLibraryRoot()
        let key = CardCoverService.key(forReference: UUID())
        let (_, file) = try makeCover(in: root, key: key)

        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            // The grid asks about a card on every render, so the
            // answer must not depend on how often it was asked.
            let first = service.coverImageURL(for: key)
            let second = service.coverImageURL(for: key)
            #expect(first == second)
            #expect(first == file)
        }
    }
}
