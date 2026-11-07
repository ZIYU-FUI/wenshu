//
//  ReferenceCorpusNarrowing.swift
//
//  The two axes the corpus narrows by: = what KIND of document it is,
//  = and WHO wrote it.
//
//  Why this type exists: = the archive narrows (= by agent and by kind,
//  = `ArchiveSettingsPane`), = and the corpus did not. = A reader who
//  can ask the archive "what did the archivist do" = but cannot ask
//  the corpus "what did the agent write" = is reading one library and
//  searching another.
//
//  **⇒ The kind axis is `EntityType`** (= the corpus's own closed set
//  of 9: = character / location / event / concept / artifact /
//  organization / era / work / other). = It is a FIELD on every
//  reference, = so narrowing by it costs no index and no disk. = The
//  archive's kind is a closed set of its own, = so the corpus's kind
//  is the corpus's own closed set (= not the archive's vocabulary
//  renamed).
//
//  **⇒ The owner axis is "you vs. an agent", = and that is the WHOLE
//  truth.** = Measured 2026-11-07: = NO producer records WHICH agent
//  wrote a reference. = The `reference_library` tool protocol carries
//  no caller identity (= `Tool.execute(input:)` takes only the input),
//  = the `Reference` model has no agent/role/provenance field, = and
//  = the only write provenance that exists is the second-writer
//  rule's binary owner (= `ReferenceWriteRecord.Owner` = `.agent` /
//  `.user`, = written to `<ws>/reference-library/.write-records/
//  <uuid>.json`). = **⇒ A menu that names six roles the app cannot
//  prove is a menu of lies** (= the archive's own rule for its agent
//  picker: = "the options come from the rows"), = so this axis offers
//  exactly the two owners the witness can prove.
//
//  **⇒ And the witness is the SAME one the second-writer rule uses.**
//  = `ReferenceWriteGuard.resolveOwnership` already answers "whose
//  text does the truth hold" = from the write record when there is
//  one, = and from the corpus copy when there is not. = **⇒ This file
//  does NOT re-decide ownership** (= a second answer to the same
//  question is how the two copies of a body drifted in the first
//  place): = it reads that one answer.
//

import Foundation

/// Who wrote a document's text (= the second-writer rule's answer).
///
/// **⇒ This is the corpus's owner axis, = and it is deliberately
/// binary.** = The app can prove "an agent wrote this" or "the user
/// wrote this" (= the write record), = and it cannot prove WHICH
/// agent (= measured 2026-11-07: = no producer records it).
enum ReferenceCorpusOwner: String, CaseIterable, Sendable, Equatable {
    /// The user wrote it (= the editor's save).
    case user

    /// An agent wrote it (= the write record says so, = and the truth
    /// still holds the text it wrote).
    case agent

    /// The label the user reads.
    ///
    /// **⇒ The label is in the CATALOG, = not in the code.** = The
    /// app ships two languages (= English is the default, = Chinese
    /// the alternate), = and a label written into the code is a label
    /// only one of them can show. = **⇒ And the label says WHAT the
    /// owner axis is** (= who wrote the text), = not which agent =
    /// because the app cannot prove that.
    var displayName: String {
        switch self {
        case .user: return String(localized: "library.search.fulltext.owner.user")
        case .agent: return String(localized: "library.search.fulltext.owner.agent")
        }
    }
}

/// The two axes the corpus narrows by.
struct ReferenceCorpusNarrowing: Sendable, Equatable {
    /// The kind of document (= nil = every kind).
    var kind: EntityType?

    /// Who wrote it (= nil = both owners).
    var owner: ReferenceCorpusOwner?

    /// The narrowing that does not narrow.
    static let all = ReferenceCorpusNarrowing(kind: nil, owner: nil)

    /// Whether this narrowing excludes anything.
    var isActive: Bool {
        kind != nil || owner != nil
    }

    /// Whether one document survives this narrowing.
    ///
    /// **⇒ This is the ONE answer to "does this document survive the
    /// narrowing"** (= the search service asks it, = and so does a
    /// caller that wants to know before it reads anything).
    ///
    /// - Parameters:
    ///   - reference: The document.
    ///   - ownerOf: Whose text the document's truth holds (= the
    ///     second-writer rule's answer; = nil when the witness cannot
    ///     read it, = and **⇒ nil reads as the USER**, = because the
    ///     agent may never claim text it cannot prove it wrote).
    func admits(
        _ reference: Reference,
        ownerOf: (Reference) -> ReferenceCorpusOwner?
    ) -> Bool {
        // **⇒ The kind axis is a FIELD on the reference** (= it costs
        // no witness read), = so it is answered FIRST.
        if let kind, reference.entityType != kind { return false }
        guard let owner else { return true }
        return (ownerOf(reference) ?? .user) == owner
    }
}

/// Reads who wrote the documents in a corpus.
///
/// **⇒ This type asks the second-writer rule, = it does not answer the
/// question itself.** = The witness lives in `ReferenceWriteGuard`
/// (= one answer, = one place), = and this file only turns that answer
/// into the corpus's owner axis.
enum ReferenceCorpusOwnership {
    /// The owner of every reference in the corpus.
    ///
    /// - Parameters:
    ///   - references: the corpus.
    ///   - referenceLibraryRoot: the corpus root (= where the write
    ///     records and the corpus copies live).
    /// - Returns: the owner per document id (= a document whose truth
    ///   cannot be read is absent: = there is nothing to prove).
    static func owners(
        for references: [Reference],
        referenceLibraryRoot: URL
    ) -> [UUID: ReferenceCorpusOwner] {
        var owners: [UUID: ReferenceCorpusOwner] = [:]
        for reference in references {
            guard let owner = owner(of: reference, referenceLibraryRoot: referenceLibraryRoot) else {
                continue
            }
            owners[reference.id] = owner
        }
        return owners
    }

    /// The owner of one document (= nil when the truth cannot be read).
    ///
    /// **⇒ The proof is the second-writer rule's own.** = The record
    /// names the owner when there is one, = and the corpus copy is the
    /// witness when there is not. = **⇒ A document with neither is NOT
    /// proved to be the agent's** (= the agent may never replace text
    /// it cannot prove it wrote), = so it reads as the user's.
    static func owner(
        of reference: Reference,
        referenceLibraryRoot: URL
    ) -> ReferenceCorpusOwner? {
        let truth = try? String(
            contentsOf: ReferenceBodyStore.truthURL(
                id: reference.id,
                referenceLibraryRoot: referenceLibraryRoot
            ),
            encoding: .utf8
        )
        guard let truth else { return nil }
        let mirror = try? String(
            contentsOf: ReferenceBodyStore.mirrorURL(
                id: reference.id,
                layer: reference.layer,
                referenceLibraryRoot: referenceLibraryRoot
            ),
            encoding: .utf8
        )
        let ownership = ReferenceWriteGuard.resolveOwnership(
            current: truth,
            mirrorBody: mirror,
            id: reference.id,
            referenceLibraryRoot: referenceLibraryRoot
        )
        return ownership == .agent ? .agent : .user
    }
}
