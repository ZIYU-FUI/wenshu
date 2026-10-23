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
import Observation
import SwiftData
import WenshuData
import os

private let coverVideoLogger = Logger(subsystem: "com.wenshu", category: "covervideo")

/// Makes a card's cover move.
@MainActor
@Observable
final class CoverVideoService {

    /// The cover store.
    private let coverService: CardCoverService

    /// The video call, injected so the service can be tested without a
    /// network call.
    private let videoClient: CoverVideoClient

    /// The cards whose clip is being made, so a second request does
    /// not start a second one.
    ///
    /// Observable on purpose: the card menu disables the item while
    /// the work is in flight, and a menu that cannot see the state
    /// stays clickable.
    private(set) var inFlight: Set<String> = []

    init(
        videoClient: CoverVideoClient = CoverVideoGenerator()
    ) {
        self.coverService = CardCoverService()
        self.videoClient = videoClient
    }

    /// The service over the library the app is running on.
    static func live() -> CoverVideoService {
        CoverVideoService()
    }

    /// Whether a card's clip is being made right now.
    func isMakingVideo(_ target: CardCoverTarget) -> Bool {
        inFlight.contains(target.coverKey)
    }

    /// The record that describes a card's cover, if it has one.
    func coverRecord(for target: CardCoverTarget) -> CoverRecord? {
        coverService.record(forKey: target.coverKey)
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
        guard let heicURL = coverService.coverImageURL(for: key) else {
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
            // A failed clip leaves the still cover working, and the
            // card says what happened: the failure is written into the
            // cover's record, so the card can show the mark and the
            // menu can show the reason.
            markFailed(for: key, kind: target.kind, error: error)
            coverVideoLogger.error(
                "[wenshu.cover] video failed key=\(key, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    /// Records that the clip could not be made.
    ///
    /// The still cover stays where it is: the user liked it, and a
    /// failed clip must not take it away.
    private func markFailed(for key: String, kind: String, error: Error) {
        var record = coverService.record(forKey: key) ?? CoverRecord(cardKind: kind)
        record.cardKind = kind
        record.status = WSCardCoverStatus.videoFailed
        record.lastAttemptAt = .now
        record.lastError = String(describing: error)
        record.updatedAt = .now
        try? coverService.writeRecord(record, forKey: key)
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
