//
//  CoverGenerationServiceTests.swift · Wenshu
//
//  Proves the generation service WITHOUT a network call.
//
//  The image call goes behind a protocol, so the test replaces it with
//  a stub. The three rules the service enforces are the ones a user
//  would notice:
//
//  - a successful generation saves a banner and marks the card ready,
//  - a FAILED generation leaves the previous picture in place, because
//    the user liked that picture,
//  - two concurrent generations for one card make ONE call, because
//    the second would spend the image allowance for nothing.
//

import AppKit
import Foundation
import SwiftData
import WenshuAgent
import Testing
import WenshuData
@testable import WenshuApp

/// A stub that counts the calls and can be told to fail.
private final class StubImageClient: CoverImageClient, @unchecked Sendable {
    var callCount = 0
    var shouldFail = false
    var lastPrompt: String?

    func generateCover(subject: String) async throws -> Data {
        callCount += 1
        lastPrompt = subject
        if shouldFail {
            throw CoverImageError.noImage
        }
        // A one-pixel JPEG is enough: the service only cares that the
        // bytes decode.
        return Self.sampleJPEG
    }

    /// A tiny valid JPEG.
    static let sampleJPEG: Data = {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [:]) else {
            return Data()
        }
        return jpeg
    }()
}

@Suite("Cover generation service")
@MainActor
struct CoverGenerationServiceTests {

    /// An in-memory container.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WSCardCover.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A throwaway library root, so the cover directory resolves and
    /// the test never touches the developer's own library.
    private static let libraryRoot = URL(fileURLWithPath: "/tmp")
        .resolvingSymlinksInPath().path

    @Test("A successful generation saves a banner and marks the card ready")
    func successfulGenerationSavesTheBanner() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSuccessfulGeneration()
        }
    }

    /// The body of the successful-generation test, inside the library
    /// root scope.
    private func runSuccessfulGeneration() async throws {
        let container = try makeContainer()
        let client = StubImageClient()
        let service = CoverGenerationService(
            imageClient: client,
            motifExtractor: StubMotifExtractor()
        )
        let target = CardCoverTarget.reference(UUID())

        await service.generateCover(for: target, title: "A lighthouse", summary: "On a cliff")

        #expect(client.callCount == 1)
        let record = service.coverRecord(for: target)
        #expect(record?.status == WSCardCoverStatus.staticReady)
        // The picture is the source of truth: a card has a cover when
        // its file is there.
        let picture = CardCoverService().coverImageURL(for: target.coverKey)
        #expect(picture != nil)
        #expect(FileManager.default.fileExists(atPath: picture!.path))
    }

    @Test("A failed generation leaves the previous picture in place")
    func failedGenerationKeepsThePreviousPicture() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runFailedGeneration()
        }
    }

    /// The body of the failed-generation test, inside the library root
    /// scope.
    private func runFailedGeneration() async throws {
        let container = try makeContainer()
        let client = StubImageClient()
        let service = CoverGenerationService(
            imageClient: client,
            motifExtractor: StubMotifExtractor()
        )
        let target = CardCoverTarget.reference(UUID())

        // One good generation, so there IS a picture.
        await service.generateCover(for: target, title: "A lighthouse", summary: "On a cliff")
        let goodPath = CardCoverService().coverImageURL(for: target.coverKey)?.path
        #expect(goodPath != nil)

        // Now a failing one.
        client.shouldFail = true
        await service.generateCover(for: target, title: "A lighthouse", summary: "On a cliff")

        let record = service.coverRecord(for: target)
        #expect(record?.status == WSCardCoverStatus.failed)
        // The picture the user liked is still there.
        #expect(CardCoverService().coverImageURL(for: target.coverKey)?.path == goodPath)
        #expect(record?.lastError != nil)
    }

    @Test("Two concurrent generations for one card make ONE call")
    func concurrentGenerationsMakeOneCall() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runConcurrentGenerations()
        }
    }

    /// The body of the concurrency test, inside the library root
    /// scope.
    private func runConcurrentGenerations() async throws {
        let container = try makeContainer()
        let client = StubImageClient()
        let service = CoverGenerationService(
            imageClient: client,
            motifExtractor: StubMotifExtractor()
        )
        let target = CardCoverTarget.reference(UUID())

        async let first: Void = service.generateCover(
            for: target, title: "A lighthouse", summary: "On a cliff"
        )
        async let second: Void = service.generateCover(
            for: target, title: "A lighthouse", summary: "On a cliff"
        )
        _ = await (first, second)

        #expect(client.callCount == 1)
    }

    @Test("The prompt the model receives starts with the art direction")
    func thePromptCarriesTheArtDirection() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runPromptCheck()
        }
    }

    /// The body of the prompt test, inside the library root scope.
    private func runPromptCheck() async throws {
        let container = try makeContainer()
        let client = StubImageClient()
        let service = CoverGenerationService(
            imageClient: client,
            motifExtractor: StubMotifExtractor()
        )
        let target = CardCoverTarget.reference(UUID())

        await service.generateCover(for: target, title: "A lighthouse", summary: "On a cliff")

        #expect(client.lastPrompt?.hasPrefix("插画设计，纯白背景上的立体插画") == true)
        #expect(client.lastPrompt?.contains("A lighthouse") == true)
        #expect(client.lastPrompt?.contains("礁灯") == true)
    }
}
