//
//  CoverAutoTriggerTests.swift · Wenshu
//
//  Proves the AUTOMATIC pass: the documents that arrive later get
//  their covers on their own.
//
//  The test that matters is the second one: a document that existed
//  BEFORE the switch was turned on gets NO automatic cover, because
//  it belongs to the batch. That distinction is the user's rule, and
//  it is invisible in the UI: without it, turning the switch on
//  would quietly spend the image allowance on the whole library.
//
//  The trigger is asked about a document and the policy decides, so
//  the test drives the trigger the way the app does.
//
//

import AppKit
import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

/// A stub that counts the calls.
private final class TriggerStubImageClient: CoverImageClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int { lock.withLock { _callCount } }

    func generateCover(subject: String) async throws -> Data {
        lock.withLock { _callCount += 1 }
        await Task.yield()
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

/// A stub that keeps the policy in memory, so the test never writes
/// to the developer's own defaults.
private func stubPolicy(
    _ policy: CoverAutoCoverPolicy
) -> () -> CoverAutoCoverPolicy {
    { policy }
}

@Suite("Cover auto trigger")
@MainActor
struct CoverAutoTriggerTests {

    /// A throwaway library root, so the cover directory resolves and
    /// the test never touches the developer's own library.
    private static let libraryRoot = URL(fileURLWithPath: "/tmp")
        .resolvingSymlinksInPath().path

    /// A fixed "now" for the tests.
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// An in-memory container.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WSCardCover.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A trigger over the given policy, with a counting image client.
    private func makeTrigger(
        container: ModelContainer,
        policy: CoverAutoCoverPolicy
    ) -> (CoverAutoTrigger, TriggerStubImageClient) {
        let client = TriggerStubImageClient()
        let trigger = CoverAutoTrigger(
            generationService: CoverGenerationService(
            imageClient: client,
            motifExtractor: StubMotifExtractor()
            ),
            policyProvider: stubPolicy(policy)
        )
        return (trigger, client)
    }

    @Test("A document created AFTER the switch gets a cover on its own")
    func aDocumentFromAfterTheSwitchGetsACover() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runAfterTheSwitchCheck()
        }
    }

    /// The body of the after-the-switch test, inside the library root
    /// scope.
    private func runAfterTheSwitchCheck() async throws {
        let container = try makeContainer()
        let (trigger, client) = makeTrigger(
            container: container,
            policy: .enabling(at: Self.now)
        )

        let started = await trigger.coverIfNeeded(
            for: .reference(UUID()),
            title: "A lighthouse",
            summary: "On a cliff",
            createdAt: Self.now.addingTimeInterval(1),
            now: Self.now
        )

        #expect(started)
        #expect(client.callCount == 1)
    }

    @Test("A document created BEFORE the switch gets NO cover")
    func aDocumentFromBeforeTheSwitchGetsNoCover() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runBeforeTheSwitchCheck()
        }
    }

    /// The body of the before-the-switch test, inside the library
    /// root scope.
    private func runBeforeTheSwitchCheck() async throws {
        let container = try makeContainer()
        let (trigger, client) = makeTrigger(
            container: container,
            policy: .enabling(at: Self.now)
        )

        let started = await trigger.coverIfNeeded(
            for: .reference(UUID()),
            title: "A lighthouse",
            summary: "On a cliff",
            createdAt: Self.now.addingTimeInterval(-3600),
            now: Self.now
        )

        #expect(started == false)
        #expect(client.callCount == 0)
    }

    @Test("The switch off means NO cover")
    func theSwitchOffMeansNoCover() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSwitchOffCheck()
        }
    }

    /// The body of the switch-off test, inside the library root
    /// scope.
    private func runSwitchOffCheck() async throws {
        let container = try makeContainer()
        let (trigger, client) = makeTrigger(
            container: container,
            policy: .disabled
        )

        let started = await trigger.coverIfNeeded(
            for: .reference(UUID()),
            title: "A lighthouse",
            summary: "On a cliff",
            createdAt: Self.now.addingTimeInterval(1),
            now: Self.now
        )

        #expect(started == false)
        #expect(client.callCount == 0)
    }

    @Test("The trigger does not fire twice for the same document")
    func theTriggerDoesNotFireTwice() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runNoDoubleFireCheck()
        }
    }

    /// The body of the no-double-fire test, inside the library root
    /// scope.
    private func runNoDoubleFireCheck() async throws {
        let container = try makeContainer()
        let (trigger, client) = makeTrigger(
            container: container,
            policy: .enabling(at: Self.now)
        )
        let target = CardCoverTarget.reference(UUID())

        let first = await trigger.coverIfNeeded(
            for: target,
            title: "A lighthouse",
            summary: "On a cliff",
            createdAt: Self.now.addingTimeInterval(1),
            now: Self.now
        )
        let second = await trigger.coverIfNeeded(
            for: target,
            title: "A lighthouse",
            summary: "On a cliff",
            createdAt: Self.now.addingTimeInterval(1),
            now: Self.now
        )

        #expect(first)
        #expect(second == false)
        #expect(client.callCount == 1)
    }

    @Test("The sweep covers only the documents the policy approves")
    func theSweepCoversOnlyTheApprovedDocuments() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runSweepCheck()
        }
    }

    /// The body of the sweep test, inside the library root scope.
    private func runSweepCheck() async throws {
        let container = try makeContainer()
        let (trigger, client) = makeTrigger(
            container: container,
            policy: .enabling(at: Self.now)
        )

        // One document from AFTER the switch, and one from BEFORE it.
        // The sweep is what the material zone calls, so this is the
        // shape it sees.
        let candidates = [
            CoverCandidate(
                target: .reference(UUID()),
                title: "A new document",
                summary: "It just arrived",
                createdAt: Self.now.addingTimeInterval(1)
            ),
            CoverCandidate(
                target: .bookDoc(UUID()),
                title: "An old document",
                summary: "It was here already",
                createdAt: Self.now.addingTimeInterval(-3600)
            )
        ]

        let started = await trigger.coverNewDocuments(candidates, now: Self.now)

        // Only the new document got a cover.
        #expect(started == 1)
        #expect(client.callCount == 1)
    }
}
