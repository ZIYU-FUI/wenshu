//
//  CoverBatchServiceTests.swift · Wenshu
//
//  Proves the batch's rules WITHOUT a network call.
//
//  The generation goes behind the same injectable seam the single-card
//  generation uses, so the batch can be tested in isolation.
//
//  The rules:
//  - the batch makes one call per document, SEQUENTIALLY (= at most
//    one in flight at any moment), never a burst,
//  - a document that already has a cover is skipped,
//  - a failure on one document does not stop the batch, and the
//    document is tried again on the next run,
//  - the stop takes effect at the next document boundary,
//  - the batch and the card menu share ONE per-card lock,
//  - the batch stops when the run is cancelled.
//

import AppKit
import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

/// A stub that counts the calls and tracks concurrency.
private final class CountingImageClient: CoverImageClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private var _maxConcurrent = 0
    private var _concurrent = 0

    var callCount: Int { lock.withLock { _callCount } }
    var maxConcurrent: Int { lock.withLock { _maxConcurrent } }

    /// The subjects the batch asked for, in order.
    private(set) var subjects: [String] = []

    /// Whether the call should fail.
    var shouldFail = false

    /// Called after each request, so a test can stop the run in the
    /// middle.
    var afterRequest: (() -> Void)?

    func generateCover(subject: String) async throws -> Data {
        lock.withLock {
            _callCount += 1
            _concurrent += 1
            _maxConcurrent = max(_maxConcurrent, _concurrent)
            subjects.append(subject)
        }
        // A short yield, so a concurrent call would overlap.
        await Task.yield()
        lock.withLock { _concurrent -= 1 }

        afterRequest?()

        if shouldFail {
            throw CoverImageError.noImage
        }
        return Self.sampleJPEG
    }

    /// A tiny valid JPEG, because the service DECODES the bytes before
    /// it encodes the banner.
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

@Suite("Cover batch service")
@MainActor
struct CoverBatchServiceTests {

    /// A throwaway library root, so the cover directory resolves and
    /// the test never touches the developer's own library.
    private static let libraryRoot = URL(fileURLWithPath: "/tmp")
        .resolvingSymlinksInPath().path

    /// An in-memory container.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WSCardCover.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Five documents with no covers.
    private func makeItems(count: Int) -> [CoverCandidate] {
        (0..<count).map { index in
            CoverCandidate(
                target: .reference(UUID()),
                subject: "Document \(index)",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }

    @Test("The batch makes one call per document, and never in parallel")
    func theBatchIsSequential() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSequentialCheck()
        }
    }

    /// The body of the sequential test, inside the library root scope.
    private func runSequentialCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        await service.run(for: makeItems(count: 5))

        #expect(client.callCount == 5)
        // The important property: never more than one in flight.
        #expect(client.maxConcurrent == 1)
    }

    @Test("A document that already has a cover is skipped")
    func aCoveredDocumentIsSkipped() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSkipCheck()
        }
    }

    /// The body of the skip test, inside the library root scope.
    private func runSkipCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        let items = makeItems(count: 3)
        // The middle one already has a cover.
        let coverService = CardCoverService()
        try coverService.saveImage(
            Data([0x01]),
            forKey: items[1].target.coverKey,
            kind: items[1].target.kind
        )

        await service.run(for: items)

        #expect(client.callCount == 2)
        #expect(service.progress.skipped == 1)
        #expect(service.progress.completed == 2)
    }

    @Test("A failure on one document does not stop the batch")
    func aFailureDoesNotStopTheBatch() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runFailureCheck()
        }
    }

    /// The body of the failure test, inside the library root scope.
    private func runFailureCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        client.shouldFail = true
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        await service.run(for: makeItems(count: 3))

        // Every document was ATTEMPTED, and every one failed.
        #expect(client.callCount == 3)
        #expect(service.progress.failed == 3)
        #expect(service.progress.completed == 0)
    }

    @Test("The stop takes effect at the next document boundary")
    func theStopTakesEffectAtTheNextBoundary() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runStopCheck()
        }
    }

    /// The body of the stop test, inside the library root scope.
    private func runStopCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        // Stop AFTER the first request: the run must finish the
        // document it is on and then stop, rather than cutting it off
        // mid-generation.
        client.afterRequest = { service.stop() }

        await service.run(for: makeItems(count: 3))

        // One document was made, and the run stopped at the next
        // boundary.
        #expect(client.callCount == 1)
        #expect(service.progress.isStopped)
        #expect(service.progress.completed == 1)
    }

    @Test("A document that failed is tried again on the next run")
    func aFailedDocumentIsRetriedOnTheNextRun() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runRetryCheck()
        }
    }

    /// The body of the retry test, inside the library root scope.
    private func runRetryCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        client.shouldFail = true
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        let items = makeItems(count: 1)
        await service.run(for: items)
        #expect(service.progress.failed == 1)

        // The second run tries the same document again: a failure
        // does not skip a document forever.
        client.shouldFail = false
        await service.run(for: items)
        #expect(client.callCount == 2)
        #expect(service.progress.completed == 1)
    }

    @Test("The run stops when it is cancelled")
    func cancellationStopsTheRun() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runCancellationCheck()
        }
    }

    /// The body of the cancellation test, inside the library root
    /// scope.
    private func runCancellationCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        let generation = CoverGenerationService(
            imageClient: client
        )
        let service = CoverBatchService(
            generationService: generation
        )

        // Cancel AFTER the first request: the run must finish the
        // document it is on and then stop, because the cancellation is
        // checked BETWEEN documents.
        client.afterRequest = { service.cancel() }

        await service.run(for: makeItems(count: 3))

        #expect(client.callCount == 1)
        #expect(service.progress.completed == 1)
        #expect(service.progress.isStopped)
    }

    @Test("The batch and the card menu share ONE per-card lock")
    func theBatchAndTheCardMenuShareOneLock() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSharedLockCheck()
        }
    }

    /// The body of the shared-lock test, inside the library root
    /// scope.
    private func runSharedLockCheck() async throws {
        let container = try makeContainer()
        let client = CountingImageClient()
        // ONE holder, so the batch and the card menu share the same
        // generation service and therefore the same per-card lock.
        let services = CoverPaneServices(
            imageClient: client
        )

        let items = makeItems(count: 1)
        let target = items[0].target

        // The batch starts on the card, and the card menu asks for the
        // same card while it is in flight.
        client.afterRequest = {
            Task { @MainActor in
                await services.generation.generateCover(for: target, subject: "Document 0")
            }
        }
        await services.batch.run(for: items)

        // The second request found the card in flight, so ONE image
        // call was made for the two of them.
        #expect(client.callCount == 1)
    }
}
