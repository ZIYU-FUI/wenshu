//
//  CardCoverServiceTests.swift · Wenshu
//
//  Proves the cover service's cover RESOLUTION, without a real
//  library.
//
//  The tests use an in-memory SwiftData container and a throwaway
//  directory, so nothing here can reach the developer's own library.
//
//  The three things that matter:
//  - a card with a stored cover resolves to that file,
//  - a card with no cover row resolves to nil,
//  - a cover whose file is gone resolves to nil (= the card falls
//    back to its gradient and symbol).
//
//  The last one is why the lookup goes through the ROW and not
//  through the directory layout: a row can point at a file that is
//  not there any more, and a card whose picture was deleted outside
//  the app must not try to draw it.
//

import Foundation
import SwiftData
import Testing
import WenshuData
@testable import WenshuApp

@Suite("Card cover service")
@MainActor
struct CardCoverServiceTests {

    /// An in-memory container holding the cover rows.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WSCardCover.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A cover row whose file exists, in a throwaway directory.
    private func makeCover(in container: ModelContainer, key: String) throws -> (row: WSCardCover, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-cover-service-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("cover.heic")
        try Data([0x01, 0x02, 0x03]).write(to: file)

        let row = WSCardCover(
            id: key,
            cardKind: WSCardCoverKind.reference,
            imagePath: file.path,
            status: WSCardCoverStatus.staticReady
        )
        container.mainContext.insert(row)
        try container.mainContext.save()
        return (row, file)
    }

    @Test("A card with a stored cover resolves to its file")
    func resolvesAStoredCover() throws {
        let container = try makeContainer()
        let key = CardCoverService.key(forReference: UUID())
        let (_, file) = try makeCover(in: container, key: key)

        let service = CardCoverService(modelContext: container.mainContext)

        #expect(service.coverImageURL(for: key) == file)
    }

    @Test("A card with no cover resolves to nil")
    func resolvesNoCover() throws {
        let container = try makeContainer()
        let service = CardCoverService(modelContext: container.mainContext)

        #expect(service.coverImageURL(for: CardCoverService.key(forReference: UUID())) == nil)
    }

    @Test("A cover whose file is gone resolves to nil")
    func resolvesAMissingFile() throws {
        let container = try makeContainer()
        let key = CardCoverService.key(forReference: UUID())
        let (_, file) = try makeCover(in: container, key: key)
        try FileManager.default.removeItem(at: file)

        let service = CardCoverService(modelContext: container.mainContext)

        #expect(service.coverImageURL(for: key) == nil)
    }

    @Test("A reference card and a book card resolve different covers")
    func resolvesPerCardKind() throws {
        let container = try makeContainer()
        let id = UUID()
        let referenceKey = CardCoverService.key(forReference: id)
        let bookKey = CardCoverService.key(forBookDoc: id)
        let (_, file) = try makeCover(in: container, key: referenceKey)

        let service = CardCoverService(modelContext: container.mainContext)

        // The book card has no cover of its own, so the reference
        // card's picture must not answer for it.
        #expect(service.coverImageURL(for: referenceKey) == file)
        #expect(service.coverImageURL(for: bookKey) == nil)
    }
}
