//
//  Features/Cover/Service/CoverGenerationService.swift
//
//   : CoverGenerationService.
//  Draws a card's cover.
//
//  The pipeline, in order:
//
//    art direction + subject
//      -> the image model
//      -> the crop and the HEIC encode
//      -> the cover directory
//      -> the cover row
//
//  Three rules shape it, and each of them is a thing a user notices:
//
//  - A card that is already being generated is NOT generated twice.
//    Two clicks make one call, not two, and the second call would
//    spend the image allowance for nothing.
//  - A FAILED generation leaves the previous picture in place. The
//    user liked that picture; a failed refresh must not take it away.
//  - The generation is cancellable. A user who navigates away
//    mid-generation cancels it, and the card goes back to whatever it
//    showed before.
//

import Foundation
import Observation
import WenshuData
import os

private let coverGenerationLogger = Logger(subsystem: "com.wenshu", category: "covergeneration")

/// Draws and stores a card's cover.
@MainActor
@Observable
final class CoverGenerationService {

    /// The cover store.
    private let coverService: CardCoverService

    /// The cards currently being generated, so a second request for
    /// the same card does not start a second call.
    ///
    /// Observable on purpose: the material zone asks every card
    /// whether it is being drawn, and a card that cannot see the
    /// answer gives the user no sign that anything is happening.
    private(set) var inFlight: Set<String> = []

    /// The store the routes live in.
    private let routeStore: CoverServiceRouteStore

    /// The image call, injected so the service can be tested without
    /// a network call.
    private let imageClient: CoverImageClient

    /// The app's current provider slug, read when a route is auto.
    ///
    /// This is the same key the settings pane writes
    /// (`wenshu.llm.provider`), so an automatic cover route follows
    /// the provider the user picked for the app.
    private let currentProviderSlug: () -> String?

    init(
        routeStore: CoverServiceRouteStore = CoverServiceRouteStore(),
        imageClient: CoverImageClient = CoverImageGenerator(),
        currentProviderSlug: @escaping () -> String? = {
            UserDefaults.standard.string(forKey: "wenshu.llm.provider")
        }
    ) {
        self.coverService = CardCoverService()
        self.routeStore = routeStore
        self.imageClient = imageClient
        self.currentProviderSlug = currentProviderSlug
    }

    /// The service over the library the app is running on.
    static func live() -> CoverGenerationService {
        CoverGenerationService()
    }

    /// Whether a card is being generated right now.
    func isGenerating(_ target: CardCoverTarget) -> Bool {
        inFlight.contains(target.coverKey)
    }

    /// The record that describes a card's cover, if it has one.
    func coverRecord(for target: CardCoverTarget) -> CoverRecord? {
        coverService.record(forKey: target.coverKey)
    }

    /// Draws a card's cover and stores it.
    ///
    /// - Parameters:
    ///   - target: the card.
    ///   - subject: what the picture should show. The art direction
    ///     is prepended, so the caller supplies the subject and the
    ///     style comes from the one constant.
    func generateCover(for target: CardCoverTarget, subject: String) async {
        let key = target.coverKey
        guard !inFlight.contains(key) else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        // The record goes to "pending" so the UI can show that the card
        // is working.
        markPending(for: key, kind: target.kind)

        do {
            let route = routeStore.route(for: .image)
            let resolved = try CoverRouteResolver.resolve(
                route,
                currentProviderSlug: currentProviderSlug()
            )
            let prompt = CoverArtDirection.prompt(subject: subject)
            let jpeg = try await imageClient.generateCover(subject: prompt)
            let banner = try CardCoverImageEncoder.decode(jpeg)
            let heic = try CardCoverImageEncoder.encode(bannerImage: banner)
            try coverService.saveImage(heic, forKey: key, kind: target.kind)
        } catch {
            // A failed generation leaves the previous picture in place.
            // The card keeps what it had; the error is recorded so the
            // UI can say why.
            markFailed(for: key, kind: target.kind, error: error)
            coverGenerationLogger.error(
                "[wenshu.cover] generation failed key=\(key, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
    }

    /// Removes a card's cover, its picture and its clip.
    func removeCover(for target: CardCoverTarget) {
        try? coverService.removeCover(forKey: target.coverKey)
    }

    // MARK: - Record state

    /// Records that the cover is being drawn.
    ///
    /// A card with no cover yet has no record to update, so one is
    /// written: the card then has a cover folder, and the folder
    /// says the work is in flight.
    private func markPending(for key: String, kind: String) {
        var record = coverService.record(forKey: key) ?? CoverRecord(cardKind: kind)
        record.cardKind = kind
        record.status = WSCardCoverStatus.pending
        record.lastAttemptAt = .now
        record.updatedAt = .now
        try? coverService.writeRecord(record, forKey: key)
    }

    /// Records that the draw failed.
    ///
    /// The picture the user liked stays where it is: a failed refresh
    /// must not take it away.
    private func markFailed(for key: String, kind: String, error: Error) {
        var record = coverService.record(forKey: key) ?? CoverRecord(cardKind: kind)
        record.cardKind = kind
        record.status = WSCardCoverStatus.failed
        record.lastAttemptAt = .now
        record.lastError = String(describing: error)
        record.updatedAt = .now
        try? coverService.writeRecord(record, forKey: key)
    }
}
