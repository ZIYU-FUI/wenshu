//
//  Features/Cover/Service/CoverVideoService.swift
//
//   : CoverVideoService.
//  Makes a card's cover move.
//
//  The rule that shapes everything: a moving cover is made FROM the
//  still cover, so a card with no still cover has nothing to animate
//  and no video is requested at all. The user looks at the picture
//  they like and THEN asks for it to move.
//
//  The video is never made automatically. The video allowance is a
//  handful of clips a day, and only the user may spend it.
//
//  A failed video leaves the still cover working. The card must keep
//  showing its picture whether the clip arrived or not.
//

import Foundation
import SwiftData
import WenshuData
import os

private let coverVideoLogger = Logger(subsystem: "com.wenshu", category: "covervideo")

/// Makes a card's cover move.
@MainActor
final class CoverVideoService {

    /// The cover store.
    private let coverService: CardCoverService

    /// The video call, injected so the service can be tested without a
    /// network call.
    private let videoClient: CoverVideoClient

    /// The cards whose clip is being made, so a second request does
    /// not start a second one.
    private var inFlight: Set<String> = []

    init(
        modelContext: ModelContext,
        videoClient: CoverVideoClient = CoverVideoGenerator()
    ) {
        self.coverService = CardCoverService(modelContext: modelContext)
        self.videoClient = videoClient
    }

    /// The service over the library the app is running on.
    static func live() -> CoverVideoService {
        CoverVideoService(modelContext: WSPersistenceContainer.current.mainContext)
    }

    /// Whether a card's clip is being made right now.
    func isMakingVideo(_ target: CardCoverTarget) -> Bool {
        inFlight.contains(target.coverKey)
    }

    /// The cover row for a card, if it has one.
    func coverRow(for target: CardCoverTarget) -> WSCardCover? {
        coverService.row(forKey: target.coverKey)
    }

    /// Makes a card's cover move.
    ///
    /// - Parameter target: the card.
    /// - Throws: `CoverVideoError.noStillCover` when the card has no
    ///   still cover, because there is nothing to animate.
    func makeVideo(for target: CardCoverTarget) async throws {
        let key = target.coverKey
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        // A clip is made FROM the still. A card with no still has
        // nothing to animate, and asking the video service for a clip
        // without a first frame would spend the scarce video quota for
        // nothing.
        guard let row = coverService.row(forKey: key),
              let heicPath = row.imagePath else {
            throw CoverVideoError.noStillCover
        }
        let heicURL = URL(fileURLWithPath: heicPath)
        guard FileManager.default.fileExists(atPath: heicURL.path) else {
            throw CoverVideoError.noStillCover
        }

        do {
            // The endpoint takes a JPEG and NOT the HEIC the cover is
            // stored as, so the conversion happens in memory and the
            // JPEG is never written to disk.
            let heic = try Data(contentsOf: heicURL)
            let jpeg = try CardCoverImageEncoder.decodeToJPEG(heic)
            let clip = try await videoClient.makeVideo(
                firstFrameJPEG: jpeg,
                prompt: Self.motionPrompt
            )
            try coverService.saveVideo(clip, forKey: key)
        } catch {
            // A failed clip leaves the still cover working.
            coverVideoLogger.error(
                "[wenshu.cover] video failed key=\(key, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    /// The motion instruction.
    ///
    /// The clip is made from a still, so the model is told to keep the
    /// scene and move within it. The measured behaviour is that the
    /// provider does NOT deliver a seamless loop, which is why the
    /// playback runs forward and then backward.
    static let motionPrompt = """
        A gentle, continuous motion in this exact scene. The subject and \
        the composition stay the same as the first frame. Slow subtle \
        movement only, no cuts, no new objects, no camera change.
        """
}
