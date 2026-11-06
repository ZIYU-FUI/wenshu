//
//  ReferenceWriteGuard.swift
//
//  Who may write the truth, = and what happens when the user got there first.
//
//  **⇒ The corpus has one truth, = and TWO writers.** = The editor
//  writes it (= the user), = and the agent writes it (= the
//  librarian's create / update / extend / upsert / import). = **⇒
//  Whoever writes second wins, = and the one that must check is the
//  agent**: = the user's text is not the agent's to overwrite.
//
//  **⇒ THE RULE (= the second-writer rule).** = *The user's write
//  wins.* = The agent may REPLACE the agent's own text, = and may ADD
//  to the user's text, = and may never REPLACE any of the user's text.
//  = So an agent write is allowed in exactly two cases, = and refused
//  in every other one:
//
//  1. **The truth still holds the body the agent itself last wrote.**
//     = The record says `agent`, = and the record's hash still matches
//     the truth on disk. = **⇒ The agent owns this text, = and may
//     replace it** (= the librarian's own update, = which is the
//     normal path).
//  2. **The write ADDS to the truth.** = The proposed body starts
//     with the truth's text (= what the `extend` verb produces = = the
//     merge appends a section to the body it read). = **⇒ Nothing the
//     user wrote is lost, = so the write lands.**
//
//  Everything else is REFUSED (= `ReferenceStoreError.userOwnsTheTruth`),
//  and the refusal is REPORTED to the caller (= the LLM), = so the
//  user hears about it instead of losing text.
//
//  **⇒ The three ways that lands.** = The same question (= "whose text
//  is in the truth right now?") = has three witnesses, = and they are
//  asked in this order:
//
//  1. **The record** (= both writers record themselves, = so it names
//     the owner and hashes the text). = A record that says `agent` but
//     no longer matches the truth on disk = the truth changed under
//     the agent (= an edit made outside the app) = = the agent cannot
//     prove what is there = = the user's write wins.
//  2. **The corpus copy** (= the mirror). = For a document written
//     before this rule (= no record), = the mirror is the only
//     witness: = a truth that holds text the mirror never saw = is
//     text the user wrote. = Measured on the user's real library: = six
//     documents, = six divergent pairs, = one of them differing in
//     CONTENT (= the user's edit) = refused, = and five differing by a
//     leading newline only = allowed.
//  3. **Nothing** (= no record and no mirror). = Then nobody can say
//     who wrote the truth, = and an unknown owner is not the agent's to
//     overwrite.
//
//  **⇒ The one case that is NOT a conflict.** = A document whose TRUTH
//  does not exist yet (= a library that predates the truth location, =
//  so only the corpus copy survives) = is not a conflict: = the write
//  CREATES the truth, = and the corpus copy is a copy (= the corpus's
//  own rule: = it is written whenever the truth is written, = and read
//  only when the truth is absent). = **⇒ So the write lands.** = The
//  case that IS a conflict is the one above it: = a truth that holds
//  text the corpus copy never saw.
//
//  **⇒ Why a record and not a clock.** = An mtime, = or the corpus
//  index row's `updatedAt`, = cannot answer this: = both are
//  second-precision, = so a user edit that lands in the same second
//  as the agent's own write is invisible, = and a comparison against
//  the mirror cannot answer it either (= the editor's save writes the
//  mirror too, = so after a user edit BOTH locations hold the user's
//  text). = The record is written by BOTH writers (= the agent's write
//  records itself, = the editor's save-through records the user), =
//  so it names the owner and hashes the text = without a clock.
//
//  **⇒ Where the record lives.** = `<ws>/reference-library/.write-records/<uuid>.json`.
//  = One file per document, = beside the corpus it describes, = in a
//  hidden directory (= nothing enumerates the corpus root's children
//  = the readers go through the per-layer index files, = and a hidden
//  directory is not a layer).
//
//  **⇒ Where the gate is asked.** = `ReferenceBodyStore.write` (= every
//  agent write reaches it, = so the answer cannot be right on one path
//  and wrong on another). = The editor does NOT come through there
//  (= it writes the truth itself, = and the store writes only the
//  mirror), = so **the editor is never blocked**.
//
//

import CryptoKit
import Foundation

/// The write record: = who wrote the truth, = and the hash of the
/// text that writer left there.
struct ReferenceWriteRecord: Codable, Equatable {
    /// The writer of the text the truth currently holds.
    enum Owner: String, Codable {
        /// An agent write (= the librarian).
        case agent
        /// The editor's save (= the user).
        case user
    }

    let owner: Owner
    let hash: String

    init(owner: Owner, hash: String) {
        self.owner = owner
        self.hash = hash
    }
}

/// The second-writer rule, = and the gate that enforces it.
enum ReferenceWriteGuard {
    // MARK: - The rule's answer

    /// Whose text the truth holds.
    enum Ownership: String, Equatable {
        /// The truth holds the agent's own text. = The agent may
        /// replace it.
        case agent
        /// The truth holds text the user wrote. = The agent may only
        /// ADD to it, = never replace it.
        case user
    }

    // MARK: - Where the record lives

    /// The directory holding one record per document.
    ///
    /// = `<ws>/reference-library/.write-records/`. = Hidden (= dot
    /// prefix) = because it is the app's own bookkeeping, = not
    /// corpus content (= the readers enumerate the per-layer index
    /// files, = never the corpus root's children).
    static func recordDirectoryURL(referenceLibraryRoot: URL) -> URL {
        referenceLibraryRoot
            .appendingPathComponent(".write-records", isDirectory: true)
    }

    /// The record of one document.
    static func recordURL(id: UUID, referenceLibraryRoot: URL) -> URL {
        recordDirectoryURL(referenceLibraryRoot: referenceLibraryRoot)
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    // MARK: - The gate

    /// Whether the agent may write `bodyMarkdown` over the truth.
    ///
    /// **⇒ This is the one place that answers it.** = The chokepoint
    /// is `ReferenceBodyStore.write` (= every agent path reaches it),
    /// = so the answer cannot be right on one path and wrong on
    /// another.
    ///
    /// - Returns: whose text the truth holds. = `.user` when the write
    ///   was allowed because it ADDS to the user's text, = so the next
    ///   agent write is held to the same rule.
    /// - Throws: `ReferenceStoreError.userOwnsTheTruth` = the truth
    ///   holds the user's text, = and this write would replace it.
    ///
    /// **⇒ The answer is `@discardableResult`.** = The write path
    /// needs it (= to keep the record's owner right), = and the store's
    /// SwiftData path needs only the refusal (= so a row is not written
    /// when the truth holds the user's text).
    @discardableResult
    static func assertWritable(
        id: UUID,
        layer: ReferenceLayer,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws -> Ownership {
        let truth = ReferenceBodyStore.truthURL(
            id: id,
            referenceLibraryRoot: referenceLibraryRoot
        )
        let mirror = ReferenceBodyStore.mirrorURL(
            id: id,
            layer: layer,
            referenceLibraryRoot: referenceLibraryRoot
        )
        let currentTruth = try? String(contentsOf: truth, encoding: .utf8)
        let mirrorBody = try? String(contentsOf: mirror, encoding: .utf8)

        let ownership: Ownership
        let current: String
        if let currentTruth {
            current = currentTruth
            ownership = resolveOwnership(
                current: currentTruth,
                mirrorBody: mirrorBody,
                id: id,
                referenceLibraryRoot: referenceLibraryRoot
            )
        } else if mirrorBody != nil {
            // **⇒ The truth does not exist yet.** = The write CREATES
            // it, = and the corpus copy is a copy (= the corpus's own
            // rule: = it is written whenever the truth is written, = and
            // read only when the truth is absent). = **⇒ So this is
            // not a conflict, = and the write lands.**
            current = mirrorBody ?? ""
            ownership = .agent
        } else {
            // Nothing on disk = there is nothing to destroy. (= the
            // first write of a new document.)
            return .agent
        }

        if ownership == .user && !addsTo(current: current, proposed: bodyMarkdown) {
            // The truth holds the user's text and this write would
            // replace it. = The user's write wins.
            throw ReferenceStoreError.userOwnsTheTruth(id: id)
        }
        return ownership
    }

    /// Whose text the truth holds.
    ///
    /// = The record is the witness when there is one (= both writers
    /// record themselves), = and the corpus copy is the witness when
    /// there is not (= a document written before this rule).
    static func resolveOwnership(
        current: String,
        mirrorBody: String?,
        id: UUID,
        referenceLibraryRoot: URL
    ) -> Ownership {
        switch readRecord(id: id, referenceLibraryRoot: referenceLibraryRoot) {
        case .some(let record):
            guard record.owner == .agent else { return .user }
            // The agent owns the text only while the truth still
            // holds what it wrote. (= an edit made outside the app
            // = = the truth changed under the agent = = the agent
            // cannot prove what is there.)
            return record.hash == hash(current) ? .agent : .user
        case .none:
            // No record = a document written before this rule. = The
            // corpus copy is the only witness. = A truth that holds
            // text the corpus copy never saw = is text the user wrote.
            guard let mirrorBody else {
                // No corpus copy = no witness at all. = An unknown
                // owner is not the agent's to overwrite.
                return .user
            }
            return normalized(mirrorBody) == normalized(current) ? .agent : .user
        }
    }

    // MARK: - Recording a write

    /// Record the agent's own write (= the truth now holds the
    /// agent's text).
    ///
    /// - Parameter ownership: = whose text the truth holds after the
    ///   write. = `.user` when the write ADDED to the user's text,
    ///   = so the truth still holds it, = and the record must keep
    ///   saying so (= the agent may add to that document, = but may
    ///   never replace any of it).
    /// - Returns: whether the record was written. = The caller keeps
    ///   the corpus copy unwritten when it was not, = so a corpus copy
    ///   that agrees with the truth never stands in for a record.
    @discardableResult
    static func recordAgentWrite(
        id: UUID,
        bodyMarkdown: String,
        ownership: Ownership,
        referenceLibraryRoot: URL
    ) -> Bool {
        let owner: ReferenceWriteRecord.Owner = (ownership == .user) ? .user : .agent
        return writeRecord(
            ReferenceWriteRecord(owner: owner, hash: hash(bodyMarkdown)),
            id: id,
            referenceLibraryRoot: referenceLibraryRoot
        )
    }

    /// Record the editor's save (= the truth now holds the user's
    /// text).
    ///
    /// **⇒ The record names the text the TRUTH holds.** = The editor
    /// wrote the truth itself (= `tab.draft`), = so the truth on the
    /// disk is the authority on what the user wrote, = and the
    /// caller's word is only the fallback for a truth that is not
    /// there. = A record that hashes text the truth does not hold is
    /// a record that cannot answer the next question.
    ///
    /// - Returns: whether the record was written. = The caller uses it
    ///   to keep one invariant: = **the corpus copy is written only
    ///   when the record was written.** = Without that invariant a
    ///   user's edit would leave the truth and the corpus copy
    ///   agreeing (= the editor's save writes both), = and the
    ///   no-record case would read that agreement as "the agent wrote
    ///   this" = = and the agent would overwrite the user's text.
    @discardableResult
    static func recordUserWrite(
        id: UUID,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) -> Bool {
        let truth = ReferenceBodyStore.truthURL(
            id: id,
            referenceLibraryRoot: referenceLibraryRoot
        )
        let onDisk = try? String(contentsOf: truth, encoding: .utf8)
        return writeRecord(
            ReferenceWriteRecord(owner: .user, hash: hash(onDisk ?? bodyMarkdown)),
            id: id,
            referenceLibraryRoot: referenceLibraryRoot
        )
    }

    /// Forget one document's record (= the document is gone).
    static func removeRecord(
        id: UUID,
        referenceLibraryRoot: URL
    ) {
        let url = recordURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - The record on disk

    /// Read one document's record (= `nil` when there is none).
    static func readRecord(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> ReferenceWriteRecord? {
        let url = recordURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ReferenceWriteRecord.self, from: data)
    }

    /// Write one document's record.
    ///
    /// Best-effort: = a record that cannot be written is a missing
    /// record, = and a missing record falls back to the corpus copy
    /// (= the conservative branch).
    @discardableResult
    private static func writeRecord(
        _ record: ReferenceWriteRecord,
        id: UUID,
        referenceLibraryRoot: URL
    ) -> Bool {
        let directory = recordDirectoryURL(referenceLibraryRoot: referenceLibraryRoot)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(record)
            try AtomicFileWrite.write(
                data,
                to: recordURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - The text rules

    /// Whether the proposed body ADDS to the truth instead of
    /// replacing it.
    ///
    /// = The proposed body starts with the truth's text. = That is
    /// what the `extend` verb produces (= the merge appends a section
    /// to the body it read), = so the user's text survives the write.
    static func addsTo(current: String, proposed: String) -> Bool {
        proposed.hasPrefix(current)
    }

    /// The text as it compares (= the surrounding whitespace aside).
    ///
    /// = The real library's five whitespace-only divergences are not
    /// user edits, = and one content divergence is.
    static func normalized(_ body: String) -> String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// SHA-256 of a body (= Apple's CryptoKit; = AGENTS.md §11.1
    /// forbids third-party crypto).
    static func hash(_ body: String) -> String {
        let digest = SHA256.hash(data: Data(body.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
