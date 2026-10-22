//
//  Features/Cover/Model/CardCoverTarget.swift
//
//   : CardCoverTarget.
//  Which card a cover belongs to.
//
//  A material-zone card is either a REFERENCE (a document in the
//  reference library) or a BOOK DOC (a .md file inside a book). The
//  cover service needs to know which, because the two kinds have
//  different cover keys, and the key is what decides whose picture
//  this is.
//

import Foundation
import WenshuData

/// The card a cover belongs to.
struct CardCoverTarget: Equatable, Sendable {
    /// The card's id.
    let id: UUID
    /// The kind of card (= a reference or a book doc).
    let kind: String

    /// A reference card.
    static func reference(_ id: UUID) -> CardCoverTarget {
        CardCoverTarget(id: id, kind: WSCardCoverKind.reference)
    }

    /// A book-doc card.
    static func bookDoc(_ id: UUID) -> CardCoverTarget {
        CardCoverTarget(id: id, kind: WSCardCoverKind.bookDoc)
    }

    /// The cover key for this card.
    var coverKey: String {
        switch kind {
        case WSCardCoverKind.bookDoc: return CardCoverService.key(forBookDoc: id)
        default: return CardCoverService.key(forReference: id)
        }
    }
}
