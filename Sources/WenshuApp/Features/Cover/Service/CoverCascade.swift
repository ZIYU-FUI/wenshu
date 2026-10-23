//
//  Features/Cover/Service/CoverCascade.swift
//
//   : CoverCascade.
//  Removes one card's cover: the cover row and the cover files.
//
//  A cover is a child of its document. The picture and the clip exist
//  to depict one document, so a document that is gone leaves a cover
//  that can never be shown again: dead weight in the library, plus a
//  row and two files that nothing owns.
//
//  The removal itself belongs to CardCoverService (= the cover
//  directory and the cover row). This service decides WHICH cover
//  goes and keeps the key convention in one place, so a reference
//  card and a book-doc card can never remove each other's cover.
//
//  The cover key comes from CardCoverService, which namespaces the
//  two card kinds apart. Two key functions produce two different
//  keys, and the symptom is a cover that survives every delete.
//
//

import Foundation
import os

private let coverCascadeLogger = Logger(subsystem: "com.wenshu", category: "covercascade")

/// Removes one card's cover row and its cover files.
@MainActor
struct CoverCascade {

    init() {}

    /// The cascade over the library the app is running on.
    ///
    /// A cover belongs to the library its document belongs to, so the
    /// cascade always looks at the covers of the library the app is
    /// running on, whatever store the app resolved at launch.
    static func live() -> CoverCascade {
        CoverCascade()
    }

    // MARK: - Removing

    /// Removes the cover stored under a key.
    ///
    /// The row and the whole cover directory go together, so a
    /// partial file from a failed generation cannot survive.
    ///
    /// A key with no cover is not an error: removing a cover that was
    /// never there leaves nothing behind and throws nothing.
    func removeCover(forKey key: String) throws {
        try service.removeCover(forKey: key)
    }

    /// Removes the cover of a reference card.
    func removeCover(forReference id: UUID) throws {
        try removeCover(forKey: CardCoverService.key(forReference: id))
    }

    /// Removes the cover of a book-doc card.
    func removeCover(forBookDoc id: UUID) throws {
        try removeCover(forKey: CardCoverService.key(forBookDoc: id))
    }

    /// Removes a cover and never fails the caller's delete.
    ///
    /// The document delete is the important operation; a cover that
    /// cannot be removed must not stop it. The failure is logged
    /// instead, and the reconciliation sweep collects the leftovers.
    func removeCoverTolerantly(forKey key: String) {
        do {
            try removeCover(forKey: key)
        } catch {
            coverCascadeLogger.error(
                "[wenshu.cover] cover removal failed key=\(key, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
    }

    /// Removes the cover of a reference card and never fails the
    /// caller's delete.
    func removeCoverTolerantly(forReference id: UUID) {
        removeCoverTolerantly(forKey: CardCoverService.key(forReference: id))
    }

    /// Removes the cover of a book-doc card and never fails the
    /// caller's delete.
    func removeCoverTolerantly(forBookDoc id: UUID) {
        removeCoverTolerantly(forKey: CardCoverService.key(forBookDoc: id))
    }

    // MARK: - Service

    /// The cover store this cascade removes through.
    private var service: CardCoverService {
        CardCoverService()
    }
}
