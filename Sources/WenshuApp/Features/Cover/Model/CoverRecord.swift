//
//  Features/Cover/Model/CoverRecord.swift
//
//   : CoverRecord.
//  The cover's own record, stored beside the picture it describes.
//
//  A cover belongs to a document, so the record that describes it
//  belongs to the same library as the document:
//
//    <library>/assets/covers/<cardKey>/cover.json
//
//  The record is a file, not a store row. A store row lives in
//  whichever container the app resolved at launch, and that is not
//  always the library the picture is written to: the app delegate
//  activates the warehouse container after the first view render, so
//  a record written before that point and a picture written after it
//  land in two different stores, and the card then finds one without
//  the other. A file has one home.
//

import Foundation
import WenshuData

/// What the cover of one card currently is.
struct CoverRecord: Codable, Equatable, Sendable {

    /// The kind of card this cover belongs to (= a reference or a
    /// book doc).
    var cardKind: String

    /// The state of the cover (= pending, staticReady, dynamicReady
    /// or failed).
    var status: String

    /// The accent colour sampled from the picture, when there is one.
    var accentHex: String?

    /// The failure of the last attempt, when the last attempt failed.
    var lastError: String?

    /// What the picture was made of (= the motifs the document was
    /// reduced to before it was drawn).
    ///
    /// It is kept so the card can say what its picture shows, and so
    /// a failed draw can be read afterwards.
    var motifs: CoverMotifs?

    /// When the last attempt started.
    var lastAttemptAt: Date?

    /// When the record was last written.
    var updatedAt: Date

    init(
        cardKind: String,
        status: String = WSCardCoverStatus.staticReady,
        accentHex: String? = nil,
        lastError: String? = nil,
        motifs: CoverMotifs? = nil,
        lastAttemptAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.cardKind = cardKind
        self.status = status
        self.accentHex = accentHex
        self.lastError = lastError
        self.motifs = motifs
        self.lastAttemptAt = lastAttemptAt
        self.updatedAt = updatedAt
    }
}

/// What one card's cover currently holds.
///
/// One entry answers every question the card view asks, so a render
/// reads the cover once instead of once per question.
struct CoverEntry: Equatable, Sendable {

    /// The stored banner, or nil when the card has no cover.
    let imageURL: URL?

    /// The stored clip, or nil when the card has no moving cover.
    let videoURL: URL?

    /// The record that describes the cover, or nil when there is none.
    let record: CoverRecord?

    /// Whether this card has a cover.
    var hasCover: Bool { imageURL != nil }

    /// An empty entry (= a card with no cover at all).
    static let none = CoverEntry(imageURL: nil, videoURL: nil, record: nil)
}
