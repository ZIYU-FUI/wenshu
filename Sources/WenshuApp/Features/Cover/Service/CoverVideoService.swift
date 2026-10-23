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

    /// The planning call, injected for the same reason.
    private let motionPlanner: CoverMotionPlanning

    /// Where the clip is made (= the user's own video service).
    private let routeStore: CoverServiceRouteStore

    /// The cards whose clip is being made, so a second request does
    /// not start a second one.
    ///
    /// Observable on purpose: the card menu disables the item while
    /// the work is in flight, and a menu that cannot see the state
    /// stays clickable.
    private(set) var inFlight: Set<String> = []

    init(
        routeStore: CoverServiceRouteStore = CoverServiceRouteStore(),
        videoClient: CoverVideoClient = CoverVideoGenerator(),
        motionPlanner: CoverMotionPlanning = CoverMotionPlanner()
    ) {
        self.coverService = CardCoverService()
        self.routeStore = routeStore
        self.videoClient = videoClient
        self.motionPlanner = motionPlanner
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
            // The clip is made at the user's own video service, which
            // is a route the user configured: a clip spends a scarce
            // allowance, so it is never spent on a service the user
            // did not choose.
            let route = routeStore.route(for: .video)
            let service = try CoverRouteResolver.resolve(route)
            // The endpoint takes a JPEG and NOT the HEIC the cover is
            // stored as, so the conversion happens in memory and the
            // JPEG is never written to disk.
            let heic = try Data(contentsOf: heicURL)
            let jpeg = try CardCoverImageEncoder.decodeToJPEG(heic)
            let prompt = try await motionPrompt(for: key)
            let clip = try await videoClient.makeVideo(
                firstFrameJPEG: jpeg,
                prompt: prompt,
                service: service
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

    /// The prompt the clip is made with.
    ///
    /// The plan comes from the card's own motifs (= the description
    /// the picture was drawn from), so the clip names the same objects
    /// the picture has, and says which of them a breeze may move.
    ///
    /// A card whose cover carries no motifs (= a cover made before
    /// the picture's description was stored) falls back to the
    /// measured generic prompt. The fallback stays because it is the
    /// only prompt known to work end to end, and a card must never be
    /// left with no way to move.
    private func motionPrompt(for key: String) async throws -> String {
        guard let motifs = coverService.record(forKey: key)?.motifs else {
            return Self.fallbackMotionPrompt
        }
        let plan = try await motionPlanner.plan(motifs: motifs)
        return CoverMotionPrompt.make(plan: plan)
    }

    /// The generic motion instruction, for a card with no motifs.
    ///
    /// The clip is made from a still, so the model is told to keep the
    /// scene and move within it. The measured behaviour is that the
    /// provider does NOT deliver a seamless loop, which is why the
    /// playback runs forward and then backward.
    ///
    /// The wording is measured, not guessed. Measured 2026-10-23
    /// against the live endpoint on the Rain Water cover (a still
    /// life: a ceramic pot, a paper bird, a cloth doll, a sprout),
    /// with the endpoint's prompt optimizer off:
    ///
    ///  - the first wording ("be gentle", no camera instruction)
    ///    produced a clip the camera drifted across, and the model
    ///    invented a table, a wall and a hard beam of sunlight that
    ///    were not in the still. So the still and the clip were two
    ///    different pictures.
    ///  - this wording produced a LOCKED camera (no push, no pull,
    ///    no pan, no tilt), a background that stayed the pale paper
    ///    of the still, and motion only in the branches and the small
    ///    objects swaying.
    ///
    /// It is the fallback, not the rule: a card whose motifs are
    /// known gets a plan, and the plan names what moves. This stays
    /// for the cards that carry no motifs.
    static let fallbackMotionPrompt = """
        [固定] A Chinese ink-and-colour still life on plain pale paper. The camera is completely locked: no push, no pull, no pan, no tilt, no shake, no cut, no change of framing. The composition, the objects and the background stay exactly as they are in the first frame.
        The only movement is a light breeze passing through the scene: the leafy branches sway a little, a few petals and a hanging silk cord stir gently. The movement is small, slow and continuous, like watching a real breeze from a seat at the table.
        Nothing else moves. The vessels, the fan, the brush and the inkstone do not move. Nothing appears, nothing disappears, nothing is added or removed. The light stays soft and even and the background stays the same pale paper: no window, no wall, no table edge, no hard beam of sunlight.
        """
}
