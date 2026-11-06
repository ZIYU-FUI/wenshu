//
//  ReferenceBodyStore.swift
//
//  Where a reference's body lives, = and the ONE place that answers.
//
//  **⇒ The corpus had two truths, = and they were both written.**
//
//  - `<ws>/reference-library/<layer>/<uuid>.md` = the layer copy.
//  - `<ws>/references/<uuid>.md` = the single-file copy
//    (= `referenceFileURL`, = the location the 2026-10-14
//    "doc-truth-git" ticket named, = and the one the editor's
//    auto-save writes).
//
//  Measured against the user's real library: = **six documents, = six
//  divergent pairs** (= every one of them), = `references/` newer in
//  every case, = and one of them differing in CONTENT (= the user
//  edited it in the editor). = The other five differ only by a
//  leading newline.
//
//  **⇒ The three ways that divergence bites:**
//
//  1. **The agent's write is invisible.** = In production the store
//     has no SwiftData container, = so the write path writes the
//     LAYER copy, = while the read path prefers the single-file copy.
//     **⇒ A document the agent just wrote reads back as the older
//     text.**
//  2. **A deleted document's body stays on disk.** = The delete path
//     removes the layer copy, = and the single-file copy survives.
//  3. **The search index is stale.** = The index is scheduled from
//     the write path. = **⇒ The editor's auto-save DOES schedule
//     one** (= `FileSystemReferenceStore.replaceReferenceByID`'s
//     file-only branch calls `scheduleSearchIndex`, = and that call
//     predates this file) = **⇒ so this was never one of the three
//     ways.** = An earlier version of this comment said the editor's
//     save did not schedule an index, = and that was false: = it was
//     written before the code was read. = **⇒ The remaining problem
//     the editor's save had was the MIRROR, = not the index** (= the
//     editor knows where the truth is and not which layer the
//     document belongs to, = so it could not write the mirror).
//
//  **⇒ The rule.** = `references/<uuid>.md` is the TRUTH. = The layer
//  copy is a MIRROR: = written whenever the truth is written, = so
//  the two cannot drift, = and read only when the truth is absent
//  (= a library that predates the truth location). = One place
//  answers "where is this body", = so the three paths cannot each
//  pick their own.
//

import Foundation

/// Where a reference's body lives.
enum ReferenceBodyStore {
    /// The truth location for one document.
    ///
    /// = `<ws>/references/<uuid>.md`. = This is the location the
    /// editor's auto-save writes, = the location the read path
    /// prefers, = and the location the doc-truth ticket named.
    nonisolated static func truthURL(
        id: UUID,
        referenceLibraryRoot: URL
    ) -> URL {
        referenceLibraryRoot
            .deletingLastPathComponent()
            .appendingPathComponent("references", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md", isDirectory: false)
    }

    /// The mirror location for one document.
    ///
    /// = `<ws>/reference-library/<layer>/<uuid>.md`. = It is written
    /// whenever the truth is written, = so a reader that walks the
    /// layer directories sees the current text.
    nonisolated static func mirrorURL(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> URL {
        referenceLibraryRoot
            .appendingPathComponent(layer.directoryName, isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md", isDirectory: false)
    }

    /// Read a body, = truth first.
    ///
    /// The mirror is the fallback, = and only when the truth is
    /// ABSENT. = A mirror that is present but older is not read: = the
    /// truth is the truth, = and the mirror is written beside it.
    nonisolated static func read(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) -> String? {
        let truth = truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        if let body = try? String(contentsOf: truth, encoding: .utf8) {
            return body
        }
        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        return try? String(contentsOf: mirror, encoding: .utf8)
    }

    /// Write a body, = to the truth and to the mirror.
    ///
    /// Both are written because the two are read by different readers,
    /// and a reader that finds one of them must find the current text.
    /// **⇒ The write is one operation, = so the two cannot drift.**
    ///
    /// **⇒ And the write is GATED.** = The truth has two writers (= the
    /// editor's save, = which is the user, = and the agent, = which is
    /// the librarian), = and the user's write wins. = So the write asks
    /// `ReferenceWriteGuard` (= the second-writer rule, = and the
    /// record of who wrote the truth) = before it lands, = and refuses
    /// the write that would replace the user's text.
    /// **⇒ The gate is HERE, = and not in one of the callers, = because
    /// every agent write reaches this function** (= the store's save /
    /// replace / upsert / import paths), = so the answer cannot be
    /// right on one path and wrong on another.
    /// **⇒ The editor does NOT come through here** (= it writes the
    /// truth itself, = and the store writes only the mirror), = so the
    /// editor is never blocked.
    nonisolated static func write(
        id: UUID,
        layer: ReferenceLayer,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        let ownership = try ReferenceWriteGuard.assertWritable(
            id: id,
            layer: layer,
            bodyMarkdown: bodyMarkdown,
            referenceLibraryRoot: referenceLibraryRoot
        )
        let truth = truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: truth.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: truth
        )

        // **⇒ The truth now holds the agent's text, = and the record
        // says so.** = Without it the next agent write could not tell
        // its own text from the user's.
        //
        // **⇒ And the record is written BEFORE the mirror.** = The
        // record names the text the TRUTH holds, = so it is true the
        // moment the truth is written. = A mirror write that failed
        // after the truth landed = = a truth with no record = = the
        // next agent write asking the corpus copy, = which is one step
        // behind. = The record is the primary witness, = and the
        // corpus copy is only the fallback for a document written
        // before this rule.
        //
        // **⇒ And the mirror is written only when the record was.**
        // = The same invariant the editor's save-through keeps: = a
        // corpus copy that AGREES with the truth, = while no record
        // names the owner, = reads as "the agent wrote this" = = and
        // the agent would overwrite the user's text. = A stale corpus
        // copy is the safe direction; = an agreeing one is not.
        let recorded = ReferenceWriteGuard.recordAgentWrite(
            id: id,
            bodyMarkdown: bodyMarkdown,
            ownership: ownership,
            referenceLibraryRoot: referenceLibraryRoot
        )

        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if recorded {
            try AtomicFileWrite.write(
                bodyMarkdown.data(using: .utf8) ?? Data(),
                to: mirror
            )
        }
    }

    /// Write ONLY the mirror.
    ///
    /// **⇒ This is the editor's path.** = The editor writes the truth
    /// location itself (= `tab.documentPath`), = and it does not know
    /// the document's layer, = so it cannot write the mirror. = The
    /// store knows the layer, = so the store writes it. = **⇒ The
    /// truth file is NOT rewritten here**: = the editor may have a
    /// watcher on it, = and rewriting a file the editor just wrote
    /// can trigger a reload it does not need.
    nonisolated static func writeMirror(
        id: UUID,
        layer: ReferenceLayer,
        bodyMarkdown: String,
        referenceLibraryRoot: URL
    ) throws {
        let mirror = mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot)
        try FileManager.default.createDirectory(
            at: mirror.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try AtomicFileWrite.write(
            bodyMarkdown.data(using: .utf8) ?? Data(),
            to: mirror
        )
    }

    /// Remove a body, = from both locations.
    ///
    /// **⇒ A delete that leaves the body on disk is not a delete.**
    nonisolated static func remove(
        id: UUID,
        layer: ReferenceLayer,
        referenceLibraryRoot: URL
    ) {
        for url in [
            truthURL(id: id, referenceLibraryRoot: referenceLibraryRoot),
            mirrorURL(id: id, layer: layer, referenceLibraryRoot: referenceLibraryRoot),
        ] where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
