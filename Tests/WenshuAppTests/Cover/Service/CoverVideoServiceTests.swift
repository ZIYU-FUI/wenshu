//
//  CoverVideoServiceTests.swift · Wenshu
//
//  Proves the video rules WITHOUT a network call.
//
//  The video call goes behind a protocol, so the test replaces it with
//  a stub. The rule that matters most is the first one:
//
//  - a video is NOT requested for a card with no still cover, because
//    the clip is made FROM the still. A card with no still has
//    nothing to animate, and asking anyway would spend the scarce
//    video quota for nothing.
//
//  The playback rule is tested as the PURE function it is, so the
//  forward-then-backward loop can be checked without a video file and
//  without a player.
//

import CoreGraphics
import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

/// A stub that counts the calls, and can be told to fail.
private final class StubVideoClient: CoverVideoClient, @unchecked Sendable {
    var callCount = 0
    var shouldFail = false

    func makeVideo(firstFrameJPEG: Data, prompt: String) async throws -> Data {
        callCount += 1
        if shouldFail {
            throw CoverVideoError.noStillCover
        }
        return Data([0x00, 0x00, 0x00, 0x18])
    }
}

@Suite("Cover video service")
@MainActor
struct CoverVideoServiceTests {

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

    @Test("A video is NOT requested for a card with no still cover")
    func noVideoWithoutAStillCover() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runNoVideoWithoutAStill()
        }
    }

    /// The body of the no-still test, inside the library root scope.
    private func runNoVideoWithoutAStill() async throws {
        let container = try makeContainer()
        let client = StubVideoClient()
        let service = CoverVideoService(
            videoClient: client
        )
        let target = CardCoverTarget.reference(UUID())

        // The card has a cover FOLDER but no picture file: the still
        // is gone, so there is nothing to animate.
        let directory = CardCoverService.directory(forKey: target.coverKey)
        try FileManager.default.createDirectory(at: directory!, withIntermediateDirectories: true)

        await #expect(throws: CoverVideoError.self) {
            try await service.makeVideo(for: target)
        }
        #expect(client.callCount == 0)
    }

    @Test("A video for a card WITH a still cover is requested once")
    func videoWithAStillCoverIsRequested() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runVideoWithAStill()
        }
    }

    /// The body of the with-still test, inside the library root scope.
    private func runVideoWithAStill() async throws {
        let container = try makeContainer()
        let client = StubVideoClient()
        let service = CoverVideoService(
            videoClient: client
        )
        let target = CardCoverTarget.reference(UUID())

        // Give the card a real still: a stored HEIC and a row that
        // points at it.
        let coverService = CardCoverService()
        let heic = try CardCoverImageEncoder.encode(
            bannerImage: CardCoverImageEncoder.centerCrop(
                Self.testBanner,
                toWidth: CardCoverImageEncoder.bannerWidth,
                toHeight: CardCoverImageEncoder.bannerHeight
            )
        )
        try coverService.saveImage(heic, forKey: target.coverKey, kind: target.kind)

        try await service.makeVideo(for: target)

        #expect(client.callCount == 1)
        let record = service.coverRecord(for: target)
        #expect(record?.status == WSCardCoverStatus.dynamicReady)
        let clip = CardCoverService().coverVideoURL(for: target.coverKey)
        #expect(clip != nil)
        #expect(FileManager.default.fileExists(atPath: clip!.path))
    }

    @Test("A failed clip leaves the still cover and says why")
    func aFailedClipIsRecorded() async throws {
        try await PathGuard.$libraryRootOverride.withValue(Self.libraryRoot) {
            try await self.runAFailedClip()
        }
    }

    /// The body of the failed-clip test, inside the library root scope.
    private func runAFailedClip() async throws {
        let client = StubVideoClient()
        client.shouldFail = true
        let service = CoverVideoService(videoClient: client)
        let target = CardCoverTarget.reference(UUID())

        // A real still, so the clip is attempted and fails.
        let coverService = CardCoverService()
        let heic = try CardCoverImageEncoder.encode(
            bannerImage: CardCoverImageEncoder.centerCrop(
                Self.testBanner,
                toWidth: CardCoverImageEncoder.bannerWidth,
                toHeight: CardCoverImageEncoder.bannerHeight
            )
        )
        try coverService.saveImage(heic, forKey: target.coverKey, kind: target.kind)
        let stillPath = coverService.coverImageURL(for: target.coverKey)?.path

        await #expect(throws: CoverVideoError.self) {
            try await service.makeVideo(for: target)
        }

        // The still is still there: a failed clip must not take it away.
        #expect(coverService.coverImageURL(for: target.coverKey)?.path == stillPath)

        // And the card can say what happened: the failure is in the
        // cover's record, marked as the clip's failure.
        let record = service.coverRecord(for: target)
        #expect(record?.status == WSCardCoverStatus.videoFailed)
        #expect(record?.lastError != nil)
    }

    @Test("The clip plays forward, then backward")
    func theClipPlaysForwardThenBackward() {
        // The provider does not deliver a seamless loop, so the clip
        // runs forward and then backward.
        #expect(CoverPlaybackRule.next(afterForwardEnd: true) == .playingBackward)
        #expect(CoverPlaybackRule.next(afterBackwardEnd: true) == .playingForward)
        // Not at an end, the direction does not change.
        #expect(CoverPlaybackRule.next(afterForwardEnd: false) == .playingForward)
        #expect(CoverPlaybackRule.next(afterBackwardEnd: false) == .playingBackward)
    }

    /// A simple test banner.
    private static let testBanner: CGImage = {
        let context = CGContext(
            data: nil,
            width: 1024,
            height: 512,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1024, height: 512))
        return context.makeImage()!
    }()
}
