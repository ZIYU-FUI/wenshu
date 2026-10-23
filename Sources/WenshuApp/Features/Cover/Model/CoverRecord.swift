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
///
/// The STILL and the CLIP are two steps with two states, because they
/// fail for different reasons and a failure in one of them says
/// nothing about the other. Before the split, ONE status and ONE
/// error carried both, and a clip that failed marked a card whose
/// PICTURE was perfect as broken (measured 2026-10-23: the orange
/// failure mark sat on a card with a good still cover, because the
/// clip's failure had overwritten the record's state and its error).
struct CoverRecord: Codable, Equatable, Sendable {

    /// The kind of card this cover belongs to (= a reference or a
    /// book doc).
    var cardKind: String

    /// The state of the STILL cover (= pending, staticReady or
    /// failed).
    var status: String

    /// The state of the CLIP (= none, ready or failed).
    ///
    /// It is separate from the still's state because a card with a
    /// good picture and a failed clip is NOT a broken card: the
    /// picture is there, and the menu says that the clip is the part
    /// that gave up.
    var clipStatus: String

    /// The accent colour sampled from the picture, when there is one.
    var accentHex: String?

    /// The failure of the last STILL attempt, when it failed.
    var lastError: String?

    /// The failure of the last CLIP attempt, when it failed.
    var clipError: String?

    /// What the picture was made of (= the motifs the document was
    /// reduced to before it was drawn).
    ///
    /// It is kept so the card can say what its picture shows, and so
    /// a failed draw can be read afterwards.
    var motifs: CoverMotifs?

    /// When the last STILL attempt started.
    var lastAttemptAt: Date?

    /// When the last CLIP attempt started.
    var clipAttemptAt: Date?

    /// When the record was last written.
    var updatedAt: Date

    init(
        cardKind: String,
        status: String = WSCardCoverStatus.staticReady,
        clipStatus: String = WSCardCoverStatus.clipNone,
        accentHex: String? = nil,
        lastError: String? = nil,
        clipError: String? = nil,
        motifs: CoverMotifs? = nil,
        lastAttemptAt: Date? = nil,
        clipAttemptAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.cardKind = cardKind
        self.status = status
        self.clipStatus = clipStatus
        self.accentHex = accentHex
        self.lastError = lastError
        self.clipError = clipError
        self.motifs = motifs
        self.lastAttemptAt = lastAttemptAt
        self.clipAttemptAt = clipAttemptAt
        self.updatedAt = updatedAt
    }

    /// Reads a record, and normalises the OLD single-state shape.
    ///
    /// A record written before the split carries ONE status, and it
    /// meant two things:
    ///
    ///  - `dynamicReady` = the picture AND the clip exist, so it reads
    ///    as still = staticReady, clip = ready;
    ///  - `videoFailed` = the clip gave up and the picture was fine,
    ///    so it reads as still = staticReady, clip = failed, and the
    ///    one error it carries was the CLIP's error, so it moves.
    ///
    /// The normalisation is HERE, in the decoder, so every reader sees
    /// the split shape and no caller has to know that the old one
    /// existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardKind = try container.decode(String.self, forKey: .cardKind)
        let rawStatus = try container.decode(String.self, forKey: .status)
        accentHex = try container.decodeIfPresent(String.self, forKey: .accentHex)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        clipError = try container.decodeIfPresent(String.self, forKey: .clipError)
        motifs = try container.decodeIfPresent(CoverMotifs.self, forKey: .motifs)
        lastAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        clipAttemptAt = try container.decodeIfPresent(Date.self, forKey: .clipAttemptAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now

        let storedClip = try container.decodeIfPresent(String.self, forKey: .clipStatus)
        switch rawStatus {
        case WSCardCoverStatus.dynamicReady:
            status = WSCardCoverStatus.staticReady
            clipStatus = storedClip ?? WSCardCoverStatus.clipReady
        case WSCardCoverStatus.videoFailed:
            status = WSCardCoverStatus.staticReady
            clipStatus = storedClip ?? WSCardCoverStatus.clipFailed
            // The one error an old record carried was the clip's.
            if let error = lastError, clipError == nil {
                clipError = error
                lastError = nil
            }
        default:
            status = rawStatus
            clipStatus = storedClip ?? WSCardCoverStatus.clipNone
        }
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
