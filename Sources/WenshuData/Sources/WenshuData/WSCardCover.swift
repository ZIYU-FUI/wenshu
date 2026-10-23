//
//  Persistence/WSCardCover.swift
//
//   : WSCardCover.
//  The LEGACY cover row. The cover record lives in the library now.
//
//  A card is a REFERENCE (a document in the reference library) or a
//  BOOK DOC (a .md file inside a book). A cover belongs to ONE card,
//  and dies with it: when the document is deleted, the cover files
//  are deleted too (= see CoverCascade).
//
//  A cover record is a FILE in the library, beside the picture it
//  describes:
//
//    <library>/assets/covers/<cardKey>/cover.heic
//    <library>/assets/covers/<cardKey>/cover.mp4
//    <library>/assets/covers/<cardKey>/cover.json
//
//  A cover belongs to a document, so its record belongs to the
//  document's library. A store row cannot make that promise: the
//  store the app resolves at launch is not always the library the
//  picture is written to, because the app delegate activates the
//  warehouse container after the first view render. A record written
//  before that point and a picture written after it land in two
//  different stores, and the card then finds one without the other.
//
//  The model stays in the schema so a library that already carries
//  the table keeps opening. Nothing writes it any more.
//

import Foundation
import SwiftData

/// The generated cover art for one material-zone card.
@Model
public final class WSCardCover {
    /// The cover key (= the card identity, namespaced by kind so two
    /// cards can never collide on one key). Unique.
    @Attribute(.unique) public var id: String
    /// The kind of card this cover belongs to (= "reference" or
    /// "bookDoc"). A discriminator string, not an enum, so adding a
    /// kind does not need a migration.
    public var cardKind: String
    /// Absolute path to the stored HEIC banner. Nil when the card has
    /// no static cover.
    public var imagePath: String?
    /// Absolute path to the stored mp4 clip. Nil until the user asks
    /// for a moving cover (= a moving cover is always deliberate).
    public var videoPath: String?
    /// The generation state (= "pending", "staticReady", "dynamicReady"
    /// or "failed"). A plain string, not an enum, so a new state does
    /// not need a migration.
    public var status: String
    /// The accent colour sampled from the cover, as a hex string.
    /// Optional: the accent is a nicety, not a requirement.
    public var accentHex: String?
    /// When the last generation attempt started.
    public var lastAttemptAt: Date?
    /// Why the last attempt failed, when it did.
    public var lastError: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        cardKind: String,
        imagePath: String? = nil,
        videoPath: String? = nil,
        status: String = WSCardCoverStatus.pending,
        createdAt: Date = .now
    ) {
        self.id = id
        self.cardKind = cardKind
        self.imagePath = imagePath
        self.videoPath = videoPath
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// The generation states a cover row can be in.
///
/// The STILL and the CLIP are two steps, they fail for different
/// reasons, and they have separate states. Before the split, ONE
/// field carried both, and a clip that failed marked a card whose
/// PICTURE was perfect as broken (measured 2026-10-23: the orange
/// failure mark sat on a card with a good still cover, because the
/// clip's failure had overwritten the record's state and its error).
public enum WSCardCoverStatus {
    /// A generation is in flight.
    public static let pending = "pending"
    /// The static banner exists and is stored.
    public static let staticReady = "staticReady"
    /// The last attempt failed. The row survives so the error and the
    /// attempt time are visible.
    public static let failed = "failed"

    /// There is no clip, and none was asked for.
    public static let clipNone = "clipNone"
    /// The clip exists and is stored.
    public static let clipReady = "clipReady"
    /// The clip could not be made, while the still cover is fine.
    public static let clipFailed = "clipFailed"

    /// The OLD single state, kept so a record written before the
    /// split can be read.
    ///
    /// It said "the picture AND the clip exist", and the record
    /// decoder turns it into still = staticReady, clip = ready.
    public static let dynamicReady = "dynamicReady"
    /// The OLD single state, kept so a record written before the
    /// split can be read.
    ///
    /// It said "the clip gave up and the picture is fine", and the
    /// record decoder turns it into still = staticReady, clip =
    /// failed, with the one error it carries being the clip's.
    public static let videoFailed = "videoFailed"
}

/// The kinds of card a cover can belong to.
public enum WSCardCoverKind {
    /// A card whose document is a file in the reference library.
    public static let reference = "reference"
    /// A card whose document is a .md file inside a book.
    public static let bookDoc = "bookDoc"
}
