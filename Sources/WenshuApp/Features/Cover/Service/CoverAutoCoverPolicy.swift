//
//  Features/Cover/Service/CoverAutoCoverPolicy.swift
//
//   : CoverAutoCoverPolicy.
//  Which documents get a cover without the user asking.
//
//  The user's rule is exactly this: a BATCH for the documents that
//  are already in the library, and AUTOMATIC for the documents that
//  come later, gated on one switch.
//
//  The boundary between the two is the moment the switch was turned
//  ON. A document created BEFORE that belongs to the batch; a
//  document created AFTER it is automatic. So the policy stores that
//  timestamp, and a document is automatic only if its creation time
//  is AFTER it.
//
//  Both card kinds carry a real creation time: a reference has
//  `createdAt` and a book doc has `createdAt`. The file MODIFICATION
//  time is the wrong signal, because editing an old document changes
//  it and would make that document look new.
//
//  The decision is a PURE function of its inputs. "Now" is passed in,
//  so there is no clock behind it and the rule is testable without
//  waiting for anything.
//

import Foundation
import WenshuData

/// Which documents get a cover automatically.
struct CoverAutoCoverPolicy: Equatable, Sendable {

    /// Whether the automatic pass is on.
    var isEnabled: Bool

    /// The moment the switch was turned on.
    ///
    /// Nil when the switch has never been on, which means every
    /// document is "stock" and belongs to the batch.
    var enabledAt: Date?

    init(isEnabled: Bool = false, enabledAt: Date? = nil) {
        self.isEnabled = isEnabled
        self.enabledAt = enabledAt
    }

    /// The policy with the switch ON, stamped now.
    ///
    /// Turning the switch on is a moment, and the stamp is what
    /// separates the documents that are already there from the ones
    /// that arrive later.
    static func enabling(at now: Date) -> CoverAutoCoverPolicy {
        CoverAutoCoverPolicy(isEnabled: true, enabledAt: now)
    }

    /// The policy with the switch OFF.
    static let disabled = CoverAutoCoverPolicy(isEnabled: false, enabledAt: nil)

    /// Whether a document should get a cover automatically.
    ///
    /// - Parameters:
    ///   - createdAt: when the document was created.
    ///   - hasCover: whether the document already has a cover.
    ///   - kind: the card's kind, checked against the kinds that get
    ///     automatic covers.
    /// - Parameter now: the current time, passed in so the decision
    ///   is a pure function.
    func shouldGenerateCover(
        createdAt: Date,
        hasCover: Bool,
        kind: String,
        now: Date
    ) -> Bool {
        // The switch off means nothing is automatic.
        guard isEnabled else { return false }
        // A document that already has a cover never gets another one.
        guard !hasCover else { return false }
        // A document created before the switch was turned on is
        // "stock": it belongs to the batch, not to the automatic path.
        guard let enabledAt else { return false }
        guard createdAt >= enabledAt else { return false }
        // A kind the user did not opt in never gets an automatic
        // cover.
        guard Self.automaticKinds.contains(kind) else { return false }
        return true
    }

    /// The card kinds that get automatic covers.
    ///
    /// An explicit list, so the user is not surprised by a picture on
    /// a kind of card they did not expect.
    static let automaticKinds: Set<String> = [
        WSCardCoverKind.reference,
        WSCardCoverKind.bookDoc,
    ]
}
