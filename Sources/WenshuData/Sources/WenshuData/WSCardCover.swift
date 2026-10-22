//
//  Persistence/WSCardCover.swift
//
//   : WSCardCover.
//  The generated cover art for one material-zone card.
//
//  A card is a REFERENCE (a document in the reference library) or a
//  BOOK DOC (a .md file inside a book). A cover belongs to ONE card,
//  and dies with it: when the document is deleted, the cover row and
//  the cover files are deleted too (= see CoverCascade).
//
//  Storage strategy (= the reason this is not a field on WSReference):
//  the cover is a DERIVED artifact, not part of the document. The
//  document is the source of truth; the cover is a picture of it that
//  can be regenerated or thrown away without touching the document.
//  A separate row also means the reference library's own index and the
//  reference .md files stay exactly as they are.
//
//  The binaries live on disk (= the cover directory under the active
//  library's assets/), not inline in the store: a HEIC banner is tens
//  of kilobytes and a clip is hundreds, so a library with hundreds of
//  covers would bloat the store for no benefit. The row keeps the
//  absolute paths, and the files are the truth for the picture itself.
//
//  `cardKind` (= "reference" or "bookDoc") is a discriminator rather
//  than a hard dependency on the card type, so a future third card
//  kind does not need a schema migration.
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
public enum WSCardCoverStatus {
    /// A generation is in flight.
    public static let pending = "pending"
    /// The static banner exists and is stored.
    public static let staticReady = "staticReady"
    /// The static banner AND the moving clip exist.
    public static let dynamicReady = "dynamicReady"
    /// The last attempt failed. The row survives so the error and the
    /// attempt time are visible.
    public static let failed = "failed"
}

/// The kinds of card a cover can belong to.
public enum WSCardCoverKind {
    /// A card whose document is a file in the reference library.
    public static let reference = "reference"
    /// A card whose document is a .md file inside a book.
    public static let bookDoc = "bookDoc"
}
