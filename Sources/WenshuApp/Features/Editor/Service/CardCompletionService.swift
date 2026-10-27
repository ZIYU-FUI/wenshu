//
//  CardCompletionService.swift
//
//  The rule that decides whether a card still needs work.
//
//  Why: the material zone's card draws an orange border and a corner
//  badge for a document that still needs work, and the card's menu
//  offers the completion action for it. Those surfaces read one flag,
//  so the decision belongs in one place (= here), not in the views.
//
//  Where the decision comes from (= two shapes of the same gap):
//  - a book document imported against a template still carries the
//    template's placeholder where a mandatory section is unanswered,
//  - a reference carries its fields in the index row while its body
//    file is missing or empty.
//
//  What it does NOT do: read a book document's file. The grid already
//  holds that body, so the rule is a decision over text. A reference
//  carries no body of its own, so its body is read through the store's
//  own body read.
//

import Foundation

/// The rules that decide whether a card still needs work.
enum CardCompletionService {
    /// The ASCII marker an import leaves where a mandatory section is
    /// unanswered.
    ///
    /// Only the prefix is part of the rule: the wording behind it
    /// belongs to the import, not to the decision.
    static let placeholderPrefix = "[TODO:"

    /// Whether a book document still carries an unanswered section.
    static func bookDocumentNeedsCompletion(body: String) -> Bool {
        body.contains(placeholderPrefix)
    }

    /// Whether a reference has no body to show.
    ///
    /// A missing body and a blank body are the same thing to the user:
    /// the index row carries the fields, the body carries nothing.
    static func referenceNeedsCompletion(body: String?) -> Bool {
        guard let body else { return true }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Which of the loaded book documents still need completion.
    ///
    /// The decision reads the body the grid already holds, so this
    /// never touches the file system.
    static func bookDocumentsNeedingCompletion(_ documents: [BookDoc]) -> Set<UUID> {
        Set(
            documents
                .filter { bookDocumentNeedsCompletion(body: $0.body) }
                .map(\.id)
        )
    }

    /// Which of the loaded references still need completion.
    ///
    /// The reference model carries no body, so every body is read
    /// through the store's own body read.
    @MainActor
    static func referencesNeedingCompletion(
        _ references: [Reference],
        store: any ReferenceStoring
    ) -> Set<UUID> {
        Set(
            references
                .filter { referenceNeedsCompletion(body: store.loadReferenceBody(id: $0.id)) }
                .map(\.id)
        )
    }
}
