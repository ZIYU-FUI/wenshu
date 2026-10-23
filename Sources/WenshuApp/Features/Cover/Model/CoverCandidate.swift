//
//  Features/Cover/Model/CoverCandidate.swift
//
//   : CoverCandidate.
//  One document that wants a cover.
//
//  The same shape serves both cover paths, because both paths ask the
//  same three questions about a document:
//
//  - WHICH card the cover belongs to (= the target),
//  - WHAT the picture should show (= the subject),
//  - WHEN the document was created (= the policy's boundary between
//    "already there" and "comes later").
//
//  One type for both paths is what keeps them from drifting: the
//  batch and the automatic pass agree on what a document is, so the
//  only thing that differs between them is the DECISION, which is the
//  policy's job.
//
//

import Foundation

/// A document that wants a cover.
struct CoverCandidate: Equatable, Sendable {

    /// The card the cover belongs to.
    let target: CardCoverTarget

    /// The document's own title.
    let title: String

    /// The document's own short summary.
    let summary: String

    /// When the document was created.
    ///
    /// This is the document's real creation time, NOT the file's
    /// modification time: editing an old document changes the file's
    /// modification time, which would make that document look new.
    let createdAt: Date
}
